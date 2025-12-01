// Presentation: Comparing Quantization Across Hardware
// CSC 4228 & 6228 - Security in IoT
// Authors: Mike Doan, Jenny Dinh

#import "@preview/polylux:0.4.0": *

#set page(paper: "presentation-16-9")
#set text(font: "JetBrainsMono NF", size: 20pt)

#let footer-text = [Doan & Dinh | CSC 4228/6228 | Fall 2024]

#set page(
  footer: align(center, footer-text),
  footer-descent: 1em,
)

// ============================================================================
// TITLE SLIDE
// ============================================================================

#slide[
  #align(center + horizon)[
    #text(size: 36pt, weight: "bold")[Comparing Quantization Across Hardware]

    #v(1em)

    #text(size: 24pt)[Benchmarking LLM Inference on Edge Devices]

    #v(2em)

    #text(size: 18pt)[
      *Mike Doan* · *Jenny Dinh*

      CSC 4228 & 6228 — Security in IoT

      Georgia State University

      Fall 2024
    ]
  ]
]

// ============================================================================
// SECTION 1: INTRODUCTION & BACKGROUND
// ============================================================================

#slide[
  = Introduction & Background

  #v(1em)

  == The Rise of Local LLM Deployment

  - Growing interest in running LLMs *locally* rather than via cloud APIs
  - Target environments:
    - *Edge devices*: smartphones, embedded systems
    - *Consumer hardware*: laptops, gaming PCs
    - *Enterprise GPUs*: data center deployments

  #v(1em)

  == The Memory Challenge

  - LLMs contain *massive weights* requiring significant memory
  - Activations during inference are also substantial
  - Example: Llama-3.1-8B requires ~16GB in FP16
]

#slide[
  = Background: What is Quantization?

  #v(1em)

  *Quantization* reduces the precision of model weights and activations to decrease memory footprint and improve inference speed.

  #v(1em)

  #table(
    columns: (1fr, 1fr, 1fr),
    inset: 10pt,
    align: horizon,
    table.header(
      [*Precision*], [*Bits per Weight*], [*Memory (8B model)*]
    ),
    [FP16 / BF16], [16 bits], [~16 GB],
    [INT8 (W8A8)], [8 bits], [~8 GB],
    [INT4 (W4A8)], [4 bits], [~4 GB],
    [NF4], [4 bits], [~4 GB],
  )

  #v(1em)

  *Trade-off*: Lower precision → smaller memory, faster inference, but potential accuracy loss
]

#slide[
  = Background: Quantization Strategies

  #v(0.5em)

  #grid(
    columns: (1fr, 1fr),
    gutter: 2em,
    [
      == Weight-Only Quantization
      - *INT8*: 8-bit integer weights
      - *INT4*: 4-bit integer weights
      - *NF4*: 4-bit NormalFloat (QLoRA)

      #v(1em)

      == Group-wise Quantization
      - *GPTQ*: Post-training quantization
      - *AWQ*: Activation-aware weights
    ],
    [
      == KV-Cache Quantization
      - Reduces memory for long contexts
      - INT8 or INT4 KV cache

      #v(1em)

      == Activation Quantization
      - *W8A8*: Both weights and activations in INT8
      - *W4A4*: Aggressive 4-bit for both
    ]
  )
]

// ============================================================================
// SECTION 2: PURPOSE & MOTIVATION
// ============================================================================

#slide[
  = Purpose & Motivation

  #v(1em)

  == Research Questions

  #v(0.5em)

  + How do different *quantization strategies* impact inference performance across hardware?

  + What are the *accuracy-efficiency trade-offs* for edge deployment?

  + Can we create a *reproducible benchmarking framework* for the community?

  #v(1em)

  == Gap in Existing Work

  - Few plug-and-play toolkits for *cross-platform quantization sweeps*
  - Limited public data on *edge device performance*
  - Need for standardized comparison methodology
]

