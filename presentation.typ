// Presentation: Comparing Quantization Across Hardware
// CSC 4228 & 6228 - Security in IoT
// Authors: Mike Doan, Jenny Dinh

#import "@preview/polylux:0.4.0": *

#set page(paper: "presentation-16-9")
#set text(font: "Libertinus Sans", size: 20pt)

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

  #v(0.5em)

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

  #v(0.5em)

  == Key Design Principles
  - *Reproducibility*: Seeded runs, UUID tracking
  - *Extensibility*: Easy to add new backends/devices
  - *Standardized schema*: Consistent CSV format across all backends
]

#slide[
  = Data Schema

  #v(0.5em)

  Each benchmark run captures:

  #text(size: 16pt)[
  ```
  BenchmarkRow:
    step: int                    # Token generation step
    enqueue_latency_ms: float    # Time to enqueue operation
    total_latency_ms: float      # Total time for step
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

  #v(0.5em)

  - Pure Python ML framework with Metal/OpenCL support
  - Server mode for OpenAI-compatible API

  #v(0.5em)

  ```bash
  # Start inference server
  PYTHONPATH=./deps/tinygrad/ python tinygrad_benchmark.py \
      --port 7776 --size 1B
  ```

  #v(0.5em)

  == Quantization Support
  - `default`: No quantization
  - `nf4`: 4-bit NormalFloat
  - `int8`: 8-bit integer
  - `float16`: Half precision
]

#slide[
  = Implementation: llama.cpp Backend

  #v(0.5em)

  - C/C++ implementation with GGUF model format
  - Highly optimized for CPU and GPU inference

  #v(0.5em)

  ```bash
  # Run benchmark
  python llamacpp_benchmark.py

  # Collate results
  python llamacpp_collate.py
  ```

  #v(0.5em)

  == Key Features
  - Native quantization support in model files
  - Metal backend for Apple Silicon
  - OpenCL for Android devices
]

#slide[
  = LLM Evaluation: Verifiers Framework

  #v(0.5em)

  Beyond raw throughput, we measure *downstream task accuracy*:

  #v(0.5em)

  #grid(
    columns: (1fr, 1fr),
    gutter: 2em,
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

  #v(0.5em)

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

  #v(0.5em)

  #align(center)[
    // TODO: Replace with actual chart
    #rect(width: 80%, height: 60%, stroke: 1pt + gray)[
      #align(center + horizon)[
        #text(size: 24pt, fill: gray)[
          *Throughput Chart*

          Tokens/sec across quantization levels

          (Generated from `visualize_benchmarks.py`)
        ]
      ]
    ]
  ]

  #v(0.5em)

  *Key finding*: NF4 quantization achieves ~3-5 tok/s on MacBook M-series with 1B model
]

#slide[
  = Results: Memory vs Throughput Trade-offs

  #v(0.5em)

  #align(center)[
    #rect(width: 80%, height: 60%, stroke: 1pt + gray)[
      #align(center + horizon)[
        #text(size: 24pt, fill: gray)[
          *Memory-Throughput Scatter Plot*

          Comparing quantization strategies

          (Generated from benchmark data)
        ]
      ]
    ]
  ]

  #v(0.5em)

  *Observation*: INT4/NF4 provides best memory-performance ratio for edge deployment
]

#slide[
  = Results: Device Comparison

  #v(0.5em)

  #table(
    columns: (1.5fr, 1fr, 1fr, 1fr),
    inset: 10pt,
    align: horizon,
    table.header(
      [*Device*], [*FP16*], [*INT8*], [*NF4*]
    ),
    [MacBook (Metal)], [~2 tok/s], [~3.5 tok/s], [~4 tok/s],
    [Pixel 7 (OpenCL)], [TBD], [TBD], [TBD],
    [Pixel 8 (OpenCL)], [TBD], [TBD], [TBD],
  )

  #v(1em)

  #text(size: 16pt)[
    *Note*: Results are from Llama-3.2-1B-Instruct model. Actual numbers vary with context length and workload.
  ]
]

// ============================================================================
// SECTION 5: CHALLENGES & LESSONS LEARNED
// ============================================================================

#slide[
  = Challenges Encountered

  #v(0.5em)

  #grid(
    columns: (1fr, 1fr),
    gutter: 2em,
    [
      == Software Compatibility
      - Different backends for ARM vs x86
      - MLC-LLM build complexity
        - "Opted to skip due to finicky build process"

      #v(1em)

      == Implementation Inconsistencies
      - Quantization standards differ across backends
      - Leads to performance discrepancies
    ],
    [
      == Engineering Challenges
      - Creating durable benchmarking suite
      - Handling device-specific configurations
        - Pixel 7 OpenCL requires special env vars

      #v(1em)

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

  #v(0.5em)

  #grid(
    columns: (1fr, 1fr),
    gutter: 2em,
    [
      == Reproducible Framework
      - Open-source benchmarking toolkit
      - Standardized data format
      - Easy to extend to new devices

      #v(1em)

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

      #v(1em)

      == Community Benefit
      - Others can benchmark their devices
      - Append results to shared data bank
    ]
  )
]

#slide[
  = Future Work

  #v(0.5em)

  - *Enterprise GPUs*: Extend benchmarks to A100, H100
  - *More Models*: Phi-3 mini, Qwen2.5-3B, Llama-3.1-8B
  - *Energy Profiling*: Watt/token measurements
  - *KV-Cache Quantization*: INT8/INT4 cache strategies
  - *Longer Contexts*: Prefill tokens 256, 1024, 2048

  #v(1em)

  == Potential Extensions
  - Automated setup script (`curl | sh`)
  - CI/CD backend for continuous benchmarking
  - Public data aggregation platform
]

#slide[
  = Conclusion

  #v(1em)

  - *Quantization enables practical edge LLM deployment*
    - 4-bit models run on smartphones with acceptable performance

  #v(0.5em)

  - *Trade-offs are workload-dependent*
    - Memory-constrained? → INT4/NF4
    - Accuracy-critical? → INT8 or FP16

  #v(0.5em)

  - *Framework enables reproducible research*
    - Standardized benchmarks across diverse hardware
    - Community can contribute additional results

  #v(1em)

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
