import re
import sys
import csv
from typing import List, Dict, Optional

def parse_metrics(line: str) -> Dict[str, Optional[float]]:
    metrics = {}
    enqueue_match = re.search(r"enqueue in\s+(\d+\.?\d*)\s+ms", line)
    if enqueue_match:
        metrics['enqueue_latency_ms'] = float(enqueue_match.group(1))
    total_match = re.search(r"total\s+(\d+\.?\d*)\s+ms,\s+(\d+\.?\d*)\s+tok/s,\s+(\d+\.?\d*)\s+GB/s,\s+param\s+(\d+\.?\d*)\s+GB/s", line)
    if total_match:
        metrics['total_latency_ms'] = float(total_match.group(1))
        metrics['tokens_per_sec'] = float(total_match.group(2))
        metrics['memory_throughput_gb_s'] = float(total_match.group(3))
        metrics['param_throughput_gb_s'] = float(total_match.group(4))
    return metrics

def parse_file(filepath: str) -> List[Dict]:
    metadata = {}
    metadata_keys = {'platform', 'release', 'device', 'username', 'hostname', 'size', 'quantize', 'seed', 'uuid'}
    
    # First pass: collect metadata
    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()
            if ':' in line:
                key, value = line.split(':', 1)
                key = key.strip()
                if key in metadata_keys:
                    metadata[key] = value.strip()
    
    # Second pass: parse results
    results = []
    current_text = ""
    step = 0
    pending_metrics = {}
    
    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith(("seed", "loaded weights", "output validated")):
                continue
            metrics = parse_metrics(line)
            if metrics:
                pending_metrics.update(metrics)
                if 'total_latency_ms' in pending_metrics or len(pending_metrics) >= 2:
                    step += 1
                    results.append({
                        'step': step,
                        'generated_text': current_text,
                        **pending_metrics,
                        **metadata
                    })
                    pending_metrics = {}
            elif line and not any(x in line for x in ["enqueue in", "total", "ms"]):
                current_text = line
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
            if v is not None:
                values.append(v)
        if values:
            summary[f'{metric}_min'] = min(values)
            summary[f'{metric}_max'] = max(values)
            summary[f'{metric}_mean'] = sum(values) / len(values)
            summary[f'{metric}_median'] = sorted(values)[len(values) // 2]
    return summary

def main():
    if len(sys.argv) < 2:
        print("Usage: python parse_benchmark.py <input_file.txt>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = input_file.replace('.txt', '.csv')
    
    results = parse_file(input_file)
    write_csv(results, output_file)
    
    summary = compute_summary(results)
    print(f"Processed {len(results)} steps -> {output_file}")
    for key, value in summary.items():
        print(f"  {key}: {value:.2f}")

if __name__ == "__main__":
    main()
