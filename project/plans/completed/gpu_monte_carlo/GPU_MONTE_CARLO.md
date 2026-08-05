# GPU Acceleration for Monte Carlo Simulation

**Document Version:** 1.0
**Created:** 2026-01-26
**Status:** 📋 Planning
**Priority:** High
**Scope:** Core Library Enhancement

---

## Executive Summary

Enable GPU acceleration for Monte Carlo simulations to achieve **10-100x performance improvement** for large-scale risk analysis and scenario modeling. The BusinessMath library already has Metal GPU infrastructure for heuristic optimization—this plan extends that capability to Monte Carlo simulation.

### Current State
- `MonteCarloSimulation` uses **CPU-only serial execution**
- No parallelization of iteration loops
- Performance bottleneck for 100K+ iteration simulations
- Metal infrastructure exists but is unused by Monte Carlo engine

### Target State
- GPU-accelerated parallel execution for distribution sampling
- Automatic fallback to CPU when GPU unavailable
- 10-100x speedup for large simulations (100K+ iterations)
- Seamless API compatibility (no breaking changes)

### Performance Projections
| Iterations | CPU Time | GPU Time (Projected) | Speedup |
|-----------|----------|---------------------|---------|
| 1,000     | 0.1s     | 0.1s                | 1x      |
| 10,000    | 1.0s     | 0.2s                | 5x      |
| 100,000   | 10.0s    | 0.5s                | 20x     |
| 1,000,000 | 100.0s   | 1.0s                | 100x    |

---

## Technical Background

### Existing GPU Infrastructure

BusinessMath already has Metal GPU support in:

**Sources/BusinessMath/Optimization/Heuristic/GPU/MetalDevice.swift**
- Singleton Metal device manager
- Buffer management and kernel compilation
- Used by: `GeneticAlgorithm`, `DifferentialEvolution`, `ParticleSwarmOptimization`

**Metal Shader Files:**
- `GeneticAlgorithm.metal` - Population evaluation kernels
- `DifferentialEvolution.metal` - Mutation/crossover kernels
- `ParticleSwarmOptimization.metal` - Velocity/position update kernels

### Current Monte Carlo Architecture

**Sources/BusinessMath/Simulation/MonteCarlo/MonteCarloSimulation.swift**

```swift
public final class MonteCarloSimulation<InputVector: DoubleVector>: Sendable {
    public func run() throws -> SimulationResults {
        var samples: [Double] = []
        samples.reserveCapacity(iterations)

        // Serial CPU loop - parallelization opportunity
        for _ in 0..<iterations {
            let inputSample = sampleInputs()
            let output = model(inputSample)
            samples.append(output)
        }

        return SimulationResults(samples: samples)
    }
}
```

**Key Insight:** The iteration loop is **embarrassingly parallel**—each iteration is independent, making it ideal for GPU acceleration.

---

## GPU Acceleration Strategy

### Why GPU Acceleration Works Here

1. **Independent Iterations**: No inter-iteration dependencies
2. **High Computational Density**: Distribution sampling + model evaluation
3. **Large Iteration Counts**: 10K-1M iterations are common in risk analysis
4. **Existing Infrastructure**: Metal device management already implemented
5. **Predictable Memory Pattern**: Fixed-size input/output vectors

### Challenges

1. **Distribution Sampling on GPU**: Need GPU-friendly RNG (not Foundation RNG)
2. **Custom Model Functions**: User-provided closures can't run on GPU directly
3. **Sendable Compliance**: Must maintain Swift 6 concurrency safety
4. **API Compatibility**: No breaking changes to existing API

### Solution Architecture

**Hybrid CPU-GPU Approach:**

```
┌─────────────────────────────────────────────────────┐
│ MonteCarloSimulation (Swift)                        │
│                                                      │
│  ┌──────────────────────────────────────┐           │
│  │ Can model run on GPU?                │           │
│  │ - Simple arithmetic only?            │           │
│  │ - Metal device available?            │           │
│  │ - Iterations > threshold (1000)?     │           │
│  └──────────┬───────────────────────────┘           │
│             │                                        │
│      ┌──────┴──────┐                                │
│      ▼             ▼                                 │
│  GPU Path      CPU Path                             │
│  ─────────     ─────────                            │
│  • Compile     • Serial                             │
│    model         loop                               │
│  • Upload      • Foundation                         │
│    params        RNG                                │
│  • GPU RNG     • User                               │
│  • Parallel      closure                            │
│    execute                                          │
│  • Download                                         │
│    results                                          │
└─────────────────────────────────────────────────────┘
```

---

## Implementation Plan

### Phase 1: Core Library GPU Engine (Week 1-2)

**Goal:** Implement GPU acceleration for simple models (arithmetic expressions)

#### Task 1.1: GPU Random Number Generator
**File:** `Sources/BusinessMath/Simulation/MonteCarlo/GPU/MonteCarloRNG.metal`

**Why:** Foundation's RNG can't run on GPU—need Metal-native PRNG (Xorshift128+)

