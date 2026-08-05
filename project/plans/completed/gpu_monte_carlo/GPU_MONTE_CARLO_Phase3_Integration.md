# GPU Monte Carlo - Phase 3: End-to-End GPU Execution

**Prerequisites:** Phase 1 ✅ Phase 2 ✅
**Goal:** Connect Phase 1 (GPU infrastructure) + Phase 2 (model compilation) for full GPU acceleration
**Target:** 10-100x speedup for large simulations (100K+ iterations)
**Approach:** Integrate compiled bytecode with Metal GPU execution

---

## Executive Summary

Phase 3 completes the GPU Monte Carlo implementation by integrating the expression compilation infrastructure (Phase 2) with the GPU execution engine (Phase 1). This enables automatic GPU acceleration for expression-based models with seamless CPU fallback.

### What Gets Connected

```
┌─────────────────────┐
│   Phase 2           │
│ Expression Builder  │──┐
│ Bytecode Compiler   │  │
│ Bytecode Optimizer  │  │
└─────────────────────┘  │
                         │  Phase 3
                         ▼  Integration
┌─────────────────────┐  │
│   Phase 1           │  │
│ GPU Device Manager  │◄─┘
│ Metal Kernels       │
│ RNG + Distributions │
└─────────────────────┘

         ▼
┌─────────────────────┐
│  Full GPU Execution │
│  10-100x Speedup    │
└─────────────────────┘
```

---

## Current State

### ✅ Phase 1: GPU Infrastructure (COMPLETE)

- MonteCarloGPUDevice manages Metal device
- GPU kernels for RNG and distributions (Normal, Uniform, Triangular)
- GPU bytecode format defined: `(opcode: Int32, arg1: Int32, arg2: Float)`
- 30 tests passing

**But:** GPU kernels expect simple hardcoded models, not compiled bytecode

### ✅ Phase 2: Model Compilation (COMPLETE)

- MonteCarloExpressionModel compiles models to bytecode
- Bytecode optimizer applies compile-time transformations
- GPU bytecode format matches Phase 1 expectations
- 110 tests passing

**But:** Compiled bytecode doesn't connect to GPU execution yet

### ❌ Missing Integration

- MonteCarloSimulation doesn't route expression models to GPU
- GPU kernels don't accept/execute compiled bytecode
- No end-to-end GPU acceleration working
- No performance validation

---

## Implementation Plan (TDD)

### Iteration 1: Update GPU Kernel to Accept Bytecode

**Goal:** Modify Metal shader to execute arbitrary bytecode instead of hardcoded models

#### Test 1.1: GPU Bytecode Interpreter Tests

**File:** `Tests/BusinessMathTests/Simulation Tests/GPU/GPUBytecodeInterpreterTests.swift` (NEW)

Tests to write:
1. Simple addition model: `a + b`
   - Bytecode: [INPUT(0), INPUT(1), ADD]
   - Validate GPU produces correct result

2. Complex model: `(a * b) - c`
   - Bytecode: [INPUT(0), INPUT(1), MUL, INPUT(2), SUB]
   - Validate multi-operation execution

3. Model with constants: `a * 1.5 + 100`
   - Bytecode includes CONST instructions
   - Validate constant handling on GPU

4. Optimized model: `a + 0` → `a`
   - Send optimized bytecode to GPU
   - Validate optimization preserves correctness

#### Implementation 1.1: Update MonteCarloKernel.metal

**File:** `Sources/BusinessMath/Simulation/MonteCarlo/GPU/MonteCarloKernel.metal` (MODIFY)

