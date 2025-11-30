// Research Report: Comparing Quantization Across Hardware
// A Comprehensive Study of LLM Inference Performance on Edge Devices
// Authors: Mike Doan, Jenny Dinh

#set page(
  paper: "us-letter",
  margin: (x: 1in, y: 1in),
)

#set text(
  font: "Linux Libertine",
  size: 10pt,
)

#set par(
  justify: true,
  leading: 0.65em,
)

// Title
#align(center)[
  #text(size: 16pt, weight: "bold")[
    Comparing Quantization Strategies Across Hardware: \
    A Comprehensive Study of LLM Inference on Edge Devices
  ]

  #v(1em)

  #text(size: 11pt)[
    Mike Doan#super[1], Jenny Dinh#super[1]

    #v(0.5em)

    #text(size: 9pt)[
      #super[1]Department of Computer Science, Georgia State University \
      Atlanta, GA, USA \
      #link("mailto:mdoan@student.gsu.edu")[mdoan\@student.gsu.edu], #link("mailto:jdinh@student.gsu.edu")[jdinh\@student.gsu.edu]
    ]
  ]
]

#v(1em)

// Abstract
#align(center)[
  #text(weight: "bold")[Abstract]
]

#box(width: 100%, inset: (x: 0.5in))[
  _[TODO: Write abstract (150-250 words)]_

  The growing interest in local deployment of Large Language Models (LLMs) on edge devices necessitates efficient compression techniques to manage memory constraints and computational limitations. This paper presents a comprehensive empirical study comparing various quantization strategies across diverse hardware platforms, ranging from mobile devices to consumer-grade laptops. We systematically benchmark multiple quantization approaches (FP16, INT8, INT4, NF4) using different inference backends (llama.cpp, tinygrad) on models including Llama-3.2-1B and Qwen2.5-1.5B. Our evaluation encompasses both raw performance metrics (throughput, latency, memory usage) and downstream task accuracy using standardized benchmarks. We present a reproducible benchmarking framework with standardized data schemas, enabling community-driven expansion of our dataset. Our findings reveal... [key results]. The codebase and collected data are publicly available under MIT license.

  _Keywords:_ Large Language Models, Quantization, Edge Computing, Mobile Inference, Benchmarking
]

#v(1em)

= Introduction

== Motivation

_[TODO: Expand on the motivation for local LLM deployment]_

The rapid advancement of Large Language Models (LLMs) has led to remarkable capabilities in natural language understanding and generation. However, the deployment of these models has traditionally been confined to cloud-based services due to their substantial computational and memory requirements. Recently, there has been growing interest in running LLMs locally on edge devices for several compelling reasons:

- *Privacy and Security*: Sensitive data remains on-device
- *Latency*: Elimination of network round-trips
- *Cost*: Reduced API costs for frequent inference
- *Availability*: Offline functionality in network-constrained environments

The primary challenge in local LLM deployment is the massive memory footprint. For instance, Llama-3.1-8B requires approximately 16GB of memory in FP16 precision, exceeding the capacity of most consumer devices and mobile platforms.

== Problem Statement

_[TODO: Define the specific research problem]_

While quantization techniques have emerged as a solution to reduce model size, there exists limited systematic comparison of these techniques across diverse hardware platforms. Existing work typically focuses on:
- Single hardware platforms (e.g., NVIDIA GPUs only)
- Single quantization methods
- Synthetic benchmarks without downstream task evaluation

This fragmentation makes it difficult for practitioners to make informed decisions about quantization strategies for their target deployment scenarios.

== Contributions

This work makes the following contributions:

+ *Comprehensive Benchmarking Framework*: We develop a reproducible, extensible benchmarking suite with standardized data schemas for cross-platform comparison.

+ *Cross-Platform Empirical Study*: We systematically evaluate multiple quantization strategies across diverse hardware (Apple Silicon, Android devices with ARM/Adreno) and inference backends (llama.cpp, tinygrad).

