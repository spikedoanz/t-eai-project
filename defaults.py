import pathlib

MODEL_DIR = pathlib.Path("./models/")

# Maps quantization key to (URL, filename suffix)
# The suffix is used to construct the local filename
MODEL_CONFIGS = {
    "default": {
        "url": "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q6_K.gguf",
        "suffix": "Q6_K",
    },
    "int8": {
        "url": "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q8_0.gguf",
        "suffix": "Q8_0",
    },
    "nf4": {
        "url": "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf",
        "suffix": "Q4_K_M",
    },
    "float16": {
        "url": "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-f16.gguf",
        "suffix": "f16",
    },
}

# Backwards compatibility
MODEL_URLS = {k: v["url"] for k, v in MODEL_CONFIGS.items()}