#slide[
  = Target Hardware & Scope

  #v(0.5em)

  #grid(
    columns: (1fr, 1fr),
    gutter: 2em,
    [
      == Edge Devices
      - *Google Pixel 7/8* (Android)
        - ARM CPU + Adreno GPU
        - OpenCL backend

      #v(1em)

      == Consumer Hardware
      - *MacBook* (Apple Silicon)
        - Metal backend
        - Unified memory
    ],
    [
      == Runtimes Evaluated
      - *llama.cpp* (GGUF format)
      - *tinygrad* (Metal/OpenCL)
      - MLC-LLM (TVM-based)

      #v(1em)

      == Models
      - Llama-3.2-1B-Instruct
      - Qwen2.5-1.5B
      - (Extensible to larger models)
    ]
  )
]

// ============================================================================
// SECTION 3: SYSTEM DESIGN & IMPLEMENTATION
// ============================================================================

#slide[
  = System Architecture

  #align(center)[
    #rect(width: 90%, inset: 1em, stroke: 1pt)[
      #grid(
        columns: (1fr, 1fr, 1fr),
        gutter: 1em,
        [
          #rect(fill: rgb("#e3f2fd"), inset: 0.8em)[
            *Benchmark Scripts*

            `tinygrad_benchmark.py`
            `llamacpp_benchmark.py`
            `mlc_benchmark.py`
          ]
        ],
        [
          #rect(fill: rgb("#fff3e0"), inset: 0.8em)[
            *Data Collection*

            `*_collate.py`
            `*_parse.py`
            CSV output
          ]
        ],
        [
          #rect(fill: rgb("#e8f5e9"), inset: 0.8em)[
            *Analysis & Viz*

            `visualize_benchmarks.py`
            `benchmark_analysis.py`
          ]
        ],
      )
    ]
  ]

  == Key Design Principles
  - *Reproducibility*: Seeded runs, UUID tracking
  - *Extensibility*: Easy to add new backends/devices
  - *Standardized schema*: Consistent CSV format across all backends
]

#slide[
  = Benchmark Workflow

  #text(size: 13pt)[
  // Row 1: Pixel Setup & Model Prep
  #grid(
    columns: (1fr, auto, 1fr, auto, 1fr),
    gutter: 0.4em,
    [
      #rect(fill: rgb("#ede7f6"), inset: 0.5em, height: 100%)[
        *0. Pixel Setup*

        Termux + SSH + OpenCL

        `croc`, `cmake`, `clang`
      ]
    ],
    [→],
    [
      #rect(fill: rgb("#e3f2fd"), inset: 0.5em, height: 100%)[
        *1. Model Prep*

        Download models

        Quantize (GGUF/HF)
      ]
    ],
    [→],
    [
      #rect(fill: rgb("#fff3e0"), inset: 0.5em, height: 100%)[
        *2. Run Benchmarks*

        Execute on devices

        Output: `.txt` logs
      ]
    ],
  )

  #v(0.5em)

  // Row 2: Presentation (leftmost) and remaining workflow (snake back)
  #grid(
    columns: (1fr, auto, 1fr, auto, 1fr),
    gutter: 0.4em,
    [
      #rect(fill: rgb("#c8e6c9"), inset: 0.5em, height: 100%)[
        *5. Presentation*

        Embed plots

        `typst compile`
      ]
    ],
    [←],
    [
      #rect(fill: rgb("#e8f5e9"), inset: 0.5em, height: 100%)[
        *4. Visualize*

        Generate plots

        `.png` files
      ]
    ],
    [←],
    [
      #rect(fill: rgb("#fce4ec"), inset: 0.5em, height: 100%)[
        *3. Collate*

        Parse logs

        Structured CSV
      ]
    ],
  )
  ]

  #v(0.3em)
  #text(size: 12pt)[
    Flow: Pixel setup → Model prep → Benchmarks → Collation → Visualization → Presentation
  ]
]

#slide[
  = Data Schema

  Each benchmark run captures:

  #text(size: 14pt)[
  ```
  BenchmarkRow:
    step: int                    # Token generation step
    enqueue_latency_ms: float    # Time to enqueue
    total_latency_ms: float      # Total time
    tokens_per_sec: float        # Throughput
    memory_throughput_gb_s: float
    param_throughput_gb_s: float
    platform: str                # Darwin, Linux, Android
    device: str                  # Metal, OpenCL, CUDA
    hostname: str                # Machine identifier
    size: str                    # Model size (1B, 3B, 8B)
    quantize: str                # nf4, int8, float16, default
    seed: int                    # For reproducibility
    uuid: str                    # Unique run identifier
  ```
  ]
]