+ *Downstream Task Evaluation*: Beyond raw performance metrics, we assess the impact of quantization on actual task performance using standardized benchmarks (GSM8K, MATH, etc.).

+ *Open-Source Release*: We release our complete codebase, collected benchmark data, and analysis tools under MIT license to enable community contributions.

== Paper Organization

The remainder of this paper is organized as follows: Section 2 reviews related work on quantization and edge deployment. Section 3 details our experimental methodology and benchmarking framework. Section 4 presents our experimental setup. Section 5 reports our results. Section 6 discusses implications and limitations. Section 7 concludes and outlines future work.

= Background and Related Work

== Large Language Models on Edge Devices

_[TODO: Literature review on edge LLM deployment]_

- Mobile deployment challenges
- Memory bandwidth limitations
- Power consumption constraints
- Previous work on on-device NLP models

== Quantization Techniques

=== Weight Quantization

_[TODO: Technical background on weight quantization]_

*Post-Training Quantization (PTQ)*: Quantization applied after model training without requiring access to training data or retraining.

*Quantization-Aware Training (QAT)*: Models trained with quantization in mind, typically achieving better accuracy at lower precision.

=== Common Quantization Formats

_[TODO: Expand on each format with citations]_

- *INT8 (W8A8)*: 8-bit integer weights and activations
- *INT4 (W4A8)*: 4-bit weights, 8-bit activations
- *NF4*: 4-bit NormalFloat used in QLoRA #cite(<dettmers2023qlora>)
- *GPTQ*: Group-wise post-training quantization #cite(<frantar2022gptq>)
- *AWQ*: Activation-aware weight quantization #cite(<lin2023awq>)

=== KV-Cache Quantization

_[TODO: Discuss KV-cache compression techniques]_

Key-value cache quantization reduces memory requirements during long-context inference.

== Inference Frameworks

_[TODO: Compare different inference frameworks]_

=== llama.cpp

High-performance C++ implementation with GGUF model format. Supports multiple backends including Metal, OpenCL, CUDA.

=== tinygrad

Pure Python deep learning framework with emphasis on simplicity and hackability.

=== MLC-LLM

TVM-based compiler for deploying LLMs across platforms.

== Benchmarking Methodologies

_[TODO: Review existing benchmarking work]_

- MLPerf Inference benchmarks
- Previous quantization studies
- Gap in cross-platform, cross-quantization comparisons

= Methodology

== Benchmarking Framework Design

=== Design Principles

Our framework is designed with the following principles:

+ *Reproducibility*: Seeded random generation, deterministic model loading
+ *Extensibility*: Modular design for adding new backends and devices
+ *Standardization*: Consistent data schema across all experiments
+ *Automation*: Minimal manual intervention required

=== Data Schema

_[TODO: Explain the rationale behind the schema design]_

We define a standardized schema for all benchmark runs:

```python
class BenchmarkRow(TypedDict):
    step: int                      # Token generation step
    enqueue_latency_ms: float      # Time to enqueue operation
    total_latency_ms: float        # Total time for step
    tokens_per_sec: float          # Throughput
    memory_throughput_gb_s: float  # Memory bandwidth utilization
    param_throughput_gb_s: float   # Parameter throughput
    generated_text: str            # Incrementally generated text
    platform: str                  # OS (Darwin, Linux, Android)
    release: str                   # OS version
    device: str                    # Hardware device identifier
    username: str                  # User identifier
    hostname: str                  # Machine hostname
    size: str                      # Model size (1B, 3B, 8B)
    quantize: str                  # Quantization strategy
    seed: int                      # Random seed
    uuid: str                      # Unique run identifier
```

This schema captures both performance metrics and environmental metadata necessary for reproducible analysis.

== Benchmark Implementation

=== Backend-Specific Implementations

_[TODO: Detail each backend implementation]_

==== llama.cpp Backend

Implementation details:
- Model format: GGUF
- Quantization: Built into model files
- Metrics collection: Custom parsing of llama-cli output

