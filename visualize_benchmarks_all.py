"""
Visualize benchmark results comparing tinygrad, llama.cpp, and MLC LLM backends.
Generates bar charts comparing tokens/sec across quantization methods.

Usage: python visualize_benchmarks_all.py
"""
import csv
import os
from collections import defaultdict
from typing import Dict, List, Tuple


def load_csv(filepath: str) -> List[Dict]:
    """Load benchmark results from CSV file."""
    results = []
    if not os.path.exists(filepath):
        return results
    with open(filepath, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            results.append(row)
    return results


def compute_averages(results: List[Dict], group_by: str = 'quantize') -> Dict:
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


def print_comparison_table(backends_data: Dict[str, Dict]):
    """Print a comparison table of results for all backends."""
    print("\n" + "=" * 100)
    print("BENCHMARK COMPARISON: Tinygrad vs llama.cpp vs MLC LLM")
    print("=" * 100)
    print(f"\n{'Quantization':<15} {'Backend':<12} {'Mean tok/s':>12} {'Min':>10} {'Max':>10} {'Samples':>10}")
    print("-" * 100)

    # Get all unique quantization methods
    all_quants = set()
    for backend_data in backends_data.values():
        all_quants.update(backend_data.keys())
    all_quants = sorted(all_quants)

    for quant in all_quants:
        for backend_name, backend_data in backends_data.items():
            if quant in backend_data:
                stats = backend_data[quant]
                print(f"{quant:<15} {backend_name:<12} {stats['mean']:>12.2f} {stats['min']:>10.2f} {stats['max']:>10.2f} {stats['count']:>10}")
        print()


def render_ascii_bar_chart(backends_data: Dict[str, Dict]):
    """Render an ASCII bar chart comparing all backends."""
    print("\n" + "=" * 100)
    print("TOKENS PER SECOND BY QUANTIZATION METHOD")
    print("=" * 100)

    # Get all unique quantization methods and find max value for scaling
    all_quants = set()
    max_val = 0
    for backend_data in backends_data.values():
        all_quants.update(backend_data.keys())
        for quant_data in backend_data.values():
            max_val = max(max_val, quant_data['mean'])
    all_quants = sorted(all_quants)

    bar_width = 50  # characters
    symbols = {
        'tinygrad': '#',
        'llama.cpp': '=',
        'mlc_llm': '*'
    }

    for quant in all_quants:
        print(f"\n{quant}:")

        for backend_name, backend_data in backends_data.items():
            if quant in backend_data:
                val = backend_data[quant]['mean']
                bar_len = int(val / max_val * bar_width) if max_val > 0 else 0
                symbol = symbols.get(backend_name, '-')
                bar = symbol * bar_len
                print(f"  {backend_name:<12}: [{bar:<{bar_width}}] {val:>8.2f} tok/s")


def render_speedup_comparison(backends_data: Dict[str, Dict]):
    """Show speedup comparison between backends."""
    print("\n" + "=" * 100)
    print("SPEEDUP COMPARISON (relative to tinygrad)")
    print("=" * 100)

    if 'tinygrad' not in backends_data:
        print("No tinygrad results found for comparison")
        return

    tinygrad_data = backends_data['tinygrad']
    
    for backend_name, backend_data in backends_data.items():
        if backend_name == 'tinygrad':
            continue
        
        print(f"\n{backend_name} vs tinygrad:")
        common_quants = set(tinygrad_data.keys()) & set(backend_data.keys())
        
        if not common_quants:
            print(f"  No common quantization methods found")
            continue
            
        for quant in sorted(common_quants):
            t_val = tinygrad_data[quant]['mean']
            b_val = backend_data[quant]['mean']
            
            if t_val > 0:
                speedup = b_val / t_val
                if speedup >= 1:
                    print(f"  {quant:<15}: {backend_name} is {speedup:.2f}x faster")
                else:
                    print(f"  {quant:<15}: tinygrad is {1/speedup:.2f}x faster")


def render_summary_stats(backends_data: Dict[str, Dict]):
    """Show summary statistics for each backend."""
    print("\n" + "=" * 100)
    print("SUMMARY STATISTICS")
    print("=" * 100)
    
    for backend_name, backend_data in backends_data.items():
        if not backend_data:
            continue
            
        all_speeds = []
        for quant_data in backend_data.values():
            all_speeds.append(quant_data['mean'])
        
        if all_speeds:
            print(f"\n{backend_name}:")
            print(f"  Average speed across all quantizations: {sum(all_speeds)/len(all_speeds):.2f} tok/s")
            print(f"  Fastest quantization: {max(all_speeds):.2f} tok/s")
            print(f"  Slowest quantization: {min(all_speeds):.2f} tok/s")
            print(f"  Number of quantization methods tested: {len(all_speeds)}")


def main():
    # Load data from all backends
    backends_data = {}
    
    # Load tinygrad results
    tinygrad_results = load_csv('benchmark_output/tinygrad.csv')
    if tinygrad_results:
        backends_data['tinygrad'] = compute_averages(tinygrad_results)
    
    # Load llama.cpp results
    llamacpp_results = load_csv('benchmark_output/llamacpp.csv')
    if llamacpp_results:
        backends_data['llama.cpp'] = compute_averages(llamacpp_results)
    
    # Load MLC LLM results
    mlc_results = load_csv('benchmark_output/mlc_llm.csv')
    if mlc_results:
        backends_data['mlc_llm'] = compute_averages(mlc_results)
    
    if not backends_data:
        print("No benchmark results found. Run the benchmarks first:")
        print("  PYTHONPATH=./deps/tinygrad/ python tinygrad_benchmark.py")
        print("  PYTHONPATH=./deps/tinygrad/ python llamacpp_benchmark.py")
        print("  python test_mlc_quick.py  # or python mlc_benchmark.py")
        return
    
    print("\nLoaded data:")
    for backend_name, backend_data in backends_data.items():
        num_quants = len(backend_data)
        total_samples = sum(d['count'] for d in backend_data.values())
        print(f"  {backend_name}: {num_quants} quantization methods, {total_samples} total samples")
    
    # Print comparison table
    print_comparison_table(backends_data)
    
    # Render ASCII bar chart
    render_ascii_bar_chart(backends_data)
    
    # Speedup comparison
    render_speedup_comparison(backends_data)
    
    # Summary statistics
    render_summary_stats(backends_data)
    
    print("\n" + "=" * 100)
    print("NOTES:")
    print("  - llama.cpp uses GGUF quantization (Q6_K, Q8_0, Q4_K_M, f16)")
    print("  - tinygrad uses runtime quantization (default=fp32, int8, nf4, float16)")
    print("  - MLC LLM uses pre-quantized models (q4f16_1, q8f16_1, etc.)")
    print("  - Quantization methods are not directly comparable but show relative performance")
    print("=" * 100)


if __name__ == "__main__":
    main()