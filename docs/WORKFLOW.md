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

## Device-Specific Setup

### Android (Pixel 7/8) Bootstrap

The Pixel devices require additional setup for benchmarking.

> **Quick Setup**: Use the automated setup script for complete installation:
> ```bash
> bash <(curl -sL https://raw.githubusercontent.com/spikedoanz/t-eai-project/master/setup/pixel7_setup.sh)
> ```
>
> **Documentation**:
> - **Automated setup**: `setup/pixel7_setup.sh` (recommended)
> - **Benchmark guide**: `setup/PIXEL-BENCHMARK.md`
> - **Troubleshooting**: `setup/PIXEL-TROUBLESHOOTING.md`
> - **SSH-only setup**: `setup/PIXEL-SSH.md`
>
> The sections below provide manual setup instructions for reference.

**Prerequisites:**
- Pixel 7 or Pixel 8 device
- Termux installed from F-Droid (NOT Play Store - Play Store version lacks full capabilities)
- Tailscale (optional, for easier remote access)
- At least 10GB free storage for models

#### 1. Install Termux
```bash
# Install Termux from F-Droid (not Play Store)
# F-Droid version has full package access
```

#### 2. Bootstrap Termux Environment
```bash
# Update packages
pkg update && pkg upgrade

# Install essential tools
pkg install python git openssh cmake clang ninja

# Install uv for Python environment management
curl -LsSf https://astral.sh/uv/install.sh | sh

# Add to PATH
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

#### 3. Setup SSH Access

**Option A: Using Tailscale (Recommended)**
```bash
# 1. Install Tailscale on Pixel from Play Store
# 2. Add device to your tailnet
# 3. On Pixel (Termux):
pkg install openssh
sshd
passwd  # Set password for SSH

# 4. Get username
id  # Will show something like u0_a190

# 5. On host machine:
tailscale status  # Find Pixel IP
ssh u0_a190@<tailscale-ip> -p 8022
```

**Option B: Local Network**
```bash
# On Pixel (Termux)
pkg install openssh
sshd  # Start SSH daemon
passwd  # Set password

# Get IP address
ifconfig wlan0  # Look for inet address

# On host machine
ssh u0_a190@<pixel-ip> -p 8022
```

#### 4. Install File Transfer Tools

**Install croc via Go (Termux)**
```bash
# Install Go compiler
pkg install golang

# Add Go bin to PATH
echo 'export PATH=$PATH:~/go/bin' >> ~/.bashrc
exec bash

# Install croc
go install github.com/schollz/croc/v10@latest

# Verify installation
croc --version
```

**Using croc for transfers:**
```bash
# On host (send files)
croc send model.gguf

# On Pixel (receive files)
croc <code-from-host>
```

#### 5. Setup OpenCL for GPU Acceleration
```bash
# Install OpenCL libraries (Pixel 7/8 has Adreno GPU)
pkg install opencl-headers opencl-vendor-driver

# Set library path for tinygrad
export LD_LIBRARY_PATH=/system/vendor/lib64:$LD_LIBRARY_PATH

# For Pixel 7 specifically (older OpenCL)
export PYOPENCL_CTX=0
export PYOPENCL_PLATFORM=0
```

#### 6. Clone Repository
```bash
cd ~
git clone https://github.com/spikedoanz/t-eai-project.git
cd t-eai-project

# Setup Python environment
uv venv
source .venv/bin/activate
uv pip install -r requirements.txt
```

#### 7. Transfer Models to Pixel

**Option A: Using croc (fast, encrypted)**
```bash
# On host machine
croc send ~/.cache/huggingface/hub/models--meta-llama--Llama-3.2-1B-Instruct

# On Pixel
croc <code-from-host>
```

**Option B: Using rsync over SSH**
```bash
# From host to Pixel
rsync -avz -e "ssh -p 8022" \
    ~/.cache/huggingface/hub/models--meta-llama--Llama-3.2-1B-Instruct \
    u0_a190@<pixel-ip>:~/t-eai-project/models/
```

**Option C: Direct download on Pixel**
```bash
# On Pixel (if you have enough space)
huggingface-cli download meta-llama/Llama-3.2-1B-Instruct
```

#### 8. Build llama.cpp for Android

```bash
cd deps/llama.cpp

# Install build dependencies
pkg install cmake clang ninja

# Build with OpenCL backend
mkdir build && cd build
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_OPENCL=ON \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++
cmake --build . --config Release -j$(nproc)

# Verify build
./bin/llama-cli --version
```

#### 9. Setup tinygrad for OpenCL

```bash
# Clone tinygrad
cd ~/t-eai-project/deps
git clone https://github.com/tinygrad/tinygrad.git

# Set environment variables (add to ~/.bashrc)
export PYTHONPATH=~/t-eai-project/deps/tinygrad:$PYTHONPATH
export GPU=1
export OPENCL=1
export LD_LIBRARY_PATH=/system/vendor/lib64:$LD_LIBRARY_PATH
```

#### 10. Verify GPU Access

```bash
# Test OpenCL
python -c "import pyopencl as cl; print(cl.get_platforms())"