==== tinygrad Backend

Implementation details:
- Server mode with OpenAI-compatible API
- Runtime quantization selection
- Direct metric extraction from framework

=== Metrics Collection

_[TODO: Explain how each metric is computed]_

*Latency Metrics*:
- Time to First Token (TTFT): Measured from prompt submission to first token
- Per-Token Latency: Time between consecutive token generations

*Throughput Metrics*:
- Tokens per second (tok/s)
- Memory bandwidth (GB/s): Computed from model size and throughput
- Parameter throughput (GB/s)

*Memory Metrics*:
- Model load size
- Peak memory utilization during inference

== Downstream Task Evaluation

=== Verifiers Framework Integration

_[TODO: Explain the verifiers framework and why it was chosen]_

We integrate the Prime Intellect Verifiers framework #cite(<verifiers>) for downstream task evaluation. This framework provides:
- Standardized benchmark environments
- Consistent evaluation protocols
- OpenAI-compatible API interface

=== OpenAI Proxy Implementation

_[TODO: Explain the proxy design]_

To bridge non-streaming backends with the Verifiers framework, we implement an OpenAI-compatible proxy server that converts between streaming and non-streaming APIs.

=== Benchmark Tasks

_[TODO: Describe each benchmark and what it measures]_

- *GSM8K*: Grade school math problems (arithmetic reasoning)
- *MATH*: Higher-level mathematics (advanced reasoning)
- *GPQA*: Graduate-level science questions (domain knowledge)
- *SimpleQA*: Factual knowledge retrieval

= Experimental Setup

== Hardware Platforms

_[TODO: Detail specifications of each device]_

#figure(
  table(
    columns: (1.2fr, 1fr, 1fr, 1fr, 1fr),
    inset: 8pt,
    align: horizon,
    table.header(
      [*Device*], [*Processor*], [*Memory*], [*GPU*], [*Backend*]
    ),
    [MacBook (M-series)], [Apple Silicon], [16-32GB], [Integrated], [Metal],
    [Google Pixel 7], [Tensor G2], [8GB], [Mali-G710], [OpenCL],
    [Google Pixel 8], [Tensor G3], [8-12GB], [Mali-G715], [OpenCL],
  ),
  caption: [Hardware platforms evaluated in this study]
)

== Model Selection

_[TODO: Justify model choices]_

We evaluate the following models:

- *Llama-3.2-1B-Instruct*: Small instruction-tuned model (1.2B parameters)
- *Qwen2.5-1.5B*: Multilingual model with strong performance (1.5B parameters)

These models were chosen for their:
- Size compatibility with edge devices
- Strong baseline performance
- Availability in multiple quantization formats

== Quantization Strategies Evaluated

_[TODO: Explain implementation details for each strategy]_

#figure(
  table(
    columns: (1fr, 1fr, 2fr),
    inset: 8pt,
    align: horizon,
    table.header(
      [*Strategy*], [*Bits*], [*Description*]
    ),
    [FP16], [16], [Half-precision floating point (baseline)],
    [INT8], [8], [8-bit integer quantization],
    [INT4], [4], [4-bit integer quantization],
    [NF4], [4], [4-bit NormalFloat (QLoRA)],
  ),
  caption: [Quantization strategies under evaluation]
)

== Inference Configurations

_[TODO: Document experimental parameters]_

- *Context lengths*: 256, 512, 1024 tokens
- *Generation lengths*: 128, 256 tokens
- *Batch size*: 1 (single-query inference)
- *Temperature*: 0.7 (for downstream tasks)
- *Random seed*: 42 (for reproducibility)

== Experimental Procedure

_[TODO: Step-by-step procedure]_

For each combination of (device, model, quantization, backend):

+ Load model and measure initialization time and memory
+ Warm-up: Generate 10 tokens to stabilize performance
+ Execute 100 token generations with standardized prompt
+ Record metrics for each token generation step
+ Compute aggregate statistics (mean, median, p95, p99)
+ For subset of configurations, run downstream task evaluation