```metal
// Xorshift128+ PRNG for GPU
struct RNGState {
    ulong s0;
    ulong s1;
};

// Thread-local RNG state
kernel void initializeRNG(
    device RNGState* states [[buffer(0)]],
    uint tid [[thread_position_in_grid]]
) {
    // Seed with thread ID for independent streams
    states[tid].s0 = 0x123456789ABCDEF0 ^ tid;
    states[tid].s1 = 0xFEDCBA987654321 ^ (tid << 32);
}

// Generate uniform [0,1)
float nextUniform(device RNGState* state) {
    ulong s1 = state->s0;
    ulong s0 = state->s1;
    state->s0 = s0;
    s1 ^= s1 << 23;
    state->s1 = s1 ^ s0 ^ (s1 >> 18) ^ (s0 >> 5);
    return (state->s0 + state->s1) * 1.08420217e-19; // Convert to [0,1)
}

// Box-Muller transform for normal distribution
float2 nextNormal(device RNGState* state, float mean, float stdDev) {
    float u1 = nextUniform(state);
    float u2 = nextUniform(state);
    float r = sqrt(-2.0 * log(u1));
    float theta = 2.0 * M_PI_F * u2;
    return float2(
        mean + stdDev * r * cos(theta),
        mean + stdDev * r * sin(theta)
    );
}
```

**Tests:** Validate RNG quality (Chi-square test, Kolmogorov-Smirnov test)

#### Task 1.2: GPU Distribution Samplers
**File:** `Sources/BusinessMath/Simulation/MonteCarlo/GPU/MonteCarloDistributions.metal`

**Why:** Support common distributions (Normal, Uniform, Triangular)

```metal
// Distribution sampler dispatcher
float sampleDistribution(
    device RNGState* rng,
    constant DistributionParams* params,
    int distType
) {
    switch (distType) {
        case DIST_NORMAL:
            return nextNormal(rng, params->mean, params->stdDev).x;
        case DIST_UNIFORM:
            return params->min + nextUniform(rng) * (params->max - params->min);
        case DIST_TRIANGULAR:
            return sampleTriangular(rng, params->min, params->mode, params->max);
        default:
            return 0.0;
    }
}
```

#### Task 1.3: GPU Model Evaluator (Simple Expressions)
**File:** `Sources/BusinessMath/Simulation/MonteCarlo/GPU/MonteCarloKernel.metal`

**Why:** Evaluate arithmetic models in parallel

```metal
// Main Monte Carlo kernel
kernel void monteCarloIteration(
    device RNGState* rngStates [[buffer(0)]],
    constant DistributionParams* distributions [[buffer(1)]],
    constant int* distTypes [[buffer(2)]],
    device float* outputs [[buffer(3)]],
    constant ModelProgram* program [[buffer(4)]],
    constant int& numInputs [[buffer(5)]],
    uint tid [[thread_position_in_grid]]
) {
    // Sample inputs
    float inputs[MAX_INPUTS];
    for (int i = 0; i < numInputs; i++) {
        inputs[i] = sampleDistribution(&rngStates[tid], &distributions[i], distTypes[i]);
    }

    // Evaluate model (bytecode interpreter for simple arithmetic)
    outputs[tid] = evaluateModel(inputs, program);
}
```

**Design Decision:** Use bytecode interpreter for model evaluation (flexible but slower than compiled Metal). Alternative: AOT compilation of expression AST → Metal code (complex but faster).

#### Task 1.4: Swift GPU Manager
**File:** `Sources/BusinessMath/Simulation/MonteCarlo/GPU/MonteCarloGPUDevice.swift`

**Why:** Bridge Swift API to Metal kernels

```swift
@available(macOS 10.15, iOS 13.0, *)
final class MonteCarloGPUDevice: @unchecked Sendable {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let rngKernel: MTLComputePipelineState
    private let simulationKernel: MTLComputePipelineState

    init?() {
        guard let device = MetalDevice.shared.device else { return nil }
        self.device = device
        guard let queue = device.makeCommandQueue() else { return nil }
        self.commandQueue = queue

        // Compile kernels
        guard let library = try? device.makeDefaultLibrary(bundle: .module) else { return nil }
        guard let rngFunc = library.makeFunction(name: "initializeRNG"),
              let simFunc = library.makeFunction(name: "monteCarloIteration") else { return nil }

        self.rngKernel = try! device.makeComputePipelineState(function: rngFunc)
        self.simulationKernel = try! device.makeComputePipelineState(function: simFunc)
    }

    func runSimulation(
        distributions: [DistributionConfig],
        model: CompiledModel,
        iterations: Int
    ) throws -> [Double] {
        // Buffer allocation
        let rngBuffer = device.makeBuffer(length: iterations * MemoryLayout<RNGState>.stride)!
        let outputBuffer = device.makeBuffer(length: iterations * MemoryLayout<Float>.stride)!

        // Initialize RNG
        let rngCommand = commandQueue.makeCommandBuffer()!
        let rngEncoder = rngCommand.makeComputeCommandEncoder()!
        rngEncoder.setComputePipelineState(rngKernel)
        rngEncoder.setBuffer(rngBuffer, offset: 0, index: 0)
        rngEncoder.dispatchThreads(MTLSize(width: iterations, height: 1, depth: 1),
                                  threadsPerThreadgroup: MTLSize(width: 256, height: 1, depth: 1))
        rngEncoder.endEncoding()
        rngCommand.commit()
        rngCommand.waitUntilCompleted()

        // Run simulation
        let simCommand = commandQueue.makeCommandBuffer()!
        let simEncoder = simCommand.makeComputeCommandEncoder()!
        simEncoder.setComputePipelineState(simulationKernel)
        // ... set buffers
        simEncoder.dispatchThreads(MTLSize(width: iterations, height: 1, depth: 1),
                                  threadsPerThreadgroup: MTLSize(width: 256, height: 1, depth: 1))
        simEncoder.endEncoding()
        simCommand.commit()
        simCommand.waitUntilCompleted()

        // Download results
        let pointer = outputBuffer.contents().bindMemory(to: Float.self, capacity: iterations)
        return (0..<iterations).map { Double(pointer[$0]) }
    }
}
```

