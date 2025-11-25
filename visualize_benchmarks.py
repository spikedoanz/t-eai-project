"""
Visualize benchmark results comparing tinygrad and llama.cpp backends.
Generates bar charts comparing tokens/sec across quantization methods.

Usage: python visualize_benchmarks.py
"""
import csv
import os
from collections import defaultdict


def load_csv(filepath: str) -> list[dict]:
    """Load benchmark results from CSV file."""
    results = []
    if not os.path.exists(filepath):
        return results
    with open(filepath, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            results.append(row)
    return results


def compute_averages(results: list[dict], group_by: str = 'quantize') -> dict:
    """Compute average tokens_per_sec grouped by quantization method."""
    grouped = defaultdict(list)
    for row in results:
        # Skip summary rows (step == 0 for llamacpp)
        if row.get('step') == '0':
            continue
        quant = row.get(group_by, 'unknown')
        try:
            tps = float(row.get('tokens_per_sec', 0))
            if tps > 0:
                grouped[quant].append(tps)
        except (ValueError, TypeError):
            pass

    averages = {}
    for quant, values in grouped.items():
        if values:
            averages[quant] = {
                'mean': sum(values) / len(values),
                'min': min(values),
                'max': max(values),
                'count': len(values),
            }
    return averages


def print_comparison_table(tinygrad_avgs: dict, llamacpp_avgs: dict):
    """Print a comparison table of results."""
    print("\n" + "=" * 80)
    print("BENCHMARK COMPARISON: Tinygrad vs llama.cpp (Llama-3.2-1B-Instruct)")
    print("=" * 80)
    print(f"\n{'Quantization':<15} {'Backend':<12} {'Mean tok/s':>12} {'Min':>10} {'Max':>10} {'Samples':>10}")
    print("-" * 80)

    # Get all quantization methods
    all_quants = sorted(set(list(tinygrad_avgs.keys()) + list(llamacpp_avgs.keys())))

    for quant in all_quants:
        if quant in tinygrad_avgs:
            t = tinygrad_avgs[quant]
            print(f"{quant:<15} {'tinygrad':<12} {t['mean']:>12.2f} {t['min']:>10.2f} {t['max']:>10.2f} {t['count']:>10}")
        if quant in llamacpp_avgs:
            l = llamacpp_avgs[quant]
            print(f"{quant:<15} {'llama.cpp':<12} {l['mean']:>12.2f} {l['min']:>10.2f} {l['max']:>10.2f} {l['count']:>10}")
        print()


def render_ascii_bar_chart(tinygrad_avgs: dict, llamacpp_avgs: dict):
    """Render an ASCII bar chart comparing backends."""
    print("\n" + "=" * 80)
    print("TOKENS PER SECOND BY QUANTIZATION METHOD")
    print("=" * 80)

    # Get all quantization methods and find max value for scaling
    all_quants = sorted(set(list(tinygrad_avgs.keys()) + list(llamacpp_avgs.keys())))
    max_val = 0
    for quant in all_quants:
        if quant in tinygrad_avgs:
            max_val = max(max_val, tinygrad_avgs[quant]['mean'])
        if quant in llamacpp_avgs:
            max_val = max(max_val, llamacpp_avgs[quant]['mean'])

    bar_width = 50  # characters

    for quant in all_quants:
        print(f"\n{quant}:")

        if quant in tinygrad_avgs:
            t_val = tinygrad_avgs[quant]['mean']
            t_bar_len = int(t_val / max_val * bar_width) if max_val > 0 else 0
            t_bar = "#" * t_bar_len
            print(f"  tinygrad:  [{t_bar:<{bar_width}}] {t_val:>8.2f} tok/s")

        if quant in llamacpp_avgs:
            l_val = llamacpp_avgs[quant]['mean']
            l_bar_len = int(l_val / max_val * bar_width) if max_val > 0 else 0
            l_bar = "=" * l_bar_len
            print(f"  llama.cpp: [{l_bar:<{bar_width}}] {l_val:>8.2f} tok/s")


def render_speedup_comparison(tinygrad_avgs: dict, llamacpp_avgs: dict):
    """Show speedup comparison between backends."""
    print("\n" + "=" * 80)
    print("SPEEDUP COMPARISON (llama.cpp vs tinygrad)")
    print("=" * 80)

    common_quants = set(tinygrad_avgs.keys()) & set(llamacpp_avgs.keys())

    for quant in sorted(common_quants):
        t_val = tinygrad_avgs[quant]['mean']
        l_val = llamacpp_avgs[quant]['mean']

        if t_val > 0:
            speedup = l_val / t_val
            if speedup >= 1:
                print(f"  {quant:<15}: llama.cpp is {speedup:.2f}x faster")
            else:
                print(f"  {quant:<15}: tinygrad is {1/speedup:.2f}x faster")


def main():
    # Load data
    tinygrad_results = load_csv('benchmark_output/tinygrad.csv')
    llamacpp_results = load_csv('benchmark_output/llamacpp.csv')

    if not tinygrad_results and not llamacpp_results:
        print("No benchmark results found. Run the benchmarks first:")
        print("  PYTHONPATH=./deps/tinygrad/ python tinygrad_benchmark.py")
        print("  PYTHONPATH=./deps/tinygrad/ python llamacpp_benchmark.py")
        return

    # Compute averages by quantization method
    tinygrad_avgs = compute_averages(tinygrad_results)
    llamacpp_avgs = compute_averages(llamacpp_results)

    print("\nLoaded data:")
    print(f"  Tinygrad: {len(tinygrad_results)} rows, {len(tinygrad_avgs)} quantization methods")
    print(f"  llama.cpp: {len(llamacpp_results)} rows, {len(llamacpp_avgs)} quantization methods")

    # Print comparison table
    print_comparison_table(tinygrad_avgs, llamacpp_avgs)

    # Render ASCII bar chart
    render_ascii_bar_chart(tinygrad_avgs, llamacpp_avgs)

    # Speedup comparison
    render_speedup_comparison(tinygrad_avgs, llamacpp_avgs)

    print("\n" + "=" * 80)
    print("NOTE: llama.cpp uses GGUF quantization (Q6_K, Q8_0, Q4_K_M, f16)")
    print("      tinygrad uses runtime quantization (default=fp32, int8, nf4, float16)")
    print("      Quantization methods are not directly comparable but show relative perf.")
    print("=" * 80)


if __name__ == "__main__":
    main()
