"""
Run llama-bench sweep over configs similar to tinygrad_benchmark.py
"""
import os
import uuid
import subprocess
import json
from typing import List, Any
from itertools import product, chain

# variables from tinygrad_benchmark.py
SSEEDS  = [("--seed", str(_)) for _ in [42]]
SSIZES  = [("--size", _) for _ in ["1B"]]
SQUANTS = [()] + [("--quantize", _) for _ in ["int8", "nf4", "float16"]]

SVARS   = [SSEEDS, SSIZES, SQUANTS]

# Map quantize to GGUF model URLs for 1B model
MODEL_URLS = {
    "default": "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q6_K.gguf",
    "int8": "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q8_0.gguf",
    "nf4": "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf",
    "float16": "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-F16.gguf",
}

def whoami():
    import platform
    import getpass
    import socket
    return {
        "platform": platform.system(),
        "release": platform.release(),
        "device": "CPU",  # llama-bench typically runs on CPU
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

# 4. pretty print for dry run
for config in configs:
    model_key = config[2][1] if len(config) > 2 and config[2] else "default"
    print(f"Config: {config}, Model: {model_key}")

# 5. actually run, and save output to file
os.makedirs("benchmark_output", exist_ok=True)

num_runs = len(configs)
for config in configs[:num_runs]:
    filename, metadata = config_to_filename_and_metadata(config)
    quantize = metadata['config']['quantize']
    model_url = MODEL_URLS[quantize]
    
    # Download model if not exists
    model_filename = f"Llama-3.2-1B-Instruct-{quantize.upper()}.gguf"
    if not os.path.exists(model_filename):
        print(f"Downloading {model_filename}...")
        subprocess.run(["wget", "-O", model_filename, model_url], check=True)
    
    # Run llama-bench
    command = [
        "./llama.cpp/build/bin/llama-bench",  # Adjust path as needed
        "-m", model_filename,
        "-p", "0",  # no prompt
        "-n", "20",  # generate 20 tokens, matching tinygrad --benchmark-len
        "-r", "5",  # repetitions
        "-o", "jsonl"
    ]
    
    try:
        with open(f"benchmark_output/{filename}", "w") as f:
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
