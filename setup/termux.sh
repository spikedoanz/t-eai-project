#!/data/data/com.termux/files/usr/bin/bash
# Pixel 7/8 Benchmark Setup Script for t-eai-project (llama.cpp backend)
#
# This script automates the complete setup from blank Termux installation
# to a ready-to-benchmark environment for LLM inference testing.
#
# Prerequisites:
#   - Termux installed from F-Droid (NOT Play Store)
#   - At least 10GB free storage
#   - Stable internet connection
#
# Usage:
#   bash <(curl -sL https://raw.githubusercontent.com/spikedoanz/t-eai-project/master/setup/pixel7_setup.sh)
#
#   Or manually:
#   curl -O https://raw.githubusercontent.com/spikedoanz/t-eai-project/master/setup/pixel7_setup.sh
#   chmod +x pixel7_setup.sh
#   ./pixel7_setup.sh

set -e  # Exit on error
set -u  # Exit on undefined variable

# ============================================================================
# CONFIGURATION
# ============================================================================

REPO_URL="git@github.com:spikedoanz/t-eai-project.git"
PROJECT_DIR="$HOME/t-eai-project"
PYTHON_MIN_VERSION="3.11"
REQUIRED_STORAGE_GB=10

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
        info "To re-run, remove marker file: rm $marker_file"
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
    echo "  t-eai-project (llama.cpp backend)"
    echo "========================================"
    echo ""

    check_termux
    check_storage

    prompt "This script will:"
    echo "  1. Install required Termux packages"
    echo "  2. Setup SSH access (optional Tailscale)"
    echo "  3. Install file transfer tools (croc)"
    echo "  4. Configure OpenCL for GPU acceleration"
    echo "  5. Clone t-eai-project repository"
    echo "  6. Build llama.cpp with OpenCL support"
    echo "  7. Setup Python environment"
    echo "  8. Prepare for model downloads"
    echo ""
    echo "Estimated time: 30-60 minutes (or seconds if cached)"
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

    info "Installing essential build tools..."
    pkg install -y \
        python \
        python-pip \
        git \
        cmake \
        clang \
        ninja \
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

        # Ensure Go bin is in PATH
        if ! grep -q "go/bin" ~/.bashrc; then
            echo 'export PATH=$PATH:~/go/bin' >> ~/.bashrc
        fi
        export PATH=$PATH:~/go/bin

        go install github.com/schollz/croc/v10@latest || error "Failed to install croc"

        if ! command -v croc &> /dev/null; then
            warn "croc installed but not in PATH. Add ~/go/bin to PATH and restart shell"
        fi
    fi

    info "croc usage:"
    echo "  To send files:    croc send <filename>"
    echo "  To receive files: croc <code-from-sender>"

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

    # Add environment variables to .bashrc
    info "Adding OpenCL environment variables to ~/.bashrc..."

    if ! grep -q "LD_LIBRARY_PATH.*vendor/lib64" ~/.bashrc; then
        cat >> ~/.bashrc << 'EOF'

# OpenCL GPU configuration for Adreno
export LD_LIBRARY_PATH=/system/vendor/lib64:$LD_LIBRARY_PATH
export PYOPENCL_CTX=0
export PYOPENCL_PLATFORM=0
EOF
        success "OpenCL environment variables added to ~/.bashrc"
    else
        info "OpenCL environment variables already in ~/.bashrc"
    fi

    # Export for current session
    export LD_LIBRARY_PATH=/system/vendor/lib64:$LD_LIBRARY_PATH
    export PYOPENCL_CTX=0
    export PYOPENCL_PLATFORM=0

    create_marker "$MARKER"
    success "Phase 4 complete: OpenCL configured"
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
# PHASE 6: BUILD LLAMA.CPP WITH OPENCL
# ============================================================================

