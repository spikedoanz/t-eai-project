"""
Collate all llama-bench benchmark results into a single CSV file.
Usage: python llamacpp_collate.py
"""
import os
import csv
import subprocess


def main():
    output_dir = "benchmark_output"

    # Find all llamacpp benchmark txt files
    files = [f for f in os.listdir(output_dir) if f.startswith('llamacpp_') and f.endswith('.txt')]

    if not files:
        print("No llamacpp benchmark files found in benchmark_output/")
        return

    all_results = []
    for file in files:
        filepath = os.path.join(output_dir, file)
        csv_file = filepath.replace('.txt', '.csv')

        # Run llamacpp_parse.py to generate CSV
        try:
            subprocess.run(["python", "llamacpp_parse.py", filepath], check=True)
        except subprocess.CalledProcessError as e:
            print(f"Failed to parse {filepath}: {e}")
            continue

        # Read the generated CSV if it exists
        if os.path.exists(csv_file):
            with open(csv_file, 'r') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    all_results.append(row)
        else:
            print(f"CSV not generated for {filepath}")

    # Write to llamacpp.csv
    if all_results:
        fieldnames = [
            'step', 'enqueue_latency_ms', 'total_latency_ms', 'tokens_per_sec',
            'memory_throughput_gb_s', 'param_throughput_gb_s', 'generated_text',
            'platform', 'release', 'device', 'username', 'hostname', 'size', 'quantize', 'seed', 'uuid',
            'build_commit', 'model_type', 'n_gen', 'n_batch', 'n_threads', 'gpu_info', 'backends'
        ]

        output_path = os.path.join(output_dir, 'llamacpp.csv')
        with open(output_path, 'w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            for row in all_results:
                # Fill missing fields
                for field in fieldnames:
                    if field not in row:
                        row[field] = ''
                writer.writerow(row)

        print(f"Collated {len(all_results)} rows from {len(files)} files -> {output_path}")
    else:
        print("No results to collate")


if __name__ == "__main__":
    main()
