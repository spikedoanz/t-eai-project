"""
Parse llama-bench JSONL output files into CSV format.
Usage: python llamacpp_parse.py <input_file.txt>
"""
import sys
import csv
import json
from typing import List, Dict, Optional


def parse_metadata(lines: List[str]) -> Dict[str, str]:
    """Parse the metadata header from the benchmark file."""
    metadata = {}
    metadata_keys = {'platform', 'release', 'device', 'username', 'hostname', 'size', 'quantize', 'seed', 'uuid'}

    for line in lines:
        line = line.strip()
        if ':' in line and not line.startswith('{'):
            key, value = line.split(':', 1)
            key = key.strip()
            if key in metadata_keys:
                metadata[key] = value.strip()

    return metadata


def parse_jsonl_metrics(line: str) -> Optional[Dict]:
    """Parse a JSONL line from llama-bench output."""
    line = line.strip()
    if not line.startswith('{'):
        return None

    try:
        data = json.loads(line)
        return data
    except json.JSONDecodeError:
        return None


def convert_to_benchmark_rows(metadata: Dict[str, str], jsonl_data: Dict) -> List[Dict]:
    """
    Convert llama-bench JSONL data to benchmark rows matching tinygrad schema.

    llama-bench gives aggregate stats (avg/stddev over repetitions),
    so we create one row per sample.
    """
    results = []

    samples_ns = jsonl_data.get('samples_ns', [])
    samples_ts = jsonl_data.get('samples_ts', [])
    n_gen = jsonl_data.get('n_gen', 20)

    for step, (ns, ts) in enumerate(zip(samples_ns, samples_ts), start=1):
        # Convert nanoseconds to milliseconds for total latency
        total_latency_ms = ns / 1_000_000

        # llama-bench doesn't provide enqueue latency separately
        # We estimate memory throughput from model size and time
        model_size_bytes = jsonl_data.get('model_size', 0)
        model_size_gb = model_size_bytes / (1024 ** 3)

        # Memory throughput: model_size * tokens / time
        # This is an approximation
        time_s = ns / 1_000_000_000
        memory_throughput_gb_s = (model_size_gb * n_gen / time_s) if time_s > 0 else 0

        # param throughput approximation
        n_params = jsonl_data.get('model_n_params', 0)
        param_bytes = n_params * 2  # assume fp16 params
        param_throughput_gb_s = (param_bytes / (1024 ** 3) * n_gen / time_s) if time_s > 0 else 0

        row = {
            'step': step,
            'enqueue_latency_ms': None,  # Not available from llama-bench
            'total_latency_ms': total_latency_ms,
            'tokens_per_sec': ts,
            'memory_throughput_gb_s': memory_throughput_gb_s,
            'param_throughput_gb_s': param_throughput_gb_s,
            'generated_text': '',  # llama-bench doesn't output text
            **metadata,
            # Additional llama-bench specific fields
            'build_commit': jsonl_data.get('build_commit', ''),
            'model_type': jsonl_data.get('model_type', ''),
            'n_gen': n_gen,
            'n_batch': jsonl_data.get('n_batch', ''),
            'n_threads': jsonl_data.get('n_threads', ''),
            'gpu_info': jsonl_data.get('gpu_info', ''),
            'backends': jsonl_data.get('backends', ''),
        }
        results.append(row)

    # Also add a summary row with averages
    avg_ns = jsonl_data.get('avg_ns', 0)
    avg_ts = jsonl_data.get('avg_ts', 0)
    stddev_ts = jsonl_data.get('stddev_ts', 0)

    summary_row = {
        'step': 0,  # 0 indicates summary
        'enqueue_latency_ms': None,
        'total_latency_ms': avg_ns / 1_000_000,
        'tokens_per_sec': avg_ts,
        'memory_throughput_gb_s': None,
        'param_throughput_gb_s': None,
        'generated_text': f'avg (stddev: {stddev_ts:.2f} tok/s)',
        **metadata,
        'build_commit': jsonl_data.get('build_commit', ''),
        'model_type': jsonl_data.get('model_type', ''),
        'n_gen': n_gen,
        'n_batch': jsonl_data.get('n_batch', ''),
        'n_threads': jsonl_data.get('n_threads', ''),
        'gpu_info': jsonl_data.get('gpu_info', ''),
        'backends': jsonl_data.get('backends', ''),
    }
    results.insert(0, summary_row)

    return results


def parse_file(filepath: str) -> List[Dict]:
    """Parse a llama-bench output file."""
    with open(filepath, 'r') as f:
        lines = f.readlines()

    metadata = parse_metadata(lines)

    results = []
    for line in lines:
        jsonl_data = parse_jsonl_metrics(line)
        if jsonl_data:
            results.extend(convert_to_benchmark_rows(metadata, jsonl_data))

    return results


def write_csv(results: List[Dict], output_file: str):
    """Write results to CSV file."""
    if not results:
        return

    fieldnames = [
        'step', 'enqueue_latency_ms', 'total_latency_ms', 'tokens_per_sec',
        'memory_throughput_gb_s', 'param_throughput_gb_s', 'generated_text',
        'platform', 'release', 'device', 'username', 'hostname', 'size', 'quantize', 'seed', 'uuid',
        'build_commit', 'model_type', 'n_gen', 'n_batch', 'n_threads', 'gpu_info', 'backends'
    ]

    with open(output_file, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in results:
            # Fill missing fields with empty string
            for field in fieldnames:
                if field not in row or row[field] is None:
                    row[field] = ''
            writer.writerow(row)


def compute_summary(results: List[Dict]) -> Dict:
    """Compute summary statistics from results."""
    summary = {}
    metrics = ['total_latency_ms', 'tokens_per_sec', 'memory_throughput_gb_s', 'param_throughput_gb_s']

    # Filter out summary row (step == 0)
    data_rows = [r for r in results if r.get('step', 0) != 0]

    for metric in metrics:
        values = []
        for r in data_rows:
            v = r.get(metric)
            if v is not None and v != '':
                try:
                    values.append(float(v))
                except (ValueError, TypeError):
                    pass

        if values:
            summary[f'{metric}_min'] = min(values)
            summary[f'{metric}_max'] = max(values)
            summary[f'{metric}_mean'] = sum(values) / len(values)
            summary[f'{metric}_median'] = sorted(values)[len(values) // 2]

    return summary


def main():
    if len(sys.argv) < 2:
        print("Usage: python llamacpp_parse.py <input_file.txt>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = input_file.replace('.txt', '.csv')

    results = parse_file(input_file)
    write_csv(results, output_file)

    summary = compute_summary(results)
    print(f"Processed {len(results)} rows -> {output_file}")
    for key, value in summary.items():
        if isinstance(value, float):
            print(f"  {key}: {value:.2f}")


if __name__ == "__main__":
    main()
