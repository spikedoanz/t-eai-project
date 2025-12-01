// Presentation: Comparing Quantization Across Hardware
// CSC 4228 & 6228 - Security in IoT
// Authors: Mike Doan, Jenny Dinh

#import "@preview/polylux:0.4.0": *

// Catppuccin Mocha color palette
#let mocha-base = rgb("#1e1e2e")
#let mocha-mantle = rgb("#181825")
#let mocha-crust = rgb("#11111b")
#let mocha-text = rgb("#cdd6f4")
#let mocha-subtext1 = rgb("#bac2de")
#let mocha-subtext0 = rgb("#a6adc8")
#let mocha-overlay2 = rgb("#9399b2")
#let mocha-surface0 = rgb("#313244")
#let mocha-surface1 = rgb("#45475a")
#let mocha-surface2 = rgb("#585b70")
#let mocha-blue = rgb("#89b4fa")
#let mocha-lavender = rgb("#b4befe")
#let mocha-sapphire = rgb("#74c7ec")
#let mocha-sky = rgb("#89dceb")
#let mocha-teal = rgb("#94e2d5")
#let mocha-green = rgb("#a6e3a1")
#let mocha-yellow = rgb("#f9e2af")
#let mocha-peach = rgb("#fab387")
#let mocha-maroon = rgb("#eba0ac")
#let mocha-red = rgb("#f38ba8")
#let mocha-mauve = rgb("#cba6f7")
#let mocha-pink = rgb("#f5c2e7")
#let mocha-flamingo = rgb("#f2cdcd")
#let mocha-rosewater = rgb("#f5e0dc")

#set page(paper: "presentation-16-9", fill: mocha-base)
#set text(font: "JetBrainsMono NF", size: 20pt, fill: mocha-text)

// Code block styling for dark theme
#show raw.where(block: true): it => {
  block(
    fill: mocha-surface0,
    inset: 0.8em,
    radius: 4pt,
    width: 100%,
    text(fill: mocha-text, it)
  )
}

#show raw.where(block: false): it => {
  box(
    fill: mocha-surface0,
    inset: (x: 0.3em, y: 0.2em),
    radius: 2pt,
    text(fill: mocha-text, it)
  )
}

// Colorful heading styles
#show heading.where(level: 1): it => {
  text(fill: mocha-mauve, weight: "bold", it)
}

#show heading.where(level: 2): it => {
  text(fill: mocha-blue, weight: "bold", it)
}

#show heading.where(level: 3): it => {
  text(fill: mocha-teal, weight: "bold", it)
}

#let footer-text = [Doan & Dinh | CSC 4228/6228 | Fall 2024]

// ============================================================================
// TITLE SLIDE
// ============================================================================

#slide[
  #set page(footer: align(center, footer-text), footer-descent: 1em)
  #align(center + horizon)[
    #text(size: 36pt, weight: "bold", fill: mocha-mauve)[Comparing Quantization Across Hardware]

    #v(1em)

    #text(size: 24pt, fill: mocha-blue)[Benchmarking LLM Inference on Edge Devices]

    #v(2em)

    #text(size: 18pt)[
      #text(fill: mocha-pink)[*Mike Doan*] · #text(fill: mocha-pink)[*Jenny Dinh*]

      #text(fill: mocha-lavender)[CSC 4228 & 6228 — Security in IoT]

      #text(fill: mocha-sapphire)[Georgia State University]

      #text(fill: mocha-teal)[Fall 2024]
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

  - Growing interest in running LLMs #text(fill: mocha-green)[*locally*] rather than via cloud APIs
  - Target environments:
    - #text(fill: mocha-peach)[*Edge devices*]: smartphones, embedded systems
    - #text(fill: mocha-blue)[*Consumer hardware*]: laptops, gaming PCs
    - #text(fill: mocha-mauve)[*Enterprise GPUs*]: data center deployments

  #v(1em)

  == The Memory Challenge

  - LLMs contain #text(fill: mocha-red)[*massive weights*] requiring significant memory
  - Activations during inference are also substantial
  - Example: #text(fill: mocha-yellow)[Llama-3.1-8B] requires ~16GB in FP16
]

#slide[
  = Background: What is Quantization?

  #v(1em)

  #text(fill: mocha-green)[*Quantization*] reduces the precision of model weights and activations to decrease #text(fill: mocha-peach)[memory footprint] and improve #text(fill: mocha-sky)[inference speed].

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

  #text(fill: mocha-yellow)[*Trade-off*]: Lower precision → #text(fill: mocha-green)[smaller memory], #text(fill: mocha-blue)[faster inference], but #text(fill: mocha-red)[potential accuracy loss]
]