#### Task 1.5: Integrate GPU Path into MonteCarloSimulation
**File:** `Sources/BusinessMath/Simulation/MonteCarlo/MonteCarloSimulation.swift`

**Why:** Add GPU execution path with automatic fallback

```swift
public final class MonteCarloSimulation<InputVector: DoubleVector>: Sendable {
    private let useGPU: Bool
    private let gpuDevice: MonteCarloGPUDevice?

    public init(
        iterations: Int,
        model: @escaping @Sendable (InputVector) -> Double,
        enableGPU: Bool = true  // New parameter (defaults to true)
    ) {
        self.iterations = iterations
        self.model = model

        if enableGPU, #available(macOS 10.15, iOS 13.0, *) {
            self.gpuDevice = MonteCarloGPUDevice()
            self.useGPU = gpuDevice != nil && iterations >= 1000  // Threshold
        } else {
            self.gpuDevice = nil
            self.useGPU = false
        }
    }

    public func run() throws -> SimulationResults {
        // Try GPU path first
        if useGPU, let gpuDevice = gpuDevice, let compiled = try? compileModelForGPU() {
            do {
                let samples = try gpuDevice.runSimulation(
                    distributions: getDistributionConfigs(),
                    model: compiled,
                    iterations: iterations
                )
                return SimulationResults(samples: samples)
            } catch {
                // Fall back to CPU on GPU error
                fputs("GPU simulation failed, falling back to CPU: \(error)\n", stderr)
            }
        }

        // CPU path (existing implementation)
        var samples: [Double] = []
        samples.reserveCapacity(iterations)

        for _ in 0..<iterations {
            let inputSample = sampleInputs()
            let output = model(inputSample)
            samples.append(output)
        }

        return SimulationResults(samples: samples)
    }

    private func compileModelForGPU() throws -> CompiledModel? {
        // Attempt to compile user's model closure to GPU bytecode
        // Returns nil if model is too complex (uses unsupported functions)
        // For Phase 1: Only support simple arithmetic models
        return nil  // TODO: Implement model compiler
    }
}
```

**Tests:**
- Unit tests for GPU RNG quality
- Functional tests comparing CPU vs GPU results (should be statistically equivalent)
- Performance benchmarks (1K, 10K, 100K, 1M iterations)

**Success Criteria:**
- ✅ GPU path produces statistically equivalent results to CPU path
- ✅ 10x+ speedup for 100K iterations on simple models
- ✅ Graceful fallback to CPU when GPU unavailable

---

### Phase 2: MCP Tool Integration (Week 3)

**Goal:** Expose GPU acceleration to MCP tools with configuration options

#### Task 2.1: Add GPU Configuration to Monte Carlo Tools
**Files:**
- `Sources/BusinessMathMCP/Tools/MonteCarloTools.swift` (7 tools)

**Changes:**
```swift
public struct RunMonteCarloSimulationTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "run_monte_carlo_simulation",
        description: """
        Run Monte Carlo simulation with optional GPU acceleration.

        **🚀 GPU Acceleration (v2.1):**
        - Automatically enabled for 1000+ iterations when Metal GPU available
        - 10-100x speedup for large simulations
        - Seamless fallback to CPU if GPU unavailable
        - Set useGPU=false to force CPU execution

        ...
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                // ... existing properties
                "useGPU": MCPSchemaProperty(
                    type: "boolean",
                    description: """
                    Enable GPU acceleration (default: true).
                    GPU automatically used when:
                    - Metal GPU device available
                    - iterations >= 1000
                    - Model is GPU-compatible (simple arithmetic)

                    Set to false to force CPU execution for debugging.
                    """
                )
            ],
            required: ["inputNames", "model", "iterations"]  // useGPU is optional
        )
    )

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        // Parse useGPU (default true)
        let useGPU = (args["useGPU"]?.value as? Bool) ?? true

        // Create simulation with GPU flag
        var simulation = MonteCarloSimulation(
            iterations: iterations,
            model: model,
            enableGPU: useGPU
        )

        let results = try simulation.run()

        // Include GPU usage info in output
        var output = """
        🎲 **Monte Carlo Simulation Results**

        **Configuration:**
        - Iterations: \(iterations)
        - Execution: \(results.usedGPU ? "GPU ⚡" : "CPU")
        ...
        """
    }
}
```