= Results

== Performance Metrics

=== Throughput Analysis

_[TODO: Present throughput results with figures]_

#figure(
  rect(width: 100%, height: 200pt, stroke: 1pt + gray)[
    #align(center + horizon)[
      #text(fill: gray)[Figure: Throughput (tok/s) across quantization strategies]

      _[TODO: Insert chart from visualize\_benchmarks.py]_
    ]
  ],
  caption: [Token generation throughput across devices and quantization strategies]
)

*Key Findings*:
- [TODO: Bullet points of key throughput findings]
- NF4 achieves X tok/s on MacBook M-series
- INT8 provides Y% improvement over FP16
- Diminishing returns observed on memory-bandwidth limited devices

=== Latency Analysis

_[TODO: Present latency results]_

#figure(
  rect(width: 100%, height: 200pt, stroke: 1pt + gray)[
    #align(center + horizon)[
      #text(fill: gray)[Figure: Per-token latency distribution]

      _[TODO: Insert latency distribution chart]_
    ]
  ],
  caption: [Per-token latency across quantization strategies (box plot)]
)

*Time to First Token (TTFT)*:
- [TODO: TTFT results]

*Generation Latency*:
- [TODO: Per-token latency results]

=== Memory Utilization

_[TODO: Memory usage results]_

#figure(
  table(
    columns: (1.5fr, 1fr, 1fr, 1fr, 1fr),
    inset: 8pt,
    align: horizon,
    table.header(
      [*Model*], [*FP16*], [*INT8*], [*INT4*], [*NF4*]
    ),
    [Llama-3.2-1B], [TBD GB], [TBD GB], [TBD GB], [TBD GB],
    [Qwen2.5-1.5B], [TBD GB], [TBD GB], [TBD GB], [TBD GB],
  ),
  caption: [Peak memory usage during inference]
)

== Downstream Task Performance

_[TODO: Accuracy results from Verifiers benchmarks]_

=== GSM8K Results

#figure(
  table(
    columns: (1.5fr, 1fr, 1fr, 1fr, 1fr),
    inset: 8pt,
    align: horizon,
    table.header(
      [*Quantization*], [*Accuracy*], [*Avg. Tokens*], [*Time (s)*], [*Score*]
    ),
    [FP16], [TBD%], [TBD], [TBD], [TBD],
    [INT8], [TBD%], [TBD], [TBD], [TBD],
    [NF4], [TBD%], [TBD], [TBD], [TBD],
  ),
  caption: [GSM8K benchmark results across quantization strategies]
)

=== Accuracy vs. Efficiency Trade-off

_[TODO: Pareto frontier analysis]_

#figure(
  rect(width: 100%, height: 200pt, stroke: 1pt + gray)[
    #align(center + horizon)[
      #text(fill: gray)[Figure: Accuracy vs. Throughput Pareto frontier]

      _[TODO: Insert Pareto plot]_
    ]
  ],
  caption: [Trade-off between downstream task accuracy and inference throughput]
)

== Cross-Device Comparison

_[TODO: Compare performance across devices]_

=== Device-Specific Observations

*MacBook (Metal)*:
- [TODO: Key findings for MacBook]

*Google Pixel (OpenCL)*:
- [TODO: Key findings for Pixel devices]

== Backend Comparison

_[TODO: Compare llama.cpp vs tinygrad]_

#figure(
  rect(width: 100%, height: 200pt, stroke: 1pt + gray)[
    #align(center + horizon)[
      #text(fill: gray)[Figure: Backend performance comparison]

      _[TODO: Insert backend comparison chart]_
    ]
  ],
  caption: [Performance comparison between llama.cpp and tinygrad backends]
)

= Discussion

== Key Findings Summary

_[TODO: Synthesize main results]_

+ *Quantization enables practical edge deployment*: 4-bit quantization reduces memory footprint by ~75% with acceptable accuracy degradation.

