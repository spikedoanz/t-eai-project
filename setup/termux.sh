#!/data/data/com.termux/files/usr/bin/bash
# Pixel 7/8 Benchmark Setup & Run Script for t-eai-project (tinygrad backend)
#
# This script automates the complete setup from blank Termux installation
# to running LLM inference benchmarks.
#
# Prerequisites:
#   - Termux installed from F-Droid (NOT Play Store)
#   - At least 5GB free storage
#   - Stable internet connection
#
# Usage:
#   # Setup only:
#   bash <(curl -sL https://raw.githubusercontent.com/spikedoanz/t-eai-project/master/setup/termux.sh)
#
#   # Setup and run benchmarks:
#   bash <(curl -sL https://raw.githubusercontent.com/spikedoanz/t-eai-project/master/setup/termux.sh) --benchmark
#
#   # Run benchmarks only (after setup):
#   ./setup/termux.sh --benchmark

set -e  # Exit on error
set -u  # Exit on undefined variable

# ============================================================================
# CONFIGURATION
# ============================================================================

REPO_URL="git@github.com:spikedoanz/t-eai-project.git"
PROJECT_DIR="$HOME/t-eai-project"
PYTHON_MIN_VERSION="3.11"
REQUIRED_STORAGE_GB=5
RUN_BENCHMARK=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --benchmark)
            RUN_BENCHMARK=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --benchmark      Run benchmarks after setup (or run benchmarks only if already set up)"
            echo "  --help           Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run with --help for usage information"
            exit 1
            ;;
    esac
done

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

prompt() {
    echo -e "\033[1;35m[PROMPT]\033[0m $1"
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

check_termux() {
    info "Checking if running in Termux..."
    if [ -z "${PREFIX:-}" ]; then
        error "This script must be run in Termux. Install Termux from F-Droid."
    fi
    success "Running in Termux environment"
}

check_storage() {
    info "Checking available storage..."
    AVAILABLE_KB=$(df $HOME | tail -1 | awk '{print $4}')
    AVAILABLE_GB=$((AVAILABLE_KB / 1024 / 1024))

    if [ $AVAILABLE_GB -lt $REQUIRED_STORAGE_GB ]; then
        error "Insufficient storage. Need ${REQUIRED_STORAGE_GB}GB, have ${AVAILABLE_GB}GB"
    fi
    success "Storage check passed (${AVAILABLE_GB}GB available)"
}

check_python_version() {
    info "Checking Python version..."
    if ! command -v python3 &> /dev/null; then
        warn "Python3 not found, will install in Phase 1"
        return 0
    fi

    PYTHON_VERSION=$(python3 --version | awk '{print $2}')
    PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
    PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

    if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 11 ]); then
        error "Python >= 3.11 required. Found: $PYTHON_VERSION"
    fi
    success "Python version check passed ($PYTHON_VERSION)"
}

skip_if_exists() {
    local marker_file="$1"
    local phase_name="$2"

    if [ -f "$marker_file" ]; then
        info "Phase '$phase_name' already completed (marker: $marker_file)"
        return 0  # Skip this phase
    fi
    return 1  # Don't skip
}

create_marker() {
    local marker_file="$1"
    mkdir -p "$(dirname "$marker_file")"
    touch "$marker_file"
}

# ============================================================================
# PHASE 0: PRE-FLIGHT CHECKS
# ============================================================================

phase0_preflight() {
    echo ""
    echo "========================================"
    echo "  Pixel 7/8 Benchmark Setup Script"
    echo "  t-eai-project (tinygrad backend)"
    echo "========================================"
    echo ""

    check_termux
    check_storage

    prompt "This script will:"
    echo "  1. Install required Termux packages"
    echo "  2. Setup SSH access"
    echo "  3. Install file transfer tools (croc)"
    echo "  4. Configure OpenCL for GPU acceleration"
    echo "  5. Clone t-eai-project repository"
    echo "  6. Setup Python environment"
    echo "  7. Download models"
    if [ "$RUN_BENCHMARK" = true ]; then
        echo "  8. Run performance benchmarks"
    fi
    echo ""
    echo "Estimated time: 5-10 minutes (or seconds if cached)"
    echo "Required storage: ${REQUIRED_STORAGE_GB}GB"
    echo ""
    info "Starting automated setup..."
}

# ============================================================================
# PHASE 1: TERMUX PACKAGE INSTALLATION
# ============================================================================

