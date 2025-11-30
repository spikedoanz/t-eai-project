# Benchmark Workflow

This document explains the complete workflow for running benchmarks and generating visualizations.

## Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      BENCHMARK WORKFLOW                          │
└─────────────────────────────────────────────────────────────────┘

    ┌───────────────────────────────────────────────┐
    │  STEP 1: Model Preparation                    │
    │  ─────────────────────────                    │
    │  • Download base models from HuggingFace      │
    │  • Convert to backend formats:                │
    │    - llama.cpp: Convert to GGUF               │
    │    - tinygrad: Keep HF format                 │
    │    - MLC-LLM: Compile with mlc_llm            │
    │  • Apply quantization (NF4, INT8, FP16)       │
    └───────────────┬───────────────────────────────┘
                    │
                    ↓
    ┌───────────────────────────────────────────────┐
    │  STEP 2: Run Benchmarks                       │
    │  ──────────────────                           │
    │  • Execute benchmark scripts:                 │
    │    - tinygrad_benchmark.py                    │
    │    - llamacpp_benchmark.py                    │
    │    - mlc_benchmark.py                         │
    │  • Output: Raw .txt logs in benchmark_output/ │
    │  • Captures per-token metrics & metadata      │
    └───────────────┬───────────────────────────────┘
                    │
                    ↓
    ┌───────────────────────────────────────────────┐
    │  STEP 3: Collate Results                      │
    │  ───────────────────                          │
    │  • Parse raw .txt logs                        │
    │  • Extract metrics:                           │
    │    - tokens_per_sec                           │
    │    - latency_ms                               │
    │    - memory_throughput_gb_s                   │
    │  • Add metadata (UUID, hostname, quantize)    │
    │  • Output: Structured CSVs                    │
    │    - benchmark_output/tinygrad.csv            │
    │    - benchmark_output/llamacpp.csv            │
    │    - benchmark_output/mlc_llm.csv             │
    └───────────────┬───────────────────────────────┘
                    │
                    ↓
    ┌───────────────────────────────────────────────┐
    │  STEP 4: Analysis & Visualization             │
    │  ────────────────────────────                 │
    │  • Run visualization scripts:                 │
    │    - generate_plots.py                        │
    │    - generate_additional_plots.py             │
    │  • Generate 8 plots:                          │
    │    - Backend comparison                       │
    │    - Speedup analysis                         │
    │    - Performance summary                      │
    │    - Quantization impact                      │
    │    - Latency distribution                     │
    │    - Memory throughput                        │
    │    - Parameter throughput                     │
    │    - Device comparison                        │
    │  • Output: PNG files in plots/                │
    └───────────────┬───────────────────────────────┘
                    │
                    ↓
    ┌───────────────────────────────────────────────┐
    │  STEP 5: Embed in Presentation                │
    │  ─────────────────────────                    │
    │  • Copy plots to docs/images/                 │
    │  • Link in presentation.typ                   │
    │  • Compile: typst compile presentation.typ    │
    │  • Output: presentation.pdf                   │
    └───────────────────────────────────────────────┘
```

## Detailed Steps

### Step 1: Model Preparation

**For tinygrad:**
```bash
# Download from HuggingFace
huggingface-cli download meta-llama/Llama-3.2-1B-Instruct

# Tinygrad loads HF models directly, quantizes at runtime
```

**For llama.cpp:**
```bash
# Download model
huggingface-cli download meta-llama/Llama-3.2-1B-Instruct

# Convert to GGUF
python deps/llama.cpp/convert_hf_to_gguf.py \
    ~/.cache/huggingface/hub/models--meta-llama--Llama-3.2-1B-Instruct

# Quantize
deps/llama.cpp/llama-quantize \
    Llama-3.2-1B-Instruct-F16.gguf \
    Llama-3.2-1B-Instruct-Q4_K_M.gguf Q4_K_M
```

**For MLC-LLM:**
```bash
# Download model
huggingface-cli download meta-llama/Llama-3.2-1B-Instruct

# Convert weights
mlc_llm convert_weight \
    ~/.cache/huggingface/hub/models--meta-llama--Llama-3.2-1B-Instruct \
    --quantization q4f16_1 \
    -o dist/Llama-3.2-1B-Instruct-q4f16_1-MLC

# Generate config
mlc_llm gen_config \
    ~/.cache/huggingface/hub/models--meta-llama--Llama-3.2-1B-Instruct \
    --quantization q4f16_1 \
    --conv-template llama-3 \
    -o dist/Llama-3.2-1B-Instruct-q4f16_1-MLC
