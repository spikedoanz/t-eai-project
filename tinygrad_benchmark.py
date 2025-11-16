# PYTHONPATH=./tinygrad/ python tinygrad_benchmark.py
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

SVARS   = [SSEEDS, SSIZES, SQUANTS]

def whoami():
  import platform
  import getpass
  import socket
  from tinygrad import Device
  return {
    "platform": platform.system(), "release": platform.release(), "device": Device.default,
    "username": getpass.getuser(), "hostname": socket.gethostname()
  }

# 1. precheck that variables are valid
def is_subset(a: List, b: List) -> bool: 
  _a = [_[1] if _ else None for _ in a]; _b = [_[1] if _ else None for _ in b]
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
  
  parts = [
    whoiam['hostname'],
    config_dict['--size'],
    config_dict.get('--quantize', 'default'),  # Use 'default' when no quantize arg
    f"seed{config_dict['--seed']}",
    f"uuid{str(uuid.uuid4())[:8]}"
  ]
  filename = '_'.join(parts) + '.txt'
  metadata = {
    'config': config_dict,
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
      subprocess.run(args=command, env=env, stdout=f)
  except Exception as e:
    print(f"{command} failed with {e}")