phase1_packages() {
    local MARKER="$HOME/.setup_markers/phase1_packages"
    if skip_if_exists "$MARKER" "Package Installation"; then
        return 0
    fi

    info "PHASE 1: Installing Termux packages..."

    info "Updating package lists..."
    pkg update -y || error "Failed to update packages"

    info "Upgrading existing packages..."
    pkg upgrade -y || warn "Some packages failed to upgrade (continuing anyway)"

    info "Installing essential packages..."
    pkg install -y \
        python \
        python-pip \
        git \
        wget \
        curl \
        || error "Failed to install essential packages"

    info "Installing OpenCL support for GPU..."
    pkg install -y \
        opencl-headers \
        opencl-vendor-driver \
        || warn "OpenCL packages may not be available (GPU acceleration may not work)"

    info "Installing optional packages..."
    pkg install -y \
        openssh \
        golang \
        rust \
        || warn "Some optional packages failed to install (continuing anyway)"

    check_python_version

    create_marker "$MARKER"
    success "Phase 1 complete: All packages installed"
}

# ============================================================================
# PHASE 2: SSH SETUP
# ============================================================================

phase2_ssh() {
    local MARKER="$HOME/.setup_markers/phase2_ssh"
    if skip_if_exists "$MARKER" "SSH Setup"; then
        return 0
    fi

    info "PHASE 2: SSH Setup..."

    # Check if SSH is already configured
    if [ -f "$PREFIX/var/run/sshd.pid" ]; then
        info "SSH daemon already running"
    else
        info "Starting SSH daemon..."
        sshd || error "Failed to start SSH daemon"
    fi

    # Check if password is set
    if ! passwd -S 2>/dev/null | grep -q "^P"; then
        prompt "SSH password not set. Setting password for SSH access..."
        passwd || error "Failed to set password"
    fi

    # Get connection info
    info "Getting SSH connection information..."
    USERNAME=$(id -un)
    info "SSH Username: $USERNAME"

    echo ""
    info "SSH connection information:"
    echo "  Username: $USERNAME"
    echo ""
    info "Option 1: Tailscale (recommended)"
    echo "  1. Install Tailscale from Google Play Store on your Pixel"
    echo "  2. Sign in and add device to your tailnet"
    echo "  3. On your host machine, run: tailscale status"
    echo "  4. Find your Pixel's tailscale IP"
    echo "  5. Connect via: ssh $USERNAME@<tailscale-ip> -p 8022"
    echo ""
    info "Option 2: Local network"
    LOCAL_IP=$(ifconfig wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}')
    if [ -n "$LOCAL_IP" ]; then
        echo "  Connect via: ssh $USERNAME@$LOCAL_IP -p 8022"
    else
        echo "  Run 'ifconfig wlan0' to find your IP address"
        echo "  Then connect via: ssh $USERNAME@<ip-address> -p 8022"
    fi

    create_marker "$MARKER"
    success "Phase 2 complete: SSH configured"
}

# ============================================================================
# PHASE 3: FILE TRANSFER TOOLS (CROC)
# ============================================================================

phase3_croc() {
    local MARKER="$HOME/.setup_markers/phase3_croc"
    if skip_if_exists "$MARKER" "Croc Installation"; then
        return 0
    fi

    info "PHASE 3: Installing croc for file transfers..."

    if command -v croc &> /dev/null; then
        info "croc already installed"
    else
        info "Installing croc via Go..."

        # Ensure Go bin is in PATH for this session
        export PATH=$PATH:~/go/bin

        go install github.com/schollz/croc/v10@latest || error "Failed to install croc"

        if ! command -v croc &> /dev/null; then
            warn "croc installed but not in PATH. Will be available after adding ~/go/bin to PATH"
        fi
    fi

    info "croc usage:"
    echo "  To send files:    ~/go/bin/croc send <filename>"
    echo "  To receive files: ~/go/bin/croc <code-from-sender>"

    create_marker "$MARKER"
    success "Phase 3 complete: croc installed"
}

# ============================================================================
# PHASE 4: OPENCL GPU CONFIGURATION
# ============================================================================