#slide[
  = Implementation: Tinygrad Backend

  - Pure Python ML framework with Metal/OpenCL support
  - Server mode for OpenAI-compatible API

  #text(size: 16pt)[
  ```bash
  # Start inference server
  PYTHONPATH=./deps/tinygrad/ python tinygrad_benchmark.py \
      --port 7776 --size 1B
  ```
  ]

  == Quantization Support
  - `default`: No quantization
  - `nf4`: 4-bit NormalFloat
  - `int8`: 8-bit integer
  - `float16`: Half precision
]

#slide[
  = Implementation: llama.cpp Backend

  - C/C++ implementation with GGUF model format
  - Highly optimized for CPU and GPU inference

  #text(size: 16pt)[
  ```bash
  # Run benchmark
  python llamacpp_benchmark.py

  # Collate results
  python llamacpp_collate.py
  ```
  ]

  == Key Features
  - Native quantization support in model files
  - Metal backend for Apple Silicon
  - OpenCL for Android devices
]

#slide[
  = Implementation: Pixel Device Setup

  #text(size: 14pt)[
  #grid(
    columns: (1fr, 1fr),
    gutter: 1em,
    [
      == Bootstrap (Termux)
      ```bash
      # Install from F-Droid
      pkg update && pkg upgrade
      pkg install python git openssh
      pkg install cmake clang ninja
      pkg install golang

      # Install uv & croc
      curl -LsSf astral.sh/uv/install.sh | sh
      go install github.com/schollz/croc/v10@latest
      ```

      == SSH Access (Tailscale)
      ```bash
      # On Pixel
      sshd
      passwd
      id  # Get username (u0_a190)

      # From host
      ssh u0_a190@<tailscale-ip> -p 8022
      ```
    ],
    [
      == OpenCL GPU Setup
      ```bash
      # Install OpenCL for Adreno GPU
      pkg install opencl-headers opencl-vendor-driver

      # Set environment
      export LD_LIBRARY_PATH=/system/vendor/lib64:$LD_LIBRARY_PATH
      export GPU=1
      export OPENCL=1
      ```

      == Build & Transfer
      ```bash
      # Build llama.cpp with OpenCL
      cmake .. -DGGML_OPENCL=ON
      cmake --build . -j$(nproc)

      # Transfer models with croc
      croc send model.gguf
      ```
    ]
  )
  ]

  Full setup guide: `docs/WORKFLOW.md` & `setup/PIXEL-SSH.md`
]

#slide[
  = LLM Evaluation: Verifiers Framework

  Beyond raw throughput, we measure *downstream task accuracy*:

  #text(size: 14pt)[
  #grid(
    columns: (1fr, 1fr),
    gutter: 1em,
    [
      == Setup
      ```bash
      # Start model server
      python tinygrad_benchmark.py \
          --port 7776 --size 1B

      # OpenAI proxy (streaming)
      python openai_proxy.py \
          --backend-port 7776 \
          --proxy-port 7777
      ```
    ],
    [
      == Run Evaluation
      ```bash
      # GSM8K math benchmark
      OPENAI_API_KEY=dummy \
      uv run vf-eval gsm8k \
          -m local \
          -b http://localhost:7777/v1 \
          -n 20 -r 1 -t 512
      ```
    ]
  )
  ]

  Available benchmarks: `gsm8k`, `math`, `gpqa`, `simpleqa`, `wordle`
]

// ============================================================================
// SECTION 4: DATA COLLECTION & RESULTS
// ============================================================================

#slide[
  = Metrics Collected

  #v(0.5em)

  #grid(
    columns: (1fr, 1fr),
    gutter: 2em,
    [
      == Performance Metrics

      *Latency*
      - Time to first token (TTFT)
      - Per-token generation time

      *Throughput*
      - Tokens per second (tok/s)
      - Memory bandwidth (GB/s)
    ],
    [
      == Resource Metrics

      *Memory*
      - Model load size (MB)
      - Peak utilization

      *Accuracy*
      - Downstream benchmark scores
      - (GSM8K, MATH, etc.)
    ]
  )
]

