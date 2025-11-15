basic setup steps for tinygrad llama backend (supports more than just llama)
```
pkg install python
pkg install rust
git clone https://github.com:/tinygrad/tinygrad.git
cd tinygrad
python3 -m venv .venv
source .venv/bin/activate
PYTHONPATH=. python examples/llama3.py
```
