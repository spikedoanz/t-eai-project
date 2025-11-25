


## Getting Started

### Cloning the Repository

Clone the project from GitHub using SSH authentication with recursive submodules:

```bash
git clone --recursive git@github.com:username/t-eai-project.git
cd t-eai-project
```

Replace `username` with your GitHub username or the repository owner's username.

### Setup

1. Ensure you have Python 3.13 or later installed.

2. Install `uv` for environment management:

   ```bash
   pip install uv
   ```

3. Sync the environment:

   ```bash
   uv sync
   ```

4. Build llama.cpp (required for llama.cpp benchmarks):

   ```bash
   cd deps/llama.cpp
   cmake -B build
   cmake --build build --config Release
   cd ../..
   ```

5. For tinygrad, ensure it's set up (it's already in deps/, but you may need to activate its environment if necessary).

### Running Benchmarks

- To run llama.cpp benchmarks:

  ```bash
  python llamacpp_benchmark.py
  python llamacpp_collate.py
  ```

- To run tinygrad benchmarks:

  ```bash
  python tinygrad_benchmark.py
  python tinygrad_collate.py
  ```

- To visualize benchmarks:

  ```bash
  python visualize_benchmarks.py
  ```

# plan

```plan
> original slides are in docs/
> for original slides

# unsorted

* move .gguf models into a centralized directory ./models/ instead of having multiple copies
- have a generalized setup process for downloading models, cloning repos, building everything and so on.

# 1. setup
- ssh instructions into a pixel
- llama.cpp setup
- mlc-llm setup
* tinygrad setup
- (can wait until later) automatic setup script from a curl | sh

# 2. sampling pipeline
? what is the information to gather?
  > get this from slides
  * define the schema
  ? what does llama.cpp benchmark gather?
- modify above pipelines to gather said information

# 3. actually sampling

* run sweep for tinygrad
  - on softmacs
  - on pixel 7 pro
  - on pixel 7
- repeat setup steps for A100 and H100 gpu
- collate data into multiple csvs

# 4. llm benchmarking

- expose an openai v1 compatible endpoint for each backend
? what are good benchmarks to use from verifiers?
- gather benchmarking info for those

# 5. analysis of data

? what's the schema for data?
  ```python
  from typing import TypedDict
  class BenchmarkRow(TypedDict):
    step: int
    enqueue_latency_ms: float
    total_latency_ms: float
    tokens_per_sec: float
    memory_throughput_gb_s: float
    param_throughput_gb_s: float
    generated_text: str
    platform: str
    release: str
    device: str
    username: str
    hostname: str
    size: str
    quantize: str
    seed: int
    uuid: str
  ```

# 6. slides

# 7. writeup
```

for planfile syntax
```
# means section
- means todo
  - can be nested
? means question
> means comment
* means resolved
! means answered
```
