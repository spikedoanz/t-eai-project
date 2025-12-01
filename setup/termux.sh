#!/data/data/com.termux/files/usr/bin/bash
# Pixel 7/8 Benchmark Script for t-eai-project (tinygrad backend)
#
# This script:
#   1. Sets up the environment (packages, venv, models)
#   2. Runs benchmarks across quantization methods
#   3. Generates plots from results
#   4. Hosts an HTTP server to view results in browser
#
# Prerequisites:
#   - Termux installed from F-Droid (NOT Play Store)
#   - At least 5GB free storage
#   - Stable internet connection
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/spikedoanz/t-eai-project/master/setup/termux.sh | bash

set -e  # Exit on error
set -u  # Exit on undefined variable

# ============================================================================
# CONFIGURATION
# ============================================================================

REPO_URL="https://github.com/spikedoanz/t-eai-project.git"
PROJECT_DIR="$HOME/t-eai-project"
VENV_DIR="$PROJECT_DIR/.venv"
REQUIRED_STORAGE_GB=5
HTTP_PORT=8080

# ============================================================================
# COLOR OUTPUT HELPERS
# ============================================================================

info() {
    echo -e "\n\033[1;34m[INFO]\033[0m $1"
}

success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
    exit 1
}

warn() {
    echo -e "\033[1;33m[WARN]\033[0m $1"
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

check_termux() {
    if [ -z "${PREFIX:-}" ]; then
        error "This script must be run in Termux. Install Termux from F-Droid."
    fi
}

check_storage() {
    AVAILABLE_KB=$(df $HOME | tail -1 | awk '{print $4}')
    AVAILABLE_GB=$((AVAILABLE_KB / 1024 / 1024))
    if [ $AVAILABLE_GB -lt $REQUIRED_STORAGE_GB ]; then
        error "Insufficient storage. Need ${REQUIRED_STORAGE_GB}GB, have ${AVAILABLE_GB}GB"
    fi
}

skip_if_exists() {
    local marker_file="$1"
    [ -f "$marker_file" ]
}

create_marker() {
    local marker_file="$1"
    mkdir -p "$(dirname "$marker_file")"
    touch "$marker_file"
}

# ============================================================================
# PHASE 1: INSTALL PACKAGES
# ============================================================================

phase1_packages() {
    local MARKER="$HOME/.setup_markers/phase1_packages"
    if skip_if_exists "$MARKER"; then
        info "Packages already installed"
        return 0
    fi

    info "Installing Termux packages..."
    # Set non-interactive mode to avoid dpkg config prompts when piped from curl
    export DEBIAN_FRONTEND=noninteractive
    pkg update -y
    pkg upgrade -y -o Dpkg::Options::="--force-confold" || true
    pkg install -y python python-pip git wget curl golang
    pkg install -y opencl-headers opencl-vendor-driver || true

    create_marker "$MARKER"
    success "Packages installed"
}

# ============================================================================
# PHASE 2: CLONE REPOSITORY
# ============================================================================

phase2_clone() {
    local MARKER="$HOME/.setup_markers/phase2_clone"
    if skip_if_exists "$MARKER"; then
        info "Repository already cloned"
        return 0
    fi

    info "Cloning repository..."
    if [ ! -d "$PROJECT_DIR" ]; then
        git clone "$REPO_URL" "$PROJECT_DIR"
    fi
    cd "$PROJECT_DIR"
    # Only init tinygrad submodule (not recursive to avoid issues)
    git submodule update --init deps/tinygrad

    create_marker "$MARKER"
    success "Repository cloned"
}

# ============================================================================
# PHASE 3: SETUP PYTHON VENV
# ============================================================================

phase3_venv() {
    local MARKER="$HOME/.setup_markers/phase3_venv"
    if skip_if_exists "$MARKER"; then
        info "Venv already set up"
        return 0
    fi

    info "Setting up Python virtual environment..."
    cd "$PROJECT_DIR"

    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"

    pip install --upgrade pip
    pip install bottle tiktoken matplotlib

    create_marker "$MARKER"
    success "Python venv ready"
}

# ============================================================================
# PHASE 4: DOWNLOAD MODEL
# ============================================================================

phase4_model() {
    local MARKER="$HOME/.setup_markers/phase4_model"
    if skip_if_exists "$MARKER"; then
        info "Model already downloaded"
        return 0
    fi

    info "Downloading model (~1.2GB)..."
    cd "$PROJECT_DIR"
    source "$VENV_DIR/bin/activate"

    # OpenCL environment for Adreno GPU
    export LD_LIBRARY_PATH=/vendor/lib64:/system/vendor/lib64:${LD_LIBRARY_PATH:-}
    export GPU=1
    export OPENCL=1
    export PYOPENCL_CTX=0
    export PYOPENCL_PLATFORM=0
    export PYTHONPATH="$PROJECT_DIR/deps/tinygrad"

    python3 -c '
from tinygrad.helpers import fetch
fetch("https://huggingface.co/bofenghuang/Meta-Llama-3-8B/resolve/main/original/tokenizer.model", "tokenizer.model", subdir="llama3-1b-instruct")
fetch("https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q6_K.gguf", "Llama-3.2-1B-Instruct-Q6_K.gguf", subdir="llama3-1b-instruct")
'

    create_marker "$MARKER"
    success "Model downloaded"
}

# ============================================================================
# PHASE 5: RUN BENCHMARKS
# ============================================================================

phase5_benchmark() {
    info "Running benchmarks..."
    cd "$PROJECT_DIR"
    source "$VENV_DIR/bin/activate"

    # OpenCL environment for Adreno GPU
    export LD_LIBRARY_PATH=/vendor/lib64/egl:/vendor/lib64:${LD_LIBRARY_PATH:-}
    export LD_LIBRARY_PATH=/vendor/lib64:${LD_LIBRARY_PATH:-}
    export PYTHONPATH="$PROJECT_DIR/deps/tinygrad"

    python3 tinygrad_benchmark.py
    success "Benchmarks complete"
}

# ============================================================================
# PHASE 6: GENERATE PLOTS
# ============================================================================

phase6_plots() {
    info "Generating plots..."
    cd "$PROJECT_DIR"
    source "$VENV_DIR/bin/activate"

    export PYTHONPATH="$PROJECT_DIR/deps/tinygrad"

    # Collate results first
    python3 tinygrad_collate.py 2>/dev/null || python3 llamacpp_collate.py 2>/dev/null || true

    # Generate plots
    python3 generate_plots.py

    success "Plots generated in plots/"
}

# ============================================================================
# PHASE 7: HOST HTTP SERVER
# ============================================================================

phase7_serve() {
    cd "$PROJECT_DIR"
    source "$VENV_DIR/bin/activate"

    # Get IP address
    LOCAL_IP=$(ifconfig wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}')
    if [ -z "$LOCAL_IP" ]; then
        LOCAL_IP="localhost"
    fi

    echo ""
    echo "=========================================="
    echo "  Results Server"
    echo "=========================================="
    echo ""
    echo "View results in your browser:"
    echo "  http://$LOCAL_IP:$HTTP_PORT/plots/"
    echo ""
    echo "Press Ctrl+C to stop the server"
    echo ""

    python3 -m http.server $HTTP_PORT
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    echo ""
    echo "========================================"
    echo "  Pixel Benchmark Script"
    echo "  t-eai-project (tinygrad)"
    echo "========================================"
    echo ""

    check_termux
    check_storage

    phase1_packages
    phase2_clone
    phase3_venv
    phase4_model
    phase5_benchmark
    phase6_plots
    phase7_serve
}

main
