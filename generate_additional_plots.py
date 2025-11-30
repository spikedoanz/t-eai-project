"""
Generate additional plots from available benchmark data.
Creates plots that were listed in the TODO section.

Usage: python generate_additional_plots.py
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


def plot_latency_distribution(tinygrad_data: List[Dict], llamacpp_data: List[Dict], output_dir: str = "plots"):
    """Generate box plot showing latency distribution across quantization methods."""
    os.makedirs(output_dir, exist_ok=True)

    # Group latencies by backend and quantization
    data_by_quant = defaultdict(lambda: {'tinygrad': [], 'llama.cpp': []})

    for row in tinygrad_data:
        if row.get('step') == '0':
            continue
        quant = row.get('quantize', 'unknown')
        try:
            latency = float(row.get('total_latency_ms', 0))
            if latency > 0:
                data_by_quant[quant]['tinygrad'].append(latency)
        except (ValueError, TypeError):
            pass

    for row in llamacpp_data:
        if row.get('step') == '0':
            continue
        quant = row.get('quantize', 'unknown')
        try:
            latency = float(row.get('total_latency_ms', 0))
            if latency > 0:
                data_by_quant[quant]['llama.cpp'].append(latency)
        except (ValueError, TypeError):
            pass

    all_quants = sorted(data_by_quant.keys())

    fig, axes = plt.subplots(1, len(all_quants), figsize=(16, 5), sharey=True)
    if len(all_quants) == 1:
        axes = [axes]

    for idx, quant in enumerate(all_quants):
        ax = axes[idx]
        data_to_plot = []
        labels = []

        if data_by_quant[quant]['tinygrad']:
            data_to_plot.append(data_by_quant[quant]['tinygrad'])
            labels.append('tinygrad')

        if data_by_quant[quant]['llama.cpp']:
            data_to_plot.append(data_by_quant[quant]['llama.cpp'])
            labels.append('llama.cpp')

        if data_to_plot:
            bp = ax.boxplot(data_to_plot, labels=labels, patch_artist=True)
            colors = {'tinygrad': '#2ecc71', 'llama.cpp': '#3498db'}
            for patch, label in zip(bp['boxes'], labels):
                patch.set_facecolor(colors.get(label, '#95a5a6'))
                patch.set_alpha(0.7)

        ax.set_title(f'{quant}', fontsize=12, fontweight='bold')
        ax.set_ylabel('Latency (ms)' if idx == 0 else '', fontsize=11)
        ax.grid(axis='y', alpha=0.3)

    fig.suptitle('Latency Distribution by Quantization Method', fontsize=14, fontweight='bold', y=1.02)
    plt.tight_layout()
    plt.savefig(f'{output_dir}/latency_distribution.png', dpi=300, bbox_inches='tight')
    print(f"Saved: {output_dir}/latency_distribution.png")
    plt.close()


def plot_memory_throughput(tinygrad_data: List[Dict], llamacpp_data: List[Dict], output_dir: str = "plots"):
    """Generate bar chart comparing memory throughput."""
    os.makedirs(output_dir, exist_ok=True)

    # Compute averages
    def compute_avg_memory_throughput(data):
        grouped = defaultdict(list)
        for row in data:
            if row.get('step') == '0':
                continue
            quant = row.get('quantize', 'unknown')
            try:
                mem_tp = float(row.get('memory_throughput_gb_s', 0))
                if mem_tp > 0:
                    grouped[quant].append(mem_tp)
            except (ValueError, TypeError):
                pass

        averages = {}
        for quant, values in grouped.items():
            if values:
                averages[quant] = sum(values) / len(values)
        return averages

    tinygrad_avgs = compute_avg_memory_throughput(tinygrad_data)
    llamacpp_avgs = compute_avg_memory_throughput(llamacpp_data)

    all_quants = sorted(set(list(tinygrad_avgs.keys()) + list(llamacpp_avgs.keys())))

    x = np.arange(len(all_quants))
    width = 0.35

    fig, ax = plt.subplots(figsize=(12, 6))

    tinygrad_vals = [tinygrad_avgs.get(q, 0) for q in all_quants]
    llamacpp_vals = [llamacpp_avgs.get(q, 0) for q in all_quants]

    ax.bar(x - width/2, tinygrad_vals, width, label='tinygrad', color='#2ecc71', alpha=0.8)
    ax.bar(x + width/2, llamacpp_vals, width, label='llama.cpp', color='#3498db', alpha=0.8)

    ax.set_xlabel('Quantization Method', fontsize=12)
    ax.set_ylabel('Memory Throughput (GB/s)', fontsize=12)
    ax.set_title('Memory Bandwidth Comparison', fontsize=14, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(all_quants)
    ax.legend()
    ax.grid(axis='y', alpha=0.3)

    plt.tight_layout()
    plt.savefig(f'{output_dir}/memory_throughput.png', dpi=300, bbox_inches='tight')
    print(f"Saved: {output_dir}/memory_throughput.png")
    plt.close()


def plot_device_comparison(tinygrad_data: List[Dict], llamacpp_data: List[Dict], output_dir: str = "plots"):
    """Generate comparison across different devices (localhost vs softmacs)."""
    os.makedirs(output_dir, exist_ok=True)

    # Group by hostname, backend, and quantization
    def group_by_device(data, backend_name):
        grouped = defaultdict(lambda: defaultdict(list))
        for row in data:
            if row.get('step') == '0':
                continue
            hostname = row.get('hostname', 'unknown')
            quant = row.get('quantize', 'unknown')
            try:
                tps = float(row.get('tokens_per_sec', 0))
                if tps > 0:
                    grouped[hostname][quant].append(tps)
            except (ValueError, TypeError):
                pass

        # Compute averages
        averages = {}
        for hostname in grouped:
            averages[hostname] = {}
            for quant, values in grouped[hostname].items():
                if values:
                    averages[hostname][quant] = sum(values) / len(values)
        return averages

    tinygrad_by_device = group_by_device(tinygrad_data, 'tinygrad')
    llamacpp_by_device = group_by_device(llamacpp_data, 'llama.cpp')

    # Get all devices and quants
    all_devices = set(list(tinygrad_by_device.keys()) + list(llamacpp_by_device.keys()))
    all_quants = set()
    for dev_data in list(tinygrad_by_device.values()) + list(llamacpp_by_device.values()):
        all_quants.update(dev_data.keys())
    all_quants = sorted(all_quants)

    if len(all_devices) < 2:
        print("Skipping device comparison: only one device found")
        return

    fig, axes = plt.subplots(1, len(all_devices), figsize=(14, 6), sharey=True)
    if len(all_devices) == 1:
        axes = [axes]

    for idx, device in enumerate(sorted(all_devices)):
        ax = axes[idx]
        x = np.arange(len(all_quants))
        width = 0.35

        tinygrad_vals = [tinygrad_by_device.get(device, {}).get(q, 0) for q in all_quants]
        llamacpp_vals = [llamacpp_by_device.get(device, {}).get(q, 0) for q in all_quants]

        ax.bar(x - width/2, tinygrad_vals, width, label='tinygrad', color='#2ecc71', alpha=0.8)
        ax.bar(x + width/2, llamacpp_vals, width, label='llama.cpp', color='#3498db', alpha=0.8)

        ax.set_title(f'{device}', fontsize=12, fontweight='bold')
        ax.set_xlabel('Quantization', fontsize=11)
        ax.set_ylabel('Tokens/sec' if idx == 0 else '', fontsize=11)
        ax.set_xticks(x)
        ax.set_xticklabels(all_quants, rotation=45, ha='right')
        if idx == len(all_devices) - 1:
            ax.legend()
        ax.grid(axis='y', alpha=0.3)

    fig.suptitle('Performance Comparison Across Devices', fontsize=14, fontweight='bold', y=1.02)
    plt.tight_layout()
    plt.savefig(f'{output_dir}/device_comparison.png', dpi=300, bbox_inches='tight')
    print(f"Saved: {output_dir}/device_comparison.png")
    plt.close()


def plot_param_throughput(tinygrad_data: List[Dict], llamacpp_data: List[Dict], output_dir: str = "plots"):
    """Generate bar chart comparing parameter throughput."""
    os.makedirs(output_dir, exist_ok=True)

    def compute_avg_param_throughput(data):
        grouped = defaultdict(list)
        for row in data:
            if row.get('step') == '0':
                continue
            quant = row.get('quantize', 'unknown')
            try:
                param_tp = float(row.get('param_throughput_gb_s', 0))
                if param_tp > 0:
                    grouped[quant].append(param_tp)
            except (ValueError, TypeError):
                pass

        averages = {}
        for quant, values in grouped.items():
            if values:
                averages[quant] = sum(values) / len(values)
        return averages

    tinygrad_avgs = compute_avg_param_throughput(tinygrad_data)
    llamacpp_avgs = compute_avg_param_throughput(llamacpp_data)

    all_quants = sorted(set(list(tinygrad_avgs.keys()) + list(llamacpp_avgs.keys())))

    x = np.arange(len(all_quants))
    width = 0.35

    fig, ax = plt.subplots(figsize=(12, 6))

    tinygrad_vals = [tinygrad_avgs.get(q, 0) for q in all_quants]
    llamacpp_vals = [llamacpp_avgs.get(q, 0) for q in all_quants]

    ax.bar(x - width/2, tinygrad_vals, width, label='tinygrad', color='#2ecc71', alpha=0.8)
    ax.bar(x + width/2, llamacpp_vals, width, label='llama.cpp', color='#3498db', alpha=0.8)

    ax.set_xlabel('Quantization Method', fontsize=12)
    ax.set_ylabel('Parameter Throughput (GB/s)', fontsize=12)
    ax.set_title('Parameter Throughput Comparison', fontsize=14, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(all_quants)
    ax.legend()
    ax.grid(axis='y', alpha=0.3)

    plt.tight_layout()
    plt.savefig(f'{output_dir}/param_throughput.png', dpi=300, bbox_inches='tight')
    print(f"Saved: {output_dir}/param_throughput.png")
    plt.close()


def main():
    # Load data
    tinygrad_results = load_csv('benchmark_output/tinygrad.csv')
    llamacpp_results = load_csv('benchmark_output/llamacpp.csv')

    if not tinygrad_results and not llamacpp_results:
        print("No benchmark results found.")
        return

    print("\n" + "=" * 80)
    print("GENERATING ADDITIONAL PLOTS")
    print("=" * 80)

    print(f"\nLoaded {len(tinygrad_results)} tinygrad results, {len(llamacpp_results)} llamacpp results")

    output_dir = "plots"
    os.makedirs(output_dir, exist_ok=True)

    print(f"\nGenerating plots in '{output_dir}/' directory...")

    plot_latency_distribution(tinygrad_results, llamacpp_results, output_dir)
    plot_memory_throughput(tinygrad_results, llamacpp_results, output_dir)
    plot_param_throughput(tinygrad_results, llamacpp_results, output_dir)
    plot_device_comparison(tinygrad_results, llamacpp_results, output_dir)

    print("\n" + "=" * 80)
    print("DONE! Additional plots saved")
    print("=" * 80)
    print("\nGenerated files:")
    print("  - plots/latency_distribution.png")
    print("  - plots/memory_throughput.png")
    print("  - plots/param_throughput.png")
    print("  - plots/device_comparison.png (if multiple devices found)")


if __name__ == "__main__":
    main()
