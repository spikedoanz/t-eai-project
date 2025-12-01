# Running Benchmarks on Pixel 7/8

This guide explains how to run LLM inference benchmarks on your Pixel device after completing the setup via `pixel7_setup.sh`.

## Prerequisites

Before running benchmarks, ensure you have:
- [ ] Completed setup via `setup/pixel7_setup.sh`
- [ ] SSH access configured (for remote execution)
- [ ] At least 5GB free storage (for models)
- [ ] Stable power supply (benchmarks can take 30-60 minutes)
- [ ] Recommended: Connect to charger during benchmarking

## Quick Start

The easiest way to run the complete benchmark suite:

```bash
cd ~/t-eai-project
./pixel_benchmark_wrapper.sh
```

This will:
1. Run performance benchmarks (all quantizations)
2. Run accuracy evaluation (GSM8K with 20 examples)
3. Collate results into CSV format
4. Package results for transfer to host

### Quick Mode (Faster)

For faster testing with fewer examples:

```bash
./pixel_benchmark_wrapper.sh --quick
```

This runs with only 5 examples instead of 20 (completes in ~10-15 minutes).

### Performance-Only Mode

To skip accuracy evaluation and only run performance benchmarks:

```bash
./pixel_benchmark_wrapper.sh --no-accuracy
```

---

## Manual Benchmark Execution

For more control over the benchmarking process, you can run each step manually.

### Step 0: Set Environment Variables

Before running any benchmarks, ensure your environment is configured:

```bash
# OpenCL GPU configuration
export LD_LIBRARY_PATH=/system/vendor/lib64:$LD_LIBRARY_PATH
export PYOPENCL_CTX=0
export PYOPENCL_PLATFORM=0

# Python path for tinygrad
export PYTHONPATH="$HOME/t-eai-project/deps/tinygrad:$PYTHONPATH"

# Navigate to project directory
cd ~/t-eai-project
```

> **Tip**: These variables are automatically added to `~/.bashrc` by the setup script, so they persist across sessions.

### Step 1: Performance Benchmarks

Run inference performance benchmarks across all quantization methods:

```bash
python3 llamacpp_benchmark.py
```

This will:
- Test 4 quantization methods: default (Q6_K), int8 (Q8_0), nf4 (Q4_K_M), float16 (f16)
- Download models automatically if not present (~6GB total)
- Generate 20 tokens per quantization with 5 repetitions
- Save raw results to `benchmark_output/llamacpp_*.txt`

**Expected time**: 5-10 minutes

**Output files**:
```
benchmark_output/
├── llamacpp_localhost_1B_default_seed42_uuid*.txt
├── llamacpp_localhost_1B_int8_seed42_uuid*.txt
├── llamacpp_localhost_1B_nf4_seed42_uuid*.txt
└── llamacpp_localhost_1B_float16_seed42_uuid*.txt
```

### Step 2: Accuracy Evaluation

Evaluate model accuracy on downstream tasks using the verifiers framework:

```bash
python3 llamacpp_sweep.py --env gsm8k --num-examples 20 --size 1B
```

**Parameters**:
- `--env gsm8k`: Task environment (grade school math problems)
- `--num-examples 20`: Number of test examples per quantization
- `--size 1B`: Model size (1B, 8B, 70B, or 405B)

**Expected time**: 40-80 minutes (depends on number of examples)

**Output files**:
```
verifiers_results/
└── llamacpp_sweep_gsm8k_1B_20251130_123456.json
```

#### Other Available Environments

The verifiers framework supports multiple evaluation tasks:

```bash
# Math problems (more challenging)
python3 llamacpp_sweep.py --env math --num-examples 10

# Graduate-level science questions
python3 llamacpp_sweep.py --env gpqa --num-examples 10

# Fact-checking
python3 llamacpp_sweep.py --env simpleqa --num-examples 20

# Word game
python3 llamacpp_sweep.py --env wordle --num-examples 10
```

### Step 3: Collate Results

Combine all raw benchmark outputs into a structured CSV file:

```bash
python3 llamacpp_collate.py
```

**Output**:
```
benchmark_output/llamacpp.csv
```

This CSV contains standardized columns:
- `step`: Token generation step
- `tokens_per_sec`: Primary performance metric
- `total_latency_ms`: Generation latency
- `memory_throughput_gb_s`: Memory bandwidth
- `param_throughput_gb_s`: Parameter throughput
- `quantize`: Quantization method
- `hostname`, `platform`, `device`: System metadata
- `uuid`, `seed`: Reproducibility identifiers

### Step 4: Transfer Results to Host

#### Option A: Using croc (Recommended)

Fastest and easiest method:

```bash
# Package results
tar -czf results_$(date +%Y%m%d).tar.gz benchmark_output/ verifiers_results/

# Send via croc
croc send results_*.tar.gz
```

On your host machine:
```bash
croc <code-from-pixel>
```

#### Option B: Using SCP over SSH

From your host machine:

```bash
# Replace <pixel-ip> with your Pixel's IP or Tailscale address
scp -P 8022 u0_a190@<pixel-ip>:~/t-eai-project/benchmark_output/*.txt ./
scp -P 8022 u0_a190@<pixel-ip>:~/t-eai-project/verifiers_results/*.json ./
```

#### Option C: Using rsync

For incremental transfers (only copies new/changed files):

```bash
rsync -avz -e "ssh -p 8022" \
    u0_a190@<pixel-ip>:~/t-eai-project/benchmark_output/ \
    ./pixel_benchmark_results/
```

---

## Customization

### Running Specific Quantizations Only

To test only one quantization method, modify `llamacpp_benchmark.py`:

