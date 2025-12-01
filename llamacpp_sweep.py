"""
Sweep verifiers benchmarks across different quantization options using llama.cpp backend.

Usage:
    python llamacpp_sweep.py
    python llamacpp_sweep.py --env gsm8k --num-examples 10
    python llamacpp_sweep.py --env gsm8k --num-examples 20 --size 1B
"""
import sys
# Unbuffered output
sys.stdout.reconfigure(line_buffering=True)
sys.stderr.reconfigure(line_buffering=True)

import argparse
import subprocess
import time
import json
import os
from datetime import datetime
from pathlib import Path

from tinygrad.helpers import fetch
from defaults import MODEL_DIR, MODEL_CONFIGS

QUANT_OPTIONS = ["default", "int8", "nf4", "float16"]
BACKEND_PORT = 8080


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


def get_model_path(quantize: str, size: str = "1B") -> Path:
    """Get path to GGUF model file, downloading if necessary."""
    model_config = MODEL_CONFIGS[quantize]
    model_url = model_config["url"]
    model_suffix = model_config["suffix"]

    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    model_path = MODEL_DIR / f"Llama-3.2-{size}-Instruct-{model_suffix}.gguf"

    if not model_path.exists():
        print(f"Downloading {model_path}...")
        fetch(model_url, name=model_path)

    return model_path


def run_benchmark(env: str, num_examples: int, max_tokens: int, port: int = None, max_concurrent: int = 1) -> dict:
    """Run vf-eval and capture results."""
    if port is None:
        port = BACKEND_PORT
    cmd = [
        "uv", "run", "vf-eval", env,
        "-m", "local",
        "-b", f"http://localhost:{port}/v1",
        "-n", str(num_examples),
        "-r", "1",
        "-t", str(max_tokens),
        "-c", str(max_concurrent),  # Max concurrent requests
        "--save-results",  # Persist runs to database for vf-tui
    ]

    env_vars = os.environ.copy()
    env_vars["OPENAI_API_KEY"] = "dummy"

    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        env=env_vars,
        timeout=None  # No timeout - let it run as long as needed
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


def run_sweep(env: str, num_examples: int, max_tokens: int, size: str, port: int = None, max_concurrent: int = 1):
    """Run benchmark sweep across all quantization options."""
    if port is None:
        port = BACKEND_PORT
    results = []
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    for quant in QUANT_OPTIONS:
        print(f"\n{'='*60}")
        print(f"Running benchmark with quantization: {quant}")
        print(f"{'='*60}")

        # Get model path (downloads if necessary)
        model_path = get_model_path(quant, size)

        # Build llama-server command
        server_cmd = [
            "./deps/llama.cpp/build/bin/llama-server",
            "-m", str(model_path),
            "--host", "0.0.0.0",
            "--port", str(port),
        ]

        # Start llama-server
        print("Starting llama-server...")
        print(f"Model: {model_path}")
        server_proc = subprocess.Popen(
            server_cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )

        try:
            # Wait for server to load
            print(f"Waiting for server on port {port}...")
            if not wait_for_server(port, timeout=180):
                print(f"ERROR: Server failed to start for quant={quant}")
                server_proc.terminate()
                continue
            print("Server ready!")

            # Run benchmark (direct connection, no proxy needed)
            print(f"Running {env} benchmark with {num_examples} examples (max_concurrent={max_concurrent})...")
            start_time = time.time()
            bench_result = run_benchmark(env, num_examples, max_tokens, port, max_concurrent)
            elapsed = time.time() - start_time

            # Parse results
            metrics = parse_results(bench_result["stdout"] + bench_result["stderr"])

            result_entry = {
                "quantization": quant,
                "size": size,
                "environment": env,
                "num_examples": num_examples,
                "max_tokens": max_tokens,
                "metrics": metrics,
                "elapsed_seconds": elapsed,
                "returncode": bench_result["returncode"],
                "timestamp": datetime.now().isoformat(),
                "backend": "llamacpp",
                "stdout": bench_result["stdout"][-1000:] if bench_result["stdout"] else "",  # Last 1000 chars
                "stderr": bench_result["stderr"][-1000:] if bench_result["stderr"] else "",  # Last 1000 chars
            }
            results.append(result_entry)

            # Print summary
            print(f"\nResults for {quant}:")
            print(f"  Time: {elapsed:.1f}s")
            print(f"  Return code: {bench_result['returncode']}")

            if bench_result['returncode'] != 0:
                print(f"  ERROR: vf-eval failed!")
                if bench_result['stderr']:
                    print(f"  Last stderr output:\n{bench_result['stderr'][-500:]}")

            for name, vals in metrics.items():
                if isinstance(vals, dict):
                    print(f"  {name}: avg={vals['avg']:.3f}, std={vals['std']:.3f}")
                else:
                    print(f"  {name}: {vals}")

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
    output_file = output_dir / f"llamacpp_sweep_{env}_{size}_{timestamp}.json"

    with open(output_file, "w") as f:
        json.dump(results, f, indent=2)

    print(f"\n{'='*60}")
    print(f"Sweep complete! Results saved to {output_file}")
    print(f"{'='*60}")

    # Print summary table
    print("\nSummary:")
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
    parser = argparse.ArgumentParser(description="Sweep verifiers benchmarks across quantization options (llama.cpp backend)")
    parser.add_argument("--env", default="gsm8k", help="Verifiers environment to benchmark")
    parser.add_argument("--num-examples", "-n", type=int, default=5, help="Number of examples per run")
    parser.add_argument("--max-tokens", "-t", type=int, default=512, help="Max tokens to generate")
    parser.add_argument("--size", default="1B", choices=["1B", "8B", "70B", "405B"], help="Model size")
    parser.add_argument("--quant", choices=QUANT_OPTIONS, help="Run single quantization instead of full sweep")
    parser.add_argument("--port", type=int, default=8080, help="Port for llama-server")
    parser.add_argument("--max-concurrent", "-c", type=int, default=1, help="Maximum concurrent requests to backend")
    args = parser.parse_args()

    try:
        if args.quant:
            # Run single quantization
            # Modify QUANT_OPTIONS to run only the specified one
            original_quant_options = QUANT_OPTIONS.copy()
            QUANT_OPTIONS.clear()
            QUANT_OPTIONS.append(args.quant)

            run_sweep(args.env, args.num_examples, args.max_tokens, args.size, args.port, args.max_concurrent)

            # Restore original
            QUANT_OPTIONS.clear()
            QUANT_OPTIONS.extend(original_quant_options)
        else:
            run_sweep(args.env, args.num_examples, args.max_tokens, args.size, args.port, args.max_concurrent)
    except KeyboardInterrupt:
        print("\nSweep interrupted by user")
        sys.exit(1)