phase4_opencl() {
    local MARKER="$HOME/.setup_markers/phase4_opencl"
    if skip_if_exists "$MARKER" "OpenCL Configuration"; then
        return 0
    fi

    info "PHASE 4: Configuring OpenCL for GPU acceleration..."

    # Check if OpenCL libraries exist
    if [ -d "/system/vendor/lib64" ]; then
        OPENCL_LIBS=$(ls /system/vendor/lib64/libOpenCL* 2>/dev/null | wc -l)
        if [ $OPENCL_LIBS -gt 0 ]; then
            success "OpenCL libraries found in /system/vendor/lib64"
        else
            warn "OpenCL libraries not found. GPU acceleration may not work"
        fi
    else
        warn "/system/vendor/lib64 not found. GPU acceleration may not work"
    fi

    create_marker "$MARKER"
    success "Phase 4 complete: OpenCL verified"
}

# ============================================================================
# PHASE 5: CLONE REPOSITORY
# ============================================================================

phase5_clone() {
    local MARKER="$HOME/.setup_markers/phase5_clone"
    if skip_if_exists "$MARKER" "Repository Clone"; then
        return 0
    fi

    info "PHASE 5: Cloning t-eai-project repository..."

    if [ -d "$PROJECT_DIR" ]; then
        info "Project directory already exists: $PROJECT_DIR"
        info "Using existing project directory"
        cd "$PROJECT_DIR"
        create_marker "$MARKER"
        return 0
    fi

    info "Cloning repository..."
    git clone "$REPO_URL" "$PROJECT_DIR" || error "Failed to clone repository"

    cd "$PROJECT_DIR"

    info "Initializing git submodules..."
    git submodule update --init --recursive || error "Failed to initialize submodules"

    success "Repository cloned: $PROJECT_DIR"

    create_marker "$MARKER"
    success "Phase 5 complete: Repository cloned"
}

# ============================================================================
# PHASE 6: PYTHON ENVIRONMENT SETUP
# ============================================================================

phase6_python() {
    local MARKER="$HOME/.setup_markers/phase6_python"
    if skip_if_exists "$MARKER" "Python Environment"; then
        return 0
    fi

    info "PHASE 6: Setting up Python environment..."

    cd "$PROJECT_DIR"

    # Install dependencies
    info "Installing Python dependencies..."

    # Check if packages are already installed (cache check)
    if python3 -c "import bottle; import tiktoken" 2>/dev/null; then
        info "Required Python packages already installed"
    else
        info "Installing missing Python packages..."
        pip install --user bottle tiktoken || error "Failed to install dependencies"
    fi

    # Verify imports (with PYTHONPATH set for tinygrad)
    info "Verifying Python imports..."
    PYTHONPATH="$PROJECT_DIR/deps/tinygrad" python3 -c "import bottle; import tiktoken; from tinygrad.helpers import fetch" \
        || error "Python import verification failed"

    create_marker "$MARKER"
    success "Phase 6 complete: Python environment ready"
}

# ============================================================================
# PHASE 7: MODEL DOWNLOAD
# ============================================================================

phase7_models() {
    local MARKER="$HOME/.setup_markers/phase7_models"
    if skip_if_exists "$MARKER" "Model Download"; then
        return 0
    fi

    info "PHASE 7: Downloading models..."

    cd "$PROJECT_DIR"

    # Tinygrad auto-downloads models to its cache directory
    TINYGRAD_CACHE="$HOME/.cache/tinygrad/downloads"
    LLAMA_1B_DIR="$TINYGRAD_CACHE/llama3-1b-instruct"

    # Check if model already exists in tinygrad cache
    if [ -f "$LLAMA_1B_DIR/Llama-3.2-1B-Instruct-Q6_K.gguf" ]; then
        info "Found existing model in tinygrad cache:"
        ls -lh "$LLAMA_1B_DIR/" 2>/dev/null | tail -n +2 | awk '{print "  - " $9 " (" $5 ")"}'
        success "Model already downloaded"
    else
        info "Downloading Llama-3.2-1B-Instruct model (~1.2GB)..."

        # Set environment for tinygrad
        export LD_LIBRARY_PATH=/system/vendor/lib64:${LD_LIBRARY_PATH:-}
        export GPU=1
        export OPENCL=1
        export PYTHONPATH="$PROJECT_DIR/deps/tinygrad"

        python3 -c '
from tinygrad.helpers import fetch
print("Downloading tokenizer...")
fetch("https://huggingface.co/bofenghuang/Meta-Llama-3-8B/resolve/main/original/tokenizer.model", "tokenizer.model", subdir="llama3-1b-instruct")
print("Downloading model (this may take a few minutes)...")
fetch("https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q6_K.gguf", "Llama-3.2-1B-Instruct-Q6_K.gguf", subdir="llama3-1b-instruct")
print("Download complete!")
' || error "Failed to download model"

        success "Model downloaded"
    fi

    create_marker "$MARKER"
    success "Phase 7 complete: Models ready"
}

