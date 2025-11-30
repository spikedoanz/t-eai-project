"""
Run llama-bench sweep over configs similar to tinygrad_benchmark.py

Usage:
    python llamacpp_benchmark.py                           # Run benchmarks
    python llamacpp_benchmark.py --port 8080               # Start server on port 8080
    python llamacpp_benchmark.py --port 8080 --quantize int8  # Server with specific quantization
"""
import os
import uuid
import argparse
import subprocess
from typing import List, Any
from itertools import product
from tinygrad.helpers import fetch
from defaults import MODEL_DIR, MODEL_CONFIGS

# variables from tinygrad_benchmark.py
SSEEDS  = [("--seed", str(_)) for _ in [42]]
SSIZES  = [("--size", _) for _ in ["1B"]]
SQUANTS = [()] + [("--quantize", _) for _ in ["int8", "nf4", "float16"]]

SVARS   = [SSEEDS, SSIZES, SQUANTS]

def whoami():
    import platform
    import getpass
    import socket
    return {
        "platform": platform.system(),
        "release": platform.release(),
        "device": "default",
        "username": getpass.getuser(),
        "hostname": socket.gethostname()
    }

# 1. precheck that variables are valid
def is_subset(a: List, b: List) -> bool:
    _a = [_[1] if _ else None for _ in a]
    _b = [_[1] if _ else None for _ in b]
    return set(_a) <= set(_b)

AVAILABLE_QUANTS = [()] + [("--quantize", _) for _ in ["int8", "nf4", "float16"]]
assert is_subset(SQUANTS, AVAILABLE_QUANTS)

# 2. generate benchmark commands (for subprocess)
configs = list(product(*SVARS))

# 3. generate corresponding filename for raw output
def config_to_filename_and_metadata(config) -> tuple[str, dict[str, Any]]:
    whoiam = whoami()
    config_dict = {}
    for tup in config:
        if tup:  # Skip empty tuples
            k, v = tup
            config_dict[k] = v

    normalized_config = {
        'size': config_dict['--size'],
        'quantize': config_dict.get('--quantize', 'default'),
        'seed': config_dict['--seed']
    }

    parts = [
        whoiam['hostname'],
        normalized_config['size'],
        normalized_config['quantize'],
        f"seed{normalized_config['seed']}",
        f"uuid{str(uuid.uuid4())[:8]}"
    ]
    filename = '_'.join(parts) + '.txt'
    metadata = {
        'config': normalized_config,
        'whoami': whoiam,
        'uuid': parts[-1]
    }
    return filename, metadata


def get_model_path(quantize: str, size: str = "1B") -> str:
    """Get path to GGUF model file, downloading if necessary."""
    model_config = MODEL_CONFIGS[quantize]
    model_url = model_config["url"]
    model_suffix = model_config["suffix"]

    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    model_path = MODEL_DIR / f"Llama-3.2-{size}-Instruct-{model_suffix}.gguf"

    if not model_path.exists():
        print(f"Downloading {model_path}...")
        fetch(model_url, name=model_path)

    return str(model_path)


def run_server(port: int, quantize: str, size: str = "1B"):
    """Run llama-server as an OpenAI-compatible server."""
    model_path = get_model_path(quantize, size)

    command = [
        "./deps/llama.cpp/build/bin/llama-server",
        "-m", model_path,
        "--host", "0.0.0.0",
        "--port", str(port),
    ]

    print(f"Starting llama-server on port {port}...")
    print(f"Model: {model_path}")
    print(f"Quantization: {quantize}")
    print(f"Command: {' '.join(command)}")
    print("\nOpenAI-compatible endpoints available at:")
    print(f"  POST http://localhost:{port}/v1/completions")
    print(f"  POST http://localhost:{port}/v1/chat/completions")
    print(f"  GET  http://localhost:{port}/v1/models")
    print()

    subprocess.run(args=command)


def run_benchmarks():
    """Run benchmark sweep over all configurations."""
    # 4. pretty print for dry run
    for config in configs:
        model_key = config[2][1] if len(config) > 2 and config[2] else "default"
        print(f"Config: {config}, Model: {model_key}")

    # 5. actually run, and save output to file
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    os.makedirs("benchmark_output", exist_ok=True)

    num_runs = len(configs)
    for config in configs[:num_runs]:
        filename, metadata = config_to_filename_and_metadata(config)
        quantize = metadata['config']['quantize']
        model_path = get_model_path(quantize)

        # Run llama-bench
        command = [
            "./deps/llama.cpp/build/bin/llama-bench",
            "-m", model_path,
            "-p", "0",  # no prompt
            "-n", "20",  # generate 20 tokens, matching tinygrad --benchmark-len
            "-r", "5",  # repetitions
            "-o", "jsonl"
        ]

        try:
            with open(f"benchmark_output/llamacpp_{filename}", "w") as f:
                # write metadata
                for key, value in metadata['whoami'].items():
                    f.write(f"{key}: {value}\n")
                for key, value in metadata['config'].items():
                    f.write(f"{key}: {value}\n")
                f.write(f"uuid: {metadata['uuid']}\n")
                # then run subprocess
                result = subprocess.run(args=command, capture_output=True, text=True)
                f.write(result.stdout)
                if result.stderr:
                    f.write(f"STDERR:\n{result.stderr}\n")
        except Exception as e:
            print(f"{command} failed with {e}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="llama.cpp benchmark and server runner")
    parser.add_argument("--port", type=int, help="Run as server on this port instead of benchmarking")
    parser.add_argument("--size", choices=["1B", "8B", "70B", "405B"], default="1B", help="Model size (default: 1B)")
    parser.add_argument("--quantize", choices=["default", "int8", "nf4", "float16"], default="default", help="Quantization method")
    args = parser.parse_args()

    if args.port:
        run_server(args.port, args.quantize, args.size)
    else:
        run_benchmarks()
