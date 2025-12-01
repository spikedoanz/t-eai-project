#!/data/data/com.termux/files/usr/bin/bash
# Pixel 7/8 Benchmark Wrapper Script
# Runs tinygrad performance benchmarks and packages results for transfer
#
# This script performs:
#   1. Performance benchmarks across all quantizations (default, int8, nf4, float16)
#   2. Result collation into CSV format
#   3. Packaging results for transfer to host
#
# Usage:
#   cd ~/t-eai-project
#   ./pixel_benchmark_wrapper.sh
#
# Options:
#   --help           Show this help message

set -e  # Exit on error

# ============================================================================
# CONFIGURATION
# ============================================================================

PROJECT_DIR="$HOME/t-eai-project"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
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
# ENVIRONMENT SETUP
# ============================================================================

# Export OpenCL environment variables
export LD_LIBRARY_PATH=/system/vendor/lib64:$LD_LIBRARY_PATH
export PYOPENCL_CTX=0
export PYOPENCL_PLATFORM=0

# Tinygrad GPU configuration
export GPU=1
export OPENCL=1

# Export PYTHONPATH for tinygrad
export PYTHONPATH="$PROJECT_DIR/deps/tinygrad:$PYTHONPATH"

# Change to project directory
cd "$PROJECT_DIR" || {
    echo "ERROR: Project directory not found: $PROJECT_DIR"
    echo "Have you run setup/termux.sh?"
    exit 1
}

# ============================================================================
# UTILITY FUNCTIONS
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

check_dependencies() {
    info "Checking dependencies..."

    # Check Python
    if ! command -v python3 &> /dev/null; then
        error "python3 not found"
    fi

    # Check Python packages
    python3 -c "import bottle; import tiktoken; from tinygrad.helpers import fetch" 2>/dev/null \
        || error "Required Python packages not installed. Run: pip3 install bottle tiktoken"

    success "All dependencies found"
}

# ============================================================================
# MAIN BENCHMARK EXECUTION
# ============================================================================

echo ""
echo "=========================================="
echo "  Pixel Benchmark Suite"
echo "  tinygrad backend"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  Project: $PROJECT_DIR"
echo "  Quantizations: default, int8, nf4, float16"
echo ""

check_dependencies

START_TIME=$(date +%s)

# ============================================================================
# STEP 1: PERFORMANCE BENCHMARKS
# ============================================================================

info "[1/3] Running performance benchmarks..."
echo "This will test all quantization methods: default, int8, nf4, float16"
echo "Expected time: 5-10 minutes"
echo ""

if python3 tinygrad_benchmark.py; then
    success "Performance benchmarks completed"
else
    error "Performance benchmarks failed"
fi

# ============================================================================
# STEP 2: COLLATE RESULTS
# ============================================================================

info "[2/3] Collating results into CSV..."

if python3 tinygrad_collate.py 2>/dev/null || python3 llamacpp_collate.py 2>/dev/null; then
    success "Results collated"
else
    warn "Collation script not found (raw results still available in benchmark_output/)"
fi

# ============================================================================
# STEP 3: PACKAGE RESULTS
# ============================================================================

info "[3/3] Packaging results..."

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
HOSTNAME=$(hostname)
RESULT_ARCHIVE="pixel_results_${HOSTNAME}_${TIMESTAMP}.tar.gz"

# Create archive with all results
tar -czf "$RESULT_ARCHIVE" \
    benchmark_output/*.txt \
    benchmark_output/*.csv \
    2>/dev/null || warn "Some result files may be missing from archive"

if [ -f "$RESULT_ARCHIVE" ]; then
    ARCHIVE_SIZE=$(du -h "$RESULT_ARCHIVE" | cut -f1)
    success "Results packaged: $RESULT_ARCHIVE ($ARCHIVE_SIZE)"
else
    error "Failed to create results archive"
fi

# ============================================================================
# FINAL SUMMARY
# ============================================================================

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
ELAPSED_MIN=$((ELAPSED / 60))
ELAPSED_SEC=$((ELAPSED % 60))

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
echo "  1. Via croc (recommended):"
echo "     croc send $RESULT_ARCHIVE"
echo ""
echo "  2. Via SSH/SCP:"
echo "     From host machine:"
echo "     scp -P 8022 \$(whoami)@<pixel-ip>:~/t-eai-project/$RESULT_ARCHIVE ."
echo ""
echo "Raw results also available in:"
echo "  - benchmark_output/*.txt (raw logs)"
echo "  - benchmark_output/*.csv (collated performance data)"
echo ""
success "All tasks completed successfully!"