#slide[
  = Background: Quantization Strategies

  #text(size: 18pt)[
  #grid(
    columns: (1fr, 1fr),
    gutter: 1.5em,
    [
      == Weight-Only Quantization
      - #text(fill: mocha-green)[*INT8*]: 8-bit integer weights
      - #text(fill: mocha-yellow)[*INT4*]: 4-bit integer weights
      - #text(fill: mocha-peach)[*NF4*]: 4-bit NormalFloat (QLoRA)

      #v(0.5em)

      == Group-wise Quantization
      - #text(fill: mocha-mauve)[*GPTQ*]: Post-training quantization
      - #text(fill: mocha-pink)[*AWQ*]: Activation-aware weights
    ],
    [
      == KV-Cache Quantization
      - Reduces memory for long contexts
      - #text(fill: mocha-sky)[INT8] or #text(fill: mocha-sapphire)[INT4] KV cache

      #v(0.5em)

      == Activation Quantization
      - #text(fill: mocha-blue)[*W8A8*]: Both weights and activations in INT8
      - *W4A4*: Aggressive 4-bit for both
    ]
  )
  ]
]

// ============================================================================
// SECTION 2: PURPOSE & MOTIVATION
// ============================================================================

#slide[
  = Purpose & Motivation

  #v(1em)

  == Research Questions

  #v(0.5em)

  + How do different #text(fill: mocha-peach)[*quantization strategies*] impact inference performance across hardware?

  + What are the #text(fill: mocha-yellow)[*accuracy-efficiency trade-offs*] for edge deployment?

  + Can we create a #text(fill: mocha-green)[*reproducible benchmarking framework*] for the community?

  #v(1em)

  == Gap in Existing Work

  - Few plug-and-play toolkits for #text(fill: mocha-mauve)[*cross-platform quantization sweeps*]
  - Limited public data on #text(fill: mocha-pink)[*edge device performance*]
  - Need for #text(fill: mocha-blue)[standardized comparison methodology]
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
    #box(width: 90%)[
      #text(size: 16pt)[
      #grid(
        columns: (1fr, 1fr, 1fr),
        gutter: 0.8em,
        [
          #rect(fill: mocha-surface0, inset: 0.6em, stroke: 1pt + mocha-blue)[
            *Benchmark Scripts* \
            #v(0.2em)
            `tinygrad_benchmark.py` \
            `llamacpp_benchmark.py` \
            `mlc_benchmark.py`
          ]
        ],
        [
          #rect(fill: mocha-surface0, inset: 0.6em, stroke: 1pt + mocha-peach)[
            *Data Collection* \
            #v(0.2em)
            `*_collate.py` \
            `*_parse.py` \
            CSV output
          ]
        ],
        [
          #rect(fill: mocha-surface0, inset: 0.6em, stroke: 1pt + mocha-green)[
            *Analysis & Viz* \
            #v(0.2em)
            `visualize_benchmarks.py` \
            `benchmark_analysis.py`
          ]
        ],
      )
      ]
    ]
  ]

  #text(size: 16pt)[
  == Key Design Principles
  - *Reproducibility*: Seeded runs, UUID tracking
  - *Extensibility*: Easy to add new backends/devices
  - *Standardized schema*: Consistent CSV format
  ]
]