**Apply to All 7 Monte Carlo Tools:**
1. `run_monte_carlo_simulation`
2. `run_monte_carlo_with_correlations`
3. `run_monte_carlo_with_constraints`
4. `run_monte_carlo_sensitivity`
5. `run_monte_carlo_percentile`
6. `run_monte_carlo_risk_metrics`
7. `run_monte_carlo_value_at_risk`

#### Task 2.2: Update Server Description
**File:** `Sources/BusinessMathMCPServer/main.swift`

```swift
let server = Server(
    name: "BusinessMath MCP Server",
    version: "2.1.0",  // Updated from 2.0.0
    instructions: """
    Comprehensive business mathematics, financial modeling, Monte Carlo simulation, and advanced analytics server.

    **🆕 v2.1 Highlights:**
    - 🚀 GPU-accelerated Monte Carlo simulation (10-100x speedup)
    - Automatic Metal GPU detection and fallback
    - Simple arithmetic models run on GPU automatically

    **🆕 v2.0 Highlights:**
    - Mean-variance portfolio optimization with realistic risk-return tradeoffs
    - Discrete scenario analysis with distributions within scenarios (stress testing)
    - Enhanced integer programming with relaxation solver selection & variable shift strategies
    - Swift 6 concurrency compliance (@Sendable throughout)

    **Monte Carlo Simulation** (7 tools with GPU acceleration):
    - Automatic GPU execution for 1000+ iterations
    - 10-100x faster for large-scale risk analysis
    - Seamless CPU fallback
    ...
    """
)
```

#### Task 2.3: Update Documentation
**File:** `BusinessMathMCP_README/MCP_README.md`

```markdown
### 🆕 What's New in v2.1

- **🚀 GPU-Accelerated Monte Carlo**: 10-100x speedup for large simulations (1000+ iterations)
- **Automatic Metal GPU Detection**: Seamless GPU/CPU switching based on availability
- **Simple Model Optimization**: Arithmetic expressions run in parallel on GPU

### 🔧 172 Computational Tools

**Monte Carlo Simulation** (7 tools with GPU acceleration):
- **🚀 Automatic GPU acceleration** for 1000+ iterations (10-100x faster)
- Risk modeling with 15 probability distributions
- Correlation support (Gaussian copula, custom correlation matrices)
...

### Performance

**GPU Acceleration Impact:**
| Tool | Iterations | CPU Time | GPU Time | Speedup |
|------|-----------|----------|----------|---------|
| `run_monte_carlo_simulation` | 100,000 | 10.0s | 0.5s | **20x** |
| `run_monte_carlo_sensitivity` | 500,000 | 50.0s | 2.0s | **25x** |
| `run_monte_carlo_value_at_risk` | 1,000,000 | 100.0s | 1.0s | **100x** |

**Requirements:**
- macOS 10.15+ or iOS 13.0+ (for Metal GPU support)
- GPU acceleration automatic when Metal device available
- Graceful CPU fallback on older systems
```

#### Task 2.4: Testing
**File:** `Tests/BusinessMathTests/MCP Tests/MonteCarloToolTests.swift`

**New Tests:**
```swift
@Test("GPU acceleration produces statistically equivalent results")
func testGPUCPUEquivalence() async throws {
    let args = ["useGPU": AnyCodable(true), "iterations": AnyCodable(10000), ...]
    let gpuResult = try await tool.execute(arguments: args)

    let cpuArgs = ["useGPU": AnyCodable(false), "iterations": AnyCodable(10000), ...]
    let cpuResult = try await tool.execute(arguments: cpuArgs)

    // Statistical comparison (mean should be within 1%)
    let gpuMean = extractMean(from: gpuResult)
    let cpuMean = extractMean(from: cpuResult)
    #expect(abs(gpuMean - cpuMean) / cpuMean < 0.01)
}

@Test("GPU automatically disabled for small simulations")
func testGPUThreshold() async throws {
    let args = ["useGPU": AnyCodable(true), "iterations": AnyCodable(500), ...]
    let result = try await tool.execute(arguments: args)

    // Should use CPU for < 1000 iterations (overhead not worth it)
    #expect(result.description.contains("CPU"))
}
```

**Success Criteria:**
- ✅ All 7 Monte Carlo tools support GPU acceleration
- ✅ Statistical equivalence between GPU and CPU results
- ✅ Documentation updated with performance benchmarks

---

### Phase 3: Advanced Features & Optimization (Week 4)

**Goal:** Support complex models and optimize performance

#### Task 3.1: Complex Model Support (Stretch Goal)
**Challenge:** User closures can't run on GPU directly

