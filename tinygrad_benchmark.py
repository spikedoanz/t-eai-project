"""
PYTHONPATH=./tinygrad/ python tinygrad_benchmark.py
"""
import os
import uuid
import subprocess
from typing import List, Any
from itertools import product, chain

# variables from examples/llama3.py
AVAILABLE_MODELS    = [ None ]
AVAILABLE_SIZES     = [("--size", _) for _ in ["1B", "8B", "70B", "405B"]]
# --shard is skipped
# --temperature is skipped
AVAILABLE_QUANTS    = [()] + [("--quantize", _) for _ in ["int8", "nf4", "float16", "fp8"]]

# variables to sweep over
SSEEDS  = [("--seed", str(_)) for _ in [42]]
SSIZES  = [("--size", _) for _ in ["1B"]]
SQUANTS = [()] + [("--quantize", _) for _ in ["int8", "nf4", "float16", "fp8"]]

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

# 4. pretty print for dry run
for config in configs:
  command = ["python", "examples/llama3.py"] + list(chain.from_iterable(config)) + ["--benchmark"]
  print(command)

# 5. actually run, and save output to file
os.makedirs("benchmark_output", exist_ok=True)

num_runs = len(configs)
for config in configs[:num_runs]:
  filename, metadata = config_to_filename_and_metadata(config)
  command = ["python", "tinygrad/examples/llama3.py"] + list(chain.from_iterable(config)) + ["--benchmark"]
  env = os.environ.copy()
  env["PYTHONPATH"] = "./tinygrad/"
  
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