```

### Step 2: Run Benchmarks

**Tinygrad:**
```bash
PYTHONPATH=./deps/tinygrad/ python tinygrad_benchmark.py \
    --size 1B \
    --quantize nf4 \
    --seed 42
```

**llama.cpp:**
```bash
python llamacpp_benchmark.py \
    --size 1B \
    --quantize nf4 \
    --seed 42
```

**MLC-LLM:**
```bash
python mlc_benchmark.py \
    --size 1B \
    --quantize q4f16_1 \
    --seed 42
```

**Output Files:**
- `benchmark_output/hostname_1B_nf4_seed42_uuid{random}.txt`
- Contains raw inference logs with timing information

### Step 3: Collate Results

**Tinygrad:**
```bash
python tinygrad_collate.py
```

**llama.cpp:**
```bash
python llamacpp_collate.py
```

**Output:**
- `benchmark_output/tinygrad.csv` - All tinygrad runs
- `benchmark_output/llamacpp.csv` - All llama.cpp runs
- `benchmark_output/mlc_llm.csv` - All MLC-LLM runs

**CSV Schema:**
```csv
step,enqueue_latency_ms,total_latency_ms,tokens_per_sec,memory_throughput_gb_s,param_throughput_gb_s,generated_text,platform,release,device,username,hostname,size,quantize,seed,uuid
```

### Step 4: Generate Visualizations

**Generate main plots:**
```bash
python generate_plots.py
```

**Generate additional plots:**
```bash
python generate_additional_plots.py
```

**Output:**
- `plots/backend_comparison.png`
- `plots/speedup_comparison.png`
- `plots/summary_stats.png`
- `plots/quantization_impact.png`
- `plots/latency_distribution.png`
- `plots/memory_throughput.png`
- `plots/param_throughput.png`
- `plots/device_comparison.png`

### Step 5: Embed in Presentation

```bash
# Copy plots to presentation directory
cp plots/*.png docs/images/

# Compile presentation
typst compile presentation.typ

# Output: presentation.pdf
```

## Parallel Execution

To run benchmarks across multiple configurations in parallel:

```bash
# Sweep script for llama.cpp
python llamacpp_sweep.py  # Runs all quantizations

# Sweep script for verifiers evaluation
python verifiers_sweep.py  # Runs accuracy benchmarks
```

## Data Flow Diagram

```
Models (HF)
    ↓
Quantization
    ↓
┌─────────────┬──────────────┬─────────────┐
│  tinygrad   │  llama.cpp   │  MLC-LLM    │
│  benchmark  │  benchmark   │  benchmark  │
└──────┬──────┴──────┬───────┴──────┬──────┘
       ↓             ↓              ↓
   .txt logs     .txt logs      .txt logs
       ↓             ↓              ↓
┌──────────────────────────────────────────┐
│           Collation Scripts              │
│   tinygrad_collate.py                    │
│   llamacpp_collate.py                    │
└──────┬───────────────────────────────────┘
       ↓
   CSV files (structured data)
       ↓
┌──────────────────────────────────────────┐
│      Visualization Scripts               │
│   generate_plots.py                      │
│   generate_additional_plots.py           │
└──────┬───────────────────────────────────┘
       ↓
   PNG plots
       ↓
┌──────────────────────────────────────────┐
│         Presentation                     │
│   presentation.typ → presentation.pdf    │
└──────────────────────────────────────────┘
```

## Key Files

### Benchmark Scripts
- `tinygrad_benchmark.py` - Tinygrad inference + metrics
- `llamacpp_benchmark.py` - llama.cpp inference + metrics
- `mlc_benchmark.py` - MLC-LLM inference + metrics

### Collation Scripts
- `tinygrad_collate.py` - Parse tinygrad logs → CSV
- `llamacpp_collate.py` - Parse llama.cpp logs → CSV

### Visualization Scripts
- `generate_plots.py` - Main 4 plots
- `generate_additional_plots.py` - Supplementary 4 plots
- `visualize_benchmarks.py` - ASCII terminal visualization
- `benchmark_analysis.py` - Statistical analysis

### Sweep Scripts
- `llamacpp_sweep.py` - Automated quantization sweep
- `verifiers_sweep.py` - Automated accuracy evaluation

### Configuration
- `defaults.py` - Default benchmark parameters

## Notes

- **UUIDs**: Each benchmark run gets a unique UUID for tracking
- **Seeds**: Set to 42 for reproducibility
- **Metadata**: Captured automatically (hostname, platform, device)
- **Incremental**: New runs append to existing CSVs
- **Idempotent**: Plots regenerate from CSV data any time