**Approach 1: Expression AST → Metal Compiler**
- Parse model expression into AST
- Compile AST to Metal Shading Language (MSL)
- JIT compile MSL to GPU kernels
- **Complexity:** High (needs full expression parser)
- **Performance:** Best (native GPU code)

**Approach 2: Bytecode Interpreter**
- Parse model into bytecode operations
- Interpret bytecode on GPU
- **Complexity:** Medium (simpler than AOT compilation)
- **Performance:** Good (still parallel)

**Approach 3: Pattern Recognition**
- Detect common patterns (linear models, polynomial models)
- Use pre-compiled kernels for recognized patterns
- **Complexity:** Low (pattern library)
- **Performance:** Best for recognized patterns

**Recommendation:** Start with Approach 3 (pattern recognition), expand to Approach 2 if needed.

#### Task 3.2: Memory Optimization
**Challenge:** Large simulations (1M+ iterations) may exceed GPU memory

**Solutions:**
- Chunked execution (run 100K iterations at a time)
- Stream results back to CPU incrementally
- Adaptive batch sizing based on available VRAM

#### Task 3.3: Distribution Expansion
**Goal:** Support all 15 distributions in GPU kernels

**Current GPU Support (Phase 1):**
- Normal (Box-Muller transform)
- Uniform (direct)
- Triangular (inverse transform)

**Additional Distributions:**
- Exponential (inverse transform)
- Lognormal (transform of Normal)
- Beta (rejection sampling)
- Gamma (Marsaglia-Tsang method)
- Weibull (inverse transform)
- Chi-Squared (sum of squared Normals)
- F, T, Pareto, Logistic, Geometric, Rayleigh

**Implementation:** Add Metal kernels for each distribution's sampling algorithm.

#### Task 3.4: Performance Profiling
**Tools:**
- Xcode Instruments (Metal System Trace)
- Custom performance benchmarks
- Comparison with CPU baseline

**Metrics:**
- Kernel execution time
- Memory transfer overhead
- End-to-end speedup
- GPU utilization %

**Optimization Targets:**
- Minimize CPU↔GPU transfers
- Maximize GPU occupancy (threads per SM)
- Optimize memory access patterns (coalescing)

**Success Criteria:**
- ✅ 50x+ speedup for 1M iterations
- ✅ Support for 10+ distributions on GPU
- ✅ Memory efficient (1M iterations < 1GB VRAM)

---

## Testing Strategy

### Unit Tests
- **GPU RNG Quality** (Chi-square, K-S tests)
- **Distribution Sampling** (compare GPU vs CPU samples)
- **Model Evaluation** (arithmetic correctness)

### Integration Tests
- **End-to-End Simulation** (full workflow CPU vs GPU)
- **Statistical Equivalence** (same random seed → same results)
- **Error Handling** (GPU unavailable, memory exhausted)

### Performance Tests
- **Benchmark Suite** (1K, 10K, 100K, 1M iterations)
- **Scalability** (linear scaling with iterations)
- **Overhead Analysis** (GPU setup cost)

### Compatibility Tests
- **macOS 10.15+** (Metal supported)
- **iOS 13.0+** (Metal supported)
- **Older Systems** (CPU fallback)
- **No GPU** (CPU fallback)

---

## Documentation Requirements

### User Documentation
**File:** `Sources/BusinessMath/BusinessMath.docc/Part4-Simulation.md`

**New Section: GPU Acceleration**
```markdown
## GPU Acceleration for Monte Carlo

Starting in v2.1, Monte Carlo simulations automatically use GPU acceleration when available.

### When GPU is Used
- Iterations >= 1,000
- Metal GPU device available (macOS 10.15+, iOS 13.0+)
- Model is GPU-compatible (arithmetic expressions)

### Performance Impact
```swift
var simulation = MonteCarloSimulation(iterations: 100_000) { inputs in
    // This model will run on GPU automatically
    inputs[0] * inputs[1] - inputs[2]
}

let results = try simulation.run()
// CPU: ~10 seconds
// GPU: ~0.5 seconds (20x faster)
```

### Disabling GPU
```swift
var simulation = MonteCarloSimulation(
    iterations: 100_000,
    enableGPU: false  // Force CPU execution
) { inputs in
    inputs[0] * inputs[1]
}
```

### Supported Distributions on GPU
- Normal (mean, stdDev)
- Uniform (min, max)
- Triangular (min, mode, max)
- Exponential (rate)
- Lognormal (logMean, logStdDev)
```

### API Documentation
**File:** `Sources/BusinessMath/Simulation/MonteCarlo/MonteCarloSimulation.swift`

**DocC Comments:**
```swift
/// Initialize a Monte Carlo simulation with optional GPU acceleration.
///
/// - Parameters:
///   - iterations: Number of simulation runs
///   - model: Model closure to evaluate (receives sampled inputs)
///   - enableGPU: Enable GPU acceleration (default: true)
///
/// GPU acceleration is automatically used when:
/// - `enableGPU` is `true`
/// - Iterations >= 1,000
/// - Metal GPU device is available
/// - Model is GPU-compatible
///
/// If GPU execution fails, the simulation automatically falls back to CPU.
///
/// - Note: GPU acceleration provides 10-100x speedup for large simulations (100K+ iterations)
public init(
    iterations: Int,
    model: @escaping @Sendable (InputVector) -> Double,
    enableGPU: Bool = true
)
```