# Test tinygrad GPU
PYTHONPATH=./deps/tinygrad python -c "from tinygrad import Device; print(Device.DEFAULT)"
```

### Pixel Benchmark Workflow

Once setup is complete, running benchmarks on Pixel:

```bash
# SSH into Pixel
ssh u0_a190@<pixel-ip> -p 8022

# Navigate to project
cd ~/t-eai-project
source .venv/bin/activate

# Set OpenCL environment
export LD_LIBRARY_PATH=/system/vendor/lib64:$LD_LIBRARY_PATH
export GPU=1
export OPENCL=1

# Run tinygrad benchmark
PYTHONPATH=./deps/tinygrad python tinygrad_benchmark.py \
    --size 1B \
    --quantize nf4 \
    --seed 42

# Run llama.cpp benchmark
python llamacpp_benchmark.py \
    --size 1B \
    --quantize nf4 \
    --seed 42

# Transfer results back to host
croc send benchmark_output/*.txt
```

### MacBook Workflow

Much simpler - Metal backend works out of the box:

```bash
# Clone repo
git clone https://github.com/spikedoanz/t-eai-project.git
cd t-eai-project

# Setup environment
uv venv
source .venv/bin/activate
uv pip install -r requirements.txt

# Download models
huggingface-cli download meta-llama/Llama-3.2-1B-Instruct

# Run benchmarks (Metal automatically detected)
PYTHONPATH=./deps/tinygrad python tinygrad_benchmark.py --size 1B
python llamacpp_benchmark.py --size 1B
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

## Troubleshooting

### Pixel-Specific Issues

#### OpenCL Not Found
```bash
# Check if OpenCL libraries exist
ls /system/vendor/lib64/libOpenCL*

# If missing, install vendor driver
pkg install opencl-vendor-driver

# Set library path
export LD_LIBRARY_PATH=/system/vendor/lib64:$LD_LIBRARY_PATH

# Verify
python -c "import pyopencl as cl; print(cl.get_platforms())"
```

#### SSH Connection Refused
```bash
# On Pixel, restart sshd
pkill sshd
sshd

# Check if running
pgrep sshd

# Get correct IP
ifconfig wlan0 | grep inet
```

#### Out of Memory on Pixel
```bash
# Check available memory
free -h

# Reduce batch size in benchmark scripts
# Edit tinygrad_benchmark.py or llamacpp_benchmark.py
# Set smaller context window or use more aggressive quantization
```

#### Slow File Transfers
```bash
# Use croc instead of scp/rsync (much faster)
# On host
croc send large_model.gguf

# On Pixel
croc <code>

# Or use compression with rsync
rsync -avz --compress-level=9 -e "ssh -p 8022" \
    model.gguf u0_a190@<pixel-ip>:~/models/
```

#### Termux Packages Won't Install
```bash
# Clear package cache
pkg clean

# Update repositories
pkg update

# If still failing, try from different mirror
pkg install -o Dir::Etc::sourcelist=/data/data/com.termux/files/usr/etc/apt/sources.list.d/termux.list <package>
```

#### GPU Not Detected by tinygrad
```bash
# Check environment variables
echo $GPU
echo $OPENCL
echo $LD_LIBRARY_PATH

# Should output:
# 1
# 1
# /system/vendor/lib64:...

# Test OpenCL directly
python -c "
import pyopencl as cl
platforms = cl.get_platforms()
for p in platforms:
    print(f'Platform: {p.name}')
    devices = p.get_devices()
    for d in devices:
        print(f'  Device: {d.name}')
"
```

#### llama.cpp Build Fails
```bash
# Make sure you have all dependencies
pkg install cmake clang ninja git

# Clean build directory
rm -rf build
mkdir build && cd build

# Try with explicit compiler flags
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_OPENCL=ON \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_CXX_FLAGS="-march=native"

# Build with verbose output
cmake --build . --config Release -j$(nproc) --verbose
```

### General Issues

#### CSV Files Not Generated
```bash
# Check if raw .txt logs exist
ls benchmark_output/*.txt

# Run collation script manually
python tinygrad_collate.py
python llamacpp_collate.py

# Check for errors in logs
tail -n 50 benchmark_output/*.txt
```

#### Plots Not Showing Up
```bash
# Make sure matplotlib is installed
uv pip install matplotlib

# Regenerate plots
python generate_plots.py
python generate_additional_plots.py

# Check output directory
ls -lh plots/
```

#### Model Download Fails on Pixel
```bash
# Use smaller chunks
huggingface-cli download meta-llama/Llama-3.2-1B-Instruct \
    --max-workers 2 \
    --resume-download

# Or download on host and transfer
# On host:
huggingface-cli download meta-llama/Llama-3.2-1B-Instruct
croc send ~/.cache/huggingface/hub/models--meta-llama--Llama-3.2-1B-Instruct

# On Pixel:
croc <code>
```

## Notes

- **UUIDs**: Each benchmark run gets a unique UUID for tracking
- **Seeds**: Set to 42 for reproducibility
- **Metadata**: Captured automatically (hostname, platform, device)
- **Incremental**: New runs append to existing CSVs
- **Idempotent**: Plots regenerate from CSV data any time
- **Pixel Setup**: Initial setup takes ~1-2 hours, but only needed once
- **File Transfers**: Use croc for large files (models), much faster than scp
- **SSH Persistence**: sshd on Termux may need restart after device sleep