#slide[
  = Results: Throughput Comparison

  #align(center)[
    #image("docs/images/backend_comparison.png", width: 90%)
  ]

  *Key findings*:
  - llama.cpp excels with NF4 (46.4 tok/s) and default (41.3 tok/s)
  - tinygrad performs best with INT8 (27.5 tok/s) and float16 (25.4 tok/s)
  - Performance varies significantly by quantization method
]

#slide[
  = Results: Speedup Analysis

  #align(center)[
    #image("docs/images/speedup_comparison.png", width: 90%)
  ]

  *Observations*:
  - llama.cpp shows 16.6x speedup over tinygrad for NF4
  - tinygrad leads by 8.0x for float16 workloads
  - INT8 and default show modest llama.cpp advantage (1.2-2.5x)
]

#slide[
  = Results: Performance Summary

  #align(center)[
    #image("docs/images/summary_stats.png", width: 90%)
  ]

  *Backend comparison*:
  - llama.cpp: Average 31.0 tok/s, peak 46.4 tok/s (NF4)
  - tinygrad: Average 18.1 tok/s, peak 27.5 tok/s (INT8)
  - Overall llama.cpp shows ~1.7x better average performance
]

#slide[
  = Results: Quantization Impact

  #align(center)[
    #image("docs/images/quantization_impact.png", width: 90%)
  ]

  *Trends*:
  - Different backends favor different quantization strategies
  - llama.cpp benefits most from aggressive quantization (NF4)
  - tinygrad shows more consistent performance across methods
]

#slide[
  = Results: Latency Analysis

  #align(center)[
    #image("docs/images/latency_distribution.png", width: 90%)
  ]

  *Latency variance*:
  - Box plots show distribution of per-token generation time
  - llama.cpp shows lower variance for NF4 and default
  - tinygrad has more consistent latency across quantizations
]

#slide[
  = Results: Memory & Parameter Throughput

  #grid(
    columns: (1fr, 1fr),
    gutter: 1em,
    [
      #image("docs/images/memory_throughput.png", width: 100%)
    ],
    [
      #image("docs/images/param_throughput.png", width: 100%)
    ]
  )

  *Observations*:
  - Memory bandwidth closely correlates with tokens/sec
  - Parameter throughput shows compute efficiency per quantization
]

#slide[
  = Results: Multi-Device Comparison

  #align(center)[
    #image("docs/images/device_comparison.png", width: 90%)
  ]

  *Cross-device insights*:
  - MacBook (softmacs) shows stronger performance overall
  - Android device (localhost) exhibits different characteristics
  - Backend choice impacts relative performance across hardware
]

#slide[
  = Results: Performance Summary Table

  #table(
    columns: (1.5fr, 1fr, 1fr, 1fr, 1fr),
    inset: 10pt,
    align: horizon,
    table.header(
      [*Backend*], [*Default*], [*FP16*], [*INT8*], [*NF4*]
    ),
    [llama.cpp], [41.3 tok/s], [3.2 tok/s], [33.2 tok/s], [46.4 tok/s],
    [tinygrad], [16.6 tok/s], [25.4 tok/s], [27.5 tok/s], [2.8 tok/s],
  )

  #v(0.5em)

  #text(size: 14pt)[
    *Note*: Results from Llama-3.2-1B-Instruct on MacBook (Metal). Performance varies with context length and workload.
  ]
]

// ============================================================================
// COMPLETED plots:
// ✅ Latency distribution (box plots showing variance)
// ✅ Memory throughput comparison (GB/s)
// ✅ Parameter throughput comparison (GB/s)
// ✅ Multi-device comparison (localhost vs softmacs)
//
// TODO: Additional plots still needed (missing data):
// ❌ Memory usage comparison (MB per quantization level) - needs profiling
// ❌ Energy consumption (watts/token) - needs power monitoring
// ❌ Accuracy vs throughput scatter - verifiers data shows 0% accuracy
// ❌ Context length impact - all runs use same context length
// ============================================================================

