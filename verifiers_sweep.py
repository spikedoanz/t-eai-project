"""
Sweep verifiers benchmarks across different quantization options.

Usage:
    python verifiers_sweep.py
    python verifiers_sweep.py --env gsm8k --num-examples 10
"""
import sys
# Unbuffered output
sys.stdout.reconfigure(line_buffering=True)
sys.stderr.reconfigure(line_buffering=True)

import argparse
import subprocess
import time
import signal
import json
import os
from datetime import datetime
from pathlib import Path

QUANT_OPTIONS = [None, "int8", "nf4", "float16"]
BACKEND_PORT = 7776
PROXY_PORT = 7777


def wait_for_server(port: int, timeout: int = 120) -> bool:
    """Wait for server to be ready."""
    import socket
    start = time.time()
    while time.time() - start < timeout:
        try:
            with socket.create_connection(("localhost", port), timeout=1):
                return True
        except (socket.timeout, ConnectionRefusedError, OSError):
            time.sleep(1)
    return False


def run_benchmark(env: str, num_examples: int, max_tokens: int) -> dict:
    """Run vf-eval and capture results."""
    cmd = [
        "uv", "run", "vf-eval", env,
        "-m", "local",
        "-b", f"http://localhost:{PROXY_PORT}/v1",
        "-n", str(num_examples),
        "-r", "1",
        "-t", str(max_tokens),
    ]

    env_vars = os.environ.copy()
    env_vars["OPENAI_API_KEY"] = "dummy"

    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        env=env_vars,
        timeout=600
    )

    return {
        "stdout": result.stdout,
        "stderr": result.stderr,
        "returncode": result.returncode
    }


def parse_results(output: str) -> dict:
    """Parse vf-eval output to extract metrics."""
    metrics = {}

    for line in output.split("\n"):
        # Parse reward lines like "reward: avg - 0.000, std - 0.000"
        if "avg -" in line and "std -" in line:
            parts = line.split(":")
            if len(parts) >= 2:
                name = parts[0].strip()
                try:
                    avg_part = line.split("avg -")[1].split(",")[0].strip()
                    std_part = line.split("std -")[1].split(",")[0].strip()
                    metrics[name] = {
                        "avg": float(avg_part),
                        "std": float(std_part)
                    }
                except (IndexError, ValueError):
                    pass

        # Parse timing
        if "Evaluation completed in" in line:
            try:
                time_str = line.split("in")[1].split("seconds")[0].strip()
                metrics["eval_time_seconds"] = float(time_str)
            except (IndexError, ValueError):
                pass

    return metrics


def run_sweep(env: str, num_examples: int, max_tokens: int, size: str):
    """Run benchmark sweep across all quantization options."""
    results = []
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    for quant in QUANT_OPTIONS:
        quant_name = quant or "default"
        print(f"\n{'='*60}")
        print(f"Running benchmark with quantization: {quant_name}")
        print(f"{'='*60}")

        # Build tinygrad server command
        server_cmd = [
            "python", "deps/tinygrad/examples/llama3.py",
            "--size", size,
            "--port", str(BACKEND_PORT),
        ]
        if quant:
            server_cmd.extend(["--quantize", quant])

        server_env = os.environ.copy()
        server_env["PYTHONPATH"] = "./deps/tinygrad/"

        # Start tinygrad server
        print(f"Starting tinygrad server...")
        server_proc = subprocess.Popen(
            server_cmd,
            env=server_env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )

        try:
            # Wait for server to load
            print(f"Waiting for server on port {BACKEND_PORT}...")
            if not wait_for_server(BACKEND_PORT, timeout=180):
                print(f"ERROR: Server failed to start for quant={quant_name}")
                server_proc.terminate()
                continue
            print(f"Server ready!")

            # Start proxy
            print(f"Starting proxy server...")
            proxy_proc = subprocess.Popen(
                ["python", "openai_proxy.py",
                 "--backend-port", str(BACKEND_PORT),
                 "--proxy-port", str(PROXY_PORT)],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
            )

            try:
                # Wait for proxy
                if not wait_for_server(PROXY_PORT, timeout=10):
                    print(f"ERROR: Proxy failed to start")
                    continue
                print(f"Proxy ready!")

                # Run benchmark
                print(f"Running {env} benchmark with {num_examples} examples...")
                start_time = time.time()
                bench_result = run_benchmark(env, num_examples, max_tokens)
                elapsed = time.time() - start_time

                # Parse results
                metrics = parse_results(bench_result["stdout"] + bench_result["stderr"])

                result_entry = {
                    "quantization": quant_name,
                    "size": size,
                    "environment": env,
                    "num_examples": num_examples,
                    "max_tokens": max_tokens,
                    "metrics": metrics,
                    "elapsed_seconds": elapsed,
                    "returncode": bench_result["returncode"],
                    "timestamp": datetime.now().isoformat(),
                }
                results.append(result_entry)

                # Print summary
                print(f"\nResults for {quant_name}:")
                print(f"  Time: {elapsed:.1f}s")
                for name, vals in metrics.items():
                    if isinstance(vals, dict):
                        print(f"  {name}: avg={vals['avg']:.3f}, std={vals['std']:.3f}")
                    else:
                        print(f"  {name}: {vals}")

            finally:
                proxy_proc.terminate()
                proxy_proc.wait(timeout=5)

        finally:
            server_proc.terminate()
            try:
                server_proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                server_proc.kill()

        # Brief pause between runs
        time.sleep(2)

    # Save results
    output_dir = Path("verifiers_results")
    output_dir.mkdir(exist_ok=True)
    output_file = output_dir / f"sweep_{env}_{size}_{timestamp}.json"

    with open(output_file, "w") as f:
        json.dump(results, f, indent=2)

    print(f"\n{'='*60}")
    print(f"Sweep complete! Results saved to {output_file}")
    print(f"{'='*60}")

    # Print summary table
    print(f"\nSummary:")
    print(f"{'Quant':<12} {'Reward Avg':<12} {'Format Avg':<12} {'Time (s)':<10}")
    print("-" * 50)
    for r in results:
        quant = r["quantization"]
        reward = r["metrics"].get("reward", {}).get("avg", "N/A")
        fmt = r["metrics"].get("format_reward_func", {}).get("avg", "N/A")
        elapsed = r["elapsed_seconds"]

        reward_str = f"{reward:.3f}" if isinstance(reward, float) else str(reward)
        fmt_str = f"{fmt:.3f}" if isinstance(fmt, float) else str(fmt)

        print(f"{quant:<12} {reward_str:<12} {fmt_str:<12} {elapsed:<10.1f}")

    return results


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Sweep verifiers benchmarks across quantization options")
    parser.add_argument("--env", default="gsm8k", help="Verifiers environment to benchmark")
    parser.add_argument("--num-examples", "-n", type=int, default=5, help="Number of examples per run")
    parser.add_argument("--max-tokens", "-t", type=int, default=512, help="Max tokens to generate")
    parser.add_argument("--size", default="1B", choices=["1B", "8B", "70B", "405B"], help="Model size")
    args = parser.parse_args()

    try:
        run_sweep(args.env, args.num_examples, args.max_tokens, args.size)
    except KeyboardInterrupt:
        print("\nSweep interrupted by user")
        sys.exit(1)
