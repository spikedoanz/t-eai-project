"""
Analyze and compare benchmark results across backends (tinygrad vs llamacpp) and hosts.
Usage: python benchmark_analysis.py
"""
import csv
from collections import defaultdict
from statistics import mean, median, stdev


def load_csv(path: str) -> list[dict]:
    with open(path, "r") as f:
        return list(csv.DictReader(f))


def safe_float(val: str) -> float | None:
    try:
        return float(val) if val else None
    except ValueError:
        return None


def aggregate_by_group(rows: list[dict], group_keys: list[str], metric: str) -> dict:
    """Group rows by keys and aggregate metric values."""
    groups = defaultdict(list)
    for row in rows:
        key = tuple(row.get(k, "unknown") for k in group_keys)
        val = safe_float(row.get(metric))
        if val is not None:
            groups[key].append(val)
    return groups


def stats(values: list[float]) -> dict:
    if not values:
        return {"n": 0, "mean": None, "median": None, "std": None, "min": None, "max": None}
    return {
        "n": len(values),
        "mean": mean(values),
        "median": median(values),
        "std": stdev(values) if len(values) > 1 else 0,
        "min": min(values),
        "max": max(values),
    }


def print_comparison_table(title: str, data: dict, metric_name: str):
    """Print a formatted comparison table."""
    print(f"\n{'='*80}")
    print(f" {title}")
    print(f"{'='*80}")
    print(f"{'Group':<50} {'N':>6} {'Mean':>10} {'Median':>10} {'Std':>10}")
    print("-" * 80)

    sorted_keys = sorted(data.keys())
    for key in sorted_keys:
        s = stats(data[key])
        if s["n"] > 0:
            label = " / ".join(str(k) for k in key)
            print(f"{label:<50} {s['n']:>6} {s['mean']:>10.2f} {s['median']:>10.2f} {s['std']:>10.2f}")


def main():
    # Load data
    tinygrad_data = load_csv("benchmark_output/tinygrad.csv")
    llamacpp_data = load_csv("benchmark_output/llamacpp.csv")

    # Add backend column
    for row in tinygrad_data:
        row["backend"] = "tinygrad"
    for row in llamacpp_data:
        row["backend"] = "llamacpp"

    all_data = tinygrad_data + llamacpp_data

    print("\n" + "=" * 80)
    print(" BENCHMARK DATA SUMMARY")
    print("=" * 80)
    print(f"Total rows: {len(all_data)}")
    print(f"  - tinygrad: {len(tinygrad_data)}")
    print(f"  - llamacpp: {len(llamacpp_data)}")

    # Get unique hosts
    hosts = set(row.get("hostname", "unknown") for row in all_data)
    print(f"Hosts: {', '.join(sorted(hosts))}")

    # Get unique quantizations
    quants = set(row.get("quantize", "unknown") for row in all_data)
    print(f"Quantizations: {', '.join(sorted(quants))}")

    # Main comparison: tokens/sec by backend and host
    groups = aggregate_by_group(all_data, ["backend", "hostname"], "tokens_per_sec")
    print_comparison_table(
        "TOKENS/SEC by Backend & Host",
        groups,
        "tokens_per_sec"
    )

    # Comparison by backend, host, and quantization
    groups = aggregate_by_group(all_data, ["backend", "hostname", "quantize"], "tokens_per_sec")
    print_comparison_table(
        "TOKENS/SEC by Backend, Host & Quantization",
        groups,
        "tokens_per_sec"
    )

    # Memory throughput comparison
    groups = aggregate_by_group(all_data, ["backend", "hostname"], "memory_throughput_gb_s")
    print_comparison_table(
        "MEMORY THROUGHPUT (GB/s) by Backend & Host",
        groups,
        "memory_throughput_gb_s"
    )

    # Param throughput comparison
    groups = aggregate_by_group(all_data, ["backend", "hostname"], "param_throughput_gb_s")
    print_comparison_table(
        "PARAM THROUGHPUT (GB/s) by Backend & Host",
        groups,
        "param_throughput_gb_s"
    )

    # Total latency comparison
    groups = aggregate_by_group(all_data, ["backend", "hostname", "quantize"], "total_latency_ms")
    print_comparison_table(
        "TOTAL LATENCY (ms) by Backend, Host & Quantization",
        groups,
        "total_latency_ms"
    )

    # Summary: best performer per host
    print("\n" + "=" * 80)
    print(" SUMMARY: MEDIAN TOKENS/SEC BY HOST")
    print("=" * 80)

    for host in sorted(hosts):
        print(f"\n{host}:")
        host_data = [r for r in all_data if r.get("hostname") == host]
        backend_groups = aggregate_by_group(host_data, ["backend", "quantize"], "tokens_per_sec")

        results = []
        for (backend, quant), values in backend_groups.items():
            s = stats(values)
            if s["n"] > 0:
                results.append((backend, quant, s["median"], s["n"]))

        results.sort(key=lambda x: x[2], reverse=True)
        for backend, quant, med, n in results:
            print(f"  {backend:10} {quant:10} -> {med:>8.2f} tok/s (n={n})")


if __name__ == "__main__":
    main()