+ *Device-specific optimal strategies*: Memory-bandwidth characteristics heavily influence optimal quantization choice.

+ *Backend implementation matters*: Significant performance variations observed between inference frameworks.

== Accuracy-Efficiency Trade-offs

_[TODO: Discuss when to use which quantization]_

*Recommendations*:
- *Memory-constrained devices* (#sym.lt 8GB): NF4 or INT4
- *Accuracy-critical applications*: INT8 or FP16
- *Balanced deployment*: INT8 provides good compromise

== Limitations

_[TODO: Acknowledge limitations]_

+ *Limited model sizes*: Focused on 1-1.5B parameter models
+ *Batch size 1*: Did not evaluate batched inference scenarios
+ *Specific hardware*: Limited to available devices
+ *Context lengths*: Did not extensively test long-context scenarios (>2K tokens)
+ *MLC-LLM excluded*: Build complexity prevented comprehensive evaluation

== Implications for Practitioners

_[TODO: Practical guidance]_

This work provides practitioners with:
- Data-driven quantization selection criteria
- Realistic performance expectations for edge deployment
- Reproducible framework for evaluating new devices

== Threats to Validity

_[TODO: Discuss validity concerns]_

*Internal Validity*:
- Variability in system background processes
- Thermal throttling on sustained workloads

*External Validity*:
- Generalization to larger models
- Different workload patterns (e.g., long conversations)

*Construct Validity*:
- Benchmark tasks may not represent all real-world use cases

= Related Work

_[TODO: Comprehensive related work section]_

== Quantization for LLMs

- QLoRA #cite(<dettmers2023qlora>)
- GPTQ #cite(<frantar2022gptq>)
- AWQ #cite(<lin2023awq>)
- SmoothQuant
- LLM.int8()

== Edge LLM Deployment

- MLC-LLM
- Mobile inference optimizations
- On-device NLP systems

== Benchmarking Studies

- MLPerf Inference
- Previous quantization comparisons
- Mobile ML benchmarks

= Conclusion and Future Work

== Conclusion

_[TODO: Summarize contributions and impact]_

This paper presented a comprehensive empirical study of quantization strategies for LLM inference on edge devices. Through systematic benchmarking across multiple hardware platforms, models, and quantization approaches, we provide actionable insights for practitioners deploying LLMs locally. Our open-source framework enables reproducible research and community-driven expansion of performance data.

Key takeaways:
- 4-bit quantization (NF4/INT4) enables practical edge deployment with manageable accuracy trade-offs
- Hardware characteristics significantly influence optimal quantization strategy
- Standardized benchmarking frameworks are essential for meaningful cross-platform comparisons

== Future Work

_[TODO: Outline future research directions]_

+ *Larger Models*: Extend evaluation to 3B, 7B, 8B parameter models
+ *Energy Profiling*: Comprehensive watt/token measurements and battery life impact
+ *KV-Cache Quantization*: Evaluate cache compression for long-context scenarios
+ *Batched Inference*: Multi-query performance on edge devices
+ *Enterprise GPUs*: Extend to A100, H100 for datacenter deployment guidance
+ *Quantization-Aware Training*: Compare PTQ vs QAT on edge devices
+ *Additional Backends*: Include MLC-LLM once build process is stabilized
+ *Production Deployment*: Real-world case studies and user studies

== Reproducibility Statement

All code, data, and analysis scripts are available at:
#link("https://github.com/spikedoanz/t-eai-project")

The repository includes:
- Complete benchmarking framework
- Data collection and parsing scripts
- Visualization and analysis code
- Raw benchmark data (CSV format)
- Setup instructions for all evaluated platforms

= Acknowledgments

_[TODO: Add acknowledgments]_

We thank the developers of llama.cpp, tinygrad, and the Verifiers framework for their excellent open-source tools. We also acknowledge [funding sources, if any] and [individuals who provided feedback].

// References section
#set par(first-line-indent: 0em, hanging-indent: 2em)

#bibliography("references.bib", title: "References", style: "ieee")