Changes needed:
```metal
// Add bytecode buffer parameter
kernel void monteCarloIteration(
    // ... existing parameters ...
    constant GPUBytecode* bytecode [[buffer(4)]],
    constant uint& bytecodeLength [[buffer(5)]],
    // ... other parameters ...
) {
    // Execute bytecode interpreter
    float result = executeBytecode(bytecode, bytecodeLength, inputs);
    results[gid] = result;
}

// Stack-based bytecode interpreter
float executeBytecode(
    constant GPUBytecode* bytecode,
    uint length,
    thread float* inputs
) {
    float stack[MAX_STACK_DEPTH];
    uint stackPtr = 0;

    for (uint i = 0; i < length; i++) {
        GPUBytecode instruction = bytecode[i];

        switch (instruction.opcode) {
            case OP_INPUT:
                stack[stackPtr++] = inputs[instruction.arg1];
                break;
            case OP_CONST:
                stack[stackPtr++] = instruction.arg2;
                break;
            case OP_ADD:
                float b = stack[--stackPtr];
                float a = stack[--stackPtr];
                stack[stackPtr++] = a + b;
                break;
            // ... other operations ...
        }
    }

    return stack[0];
}
```

---

### Iteration 2: Update MonteCarloGPUDevice

**Goal:** Upload compiled bytecode to GPU and execute it

#### Test 2.1: GPU Device Bytecode Execution Tests

**File:** `Tests/BusinessMathTests/Simulation Tests/GPU/MonteCarloGPUDeviceBytecodeTests.swift` (NEW)

Tests to write:
1. Upload bytecode to GPU buffer
   - Create expression model
   - Upload bytecode to GPU
   - Verify buffer contents

2. Execute bytecode on GPU
   - Simple model: `a + b`
   - 1000 iterations
   - Validate results match CPU

3. Execute optimized bytecode
   - Model with optimization: `(a + 0) * 1`
   - Verify GPU executes optimized version
   - Results match unoptimized CPU

4. GPU vs CPU equivalence
   - Complex financial model
   - 10K iterations on both GPU and CPU
   - Statistical equivalence (means within 1%)

#### Implementation 2.1: Update MonteCarloGPUDevice.swift

**File:** `Sources/BusinessMath/Simulation/MonteCarlo/GPU/MonteCarloGPUDevice.swift` (MODIFY)

Changes needed:
```swift
public class MonteCarloGPUDevice {

    // Add bytecode buffer
    private var bytecodeBuffer: MTLBuffer?

    /// Run simulation with compiled bytecode model
    public func runSimulation(
        iterations: Int,
        distributionConfigs: [DistributionConfig],
        bytecode: [(opcode: Int32, arg1: Int32, arg2: Float)],  // NEW
        seed: UInt64
    ) -> [Float]? {

        // Create bytecode buffer
        guard let buffer = createBytecodeBuffer(bytecode: bytecode) else {
            return nil
        }
        self.bytecodeBuffer = buffer

        // Set bytecode buffer on compute encoder
        computeEncoder.setBuffer(buffer, offset: 0, index: 4)
        computeEncoder.setBytes(&bytecodeLength, length: MemoryLayout<UInt32>.size, index: 5)

        // ... rest of execution ...
    }

    private func createBytecodeBuffer(
        bytecode: [(opcode: Int32, arg1: Int32, arg2: Float)]
    ) -> MTLBuffer? {
        let byteCount = bytecode.count * MemoryLayout<GPUBytecode>.stride
        return device.makeBuffer(bytes: bytecode, length: byteCount, options: .storageModeShared)
    }
}
```

---

### Iteration 3: MonteCarloSimulation Integration

**Goal:** Seamless GPU routing for expression models

#### Test 3.1: Simulation Integration Tests

**File:** `Tests/BusinessMathTests/Simulation Tests/MonteCarloGPUIntegrationTests.swift` (MODIFY)

Add tests:
1. Expression model automatic GPU routing
   - Create expression model
   - Create simulation with `enableGPU: true`
   - Verify GPU execution path taken

2. GPU threshold behavior
   - < 1000 iterations → CPU
   - ≥ 1000 iterations → GPU (if available)
   - Verify via `results.usedGPU` flag