### MCP Tool Documentation
**Already covered in Phase 2 tasks** (server description, MCP_README.md updates)

---

## Success Metrics

### Performance Targets
- ✅ **10x speedup** for 100,000 iterations
- ✅ **50x speedup** for 1,000,000 iterations
- ✅ **< 100ms overhead** for GPU initialization

### Reliability Targets
- ✅ **Statistical equivalence** (GPU vs CPU results within 1% mean difference)
- ✅ **100% CPU fallback** (no crashes when GPU unavailable)
- ✅ **Zero breaking changes** (existing API fully compatible)

### Coverage Targets
- ✅ **All 7 Monte Carlo MCP tools** support GPU
- ✅ **5+ distributions** on GPU (Normal, Uniform, Triangular, Exponential, Lognormal)
- ✅ **Comprehensive test suite** (unit, integration, performance, compatibility)

---

## Risk Assessment

### Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| RNG quality issues | Low | High | Chi-square/K-S validation, peer review |
| Statistical divergence | Medium | High | Side-by-side comparison tests, seeding parity |
| GPU memory limits | Medium | Medium | Chunked execution, adaptive batching |
| Metal API changes | Low | Low | Use stable Metal APIs (v2.0+) |
| Compilation failures | Low | Medium | Robust error handling, CPU fallback |

### Project Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Complex model support delayed | High | Low | Ship Phase 1 with simple models first |
| Performance target missed | Low | Medium | Profile early, optimize incrementally |
| Testing coverage gaps | Medium | High | TDD approach, automated benchmarks |
| Documentation lag | Low | Low | Document alongside implementation |

---

## Dependencies

### External Dependencies
- **Metal Framework** (macOS 10.15+, iOS 13.0+) - Already used by heuristic optimization
- **Swift 6** - Already required for @Sendable compliance
- **Swift Testing** - Already used for testing

### Internal Dependencies
- **MetalDevice.swift** - Existing GPU infrastructure (reuse)
- **DistributionRandom protocols** - Existing distribution API (extend)
- **MonteCarloSimulation** - Core simulation engine (enhance)

### No New Dependencies Required
All necessary frameworks and infrastructure already exist in the project.

---

## Timeline Estimate

### Phase 1: Core Library GPU Engine
**Estimated Time:** 2 weeks

- Task 1.1: GPU RNG (3 days)
- Task 1.2: Distribution samplers (2 days)
- Task 1.3: Model evaluator (3 days)
- Task 1.4: Swift GPU manager (2 days)
- Task 1.5: Integration + testing (4 days)

### Phase 2: MCP Tool Integration
**Estimated Time:** 1 week

- Task 2.1: Tool updates (2 days)
- Task 2.2: Server description (0.5 days)
- Task 2.3: Documentation (1 day)
- Task 2.4: Testing (1.5 days)

### Phase 3: Advanced Features (Optional)
**Estimated Time:** 1 week

- Task 3.1: Complex models (3 days)
- Task 3.2: Memory optimization (1 day)
- Task 3.3: Distribution expansion (2 days)
- Task 3.4: Performance profiling (1 day)

**Total Timeline:** 3-4 weeks (depending on Phase 3 scope)

---

## Future Enhancements (Post-Release)

### v2.2 Ideas
- **Multi-GPU Support**: Distribute simulations across multiple GPUs
- **Cloud GPU**: Run simulations on remote Metal-capable instances
- **Model Compilation**: Full AOT compilation of complex closures to Metal
- **Adaptive Execution**: Automatically choose CPU/GPU based on profiling

### v3.0 Ideas
- **Neural Network Models**: Support ML models as simulation inputs
- **Custom Kernels**: Allow users to provide custom Metal kernels
- **Distributed Simulation**: Cluster computing for billion-iteration simulations

---

## Appendix A: Metal RNG Validation

### Statistical Tests for GPU RNG Quality

**Chi-Square Test (Uniformity):**
```swift
func validateUniformity(samples: [Double], bins: Int = 100) -> Double {
    let histogram = createHistogram(samples, bins: bins)
    let expected = Double(samples.count) / Double(bins)
    let chiSquare = histogram.reduce(0.0) { sum, count in
        sum + pow(Double(count) - expected, 2) / expected
    }
    // chi-square < critical value (df=99, α=0.05) → uniform
    return chiSquare
}
```

**Kolmogorov-Smirnov Test (Distribution Match):**
```swift
func validateDistribution(
    samples: [Double],
    expectedCDF: (Double) -> Double
) -> Double {
    let sorted = samples.sorted()
    let maxDeviation = sorted.enumerated().map { i, x in
        let empiricalCDF = Double(i + 1) / Double(samples.count)
        return abs(empiricalCDF - expectedCDF(x))
    }.max()!
    // maxDeviation < critical value → distribution match
    return maxDeviation
}
```

