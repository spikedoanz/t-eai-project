# Presentation Update - Plots Linked

## Summary

Successfully linked all generated benchmark visualization plots to the presentation slides in `presentation.typ`.

## Changes Made

### 1. Updated Results Slides (Lines 405-494)

#### Slide: "Results: Throughput Comparison"
- **Before**: Placeholder gray box with TODO comment
- **After**: Real plot showing backend comparison (`docs/images/backend_comparison.png`)
- **Key findings added**:
  - llama.cpp excels with NF4 (46.4 tok/s) and default (41.3 tok/s)
  - tinygrad performs best with INT8 (27.5 tok/s) and float16 (25.4 tok/s)

#### Slide: "Results: Speedup Analysis" (formerly Memory vs Throughput)
- **Before**: Placeholder for memory-throughput scatter plot
- **After**: Speedup comparison chart (`docs/images/speedup_comparison.png`)
- **Key findings added**:
  - llama.cpp: 16.6x speedup for NF4
  - tinygrad: 8.0x faster for float16
  - Modest advantages for INT8/default

#### NEW Slide: "Results: Performance Summary"
- **Added**: Summary statistics chart (`docs/images/summary_stats.png`)
- **Shows**: Average, max, min performance per backend
- **Key metrics**:
  - llama.cpp: avg 31.0 tok/s, peak 46.4 tok/s
  - tinygrad: avg 18.1 tok/s, peak 27.5 tok/s

#### NEW Slide: "Results: Quantization Impact"
- **Added**: Line chart showing trends (`docs/images/quantization_impact.png`)
- **Insights**:
  - Different backends favor different strategies
  - llama.cpp benefits from aggressive quantization
  - tinygrad shows consistent performance

#### Slide: "Results: Device Comparison"
- **Updated**: Table now shows actual benchmark data instead of TBD placeholders
- **Data source**: Real measurements from MacBook Metal backend
- **Format**: Cleaner 5-column layout with all quantization types

### 2. Added TODO Section (Lines 496-504)

Created comprehensive list of additional plots needed:
- Memory usage comparison
- Energy consumption (watts/token)
- Latency distribution (box plots)
- Accuracy vs throughput scatter
- Multi-device comparison (Pixel data)
- Context length impact analysis

## Files Modified

1. **presentation.typ**:
   - Linked 4 plot images
   - Updated 2 existing slides
   - Added 2 new result slides
   - Added TODO section for future plots

## Available Plots

All plots are in both locations:
- `plots/*.png` (original output)
- `docs/images/*.png` (copied for presentation)

### Plot Files
1. `backend_comparison.png` - Bar chart comparing backends ✅ Linked
2. `speedup_comparison.png` - Speedup vs tinygrad baseline ✅ Linked
3. `summary_stats.png` - Average/max/min per backend ✅ Linked
4. `quantization_impact.png` - Line chart of trends ✅ Linked

## How to Compile Presentation

```bash
# If using Typst compiler
typst compile presentation.typ

# Output: presentation.pdf
```

## Data Source

All visualizations generated from:
- `benchmark_output/tinygrad.csv` - 360 samples, 4 quantization methods
- `benchmark_output/llamacpp.csv` - 55 samples, 4 quantization methods
- Model: Llama-3.2-1B-Instruct on MacBook (Metal backend)

## Next Steps

To regenerate plots with updated data:
```bash
# Run additional benchmarks (when ready)
python mlc_benchmark.py  # When bool bugs are fixed
# Run on Pixel devices...

# Regenerate all plots
python generate_plots.py

# Copy to presentation
cp plots/*.png docs/images/
```

For the TODO plots, we need to:
1. Collect memory usage data during benchmarks
2. Add energy profiling (if hardware supports it)
3. Run verifiers benchmarks for accuracy data
4. Run benchmarks on Pixel 7/8 devices
5. Vary context lengths in benchmark configs
