"""
PYTHONPATH=./deps/tinygrad/ python tinygrad_benchmark.py
PYTHONPATH=./deps/tinygrad/ python tinygrad_benchmark.py --port 7776 --size 1B --quantize int8
"""
import os
import uuid
import argparse
import subprocess
from typing import List, Any
from itertools import product, chain

# variables from examples/llama3.py
AVAILABLE_MODELS    = [ None ]
AVAILABLE_SIZES     = [("--size", _) for _ in ["1B", "8B", "70B", "405B"]]
# --shard is skipped
# --temperature is skipped
AVAILABLE_QUANTS    = [()] + [("--quantize", _) for _ in ["int8", "nf4", "float16"]] # fp8 disabled due to lack of hardware support

# variables to sweep over
SSEEDS  = [("--seed", str(_)) for _ in [42]]
SSIZES  = [("--size", _) for _ in ["1B"]]
SQUANTS = [()] + [("--quantize", _) for _ in ["int8", "nf4", "float16"]]

# SLEN    = [20] -- number of output tokens
# SINPUT  = ["some string to pass in, or file to pass in, to test prefill"]

SVARS   = [SSEEDS, SSIZES, SQUANTS]

def whoami():
  import platform
  import getpass
  import socket
  from tinygrad.device import Device
  return {
    "platform": platform.system(), "release": platform.release(), "device": str(Device.default),
    "username": getpass.getuser(), "hostname": socket.gethostname()
  }

# 1. precheck that variables are valid
def is_subset(a: List, b: List) -> bool:
  _a = [_[1] if _ else None for _ in a]
  _b = [_[1] if _ else None for _ in b]
  return set(_a) <= set(_b)

assert is_subset(SSIZES,    AVAILABLE_SIZES)
assert is_subset(SQUANTS,   AVAILABLE_QUANTS)

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

def run_benchmarks():
  """Run benchmark sweep over all configurations."""
  # 4. pretty print for dry run
  for config in configs:
    command = ["python", "examples/llama3.py"] + list(chain.from_iterable(config)) + ["--benchmark"]
    print(command)

  # 5. actually run, and save output to file
  os.makedirs("benchmark_output", exist_ok=True)

  num_runs = len(configs)
  for config in configs[:num_runs]:
    filename, metadata = config_to_filename_and_metadata(config)
    command = ["python", "deps/tinygrad/examples/llama3.py"] + list(chain.from_iterable(config)) + ["--benchmark"]
    env = os.environ.copy()
    env["PYTHONPATH"] = "./deps/tinygrad/"

    try:
      with open(f"benchmark_output/{filename}", "w") as f:
        # write metadata
        for key, value in metadata['whoami'].items():
          f.write(f"{key}: {value}\n")
        for key, value in metadata['config'].items():
          f.write(f"{key}: {value}\n")
        f.write(f"uuid: {metadata['uuid']}\n")
        # then run subprocess
        subprocess.run(args=command, env=env, stdout=f)
    except Exception as e:
      print(f"{command} failed with {e}")


def run_server(port: int, size: str, quantize: str | None, seed: int | None):
  """Run llama3.py as an OpenAI-compatible server."""
  command = ["python", "deps/tinygrad/examples/llama3.py", "--size", size, "--port", str(port)]

  if quantize:
    command.extend(["--quantize", quantize])
  if seed is not None:
    command.extend(["--seed", str(seed)])

  env = os.environ.copy()
  env["PYTHONPATH"] = "./deps/tinygrad/"

  print(f"Starting server on port {port}...")
  print(f"Command: {' '.join(command)}")
  print(f"\nOpenAI-compatible endpoints available at:")
  print(f"  POST http://localhost:{port}/v1/completions")
  print(f"  POST http://localhost:{port}/v1/chat/completions")
  print(f"  GET  http://localhost:{port}/v1/models")
  print()

  subprocess.run(args=command, env=env)


if __name__ == "__main__":
  parser = argparse.ArgumentParser(description="Tinygrad LLaMA benchmark and server runner")
  parser.add_argument("--port", type=int, help="Run as server on this port instead of benchmarking")
  parser.add_argument("--size", choices=["1B", "8B", "70B", "405B"], default="1B", help="Model size (default: 1B)")
  parser.add_argument("--quantize", choices=["int8", "nf4", "float16"], help="Quantization method")
  parser.add_argument("--seed", type=int, default=42, help="Random seed (default: 42)")
  args = parser.parse_args()

  if args.port:
    run_server(args.port, args.size, args.quantize, args.seed)
  else:
    run_benchmarks()