```python
# Edit lines 20-21
SQUANTS = [()] + [("--quantize", _) for _ in ["nf4"]]  # Only NF4
```

Or use `llamacpp_sweep.py` with the `--quant` flag:

```bash
python3 llamacpp_sweep.py --env gsm8k --num-examples 20 --quant nf4
```

### Adjusting Number of Examples

For faster testing:
```bash
# Quick test with 5 examples
python3 llamacpp_sweep.py --env gsm8k --num-examples 5

# Standard test with 20 examples
python3 llamacpp_sweep.py --env gsm8k --num-examples 20

# Thorough test with 100 examples
python3 llamacpp_sweep.py --env gsm8k --num-examples 100
```

### Using Different Model Sizes

If you have storage for larger models:

```bash
# 8B model (requires ~16GB storage)
python3 llamacpp_benchmark.py --size 8B
python3 llamacpp_sweep.py --env gsm8k --num-examples 10 --size 8B
```

> **Warning**: Larger models may cause out-of-memory errors on Pixel devices. Stick with 1B for reliable results.

---

## Expected Output

### Performance Benchmark Results

After running `llamacpp_benchmark.py`, you should see output like:

```
Config: (('--seed', '42'), ('--size', '1B'), ()), Model: default
Config: (('--seed', '42'), ('--size', '1B'), ('--quantize', 'int8')), Model: int8
Config: (('--seed', '42'), ('--size', '1B'), ('--quantize', 'nf4')), Model: nf4
Config: (('--seed', '42'), ('--size', '1B'), ('--quantize', 'float16')), Model: float16
```

### Accuracy Evaluation Results

After running `llamacpp_sweep.py`, you'll see a summary table:

```
Summary:
Quant        Reward Avg   Format Avg   Time (s)
--------------------------------------------------
default      0.200        1.000        69.7
int8         0.250        1.000        54.5
nf4          0.200        1.000        47.3
float16      0.150        1.000        54.0
```

**Metrics explained**:
- **Reward Avg**: Correctness score (0.0 - 1.0, higher is better)
- **Format Avg**: Response format validity (should be 1.0)
- **Time (s)**: Total evaluation time in seconds

### CSV Output Structure

The `llamacpp.csv` file contains rows like:

```csv
step,enqueue_latency_ms,total_latency_ms,tokens_per_sec,memory_throughput_gb_s,param_throughput_gb_s,...
0,0.0,0.0,41.3,5.2,82.6,Darwin,25.0.0,Metal,spike,localhost,1B,default,42,uuid12345
1,24.1,24.1,41.5,5.3,83.0,...
2,23.9,48.0,41.8,5.3,83.6,...
```

---

## Performance Monitoring

### Monitoring Benchmark Progress

In a separate SSH session, monitor progress:

```bash
# Watch CPU/memory usage
top

# Monitor GPU usage (if available)
cat /sys/class/kgsl/kgsl-3d0/gpubusy_percentage

# Tail benchmark output
tail -f benchmark_output/llamacpp_*.txt
```

### Estimated Completion Times

Based on Pixel 7 performance:

| Task | Examples | Expected Time |
|------|----------|---------------|
| Performance benchmark | All quantizations | 5-10 min |
| GSM8K accuracy | 5 examples | 10-20 min |
| GSM8K accuracy | 20 examples | 40-80 min |
| GSM8K accuracy | 100 examples | 3-7 hours |
| Full benchmark suite | Default config | 45-90 min |

---

## Tips and Best Practices

### Performance Optimization

1. **Close other apps**: Free up memory by closing background apps
2. **Use charger**: Prevent thermal throttling from battery drain
3. **Cool device**: Allow device to cool between runs for consistent results
4. **Airplane mode**: Disable notifications to reduce interruptions

### Storage Management

Models consume significant storage:
```
models/
├── Llama-3.2-1B-Instruct-Q6_K.gguf     # ~1.2GB (default)
├── Llama-3.2-1B-Instruct-Q8_0.gguf     # ~1.5GB (int8)
├── Llama-3.2-1B-Instruct-Q4_K_M.gguf   # ~800MB (nf4)
└── Llama-3.2-1B-Instruct-f16.gguf      # ~2.5GB (float16)
```

To free space after benchmarking:
```bash
# Remove individual models
rm models/Llama-3.2-1B-Instruct-f16.gguf

# Keep only nf4 (smallest, good performance)
cd models && ls | grep -v nf4 | grep -v Q4_K_M | xargs rm

# Remove all models (will re-download on next run)
rm -rf models/*.gguf
```

### Reproducibility

For reproducible results:
- Same seed is used by default (42)
- UUID tracking ensures run uniqueness
- Hostname and timestamp in output filenames
- All metadata saved in result files

---

## Next Steps

After completing benchmarks:

1. **Visualize results** (on host machine after transfer):
   ```bash
   python3 visualize_benchmarks.py
   python3 generate_plots.py
   ```

2. **Analyze performance trends**:
   ```bash
   python3 benchmark_analysis.py
   ```

3. **View accuracy details** (interactive):
   ```bash
   uv run vf-tui
   ```

4. **Share results** with the community by submitting data to the project repository

---

## Troubleshooting

If you encounter issues during benchmarking, see [PIXEL-TROUBLESHOOTING.md](./PIXEL-TROUBLESHOOTING.md) for detailed solutions.

Common issues:
- **Out of memory**: Use more aggressive quantization (nf4) or smaller models
- **Models not downloading**: Check internet connection and storage space
- **Slow performance**: Verify GPU is being used (check LD_LIBRARY_PATH)
- **Import errors**: Ensure PYTHONPATH includes tinygrad directory

For detailed troubleshooting steps, refer to the comprehensive troubleshooting guide.