**Autocorrelation Test (Independence):**
```swift
func validateIndependence(samples: [Double], lag: Int = 1) -> Double {
    // Lag-k autocorrelation should be ~0 for independent samples
    let mean = samples.reduce(0.0, +) / Double(samples.count)
    let variance = samples.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(samples.count)

    let autocorr = zip(samples.dropLast(lag), samples.dropFirst(lag))
        .map { ($0 - mean) * ($1 - mean) }
        .reduce(0.0, +) / (Double(samples.count - lag) * variance)

    // |autocorr| < 0.05 → independent
    return autocorr
}
```

---

## Appendix B: Example GPU Kernel (Full Implementation)

**File:** `Sources/BusinessMath/Simulation/MonteCarlo/GPU/MonteCarloKernel.metal`

```metal
#include <metal_stdlib>
using namespace metal;

// RNG state (Xorshift128+)
struct RNGState {
    ulong s0;
    ulong s1;
};

// Distribution configuration
struct DistributionParams {
    float param1;  // mean, min, rate, etc.
    float param2;  // stdDev, max, shape, etc.
    float param3;  // mode (triangular), scale, etc.
};

// Distribution type enum
enum DistributionType : int {
    DIST_NORMAL = 0,
    DIST_UNIFORM = 1,
    DIST_TRIANGULAR = 2,
    DIST_EXPONENTIAL = 3,
    DIST_LOGNORMAL = 4
};

// Model bytecode operation
struct ModelOp {
    int opcode;  // ADD=0, SUB=1, MUL=2, DIV=3, INPUT=4, CONST=5
    int arg1;    // Input index or stack position
    float arg2;  // Constant value
};

// Constants
constant int MAX_INPUTS = 32;
constant int MAX_OPS = 128;

// ============================================================
// RNG Functions
// ============================================================

inline float nextUniform(thread RNGState* state) {
    ulong s1 = state->s0;
    ulong s0 = state->s1;
    state->s0 = s0;
    s1 ^= s1 << 23;
    state->s1 = s1 ^ s0 ^ (s1 >> 18) ^ (s0 >> 5);
    return float(state->s0 + state->s1) * 1.08420217e-19f;
}

inline float2 nextNormal(thread RNGState* state, float mean, float stdDev) {
    float u1 = nextUniform(state);
    float u2 = nextUniform(state);
    float r = sqrt(-2.0f * log(u1));
    float theta = 2.0f * M_PI_F * u2;
    return float2(
        mean + stdDev * r * cos(theta),
        mean + stdDev * r * sin(theta)
    );
}

// ============================================================
// Distribution Samplers
// ============================================================

inline float sampleNormal(thread RNGState* state, constant DistributionParams* params) {
    return nextNormal(state, params->param1, params->param2).x;
}

inline float sampleUniform(thread RNGState* state, constant DistributionParams* params) {
    return params->param1 + nextUniform(state) * (params->param2 - params->param1);
}

inline float sampleTriangular(thread RNGState* state, constant DistributionParams* params) {
    float min = params->param1;
    float max = params->param2;
    float mode = params->param3;

    float u = nextUniform(state);
    float fc = (mode - min) / (max - min);

    if (u < fc) {
        return min + sqrt(u * (max - min) * (mode - min));
    } else {
        return max - sqrt((1.0f - u) * (max - min) * (max - mode));
    }
}

inline float sampleExponential(thread RNGState* state, constant DistributionParams* params) {
    float rate = params->param1;
    return -log(1.0f - nextUniform(state)) / rate;
}

inline float sampleLognormal(thread RNGState* state, constant DistributionParams* params) {
    float logMean = params->param1;
    float logStdDev = params->param2;
    float normal = nextNormal(state, logMean, logStdDev).x;
    return exp(normal);
}

inline float sampleDistribution(
    thread RNGState* state,
    constant DistributionParams* params,
    int distType
) {
    switch (distType) {
        case DIST_NORMAL: return sampleNormal(state, params);
        case DIST_UNIFORM: return sampleUniform(state, params);
        case DIST_TRIANGULAR: return sampleTriangular(state, params);
        case DIST_EXPONENTIAL: return sampleExponential(state, params);
        case DIST_LOGNORMAL: return sampleLognormal(state, params);
        default: return 0.0f;
    }
}

// ============================================================
// Model Evaluator (Stack-based Bytecode Interpreter)
// ============================================================

inline float evaluateModel(
    thread float* inputs,
    constant ModelOp* ops,
    int numOps
) {
    float stack[32];
    int stackPtr = 0;

    for (int i = 0; i < numOps; i++) {
        constant ModelOp& op = ops[i];

        switch (op.opcode) {
            case 0: // ADD
                stack[stackPtr - 2] = stack[stackPtr - 2] + stack[stackPtr - 1];
                stackPtr--;
                break;
            case 1: // SUB
                stack[stackPtr - 2] = stack[stackPtr - 2] - stack[stackPtr - 1];
                stackPtr--;
                break;
            case 2: // MUL
                stack[stackPtr - 2] = stack[stackPtr - 2] * stack[stackPtr - 1];
                stackPtr--;
                break;
            case 3: // DIV
                stack[stackPtr - 2] = stack[stackPtr - 2] / stack[stackPtr - 1];
                stackPtr--;
                break;
            case 4: // INPUT
                stack[stackPtr++] = inputs[op.arg1];
                break;
            case 5: // CONST
                stack[stackPtr++] = op.arg2;
                break;
        }
    }

    return stack[0];
}

// ============================================================
// Main Kernel
// ============================================================

kernel void monteCarloIteration(
    device RNGState* rngStates [[buffer(0)]],
    constant DistributionParams* distributions [[buffer(1)]],
    constant int* distTypes [[buffer(2)]],
    constant ModelOp* modelOps [[buffer(3)]],
    device float* outputs [[buffer(4)]],
    constant int& numInputs [[buffer(5)]],
    constant int& numOps [[buffer(6)]],
    uint tid [[thread_position_in_grid]]
) {
    // Thread-local RNG state
    thread RNGState rng = rngStates[tid];

    // Sample inputs
    thread float inputs[MAX_INPUTS];
    for (int i = 0; i < numInputs; i++) {
        inputs[i] = sampleDistribution(&rng, &distributions[i], distTypes[i]);
    }

    // Evaluate model
    float result = evaluateModel(inputs, modelOps, numOps);

    // Store result
    outputs[tid] = result;

    // Update RNG state for next iteration (if multi-pass)
    rngStates[tid] = rng;
}

// ============================================================
// RNG Initialization Kernel
// ============================================================

kernel void initializeRNG(
    device RNGState* states [[buffer(0)]],
    constant ulong& baseSeed [[buffer(1)]],
    uint tid [[thread_position_in_grid]]
) {
    // Create independent RNG stream for each thread
    states[tid].s0 = baseSeed ^ tid;
    states[tid].s1 = (baseSeed >> 32) ^ (ulong(tid) << 32);

    // Warm up the RNG (discard first few values)
    for (int i = 0; i < 10; i++) {
        nextUniform(&states[tid]);
    }
}
```