// ============================================================================
// SECTION 5: CHALLENGES & LESSONS LEARNED
// ============================================================================

#slide[
  = Challenges Encountered

  #grid(
    columns: (1fr, 1fr),
    gutter: 1.5em,
    [
      == Software Compatibility
      - Different backends for ARM vs x86
      - MLC-LLM build complexity

      #v(0.5em)

      == Implementation Inconsistencies
      - Quantization standards differ across backends
      - Leads to performance discrepancies
    ],
    [
      == Engineering Challenges
      - Creating durable benchmarking suite
      - Handling device-specific configurations

      #v(0.5em)

      == Android Setup
      - SSH into Pixel devices
      - OpenCL library path configuration
    ]
  )
]

// ============================================================================
// SECTION 6: CONCLUSION & FUTURE WORK
// ============================================================================

#slide[
  = Contributions

  #grid(
    columns: (1fr, 1fr),
    gutter: 1.5em,
    [
      == Reproducible Framework
      - Open-source benchmarking toolkit
      - Standardized data format
      - Easy to extend to new devices

      #v(0.5em)

      == Public Codebase
      - MIT licensed
      - Well-documented
      - GitHub repository
    ],
    [
      == Empirical Results
      - Cross-device performance data
      - Quantization trade-off analysis
      - Downstream accuracy evaluation

      #v(0.5em)

      == Community Benefit
      - Others can benchmark their devices
      - Append results to shared data bank
    ]
  )
]

#slide[
  = Future Work

  - *Enterprise GPUs*: Extend benchmarks to A100, H100
  - *More Models*: Phi-3 mini, Qwen2.5-3B, Llama-3.1-8B
  - *Energy Profiling*: Watt/token measurements
  - *KV-Cache Quantization*: INT8/INT4 cache strategies
  - *Longer Contexts*: Prefill tokens 256, 1024, 2048

  #v(0.5em)

  == Potential Extensions
  - Automated setup script (`curl | sh`)
  - CI/CD backend for continuous benchmarking
  - Public data aggregation platform
]

#slide[
  = Conclusion

  - *Quantization enables practical edge LLM deployment*
    - 4-bit models run on smartphones with acceptable performance

  #v(0.3em)

  - *Trade-offs are workload-dependent*
    - Memory-constrained? → INT4/NF4
    - Accuracy-critical? → INT8 or FP16

  #v(0.3em)

  - *Framework enables reproducible research*
    - Standardized benchmarks across diverse hardware
    - Community can contribute additional results

  #v(0.5em)

  #align(center)[
    #text(size: 18pt)[
      *Code*: `github.com/spikedoanz/t-eai-project`
    ]
  ]
]

// ============================================================================
// REFERENCES
// ============================================================================

#slide[
  = References

  #v(0.5em)

  #text(size: 14pt)[
    + *llama.cpp* — Georgi Gerganov et al. High-performance LLM inference in C/C++. \ https://github.com/ggerganov/llama.cpp

    + *tinygrad* — George Hotz et al. A simple deep learning framework. \ https://github.com/tinygrad/tinygrad

    + *MLC-LLM* — Machine Learning Compilation for LLMs. \ https://github.com/mlc-ai/mlc-llm

    + *Verifiers* — Prime Intellect. LLM evaluation framework. \ https://github.com/PrimeIntellect-ai/verifiers

    + *QLoRA* — Dettmers et al. (2023). Efficient Finetuning of Quantized LLMs.

    + *GPTQ* — Frantar et al. (2022). Accurate Post-Training Quantization.

    + *AWQ* — Lin et al. (2023). Activation-aware Weight Quantization.
  ]
]

#slide[
  #align(center + horizon)[
    #text(size: 36pt, weight: "bold")[Thank You!]

    #v(2em)

    #text(size: 20pt)[
      *Questions?*

      #v(1em)

      Mike Doan · Jenny Dinh

      #v(1em)

      `github.com/spikedoanz/t-eai-project`
    ]
  ]
]
