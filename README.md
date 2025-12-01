


## Getting Started

### Pixel 7/8 Devices (Android/Termux)

For Pixel devices, use the automated setup script:

```bash
# In Termux (installed from F-Droid)
bash <(curl -sL https://raw.githubusercontent.com/spikedoanz/t-eai-project/master/setup/pixel7_setup.sh)
```

After setup completes, run benchmarks with:
```bash
cd ~/t-eai-project
./pixel_benchmark_wrapper.sh
```

**Documentation**:
- [Automated Setup Script](setup/pixel7_setup.sh)
- [Benchmark Execution Guide](setup/PIXEL-BENCHMARK.md)
- [Troubleshooting Guide](setup/PIXEL-TROUBLESHOOTING.md)
- [Complete Workflow](docs/WORKFLOW.md)

### Desktop/Server Setup

### Cloning the Repository

Clone the project from GitHub using SSH authentication with recursive submodules:

```bash
git clone --recursive git@github.com:spikedoanz/t-eai-project.git
cd t-eai-project
```


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

### LLM Evaluation with Verifiers

Run downstream task benchmarks (GSM8K math problems, etc.) using the [Prime Intellect verifiers](https://github.com/PrimeIntellect-ai/verifiers) framework.

#### Initial Setup

Install verifiers and benchmark environments:

```bash
uv add verifiers
uv run vf-install gsm8k --from-repo
```

Other available environments: `math`, `gpqa`, `simpleqa`, `wordle`, `wiki-search`, etc.

#### Architecture

**Tinygrad backend:**
```
verifiers (vf-eval) → openai_proxy.py:7777 → tinygrad:7776
                      (non-streaming → streaming conversion)
```
The tinygrad server only supports streaming responses, but verifiers requires non-streaming. The proxy handles this conversion.

**llama.cpp backend:**
```
verifiers (vf-eval) → llama-server:8080
                      (direct connection, no proxy needed)
```
The llama.cpp server natively supports non-streaming responses, so no proxy is required.

#### Option 1: Tinygrad Automated Quantization Sweep

Run benchmarks across all quantization options automatically:

```bash
python verifiers_sweep.py --env gsm8k --num-examples 20 --size 1B
```

Options:
- `--env`: Verifiers environment (default: `gsm8k`)
- `--num-examples`, `-n`: Examples per quantization (default: 5)
- `--max-tokens`, `-t`: Max tokens to generate (default: 512)
- `--size`: Model size - `1B`, `8B`, `70B`, `405B` (default: `1B`)

Results are saved to `verifiers_results/sweep_<env>_<size>_<timestamp>.json`.

Example output:
```
Summary:
Quant        Reward Avg   Format Avg   Time (s)
--------------------------------------------------
default      0.000        1.000        69.7
int8         0.000        1.000        54.5
nf4          0.200        1.000        274.3
float16      0.200        1.000        54.0
```

#### Option 2: Tinygrad Manual Single Run

For running a single benchmark configuration manually:

1. Start the tinygrad server (terminal 1):

   ```bash
   PYTHONPATH=./deps/tinygrad/ python tinygrad_benchmark.py --port 7776 --size 1B
   # Add --quantize int8|nf4|float16 for quantized models
   ```

2. Start the OpenAI proxy (terminal 2):

   ```bash
   python openai_proxy.py --backend-port 7776 --proxy-port 7777
   ```

3. Run the benchmark (terminal 3):

   ```bash
   OPENAI_API_KEY=dummy uv run vf-eval gsm8k -m local -b http://localhost:7777/v1 -n 20 -r 1 -t 512
   ```

   Options:
   - `-n`: Number of examples to evaluate
   - `-r`: Rollouts per example
   - `-t`: Max tokens to generate
   - `-s`: Save results to disk
   - `-v`: Verbose output

#### Option 3: llama.cpp Automated Quantization Sweep

Run benchmarks across all quantization options automatically using the llama.cpp backend:

```bash
python llamacpp_sweep.py --env gsm8k --num-examples 20 --size 1B
```

Options:
- `--env`: Verifiers environment (default: `gsm8k`)
- `--num-examples`, `-n`: Examples per quantization (default: 5)
- `--max-tokens`, `-t`: Max tokens to generate (default: 512)
- `--size`: Model size - `1B`, `8B`, `70B`, `405B` (default: `1B`)

Results are saved to `verifiers_results/llamacpp_sweep_<env>_<size>_<timestamp>.json`.

#### Option 4: llama.cpp Manual Single Run

For running a single benchmark configuration manually:

1. Start the llama.cpp server (terminal 1):

   ```bash
   python llamacpp_benchmark.py --port 8080 --size 1B
   # Add --quantize default|int8|nf4|float16 for different quantizations
   ```

2. Run the benchmark (terminal 2):

   ```bash
   OPENAI_API_KEY=dummy uv run vf-eval gsm8k -m local -b http://localhost:8080/v1 -n 20 -r 1 -t 512
   ```

   Note: No proxy is needed for llama.cpp since it natively supports non-streaming responses.

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
> shafting this for now. build instructions are a bit too finickey.
    > "we opted to skip mlc-llm for now because of the difficulty of the build process"
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
  * on softmacs
  * on pixel 7 pro
  - on pixel 7
- repeat setup steps for A100 and H100 gpu
- collate data into multiple csvs

# 4. llm benchmarking

- expose an openai v1 compatible endpoint for each backend
? what are good benchmarks to use from verifiers?
- gather benchmarking info for those

# 5. analysis of data

? what's the schema for data?
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

# 6. slides

# 7. writeup

# 8. remaining tasks

- Implement verifiers benchmarking framework for downstream performance evaluation
- Work on detailed research writeup in arXiv preprint format
- Conduct full sweeps across all quantization strategies, models, and devices
- Scale up benchmarking to include enterprise GPUs and public data sourcing
- Prepare and deliver final presentation
- Ensure codebase is well-tested, reproducible, and released under MIT license
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


for pixel 7, to enable opencl backend, add envvars
```
export LD_LIBRARY_PATH=/vendor/lib64/egl:/vendor/lib64:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/vendor/lib64:$LD_LIBRARY_PATH
```