#slide[
  = Benchmark Workflow

  #align(center)[
    #box(width: 95%)[
      #grid(
        columns: (1fr, 1fr, 1fr),
        gutter: 0.8em,
        [
          #rect(fill: mocha-surface0, inset: 0.8em, width: 100%, stroke: 1pt + mocha-mauve)[
            #text(size: 14pt, fill: mocha-text)[
              *0. Pixel Setup* \
              Termux + SSH + OpenCL \
              `croc`, `cmake`
            ]
          ]
        ],
        [
          #rect(fill: mocha-surface0, inset: 0.8em, width: 100%, stroke: 1pt + mocha-blue)[
            #text(size: 14pt, fill: mocha-text)[
              *1. Model Prep* \
              Download models \
              Quantize (GGUF/HF)
            ]
          ]
        ],
        [
          #rect(fill: mocha-surface0, inset: 0.8em, width: 100%, stroke: 1pt + mocha-peach)[
            #text(size: 14pt, fill: mocha-text)[
              *2. Run Benchmarks* \
              Execute on devices \
              Output: `.txt` logs
            ]
          ]
        ],
        [
          #rect(fill: mocha-surface0, inset: 0.8em, width: 100%, stroke: 1pt + mocha-pink)[
            #text(size: 14pt, fill: mocha-text)[
              *3. Collate* \
              Parse logs \
              Structured CSV
            ]
          ]
        ],
        [
          #rect(fill: mocha-surface0, inset: 0.8em, width: 100%, stroke: 1pt + mocha-teal)[
            #text(size: 14pt, fill: mocha-text)[
              *4. Visualize* \
              Generate plots \
              `.png` files
            ]
          ]
        ],
        [
          #rect(fill: mocha-surface0, inset: 0.8em, width: 100%, stroke: 1pt + mocha-green)[
            #text(size: 14pt, fill: mocha-text)[
              *5. Presentation* \
              Embed plots \
              `typst compile`
            ]
          ]
        ],
      )
    ]
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

  #text(size: 12pt)[
  #grid(
    columns: (1fr, 1fr),
    gutter: 0.8em,
    [
      == Bootstrap (Termux)
      ```bash
      # Install from F-Droid
      pkg update && pkg upgrade
      pkg install python git openssh
      pkg install cmake clang ninja golang

      # Install uv & croc
      curl -LsSf astral.sh/uv/install.sh | sh
      go install github.com/schollz/croc/v10@latest
      ```

      == SSH Access (Tailscale)
      ```bash
      # On Pixel
      sshd
      passwd
      id  # Get username

      # From host
      ssh u0_a190@<ip> -p 8022
      ```
    ],
    [
      == OpenCL GPU Setup
      ```bash
      # Install OpenCL for Adreno GPU
      pkg install opencl-headers \
        opencl-vendor-driver

      # Set environment
      export LD_LIBRARY_PATH=\
        /system/vendor/lib64:$LD_LIBRARY_PATH
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
  #text(size: 10pt)[
    Full setup guide: `docs/WORKFLOW.md` & `setup/PIXEL-SSH.md`
  ]
  ]
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

#slide[
  = Benchmark Tasks Explained

  #text(size: 14pt)[
  #grid(
    columns: (1fr, 1fr, 1fr),
    gutter: 1em,
    [
      == #text(fill: mocha-blue)[GSM8k]
      Grade School Math

      Tests mathematical reasoning on word problems

      #v(0.2em)

      *Input:*
      ```
      "A restaurant serves
      20 customers/hour.
      If open 8 hours,
      how many total?"
      ```

      *Output:* `160`

      #v(0.2em)

      *Metric*: Exact match
    ],
    [
      == #text(fill: mocha-pink)[Reverse Text]
      String Manipulation

      Tests character-by-character string reversal

      #v(0.2em)

      *Input:*
      ```
      "hello world"
      ```

      #v(0.5em)

      *Output:*
      ```
      "dlrow olleh"
      ```

      #v(0.2em)

      *Metric*: LCS similarity
    ],
    [
      == #text(fill: mocha-green)[Wordle]
      Word Guessing Game

      Tests strategic word guessing with feedback

      #v(0.2em)

      *Input:*
      ```
      Target: "CRANE"
      Guess: "PRINT"
      Feedback: ⬜🟨🬜⬜🟩
      ```

      *Output:* Next guess

      #v(0.2em)

      *Metric*: Format + partial credit
    ]
  )
  ]
]

#slide[
  = Results: Downstream Task Accuracy

  #text(fill: mocha-yellow)[*Qwen2.5-Math-1.5B-Instruct*] on #text(fill: mocha-blue)[GSM8k], #text(fill: mocha-pink)[Reverse Text], #text(fill: mocha-green)[Wordle] (llama.cpp)

  #align(center)[
    #text(size: 12pt)[
    #table(
      columns: (auto, auto, auto, auto, auto, auto, auto),
      inset: 6pt,
      align: center,
      table.header(
        [*Quant*], [*GSM8k*], [*Time*], [*RevText*], [*Time*], [*Wordle*], [*Time*]
      ),
      [#text(fill: mocha-green)[INT8]], [7.0%], [423s], [10.6%], [158s], [14.0%], [9s],
      [#text(fill: mocha-peach)[NF4]], [6.8%], [476s], [11.9%], [183s], [14.0%], [11s],
      [#text(fill: mocha-blue)[FP16]], [6.2%], [445s], [10.2%], [264s], [14.0%], [13s],
      [#text(fill: mocha-mauve)[Default]], [4.7%], [495s], [10.5%], [189s], [14.1%], [16s],
    )
    ]
  ]

  #v(0.2em)

  #text(size: 14pt)[
  *Key Findings*:
  - #text(fill: mocha-green)[Quantization does not degrade performance] - INT8/NF4 match or exceed baseline
  - #text(fill: mocha-blue)[INT8 provides best speed/accuracy trade-off] across all tasks
  - #text(fill: mocha-yellow)[Minimal variance across quantizations] (within measurement error)
  - #text(fill: mocha-pink)[Wordle shows identical performance] (14%) across all quantizations
  ]
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
  #figure(
    [
      #text(size: 24pt, fill: mocha-mauve, weight: "bold")[Results: Speedup Analysis]

      #v(0.5em)

      #image("docs/images/speedup_comparison.png", width: 85%)

      #v(0.3em)

      #text(size: 15pt)[
      *Observations*:
      - llama.cpp shows 16.6x speedup over tinygrad for NF4
      - tinygrad leads by 8.0x for float16 workloads
      - INT8 and default show modest llama.cpp advantage (1.2-2.5x)
      ]
    ]
  )
]

#slide[
  #figure(
    [
      #text(size: 24pt, fill: mocha-mauve, weight: "bold")[Results: Performance Summary]

      #v(0.5em)

      #image("docs/images/summary_stats.png", width: 85%)

      #v(0.3em)

      #text(size: 15pt)[
      *Backend comparison*:
      - llama.cpp: Average 31.0 tok/s, peak 46.4 tok/s (NF4)
      - tinygrad: Average 18.1 tok/s, peak 27.5 tok/s (INT8)
      - Overall llama.cpp shows ~1.7x better average performance
      ]
    ]
  )
]

#slide[
  #figure(
    [
      #text(size: 24pt, fill: mocha-mauve, weight: "bold")[Results: Quantization Impact]

      #v(0.5em)

      #image("docs/images/quantization_impact.png", width: 85%)

      #v(0.3em)

      #text(size: 15pt)[
      *Trends*:
      - Different backends favor different quantization strategies
      - llama.cpp benefits most from aggressive quantization (NF4)
      - tinygrad shows more consistent performance across methods
      ]
    ]
  )
]

#slide[
  = Results: Latency Analysis

  #align(center)[
    #image("docs/images/latency_distribution.png", width: 90%)
  ]

  #text(size: 16pt)[
  *Latency variance*:
  - Box plots show distribution of per-token generation time
  - llama.cpp shows lower variance for NF4 and default
  - tinygrad has more consistent latency across quantizations
  ]
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

  #text(size: 18pt)[
  #grid(
    columns: (1fr, 1fr),
    gutter: 1.5em,
    [
      == Reproducible Framework
      - Open-source benchmarking toolkit
      - Standardized data format
      - Easy to extend to new devices

      #v(0.3em)

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

      #v(0.3em)

      == Community Benefit
      - Others can benchmark their devices
      - Append results to shared data bank
    ]
  )
  ]
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

  - #text(fill: mocha-green)[*Quantization enables practical edge LLM deployment*]
    - 4-bit models run on smartphones with acceptable performance

  #v(0.3em)

  - #text(fill: mocha-yellow)[*Trade-offs are workload-dependent*]
    - Memory-constrained? → #text(fill: mocha-peach)[INT4/NF4]
    - Accuracy-critical? → #text(fill: mocha-blue)[INT8] or #text(fill: mocha-mauve)[FP16]

  #v(0.3em)

  - #text(fill: mocha-pink)[*Framework enables reproducible research*]
    - Standardized benchmarks across diverse hardware
    - Community can contribute additional results

  #v(0.5em)

  #align(center)[
    #text(size: 18pt, fill: mocha-sapphire)[
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
  #set page(footer: align(center, footer-text), footer-descent: 1em)
  #align(center + horizon)[
    #text(size: 36pt, weight: "bold", fill: mocha-mauve)[Thank You!]

    #v(2em)

    #text(size: 20pt)[
      #text(fill: mocha-pink)[*Questions?*]

      #v(1em)

      #text(fill: mocha-blue)[Mike Doan] · #text(fill: mocha-blue)[Jenny Dinh]

      #v(1em)

      #text(fill: mocha-sapphire)[`github.com/spikedoanz/t-eai-project`]
    ]
  ]
]