# ============================================================================
# PHASE 8: RUN BENCHMARKS
# ============================================================================

phase8_benchmark() {
    if [ "$RUN_BENCHMARK" != true ]; then
        return 0
    fi

    info "PHASE 8: Running performance benchmarks..."

    cd "$PROJECT_DIR"

    # Set environment for tinygrad with GPU
    export LD_LIBRARY_PATH=/system/vendor/lib64:${LD_LIBRARY_PATH:-}
    export GPU=1
    export OPENCL=1
    export PYTHONPATH="$PROJECT_DIR/deps/tinygrad"

    echo ""
    echo "=========================================="
    echo "  Running Benchmarks"
    echo "  Quantizations: default, int8, nf4, float16"
    echo "=========================================="
    echo ""

    START_TIME=$(date +%s)

    # Run benchmarks
    info "Running tinygrad_benchmark.py..."
    if python3 tinygrad_benchmark.py; then
        success "Performance benchmarks completed"
    else
        error "Performance benchmarks failed"
    fi

    # Collate results
    info "Collating results..."
    if python3 tinygrad_collate.py 2>/dev/null || python3 llamacpp_collate.py 2>/dev/null; then
        success "Results collated"
    else
        warn "Collation script not found (raw results still available in benchmark_output/)"
    fi

    # Package results
    info "Packaging results..."
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    HOSTNAME=$(hostname)
    RESULT_ARCHIVE="pixel_results_${HOSTNAME}_${TIMESTAMP}.tar.gz"

    tar -czf "$RESULT_ARCHIVE" \
        benchmark_output/*.txt \
        benchmark_output/*.csv \
        2>/dev/null || warn "Some result files may be missing from archive"

    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    ELAPSED_MIN=$((ELAPSED / 60))
    ELAPSED_SEC=$((ELAPSED % 60))

    if [ -f "$RESULT_ARCHIVE" ]; then
        ARCHIVE_SIZE=$(du -h "$RESULT_ARCHIVE" | cut -f1)
        echo ""
        echo "=========================================="
        echo "  Benchmark Complete!"
        echo "=========================================="
        echo ""
        echo "Results summary:"
        echo "  Archive: $RESULT_ARCHIVE"
        echo "  Size: $ARCHIVE_SIZE"
        echo "  Time elapsed: ${ELAPSED_MIN}m ${ELAPSED_SEC}s"
        echo ""
        echo "To transfer results to your host machine:"
        echo "  ~/go/bin/croc send $RESULT_ARCHIVE"
        echo ""
        success "Benchmarks completed successfully!"
    else
        warn "Failed to create results archive"
    fi
}

# ============================================================================
# PHASE 9: FINAL SUMMARY
# ============================================================================

phase9_summary() {
    cd "$PROJECT_DIR"

    echo ""
    echo "========================================"
    echo "  Setup Complete!"
    echo "========================================"
    echo ""

    info "Verification checklist:"
    echo "  [✓] Termux packages installed"
    echo "  [✓] SSH configured"
    echo "  [✓] croc file transfer tool installed"
    echo "  [✓] OpenCL GPU verified"
    echo "  [✓] Repository cloned"
    echo "  [✓] Python environment ready"
    echo "  [✓] Models downloaded"
    if [ "$RUN_BENCHMARK" = true ]; then
        echo "  [✓] Benchmarks completed"
    fi
    echo ""

    if [ "$RUN_BENCHMARK" != true ]; then
        info "To run benchmarks:"
        echo "  cd ~/t-eai-project"
        echo "  ./setup/termux.sh --benchmark"
        echo ""
        info "Or manually:"
        echo "  cd ~/t-eai-project"
        echo "  LD_LIBRARY_PATH=/system/vendor/lib64 GPU=1 OPENCL=1 PYTHONPATH=./deps/tinygrad python3 tinygrad_benchmark.py"
        echo ""
    fi

    info "To transfer results:"
    echo "  ~/go/bin/croc send benchmark_output/"
    echo ""

    success "All done!"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    phase0_preflight
    phase1_packages
    phase2_ssh
    phase3_croc
    phase4_opencl
    phase5_clone
    phase6_python
    phase7_models
    phase8_benchmark
    phase9_summary
}

# Run main function
main
