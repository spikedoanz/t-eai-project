import os
import csv
import subprocess
from typing import List, Dict

def main():
    output_dir = "benchmark_output"
    # Only process tinygrad files (not llamacpp files)
    files = [f for f in os.listdir(output_dir) if f.endswith('.txt') and not f.startswith('llamacpp_')]

    all_results = []
    for file in files:
        filepath = os.path.join(output_dir, file)
        # Run tinygrad_parse.py
        try:
            subprocess.run(["python", "tinygrad_parse.py", filepath], check=True)
        except subprocess.CalledProcessError:
            print(f"Failed to parse {filepath}")
            continue
        
        # Read the generated csv if it exists
        csv_file = filepath.replace('.txt', '.csv')
        if os.path.exists(csv_file):
            with open(csv_file, 'r') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    all_results.append(row)
    
    # Write to tinygrad.csv
    if all_results:
        fieldnames = ['step', 'enqueue_latency_ms', 'total_latency_ms', 'tokens_per_sec', 
                      'memory_throughput_gb_s', 'param_throughput_gb_s', 'generated_text',
                      'platform', 'release', 'device', 'username', 'hostname', 'size', 'quantize', 'seed', 'uuid']
        with open('benchmark_output/tinygrad.csv', 'w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            for row in all_results:
                for field in fieldnames:
                    if field not in row:
                        row[field] = ''
                writer.writerow(row)

if __name__ == "__main__":
    main()