phase6_build_llama() {
    local MARKER="$HOME/.setup_markers/phase6_build_llama"
    if skip_if_exists "$MARKER" "llama.cpp Build"; then
        return 0
    fi

    info "PHASE 6: Building llama.cpp with OpenCL support..."

    cd "$PROJECT_DIR/deps/llama.cpp"

    # Check if binaries already exist (cache check)
    if [ -f "build/bin/llama-server" ] && [ -f "build/bin/llama-bench" ]; then
        info "llama.cpp binaries already exist"

        # Verify they work
        if ./build/bin/llama-server --version 2>/dev/null; then
            success "Existing llama.cpp build verified and working"
            create_marker "$MARKER"
            return 0
        else
            warn "Existing binaries found but not working, will rebuild"
        fi
    fi

    # Clean previous build if exists but broken
    if [ -d "build" ]; then
        warn "Previous build directory exists but binaries missing/broken - cleaning"
        rm -rf build
    fi

    mkdir -p build
    cd build

    info "Running CMake configuration with OpenCL..."
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DGGML_OPENCL=ON \
        -DCMAKE_C_COMPILER=clang \
        -DCMAKE_CXX_COMPILER=clang++ \
        || error "CMake configuration failed"

    info "Building llama.cpp (this may take 10-20 minutes)..."
    cmake --build . --config Release -j$(nproc) || error "Build failed"

    # Verify binaries
    info "Verifying build artifacts..."
    if [ ! -f "bin/llama-server" ]; then
        error "llama-server binary not found"
    fi
    if [ ! -f "bin/llama-bench" ]; then
        error "llama-bench binary not found"
    fi

    # Test binary
    info "Testing llama-server binary..."
    ./bin/llama-server --version || warn "llama-server version check failed (may still work)"

    create_marker "$MARKER"
    success "Phase 6 complete: llama.cpp built successfully"
}

# ============================================================================
# PHASE 7: PYTHON ENVIRONMENT SETUP
# ============================================================================

phase7_python() {
    local MARKER="$HOME/.setup_markers/phase7_python"
    if skip_if_exists "$MARKER" "Python Environment"; then
        return 0
    fi

    info "PHASE 7: Setting up Python environment..."

    cd "$PROJECT_DIR"

    # Upgrade pip
    info "Upgrading pip..."
    python3 -m pip install --upgrade pip --user || warn "pip upgrade failed (continuing anyway)"

    # Install dependencies
    info "Installing Python dependencies..."

    # Check if packages are already installed (cache check)
    if python3 -c "import bottle; import tiktoken; import verifiers" 2>/dev/null; then
        info "Required Python packages already installed"
    else
        info "Installing missing Python packages..."
        if [ -f "requirements.txt" ]; then
            python3 -m pip install --user -r requirements.txt || error "Failed to install dependencies"
        else
            warn "requirements.txt not found, installing packages individually..."
            python3 -m pip install --user bottle tiktoken verifiers || error "Failed to install dependencies"
        fi
    fi

    # Add tinygrad to PYTHONPATH
    info "Configuring PYTHONPATH for tinygrad..."
    if ! grep -q "PYTHONPATH.*tinygrad" ~/.bashrc; then
        echo "export PYTHONPATH=\"$PROJECT_DIR/deps/tinygrad:\$PYTHONPATH\"" >> ~/.bashrc
        success "Added tinygrad to PYTHONPATH in ~/.bashrc"
    else
        info "tinygrad already in PYTHONPATH"
    fi
    export PYTHONPATH="$PROJECT_DIR/deps/tinygrad:$PYTHONPATH"

    # Verify imports
    info "Verifying Python imports..."
    python3 -c "import bottle; import tiktoken; from tinygrad.helpers import fetch" \
        || error "Python import verification failed"

    # Install verifiers environment for wordle
    info "Installing verifiers wordle environment..."

    # Check if wordle environment is already installed (cache check)
    if [ -d "$PROJECT_DIR/environments/wordle" ] && python3 -c "from verifiers.envs.wordle import Wordle" 2>/dev/null; then
        info "Wordle environment already installed"
    else
        info "Installing wordle environment from repo..."
        cd "$PROJECT_DIR/deps/verifiers"
        if python3 -m verifiers.scripts.install wordle --from-repo; then
            success "Wordle environment installed"
        else
            warn "Failed to install wordle environment (you can install it later with: python3 -m verifiers.scripts.install wordle --from-repo)"
        fi
        cd "$PROJECT_DIR"
    fi

    create_marker "$MARKER"
    success "Phase 7 complete: Python environment ready"
}

