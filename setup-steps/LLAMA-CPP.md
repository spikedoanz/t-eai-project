```
termux-setup-storage
pkg install git cmake rust
wget https://huggingface.co/ggml-org/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q4_K_M.gguf -O ~/gemma-1b.gguf
git clone https://github.com/ggml-org/llama.cpp
cd llama.cpp
cmake -B build
cmake --build build --config Release
./build/bin/llama-cli -m ~/gemma-1b.gguf -p "Hello, who are you?" -c 4096
```
