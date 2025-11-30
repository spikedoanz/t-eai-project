"""
Generate matplotlib plots for benchmark comparison slides.
Creates PNG images that can be embedded in presentation slides.

Usage: python generate_plots.py
"""
import csv
import os
from collections import defaultdict
from typing import Dict, List
import matplotlib.pyplot as plt
import numpy as np


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


def plot_backend_comparison(backends_data: Dict[str, Dict], output_dir: str = "plots"):
    """Generate bar chart comparing backends across quantization methods."""
    os.makedirs(output_dir, exist_ok=True)

    # Get all unique quantization methods
    all_quants = set()
    for backend_data in backends_data.values():
        all_quants.update(backend_data.keys())
    all_quants = sorted(all_quants)

    # Prepare data for plotting
    backend_names = list(backends_data.keys())
    x = np.arange(len(all_quants))
    width = 0.25  # width of bars

    fig, ax = plt.subplots(figsize=(12, 6))

    colors = {'tinygrad': '#2ecc71', 'llama.cpp': '#3498db', 'mlc_llm': '#e74c3c'}

    for i, backend_name in enumerate(backend_names):
        backend_data = backends_data[backend_name]
        means = [backend_data.get(q, {'mean': 0})['mean'] for q in all_quants]
        offset = (i - len(backend_names)/2 + 0.5) * width
        color = colors.get(backend_name, '#95a5a6')
        ax.bar(x + offset, means, width, label=backend_name, color=color, alpha=0.8)

    ax.set_xlabel('Quantization Method', fontsize=12)
    ax.set_ylabel('Tokens per Second', fontsize=12)
    ax.set_title('Backend Performance Comparison (Llama-3.2-1B)', fontsize=14, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(all_quants)
    ax.legend()
    ax.grid(axis='y', alpha=0.3)

    plt.tight_layout()
    plt.savefig(f'{output_dir}/backend_comparison.png', dpi=300, bbox_inches='tight')
    print(f"Saved: {output_dir}/backend_comparison.png")
    plt.close()


def plot_speedup_comparison(backends_data: Dict[str, Dict], output_dir: str = "plots"):
    """Generate speedup comparison chart relative to baseline."""
    os.makedirs(output_dir, exist_ok=True)

    if 'tinygrad' not in backends_data:
        print("No tinygrad baseline for speedup comparison")
        return

    tinygrad_data = backends_data['tinygrad']

    # Get common quantization methods
    all_quants = set(tinygrad_data.keys())
    for backend_data in backends_data.values():
        all_quants &= set(backend_data.keys())
    all_quants = sorted(all_quants)

    if not all_quants:
        print("No common quantization methods found for speedup comparison")
        return

    fig, ax = plt.subplots(figsize=(10, 6))

    x = np.arange(len(all_quants))
    width = 0.35

    colors = {'llama.cpp': '#3498db', 'mlc_llm': '#e74c3c'}

    i = 0
    for backend_name, backend_data in backends_data.items():
        if backend_name == 'tinygrad':
            continue

        speedups = []
        for quant in all_quants:
            t_val = tinygrad_data[quant]['mean']
            b_val = backend_data.get(quant, {'mean': 0})['mean']
            speedup = b_val / t_val if t_val > 0 else 0
            speedups.append(speedup)

        offset = (i - 0.5) * width
        color = colors.get(backend_name, '#95a5a6')
        ax.bar(x + offset, speedups, width, label=f'{backend_name} vs tinygrad',
               color=color, alpha=0.8)
        i += 1

    ax.axhline(y=1.0, color='red', linestyle='--', linewidth=2, alpha=0.5, label='Baseline (tinygrad)')
    ax.set_xlabel('Quantization Method', fontsize=12)
    ax.set_ylabel('Speedup (relative to tinygrad)', fontsize=12)
    ax.set_title('Speedup Comparison vs Tinygrad Baseline', fontsize=14, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(all_quants)
    ax.legend()
    ax.grid(axis='y', alpha=0.3)

    plt.tight_layout()
    plt.savefig(f'{output_dir}/speedup_comparison.png', dpi=300, bbox_inches='tight')
    print(f"Saved: {output_dir}/speedup_comparison.png")
    plt.close()


def plot_summary_stats(backends_data: Dict[str, Dict], output_dir: str = "plots"):
    """Generate summary statistics bar chart."""
    os.makedirs(output_dir, exist_ok=True)

    backend_names = []
    avg_speeds = []
    max_speeds = []
    min_speeds = []

    for backend_name, backend_data in backends_data.items():
        if not backend_data:
            continue

        speeds = [d['mean'] for d in backend_data.values()]
        backend_names.append(backend_name)
        avg_speeds.append(sum(speeds) / len(speeds))
        max_speeds.append(max(speeds))
        min_speeds.append(min(speeds))

    x = np.arange(len(backend_names))
    width = 0.25

    fig, ax = plt.subplots(figsize=(10, 6))

    ax.bar(x - width, avg_speeds, width, label='Average', color='#3498db', alpha=0.8)
    ax.bar(x, max_speeds, width, label='Max', color='#2ecc71', alpha=0.8)
    ax.bar(x + width, min_speeds, width, label='Min', color='#e74c3c', alpha=0.8)

    ax.set_xlabel('Backend', fontsize=12)
    ax.set_ylabel('Tokens per Second', fontsize=12)
    ax.set_title('Performance Summary by Backend', fontsize=14, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(backend_names)
    ax.legend()
    ax.grid(axis='y', alpha=0.3)

    plt.tight_layout()
    plt.savefig(f'{output_dir}/summary_stats.png', dpi=300, bbox_inches='tight')
    print(f"Saved: {output_dir}/summary_stats.png")
    plt.close()


def plot_quantization_impact(backends_data: Dict[str, Dict], output_dir: str = "plots"):
    """Generate line chart showing quantization impact per backend."""
    os.makedirs(output_dir, exist_ok=True)

    # Get all unique quantization methods
    all_quants = set()
    for backend_data in backends_data.values():
        all_quants.update(backend_data.keys())
    all_quants = sorted(all_quants)

    fig, ax = plt.subplots(figsize=(12, 6))

    colors = {'tinygrad': '#2ecc71', 'llama.cpp': '#3498db', 'mlc_llm': '#e74c3c'}
    markers = {'tinygrad': 'o', 'llama.cpp': 's', 'mlc_llm': '^'}

    for backend_name, backend_data in backends_data.items():
        x_vals = []
        y_vals = []

        for i, quant in enumerate(all_quants):
            if quant in backend_data:
                x_vals.append(i)
                y_vals.append(backend_data[quant]['mean'])

        if x_vals:
            color = colors.get(backend_name, '#95a5a6')
            marker = markers.get(backend_name, 'x')
            ax.plot(x_vals, y_vals, marker=marker, linewidth=2, markersize=8,
                   label=backend_name, color=color, alpha=0.8)

    ax.set_xlabel('Quantization Method', fontsize=12)
    ax.set_ylabel('Tokens per Second', fontsize=12)
    ax.set_title('Quantization Impact Across Backends', fontsize=14, fontweight='bold')
    ax.set_xticks(range(len(all_quants)))
    ax.set_xticklabels(all_quants)
    ax.legend()
    ax.grid(alpha=0.3)

    plt.tight_layout()
    plt.savefig(f'{output_dir}/quantization_impact.png', dpi=300, bbox_inches='tight')
    print(f"Saved: {output_dir}/quantization_impact.png")
    plt.close()


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
        print("  python mlc_benchmark.py")
        return

    print("\n" + "=" * 80)
    print("GENERATING PLOTS FOR PRESENTATION")
    print("=" * 80)

    print(f"\nLoaded data from {len(backends_data)} backend(s):")
    for backend_name, backend_data in backends_data.items():
        print(f"  - {backend_name}: {len(backend_data)} quantization methods")

    output_dir = "plots"
    os.makedirs(output_dir, exist_ok=True)

    # Generate all plots
    print(f"\nGenerating plots in '{output_dir}/' directory...")
    plot_backend_comparison(backends_data, output_dir)
    plot_speedup_comparison(backends_data, output_dir)
    plot_summary_stats(backends_data, output_dir)
    plot_quantization_impact(backends_data, output_dir)

    print("\n" + "=" * 80)
    print("DONE! All plots saved to 'plots/' directory")
    print("=" * 80)
    print("\nGenerated files:")
    print("  - plots/backend_comparison.png")
    print("  - plots/speedup_comparison.png")
    print("  - plots/summary_stats.png")
    print("  - plots/quantization_impact.png")
    print("\nYou can now use these images in your presentation slides!")


if __name__ == "__main__":
    main()