3. Automatic fallback on GPU error
   - Force GPU error
   - Verify automatic CPU fallback
   - Results still valid

4. Closure model still works
   - Traditional closure-based model
   - Should always use CPU (can't compile)
   - Backward compatibility preserved

#### Implementation 3.1: Update MonteCarloSimulation.swift

**File:** `Sources/BusinessMath/Simulation/MonteCarlo/MonteCarloSimulation.swift` (MODIFY)

Add new initializer:
```swift
public init(
    iterations: Int,
    model: MonteCarloExpressionModel,  // NEW: Direct expression model support
    enableGPU: Bool = true
) {
    self.iterations = iterations
    self.enableGPU = enableGPU
    self.expressionModel = model  // Store expression model
    self.model = model.toClosure()  // Fallback closure
    self.inputs = []

    #if canImport(Metal)
    if enableGPU {
        self.gpuDevice = MonteCarloGPUDevice()
    } else {
        self.gpuDevice = nil
    }
    #endif
}
```

Update `run()` method:
```swift
public mutating func run() throws -> SimulationResults {
    // Check GPU eligibility
    let useGPU = shouldUseGPU()

    if useGPU, let expressionModel = self.expressionModel {
        // GPU path: Use compiled bytecode
        return try runGPU(expressionModel: expressionModel)
    } else {
        // CPU path: Use closure model
        return try runCPU()
    }
}

private func shouldUseGPU() -> Bool {
    guard enableGPU else { return false }
    guard iterations >= 1000 else { return false }  // GPU threshold

    #if canImport(Metal)
    guard gpuDevice != nil else { return false }
    #else
    return false
    #endif

    // Must have expression model (closures can't compile)
    guard expressionModel != nil else { return false }

    return true
}
```

---

### Iteration 4: End-to-End GPU Execution Tests

**Goal:** Validate full GPU pipeline works correctly

#### Test 4.1: Full GPU Monte Carlo Tests

**File:** `Tests/BusinessMathTests/Simulation Tests/MonteCarloGPUEndToEndTests.swift` (NEW)

Comprehensive tests:
1. Simple model GPU vs CPU equivalence
   - Model: `a + b`
   - Distributions: Normal(100, 10), Normal(50, 5)
   - 10K iterations on GPU and CPU
   - Validate means within 1%, stdDevs within 5%

2. Complex financial model
   - Model: `(revenue * price) - (costs * (1 + tax))`
   - 4 input variables
   - 100K iterations on GPU
   - Results statistically equivalent to CPU

3. GPU optimization benefit
   - Unoptimized model: `(a + 0) * 1 + (5 * 2)`
   - Optimized model: `a + 10`
   - GPU should execute optimized version
   - Verify instruction count reduced

4. Large-scale simulation
   - 1M iterations on GPU
   - Validate results are reasonable
   - Check for GPU memory issues
   - Verify performance is acceptable

5. Mixed distributions
   - Normal, Uniform, Triangular all in one model
   - GPU handles heterogeneous distributions
   - Results match CPU

#### Implementation 4.1: Complete GPU Pipeline

Ensure all pieces work together:
- Expression model compiles bytecode ✅ (Phase 2)
- Bytecode uploaded to GPU ✅ (Iteration 2)
- GPU kernel executes bytecode ✅ (Iteration 1)
- Results returned to CPU ✅ (Phase 1)
- MonteCarloSimulation routes correctly ✅ (Iteration 3)

---

### Iteration 5: Performance Benchmarking

**Goal:** Validate GPU performance gains

#### Test 5.1: Performance Benchmark Tests

**File:** `Tests/BusinessMathTests/Simulation Tests/MonteCarloGPUPerformanceTests.swift` (NEW)

Benchmarks:
1. CPU vs GPU performance comparison
   - Test iterations: 1K, 10K, 100K, 1M
   - Measure execution time for both
   - Calculate speedup ratio
   - Validate 10x+ speedup for 100K+ iterations

2. GPU overhead measurement
   - Measure initialization time
   - Measure buffer upload time
   - Validate overhead < 100ms

3. Optimal GPU threshold
   - Find crossover point where GPU beats CPU
   - Expected: ~1000 iterations
   - Document in code comments

4. Model complexity impact
   - Simple models (a + b)
   - Complex models (20+ operations)
   - Measure performance scaling

**Note:** These are manual performance tests, not part of regular test suite

---

## Success Criteria

### Functional Requirements

- ✅ GPU path produces statistically equivalent results to CPU (means within 1%)
- ✅ Automatic GPU routing for expression models when eligible
- ✅ Automatic CPU fallback when GPU unavailable or model incompatible
- ✅ Closure-based models continue working (CPU path)
- ✅ No breaking changes to existing API

### Performance Requirements

- ✅ 10x+ speedup for 100K iterations on simple models
- ✅ 50x+ speedup for 1M iterations on simple models
- ✅ GPU overhead < 100ms for initialization
- ✅ Graceful degradation for small simulations (< 1000 iterations → CPU)

### Quality Requirements

- ✅ All existing tests still pass
- ✅ New GPU integration tests pass
- ✅ Statistical validation passes (GPU results match CPU)
- ✅ Conditional GPU tests skip gracefully when Metal unavailable

---

## Files to Modify

### Existing Files

1. `MonteCarloKernel.metal`
   - Add bytecode interpreter
   - Accept bytecode buffer parameter
   - Execute arbitrary compiled models

2. `MonteCarloGPUDevice.swift`
   - Accept compiled bytecode
   - Upload bytecode to GPU buffer
   - Pass bytecode to kernel

3. `MonteCarloSimulation.swift`
   - Add `init(iterations:model:enableGPU:)` overload
   - Store expression model reference
   - GPU routing logic in `run()`
   - `shouldUseGPU()` helper

4. `SimulationResults.swift`
   - Already has `usedGPU: Bool` property (Phase 1)

### New Test Files

1. `GPUBytecodeInterpreterTests.swift` - GPU kernel bytecode execution
2. `MonteCarloGPUDeviceBytecodeTests.swift` - Device-level integration
3. `MonteCarloGPUEndToEndTests.swift` - Full pipeline validation
4. `MonteCarloGPUPerformanceTests.swift` - Performance benchmarks

---

## Documentation Updates (Phase 3)

### Required Updates

Since Phase 3 enables **actual GPU acceleration**, we need:

1. **GPU Acceleration Guide** (NEW)
   - When to use GPU acceleration
   - Expression model requirements
   - Performance characteristics
   - Troubleshooting GPU issues
   - System requirements

2. **Expression Model Tutorial** (NEW)
   - Converting closure to expression model
   - GPU benefits and tradeoffs
   - Supported operations
   - Examples

3. **Performance Guide** (NEW)
   - GPU vs CPU performance comparison
   - Optimal simulation sizes
   - Memory considerations
   - Best practices

4. **Update Existing Tutorials**
   - Add "GPU Acceleration" callout boxes
   - Show expression model alternative
   - No changes to existing examples

### DocC Articles to Add

```swift
// Sources/BusinessMath/BusinessMath.docc/GPUAccelerationGuide.md (NEW)

# GPU Acceleration for Monte Carlo Simulations

Achieve 10-100x speedup for large simulations using Metal GPU acceleration.

## Overview

GPU acceleration is automatically enabled for simulations using expression-based
models with 1000+ iterations. The GPU path is completely transparent - your
models produce identical statistical results whether running on GPU or CPU.

## Requirements

- macOS 13.0+ with Metal-capable GPU
- 1000+ iterations (GPU overhead not worth it for smaller simulations)
- Expression-based model (closures can't be compiled to GPU)

## Usage

```swift
// 1. Define model using expression builder
let model = MonteCarloExpressionModel { builder in
    let revenue = builder[0]
    let costs = builder[1]
    return revenue - costs
}

// 2. Create simulation with GPU enabled (default)
var simulation = MonteCarloSimulation(
    iterations: 100_000,
    model: model,
    enableGPU: true  // default, can omit
)

// 3. Add inputs and run
simulation.addInput(...)
let results = try simulation.run()

// 4. Check if GPU was used
print("Executed on: \(results.usedGPU ? "GPU ⚡" : "CPU")")
```

## Performance Characteristics

| Iterations | CPU Time | GPU Time | Speedup |
|------------|----------|----------|---------|
| 1,000      | 10ms     | 15ms     | 0.7x    |
| 10,000     | 100ms    | 20ms     | 5x      |
| 100,000    | 1s       | 50ms     | 20x     |
| 1,000,000  | 10s      | 200ms    | 50x     |

## Automatic Fallback

The GPU path automatically falls back to CPU when:
- GPU is unavailable (no Metal device)
- Simulation is too small (< 1000 iterations)
- Model is closure-based (can't compile)
- GPU execution fails (rare)

Results are always correct regardless of execution path.

## Topics

### Guides
- <doc:ExpressionModelGuide>
- <doc:PerformanceOptimization>
- <doc:TroubleshootingGPU>
```

---

## Risk Mitigation

### Risk 1: GPU Results Diverge from CPU

**Problem:** Floating-point differences between GPU and CPU
**Mitigation:** Statistical validation (means within 1%, not bit-exact)
**Testing:** Comprehensive equivalence tests with tolerance

### Risk 2: GPU Memory Limitations

**Problem:** Very large simulations might exceed GPU memory
**Mitigation:** Automatic chunking for large simulations
**Fallback:** CPU path if GPU memory allocation fails

### Risk 3: Metal Unavailability

**Problem:** Older Macs or non-Apple platforms
**Mitigation:** Conditional compilation, graceful fallback
**Testing:** Tests skip when Metal unavailable

### Risk 4: Performance Doesn't Meet Targets

**Problem:** GPU overhead too high for claimed speedup
**Mitigation:** Profile and optimize GPU kernel
**Measurement:** Comprehensive performance benchmarking

---

## Timeline Estimate

**Session 1:** Iteration 1-2 (GPU kernel + device updates)
**Session 2:** Iteration 3-4 (Simulation integration + end-to-end tests)
**Session 3:** Iteration 5 (Performance benchmarking + optimization)
**Session 4:** Documentation updates

**Total:** 3-4 implementation sessions

---

## Phase 3 Deliverables

### Code
- ✅ GPU bytecode interpreter in Metal kernel
- ✅ MonteCarloGPUDevice accepts compiled bytecode
- ✅ MonteCarloSimulation automatic GPU routing
- ✅ End-to-end GPU execution working

### Tests
- ✅ GPU kernel bytecode execution tests
- ✅ Device-level integration tests
- ✅ Full pipeline integration tests
- ✅ Performance benchmarks

### Documentation
- ✅ GPU Acceleration Guide
- ✅ Expression Model Tutorial
- ✅ Performance Guide
- ✅ Updated existing docs with GPU callouts

### Performance
- ✅ 10x+ speedup demonstrated for 100K iterations
- ✅ Benchmarks documented
- ✅ Optimal thresholds identified

---

## After Phase 3

With Phase 3 complete, the Monte Carlo GPU acceleration will be **production-ready**:

- Full GPU acceleration working
- Comprehensive test coverage
- Performance validated
- Documentation complete
- Zero breaking changes

Future enhancements can then focus on:
- Additional distributions (Phase 4)
- Correlation support for expression models (Phase 5)
- Advanced expression features (if/else, function calls)
- MCP tool integration for remote GPU execution

But the core GPU Monte Carlo will be **done** ✅
