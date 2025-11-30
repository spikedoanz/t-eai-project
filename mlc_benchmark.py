"""
MLC LLM benchmark runner using Python API.

This script uses pre-compiled models from HuggingFace (mlc-ai org).
The model library is JIT compiled on first run.

Run with:
   python mlc_benchmark.py
"""
import os
import uuid
import time
import json
import platform
import getpass
import socket
from typing import Any
from itertools import product

from mlc_llm import MLCEngine

# Benchmark config - matching other benchmarks
SSEEDS = [("--seed", str(_)) for _ in [42]]
SSIZES = [("--size", _) for _ in ["1B"]]
SQUANTS = [()] + [("--quantize", _) for _ in ["q4f16_1"]]
SVARS = [SSEEDS, SSIZES, SQUANTS]

# MLC model configs - use locally compiled models
# Model lib is JIT compiled on first run
MLC_MODEL_CONFIGS = {
    "default": {
        "model": "/Users/spike/R/t-eai-project/dist/Llama-3.2-1B-Instruct-q4f16_1-MLC",
    },
    "q4f16_1": {
        "model": "/Users/spike/R/t-eai-project/dist/Llama-3.2-1B-Instruct-q4f16_1-MLC",
    },
}


def whoami():
    return {
        "platform": platform.system(),
        "release": platform.release(),
        "device": "metal",
        "username": getpass.getuser(),
        "hostname": socket.gethostname(),
    }


def config_to_filename_and_metadata(config) -> tuple[str, dict[str, Any]]:
    whoiam = whoami()
    config_dict = {}
    for tup in config:
        if tup:
            k, v = tup
            config_dict[k] = v

    normalized_config = {
        "size": config_dict["--size"],
        "quantize": config_dict.get("--quantize", "default"),
        "seed": config_dict["--seed"],
    }

    parts = [
        whoiam["hostname"],
        normalized_config["size"],
        normalized_config["quantize"],
        f"seed{normalized_config['seed']}",
        f"uuid{str(uuid.uuid4())[:8]}",
    ]
    filename = "_".join(parts) + ".txt"
    metadata = {
        "config": normalized_config,
        "whoami": whoiam,
        "uuid": parts[-1],
    }
    return filename, metadata


def run_benchmark(engine, num_tokens: int = 20, num_runs: int = 5) -> list[dict]:
    """Run benchmark and return timing stats."""
    results = []
    for i in range(num_runs):
        start = time.perf_counter()
        response = engine.chat.completions.create(
            messages=[{"role": "user", "content": "Hello, how are you today?"}],
            max_tokens=num_tokens,
        )
        elapsed = time.perf_counter() - start
        tokens = response.usage.completion_tokens
        results.append({
            "run": i + 1,
            "tokens": tokens,
            "time_s": elapsed,
            "tok_per_sec": tokens / elapsed if elapsed > 0 else 0,
        })
        print(f"  Run {i+1}: {tokens} tokens in {elapsed:.3f}s = {tokens/elapsed:.2f} tok/s")
    return results


def main():
    configs = list(product(*SVARS))

    # Dry run - print configs
    print("=== MLC LLM Benchmark Configs ===")
    for config in configs:
        quant = config[2][1] if len(config) > 2 and config[2] else "default"
        print(f"Config: {config}, Quantization: {quant}")
    print()

    os.makedirs("benchmark_output", exist_ok=True)

    for config in configs:
        filename, metadata = config_to_filename_and_metadata(config)
        quantize = metadata["config"]["quantize"]

        if quantize not in MLC_MODEL_CONFIGS:
            print(f"Skipping {quantize} - not configured")
            continue

        model_config = MLC_MODEL_CONFIGS[quantize]
        model_path = model_config["model"]

        print(f"\n=== Running benchmark: {quantize} ===")
        print(f"Model: {model_path}")

        try:
            # Initialize engine - model lib is JIT compiled automatically
            print("  Loading model (JIT compiling on first run, may take a few minutes)...")
            engine = MLCEngine(
                model=model_path,
                mode="interactive",  # Using interactive mode due to nightly bug in server mode
            )

            # Run benchmark
            results = run_benchmark(engine, num_tokens=20, num_runs=5)

            # Calculate stats
            tok_per_sec_values = [r["tok_per_sec"] for r in results]
            avg_tok_per_sec = sum(tok_per_sec_values) / len(tok_per_sec_values)
            print(f"  Average: {avg_tok_per_sec:.2f} tok/s")

            # Write output
            output_path = f"benchmark_output/mlc_{filename}"
            with open(output_path, "w") as f:
                # Write metadata
                for key, value in metadata["whoami"].items():
                    f.write(f"{key}: {value}\n")
                for key, value in metadata["config"].items():
                    f.write(f"{key}: {value}\n")
                f.write(f"uuid: {metadata['uuid']}\n")
                f.write("framework: mlc_llm\n")
                f.write("\n=== Results ===\n")
                for r in results:
                    f.write(json.dumps(r) + "\n")
                f.write(f"\navg_tok_per_sec: {avg_tok_per_sec:.2f}\n")

            print(f"  Output saved to: {output_path}")

            # Cleanup
            del engine

        except Exception as e:
            print(f"  Error: {e}")
            import traceback
            traceback.print_exc()


if __name__ == "__main__":
    main()
