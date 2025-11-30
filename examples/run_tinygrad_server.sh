#!/bin/bash
# Start tinygrad LLaMA server
cd "$(dirname "$0")/.."
PYTHONPATH=./deps/tinygrad/ python tinygrad_benchmark.py --port 7776 --size 1B