# ============================================================================
# PHASE 8: MODEL DOWNLOAD PREPARATION
# ============================================================================

phase8_models() {
    local MARKER="$HOME/.setup_markers/phase8_models"
    if skip_if_exists "$MARKER" "Model Download Preparation"; then
        return 0
    fi

    info "PHASE 8: Model download preparation..."

    cd "$PROJECT_DIR"

    # Create models directory
    mkdir -p models

    info "Model information:"
    echo "  Models are downloaded on-demand during benchmarking"
    echo "  Location: $PROJECT_DIR/models/"
    echo ""
    echo "  Available quantizations (Llama-3.2-1B-Instruct):"
    echo "    - default (Q6_K):  ~1.2GB"
    echo "    - int8 (Q8_0):     ~1.5GB"
    echo "    - nf4 (Q4_K_M):    ~800MB"
    echo "    - float16 (f16):   ~2.5GB"
    echo ""
    echo "  Total for all quantizations: ~6GB"
    echo ""

    # Check if any models already exist (cache check)
    if ls models/*.gguf 1> /dev/null 2>&1; then
        info "Found existing model files:"
        ls -lh models/*.gguf | awk '{print "  - " $9 " (" $5 ")"}'
        success "Models already downloaded, skipping download step"
    else
        info "No models found. Models will be downloaded automatically during first benchmark run"
        info "Or download manually now with:"
        echo "  python3 << 'EOF'"
        echo "  from tinygrad.helpers import fetch"
        echo "  from defaults import MODEL_CONFIGS"
        echo "  fetch(MODEL_CONFIGS['nf4']['url'], name='./models/Llama-3.2-1B-Instruct-Q4_K_M.gguf')"
        echo "  EOF"
    fi

    create_marker "$MARKER"
    success "Phase 8 complete: Ready for model downloads"
}

# ============================================================================
# PHASE 9: VERIFICATION AND NEXT STEPS
# ============================================================================

phase9_verify() {
    info "PHASE 9: Final verification..."

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
    echo "  [✓] OpenCL GPU configured"
    echo "  [✓] Repository cloned"
    echo "  [✓] llama.cpp built with OpenCL"
    echo "  [✓] Python environment ready"
    echo "  [✓] Ready for benchmarking"
    echo ""

    info "Next steps:"
    echo "  1. Reload shell environment:"
    echo "     source ~/.bashrc"
    echo ""
    echo "  2. Review benchmark documentation:"
    echo "     cat setup/PIXEL-BENCHMARK.md"
    echo ""
    echo "  3. Run benchmarks (quick):"
    echo "     cd ~/t-eai-project"
    echo "     ./pixel_benchmark_wrapper.sh"
    echo ""
    echo "  4. Or run benchmarks manually:"
    echo "     python3 llamacpp_benchmark.py"
    echo "     python3 llamacpp_sweep.py --env gsm8k --num-examples 20"
    echo ""
    echo "  5. Transfer results to host:"
    echo "     croc send benchmark_output/"
    echo ""

    success "Setup script completed successfully!"

    info "To apply environment changes, reload your shell with:"
    echo "  source ~/.bashrc"
    echo ""
    echo "Or start a new shell session"
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
    phase6_build_llama
    phase7_python
    phase8_models
    phase9_verify
}

# Run main function
main
