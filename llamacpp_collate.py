import os
import csv
import subprocess
from typing import List, Dict

def main():
    output_dir = "benchmark_output"
    files = [f for f in os.listdir(output_dir) if f.endswith('.txt') and 'softmacs' not in f]  # Assuming llamacpp files don't have 'softmacs'
    
    all_results = []
    for file in files:
        filepath = os.path.join(output_dir, file)
        # Run llamacpp_parse.py
        subprocess.run(["python", "llamacpp_parse.py", filepath], check=True)
        
        # Read the generated csv if it exists
        csv_file = filepath.replace('.txt', '.csv')
        if os.path.exists(csv_file):
            with open(csv_file, 'r') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    all_results.append(row)
    
    # Write to llamacpp.csv
    if all_results:
        fieldnames = ['step', 'enqueue_latency_ms', 'total_latency_ms', 'tokens_per_sec', 
                      'memory_throughput_gb_s', 'param_throughput_gb_s', 'generated_text',
                      'platform', 'release', 'device', 'username', 'hostname', 'size', 'quantize', 'seed', 'uuid']
        with open('benchmark_output/llamacpp.csv', 'w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            for row in all_results:
                for field in fieldnames:
                    if field not in row:
                        row[field] = ''
                writer.writerow(row)

if __name__ == "__main__":
    main()