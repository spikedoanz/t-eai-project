import re
import sys
import csv
import json
from typing import List, Dict, Optional

def parse_file(filepath: str) -> List[Dict]:
    metadata = {}
    metadata_keys = {'platform', 'release', 'device', 'username', 'hostname', 'size', 'quantize', 'seed', 'uuid'}
    
    results = []
    jsonl_started = False
    
    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()
            if not jsonl_started:
                if ':' in line:
                    key, value = line.split(':', 1)
                    key = key.strip()
                    if key in metadata_keys:
                        metadata[key] = value.strip()
                elif line.startswith('{'):  # Start of JSONL
                    jsonl_started = True
                    # Parse the JSON line
                    data = json.loads(line)
                    # Create a single result row with aggregate metrics
                    result = {
                        'step': 1,  # Aggregate, so step=1
                        'enqueue_latency_ms': 0.0,  # Not available
                        'total_latency_ms': data.get('avg_ns', 0) / 1e6,  # Convert ns to ms
                        'tokens_per_sec': data.get('avg_ts', 0.0),
                        'memory_throughput_gb_s': 0.0,  # Not directly available
                        'param_throughput_gb_s': 0.0,  # Not directly available
                        'generated_text': '',  # No text generated
                        **metadata
                    }
                    results.append(result)
                else:
                    continue
            else:
                # Additional JSONL lines if any
                if line.startswith('{'):
                    data = json.loads(line)
                    # For multiple entries, but typically one
                    result = {
                        'step': len(results) + 1,
                        'enqueue_latency_ms': 0.0,
                        'total_latency_ms': data.get('avg_ns', 0) / 1e6,
                        'tokens_per_sec': data.get('avg_ts', 0.0),
                        'memory_throughput_gb_s': 0.0,
                        'param_throughput_gb_s': 0.0,
                        'generated_text': '',
                        **metadata
                    }
                    results.append(result)
    
    return results

def write_csv(results: List[Dict], output_file: str):
    if not results:
        return
    fieldnames = ['step', 'enqueue_latency_ms', 'total_latency_ms', 'tokens_per_sec', 
                  'memory_throughput_gb_s', 'param_throughput_gb_s', 'generated_text',
                  'platform', 'release', 'device', 'username', 'hostname', 'size', 'quantize', 'seed', 'uuid']
    with open(output_file, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in results:
            for field in fieldnames:
                if field not in row:
                    row[field] = ''
            writer.writerow(row)

def compute_summary(results: List[Dict]) -> Dict:
    summary = {}
    metrics = ['enqueue_latency_ms', 'total_latency_ms', 'tokens_per_sec', 
               'memory_throughput_gb_s', 'param_throughput_gb_s']
    for metric in metrics:
        values = []
        for r in results:
            v = r.get(metric)
            if v is not None and v != 0.0:  # Skip zeros
                values.append(v)
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
    print(f"Processed {len(results)} results -> {output_file}")
    for key, value in summary.items():
        print(f"  {key}: {value:.2f}")

if __name__ == "__main__":
    main()