---

## Appendix C: Performance Benchmark Script

**File:** `Tests/PerformanceTests/MonteCarloGPUBenchmark.swift`

```swift
import XCTest
import BusinessMath
import Foundation

final class MonteCarloGPUBenchmark: XCTestCase {
    func testPerformanceComparison() throws {
        let iterationCounts = [1_000, 10_000, 100_000, 1_000_000]

        var results: [(iterations: Int, cpuTime: TimeInterval, gpuTime: TimeInterval)] = []

        for iterations in iterationCounts {
            // CPU benchmark
            let cpuStart = Date()
            var cpuSim = MonteCarloSimulation<Vector3<Double>>(
                iterations: iterations,
                model: { inputs in inputs[0] * inputs[1] - inputs[2] },
                enableGPU: false
            )
            cpuSim.addInput(DistributionNormal(100, 10))
            cpuSim.addInput(DistributionNormal(50, 5))
            cpuSim.addInput(DistributionNormal(1000, 100))
            _ = try cpuSim.run()
            let cpuTime = Date().timeIntervalSince(cpuStart)

            // GPU benchmark
            let gpuStart = Date()
            var gpuSim = MonteCarloSimulation<Vector3<Double>>(
                iterations: iterations,
                model: { inputs in inputs[0] * inputs[1] - inputs[2] },
                enableGPU: true
            )
            gpuSim.addInput(DistributionNormal(100, 10))
            gpuSim.addInput(DistributionNormal(50, 5))
            gpuSim.addInput(DistributionNormal(1000, 100))
            _ = try gpuSim.run()
            let gpuTime = Date().timeIntervalSince(gpuStart)

            results.append((iterations, cpuTime, gpuTime))

            print("""
            Iterations: \(iterations)
              CPU: \(String(format: "%.3f", cpuTime))s
              GPU: \(String(format: "%.3f", gpuTime))s
              Speedup: \(String(format: "%.1f", cpuTime / gpuTime))x
            """)
        }

        // Generate markdown table
        print("\n| Iterations | CPU Time | GPU Time | Speedup |")
        print("|-----------|----------|----------|---------|")
        for result in results {
            print("| \(result.iterations) | \(String(format: "%.3f", result.cpuTime))s | \(String(format: "%.3f", result.gpuTime))s | \(String(format: "%.1f", result.cpuTime / result.gpuTime))x |")
        }
    }
}
```

---

## Sign-Off

**Implementation Owner:** TBD
**Reviewer:** TBD
**Target Release:** v2.1.0
**Priority:** High (major performance improvement)
**Estimated Effort:** 3-4 weeks

**Next Steps:**
1. Review this plan with team
2. Assign implementation owner
3. Create GitHub issues for each phase/task
4. Begin Phase 1 implementation
5. Set up CI/CD for performance regression testing

---

*Document created: 2026-01-26*
*Last updated: 2026-01-26*
*Version: 1.0*
