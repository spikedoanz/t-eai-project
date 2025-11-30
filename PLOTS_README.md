# Benchmark Visualization Plots

This document describes the visualization plots generated from benchmark data.

## Generated Plots

All plots are available in both locations:
- `plots/` - Original output directory
- `docs/images/` - Copied for use in presentations

### 1. Backend Comparison (`backend_comparison.png`)
Bar chart comparing performance across different backends (tinygrad, llama.cpp, mlc_llm) for each quantization method.
- **X-axis**: Quantization methods (default, float16, int8, nf4)
- **Y-axis**: Tokens per second
- **Purpose**: Shows which backend performs best for each quantization type

### 2. Speedup Comparison (`speedup_comparison.png`)
Bar chart showing speedup relative to tinygrad baseline for common quantization methods.
- **X-axis**: Quantization methods
- **Y-axis**: Speedup multiplier (values > 1.0 mean faster than tinygrad)
- **Baseline**: Red dashed line at 1.0x (tinygrad performance)
- **Purpose**: Quantifies performance gains/losses vs baseline

### 3. Summary Statistics (`summary_stats.png`)
Bar chart showing average, max, and min performance for each backend.
- **X-axis**: Backend names
- **Y-axis**: Tokens per second
- **Metrics**: Average (blue), Max (green), Min (red)
- **Purpose**: High-level overview of backend performance characteristics

### 4. Quantization Impact (`quantization_impact.png`)
Line chart showing how quantization affects performance for each backend.
- **X-axis**: Quantization methods
- **Y-axis**: Tokens per second
- **Lines**: One per backend with different markers
- **Purpose**: Shows quantization impact trends across backends

## Current Data Summary

Based on the visualization script output:

### Loaded Data
- **tinygrad**: 4 quantization methods, 360 total samples
- **llama.cpp**: 4 quantization methods, 55 total samples
- **mlc_llm**: No data yet (benchmarks blocked by bool type bugs)

### Key Findings

#### Performance by Quantization (tokens/sec mean)
- **default**: tinygrad 16.58, llama.cpp 41.26 (2.49x faster)
- **float16**: tinygrad 25.42, llama.cpp 3.19 (tinygrad 7.98x faster)
- **int8**: tinygrad 27.48, llama.cpp 33.16 (1.21x faster)
- **nf4**: tinygrad 2.79, llama.cpp 46.40 (16.61x faster)

#### Overall Summary
- **tinygrad**: Average 18.07 tok/s, Fastest 27.48 tok/s (int8), Slowest 2.79 tok/s (nf4)
- **llama.cpp**: Average 31.00 tok/s, Fastest 46.40 tok/s (nf4), Slowest 3.19 tok/s (float16)

## Usage in Presentations

To embed these plots in markdown presentations:

```markdown
![Backend Comparison](images/backend_comparison.png)

![Speedup Comparison](images/speedup_comparison.png)

![Summary Statistics](images/summary_stats.png)

![Quantization Impact](images/quantization_impact.png)
```

## Regenerating Plots

To regenerate the plots with updated benchmark data:

```bash
# Run benchmarks first (if needed)
PYTHONPATH=./deps/tinygrad/ python tinygrad_benchmark.py
PYTHONPATH=./deps/tinygrad/ python llamacpp_benchmark.py
python mlc_benchmark.py  # When mlc_llm bugs are fixed

# Generate plots
python generate_plots.py

# Copy to docs
cp plots/*.png docs/images/
```

## Scripts

- **generate_plots.py**: Main script to generate matplotlib plots
- **visualize_benchmarks_all.py**: ASCII visualization in terminal
- **benchmark_analysis.py**: Detailed statistical analysis
