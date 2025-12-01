#!/data/data/com.termux/files/usr/bin/bash
# Pixel 7/8 Benchmark Wrapper Script
# Runs complete llama.cpp benchmark suite and packages results for transfer
#
# This script performs:
#   1. Performance benchmarks across all quantizations
#   2. Accuracy evaluation using verifiers (GSM8K)
#   3. Result collation into CSV format
#   4. Packaging results for transfer to host
#
# Usage:
#   cd ~/t-eai-project
#   ./pixel_benchmark_wrapper.sh
#
# Options:
#   --quick          Run with fewer examples (5 instead of 20)
#   --no-accuracy    Skip accuracy evaluation, only run performance benchmarks
#   --help           Show this help message

set -e  # Exit on error

# ============================================================================
# CONFIGURATION
# ============================================================================

PROJECT_DIR="$HOME/t-eai-project"
NUM_EXAMPLES=20
RUN_ACCURACY=true

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --quick)
            NUM_EXAMPLES=5
            shift
            ;;
        --no-accuracy)
            RUN_ACCURACY=false
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --quick          Run with fewer examples (5 instead of 20)"
            echo "  --no-accuracy    Skip accuracy evaluation"
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

# Export PYTHONPATH for tinygrad
export PYTHONPATH="$PROJECT_DIR/deps/tinygrad:$PYTHONPATH"

# Change to project directory
cd "$PROJECT_DIR" || {
    echo "ERROR: Project directory not found: $PROJECT_DIR"
    echo "Have you run setup/pixel7_setup.sh?"
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

    # Check llama.cpp binaries
    if [ ! -f "deps/llama.cpp/build/bin/llama-bench" ]; then
        error "llama-bench not found. Run setup/pixel7_setup.sh first"
    fi

    # Check Python
    if ! command -v python3 &> /dev/null; then
        error "python3 not found"
    fi

    # Check Python packages
    python3 -c "import bottle; import tiktoken; from tinygrad.helpers import fetch" 2>/dev/null \
        || error "Required Python packages not installed. Run: pip3 install -r requirements.txt"

    success "All dependencies found"
}

# ============================================================================
# MAIN BENCHMARK EXECUTION
# ============================================================================

echo ""
echo "=========================================="
echo "  Pixel Benchmark Suite"
echo "  llama.cpp backend"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  Project: $PROJECT_DIR"
echo "  Accuracy evaluation: $RUN_ACCURACY"
if [ "$RUN_ACCURACY" = true ]; then
    echo "  GSM8K examples: $NUM_EXAMPLES"
fi
echo ""

check_dependencies

START_TIME=$(date +%s)

# ============================================================================
# STEP 1: PERFORMANCE BENCHMARKS
# ============================================================================

info "[1/$([ "$RUN_ACCURACY" = true ] && echo "4" || echo "3")] Running performance benchmarks..."
echo "This will test all quantization methods: default, int8, nf4, float16"
echo "Expected time: 5-10 minutes"
echo ""

if python3 llamacpp_benchmark.py; then
    success "Performance benchmarks completed"
else
    error "Performance benchmarks failed"
fi

# ============================================================================
# STEP 2: ACCURACY EVALUATION (OPTIONAL)
# ============================================================================

if [ "$RUN_ACCURACY" = true ]; then
    info "[2/4] Running accuracy evaluation (wordle, $NUM_EXAMPLES examples)..."
    echo "This evaluates model accuracy on word-guessing tasks"
    echo "Expected time: $(($NUM_EXAMPLES * 1))-$(($NUM_EXAMPLES * 2)) minutes"
    echo ""

    if python3 llamacpp_sweep.py --env wordle --num-examples $NUM_EXAMPLES --size 1B; then
        success "Accuracy evaluation completed"
    else
        warn "Accuracy evaluation failed (continuing with result packaging)"
    fi
else
    info "Skipping accuracy evaluation (--no-accuracy flag set)"
fi

# ============================================================================
# STEP 3: COLLATE RESULTS
# ============================================================================

COLLATE_STEP=$([ "$RUN_ACCURACY" = true ] && echo "3" || echo "2")
TOTAL_STEPS=$([ "$RUN_ACCURACY" = true ] && echo "4" || echo "3")

info "[$COLLATE_STEP/$TOTAL_STEPS] Collating results into CSV..."

if python3 llamacpp_collate.py; then
    success "Results collated"
else
    warn "Collation failed (raw results still available in benchmark_output/)"
fi

# ============================================================================
# STEP 4: PACKAGE RESULTS
# ============================================================================

PACKAGE_STEP=$([ "$RUN_ACCURACY" = true ] && echo "4" || echo "3")

info "[$PACKAGE_STEP/$TOTAL_STEPS] Packaging results..."

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
HOSTNAME=$(hostname)
RESULT_ARCHIVE="pixel_results_${HOSTNAME}_${TIMESTAMP}.tar.gz"

# Create archive with all results
tar -czf "$RESULT_ARCHIVE" \
    benchmark_output/*.txt \
    benchmark_output/llamacpp.csv \
    $([ "$RUN_ACCURACY" = true ] && echo "verifiers_results/*.json" || echo "") \
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
echo "  - benchmark_output/llamacpp.csv (collated performance data)"
if [ "$RUN_ACCURACY" = true ]; then
    echo "  - verifiers_results/*.json (accuracy evaluation)"
fi
echo ""
echo "To view results summary:"
echo "  python3 visualize_benchmarks.py"
echo ""
success "All tasks completed successfully!"
