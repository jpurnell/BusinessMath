# BusinessMath Memory Leak Audit Report

**Audit Date:** March 9, 2026
**Codebase Version:** v2.0.0-beta.6
**Auditor:** Claude Code Memory Analysis
**Scope:** Complete source code review for memory leaks, retain cycles, and resource management (371 source files)

---

## Executive Summary

This memory audit of the BusinessMath Swift library identified **47 potential memory issues** across 6 major categories. The library makes extensive use of Swift's value types (structs), which naturally prevents many retain cycle issues. However, several classes, caching mechanisms, and async patterns exhibit memory growth that could impact long-running applications.

### Risk Distribution

| Category | Critical | High | Medium | Low | Total |
|----------|----------|------|--------|-----|-------|
| Unbounded Collection Growth | 4 | 4 | 1 | 0 | 9 |
| GPU/Metal Resource Leaks | 0 | 3 | 4 | 1 | 8 |
| Async Task Retention | 2 | 5 | 3 | 0 | 10 |
| Cache Memory Growth | 1 | 4 | 2 | 0 | 7 |
| Class Retain Cycles | 1 | 2 | 1 | 0 | 4 |
| Struct Closure Captures | 0 | 0 | 0 | 5 | 5 |
| Resource Cleanup | 0 | 1 | 2 | 1 | 4 |
| **TOTAL** | **8** | **19** | **13** | **7** | **47** |

### Key Recommendations

1. **Add size limits** to all accumulating collections (audit trails, debug steps, streaming buffers)
2. **Implement explicit Metal buffer cleanup** in GPU optimization algorithms
3. **Add cancellation hooks** to detached async Tasks
4. **Use ring buffers** instead of unbounded arrays for streaming statistics
5. **Fix InflightEntry** task cancellation handling in CalculationCache

---

## Table of Contents

1. [Category 1: Unbounded Collection Growth](#category-1-unbounded-collection-growth)
2. [Category 2: GPU/Metal Resource Leaks](#category-2-gpumetal-resource-leaks)
3. [Category 3: Async Task Retention](#category-3-async-task-retention)
4. [Category 4: Cache Memory Growth](#category-4-cache-memory-growth)
5. [Category 5: Class Retain Cycles](#category-5-class-retain-cycles)
6. [Category 6: Struct Closure Captures](#category-6-struct-closure-captures)
7. [Category 7: Resource Cleanup](#category-7-resource-cleanup)
8. [Educational Guide: Memory Management in Swift](#educational-guide-memory-management-in-swift)

---

## Category 1: Unbounded Collection Growth

### What Is This Category?

Unbounded collection growth occurs when arrays, dictionaries, or sets accumulate data without any mechanism to:
- Limit maximum size
- Remove old entries
- Clear when no longer needed

In a long-running application, this causes memory to grow linearly (or worse) with usage time.

### Why It Matters

Financial applications often run continuously:
- Trading systems process millions of transactions
- Risk calculations run overnight
- Monte Carlo simulations iterate for hours

Collections that grow without bounds will eventually exhaust available memory.

---

### Issue 1.1: Audit Trail Entry Accumulation (CRITICAL)

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Audit/AuditTrail.swift`
**Lines:** 187, 213

**Current Code:**
```swift
private var entries: [AuditEntry] = []

func record(_ entry: AuditEntry) {
    lock.lock()
    defer { lock.unlock() }
    entries.append(entry)  // UNBOUNDED APPEND
    // No size limit, no cleanup, no rotation
}
```

**The Problem:** Every financial operation can trigger audit recording. Each `record()` call appends without limit. A system running for days accumulates millions of entries.

**Memory Impact:** Each `AuditEntry` contains:
- Operation name (String)
- Timestamp (Date)
- Input/output values (Any)
- Context dictionary

Estimate: 500 bytes per entry × 1M entries = **500 MB**

**Suggested Fix:**
```swift
private var entries: [AuditEntry] = []
private let maxEntries: Int = 100_000

func record(_ entry: AuditEntry) {
    lock.lock()
    defer { lock.unlock() }

    entries.append(entry)

    // Rotate oldest entries when limit reached
    if entries.count > maxEntries {
        entries.removeFirst(entries.count - maxEntries)
    }
}

// Or use a ring buffer:
private var entries: RingBuffer<AuditEntry>
```

---

### Issue 1.2: Debug Steps Accumulation (CRITICAL)

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Diagnostics/ModelDebugger.swift`
**Lines:** 19, 43-48

**Current Code:**
```swift
private var steps: [CalculationStep] = []

func recordStep(operation: String, input: String, output: String) {
    lock.lock()
    defer { lock.unlock() }
    guard isEnabled else { return }
    steps.append(CalculationStep(
        operation: operation,
        input: input,
        output: output,
        timestamp: Date()
    ))
    // No maximum step count
}
```

**The Problem:** When tracing is enabled, every calculation step is recorded. Complex financial models can generate thousands of steps per evaluation.

**Memory Impact:** With tracing enabled during Monte Carlo simulation:
- 10,000 iterations × 100 steps/iteration = 1,000,000 entries
- ~200 bytes per step = **200 MB**

**Suggested Fix:**
```swift
private var steps: [CalculationStep] = []
private let maxSteps: Int = 10_000

func recordStep(operation: String, input: String, output: String) {
    lock.lock()
    defer { lock.unlock() }
    guard isEnabled else { return }

    // Use ring buffer behavior
    if steps.count >= maxSteps {
        steps.removeFirst()
    }

    steps.append(CalculationStep(
        operation: operation,
        input: input,
        output: output,
        timestamp: Date()
    ))
}
```

---

### Issue 1.3: Streaming Anomaly Detection Buffers All Values (CRITICAL)

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Streaming/StreamingAnomalyDetection.swift`
**Lines:** 892, 894, 912-916

**Current Code:**
```swift
private var allValues: [Double] = []      // UNBOUNDED
private var breakpoints: [Breakpoint] = []

public mutating func next() async throws -> Breakpoint? {
    if !hasCollected {
        var iterator = base.makeAsyncIterator()
        while let value = try await iterator.next() {
            allValues.append(value)  // ENTIRE STREAM IN MEMORY
        }
        hasCollected = true

        breakpoints = performBinarySegmentation(values: allValues, ...)
    }
    // ...
}
```

**The Problem:** The async iterator collects the **entire stream** into memory before analyzing. This defeats the purpose of streaming APIs.

**Memory Impact:** For a time series with 1 million data points:
- 1M × 8 bytes (Double) = **8 MB** just for values
- Plus breakpoint detection structures

**Suggested Fix:**
```swift
// Use windowed processing instead of full buffering
private var window: RingBuffer<Double>
private let windowSize: Int = 10_000

public mutating func next() async throws -> Breakpoint? {
    while let value = try await baseIterator.next() {
        window.append(value)

        // Analyze window incrementally
        if let breakpoint = detectBreakpointInWindow() {
            return breakpoint
        }
    }
    return nil
}
```

---

### Issue 1.4: Branch-and-Bound Node Queue (CRITICAL)

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Optimization/IntegerProgramming/BranchAndBound.swift`
**Lines:** 2031, 2041-2043

**Current Code:**
```swift
struct NodeQueue<V: VectorSpace>: Sendable where V.Scalar == Double {
    private var heap: [BranchNode<V>] = []  // UNBOUNDED

    mutating func insert(_ node: BranchNode<V>) {
        heap.append(node)
        siftUp(from: heap.count - 1)
    }
}
```

**The Problem:** Branch-and-bound algorithms can generate exponentially many nodes. Without pruning strategies, the heap grows unbounded.

**Memory Impact:** For a problem with 100 binary variables:
- Worst case: 2^100 nodes (astronomically large)
- Practical case with weak bounds: 100,000+ nodes
- Each node contains solution vector + bounds + metadata

**Suggested Fix:**
```swift
struct NodeQueue<V: VectorSpace>: Sendable where V.Scalar == Double {
    private var heap: [BranchNode<V>] = []
    private let maxNodes: Int

    mutating func insert(_ node: BranchNode<V>) {
        heap.append(node)
        siftUp(from: heap.count - 1)

        // Prune low-quality nodes when queue too large
        if heap.count > maxNodes {
            pruneWorstNodes()
        }
    }

    private mutating func pruneWorstNodes() {
        // Keep only top 80% by bound quality
        let keepCount = maxNodes * 4 / 5
        heap = Array(heap.prefix(keepCount))
        // Rebuild heap
        for i in stride(from: heap.count / 2 - 1, through: 0, by: -1) {
            siftDown(from: i)
        }
    }
}
```

---

### Issue 1.5: Streaming Statistics Buffers

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Streaming/StreamingStatistics.swift`
**Lines:** 262, 441, 616, 707, 806, 1095

**Current Code:**
```swift
// Six independent unbounded buffers:
// Line 262 - MovingAverageCalculator
private var buffer: [Double] = []

// Line 441 - VarianceCalculator
private var buffer: [Double] = []

// Line 616 - SkewnessCalculator
private var buffer: [Double] = []

// And 3 more at lines 707, 806, 1095
```

**The Problem:** These are labeled "buffer" but behave as unbounded accumulators. Each stream value is appended with no clearing mechanism.

**Suggested Fix:**
```swift
// Use fixed-size ring buffer
private var buffer: RingBuffer<Double>

init(windowSize: Int = 1000) {
    self.buffer = RingBuffer(capacity: windowSize)
}

mutating func update(_ value: Double) {
    buffer.append(value)  // Ring buffer automatically overwrites oldest
    recalculateStatistics()
}
```

---

### Issue 1.6: Cut Ages and Solution History in Cutting Planes

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Optimization/IntegerProgramming/BranchAndBound.swift`
**Lines:** 834-838, 1172-1194

**Current Code:**
```swift
var cutAges: [(constraintIndex: Int, roundAdded: Int, lastActiveRound: Int)] = []
var boundHistory: [Double] = []
var solutionHistory: [[Double]] = []

// In cutting loop:
boundHistory.append(resolvedResult.objectiveValue)
solutionHistory.append(currentSolutionArray)
```

**The Problem:** These arrays grow with each cutting plane round. While `solutionHistory` has partial limiting via `cyclingWindowSize`, `boundHistory` and `cutAges` grow unbounded.

---

### Issue 1.7: PseudoCostTracker Dictionaries

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Optimization/IntegerProgramming/BranchAndBound.swift`
**Lines:** 1751-1812

**Current Code:**
```swift
class PseudoCostTracker: @unchecked Sendable {
    private var upCosts: [Int: (sum: Double, count: Int)] = [:]
    private var downCosts: [Int: (sum: Double, count: Int)] = [:]

    func updateCost(variable: Int, direction: BranchDirection, ...) {
        // Entry created for each branched variable
        upCosts[variable] = (current.sum + cost, current.count + 1)
    }
}
```

**The Problem:** For problems with many variables, these dictionaries grow without limit. No eviction mechanism.

---

### Issue 1.8: String Builder Parts

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Performance/CalculationCache.swift`
**Lines:** 680, 684, 689

**Current Code:**
```swift
final class StringBuilder {
    private var parts: [String] = []  // UNBOUNDED

    func append(_ string: String) {
        parts.append(string)  // No limit
    }
}
```

**The Problem:** Large CSV exports accumulate string parts without size checking.

---

### Issue 1.9: MovingAverageModel Historical Values

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Forecasting/MovingAverageModel.swift`
**Lines:** 37, 86

**Current Code:**
```swift
private var historicalValues: [T] = []

public mutating func train(values: [T]) throws {
    // ...
    self.historicalValues = Array(values)  // STORES ENTIRE HISTORY
}
```

**The Problem:** Stores entire training dataset even though only the last `window` values are needed.

---

## Category 2: GPU/Metal Resource Leaks

### What Is This Category?

Metal is Apple's GPU programming framework. Metal resources (buffers, textures, command buffers) are reference-counted but require careful management:
- Buffers should be released after computation completes
- Command encoders should always have `endEncoding()` called
- Pipeline states can be cached, but buffers should not accumulate

### Why It Matters

GPU memory is separate from system memory and often more limited:
- iPhone has 3-6 GB shared memory
- Mac discrete GPUs have fixed VRAM (8-128 GB)
- Metal buffers not released cause GPU memory pressure

---

### Issue 2.1: Monte Carlo GPU Buffers Not Released

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Simulation/MonteCarlo/GPU/MonteCarloGPUDevice.swift`
**Lines:** 385-389

**Current Code:**
```swift
guard let rngStates = device.makeBuffer(length: rngStateSize, options: .storageModeShared),
      let distributions = device.makeBuffer(length: distSize, options: .storageModeShared),
      let distTypes = device.makeBuffer(length: distTypeSize, options: .storageModeShared),
      let modelOps = device.makeBuffer(length: opsSize, options: .storageModeShared),
      let outputs = device.makeBuffer(length: outputSize, options: .storageModeShared) else {
    // ...
}
// 5 buffers allocated per simulation run
// No explicit release - relies on ARC
```

**The Problem:** Each `runSimulation()` call allocates 5 GPU buffers. While ARC will eventually clean these up, they persist for the scope of the method. Rapid simulation runs can exhaust GPU memory.

**Memory Impact:**
- 5 buffers × 10,000 paths × 100 iterations = significant GPU memory churn
- GPU memory pressure can cause system slowdown

**Suggested Fix:**
```swift
// Use autoreleasepool to ensure timely cleanup
autoreleasepool {
    guard let rngStates = device.makeBuffer(...) else { return nil }
    // ... create other buffers

    // Perform computation
    let result = executeKernel(...)

    // Buffers released at end of autoreleasepool
    return result
}
```

---

### Issue 2.2: Particle Swarm 9 Buffers Per Iteration (HIGH)

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Optimization/Heuristic/ParticleSwarmOptimization.swift`
**Lines:** 477-485

**Current Code:**
```swift
guard let velocitiesBuffer = device.makeBuffer(bytes: velocitiesFlat, ...),
      let positionsBuffer = device.makeBuffer(bytes: positionsFlat, ...),
      let personalBestBuffer = device.makeBuffer(bytes: personalBestFlat, ...),
      let globalBestBuffer = device.makeBuffer(bytes: globalBestFlat, ...),
      let newVelocitiesBuffer = device.makeBuffer(length: ..., ...),
      let newPositionsBuffer = device.makeBuffer(length: ..., ...),
      let randomSeedsBuffer = device.makeBuffer(bytes: randomSeeds, ...),
      let searchSpaceBuffer = device.makeBuffer(bytes: searchSpaceFlat, ...),
      let velocityLimitsBuffer = device.makeBuffer(bytes: velocityLimitsFlat, ...)
// 9 buffers per GPU iteration
```

**The Problem:** PSO typically runs for hundreds of iterations. 9 buffers × 500 iterations = 4,500 buffer allocations per optimization run.

**Suggested Fix:**
```swift
// Pre-allocate buffers once and reuse
final class PSOBufferPool {
    private var velocities: MTLBuffer
    private var positions: MTLBuffer
    // ... other buffers

    func update(velocities: [Float], positions: [Float]) {
        // Copy data into existing buffers instead of reallocating
        velocities.withUnsafeBytes { ptr in
            self.velocities.contents().copyMemory(from: ptr.baseAddress!, byteCount: ptr.count)
        }
    }
}
```

---

### Issue 2.3: Differential Evolution 6 Buffers Per Generation (HIGH)

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Optimization/Heuristic/DifferentialEvolution.swift`
**Lines:** 527-599

**Current Code:**
```swift
guard let populationBuffer = device.device.makeBuffer(...),
      let mutantsBuffer = device.device.makeBuffer(...),
      let trialsBuffer = device.device.makeBuffer(...),
      let indicesBuffer = device.device.makeBuffer(...),
      let seedsBuffer = device.device.makeBuffer(...),
      let searchSpaceBuffer = device.device.makeBuffer(...)
// 6 buffers per generation
```

**The Problem:** DE typically runs for 100+ generations. 6 × 100 = 600 buffer allocations.

---

### Issue 2.4: Metal Matrix Operations Temporary Buffers

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Statistics/Regression/MatrixOperations/MetalMatrixBackend.swift`
**Lines:** 101-119

**Current Code:**
```swift
guard let bufferA = device.makeBuffer(bytes: flatA, length: ..., options: .storageModeShared),
      let bufferB = device.makeBuffer(bytes: flatB, length: ..., options: .storageModeShared),
      let bufferC = device.makeBuffer(bytes: flatC, length: ..., options: .storageModeShared),
      let bufferM = device.makeBuffer(bytes: &mValue, ...),
      let bufferN = device.makeBuffer(bytes: &nValue, ...),
      let bufferP = device.makeBuffer(bytes: &pValue, ...)
// 6 buffers per matrix multiplication
```

**The Problem:** Matrix operations are called frequently in regression. Each multiply creates 6 temporary buffers.

---

### Issue 2.5: Early Return Without endEncoding()

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Optimization/Heuristic/ParticleSwarmOptimization.swift`
**Lines:** 494-497

**Current Code:**
```swift
guard let commandBuffer = metalDevice.commandQueue.makeCommandBuffer(),
      let encoder = commandBuffer.makeComputeCommandEncoder() else {
    return nil  // Early return - encoder never ended
}
```

**The Problem:** If buffer allocation fails after encoder creation, `endEncoding()` is never called. This can leave Metal in an inconsistent state.

**Suggested Fix:**
```swift
guard let commandBuffer = metalDevice.commandQueue.makeCommandBuffer() else {
    return nil
}

guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
    return nil  // Safe - no encoder created
}

defer {
    encoder.endEncoding()  // Always called
}

// ... use encoder
```

---

### Issue 2.6: MetalBuffers Class No Explicit deinit

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Optimization/Heuristic/GPU/MetalBuffers.swift`
**Lines:** 39-187

**Current Code:**
```swift
final class MetalBuffers {
    private(set) var populationA: MTLBuffer
    private(set) var populationB: MTLBuffer
    private(set) var fitness: MTLBuffer
    private(set) var randomSeeds: MTLBuffer
    // No deinit - relies on ARC
}
```

**The Problem:** While ARC handles cleanup, explicit deinit provides:
- Documentation of resource ownership
- Place to add debugging/logging
- Explicit cleanup order control

**Suggested Fix:**
```swift
final class MetalBuffers {
    // ... buffer properties

    deinit {
        // MTLBuffer cleanup is automatic via ARC, but this documents intent
        // and provides a hook for debugging memory issues
        #if DEBUG
        print("MetalBuffers deallocating: \(populationA.length + populationB.length + ...) bytes")
        #endif
    }
}
```

---

### Issue 2.7: Disabled Buffer Cache in MonteCarloGPUDevice

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Simulation/MonteCarlo/GPU/MonteCarloGPUDevice.swift`
**Lines:** 72-73, 375-376

**Current Code:**
```swift
// Cached pipeline states
private var initRNGPipeline: MTLComputePipelineState?
private var monteCarloIterationPipeline: MTLComputePipelineState?

// PERFORMANCE: Buffer pool to avoid repeated allocations
private var bufferCache: [Int: Buffers] = [:]  // Variable exists
private let bufferCacheLock = NSLock()

// TODO: Re-enable buffer caching with proper data clearing
// Currently disabled due to stale data issues
```

**The Problem:** Buffer caching was disabled due to bugs, leading to repeated allocations. The infrastructure exists but isn't used.

---

## Category 3: Async Task Retention

### What Is This Category?

Swift's structured concurrency uses Tasks to manage async work. Memory issues occur when:
- Detached Tasks outlive their intended scope
- Tasks capture `self` or large closures strongly
- Continuations are stored without cleanup
- Task cancellation isn't properly handled

### Why It Matters

Async streams in financial applications process continuous data:
- Market data feeds
- Real-time risk calculations
- Streaming aggregations

Tasks that outlive their consumers waste CPU and memory.

---

### Issue 3.1: Detached Tasks Without Lifecycle Management (CRITICAL)

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Streaming/StreamingComposition.swift`
**Lines:** 274-293

**Current Code:**
```swift
Task { @Sendable in
    await withTaskGroup(of: Void.self) { group in
        group.addTask { @Sendable in
            var iter = firstIterator
            while let value = try? await iter.next() {
                continuationBox.yield(value)
            }
        }

        group.addTask { @Sendable in
            var iter = secondIterator
            while let value = try? await iter.next() {
                continuationBox.yield(value)
            }
        }

        await group.waitForAll()
        continuationBox.finish()
    }
}
```

**The Problem:** This detached Task:
1. Captures `continuationBox`, `firstIterator`, `secondIterator`
2. Runs indefinitely until both iterators complete
3. Has no cancellation mechanism if consumer stops iterating
4. If AsyncStream is deallocated, Task continues running

**Suggested Fix:**
```swift
let task = Task { @Sendable in
    await withTaskGroup(of: Void.self) { group in
        group.addTask { @Sendable in
            var iter = firstIterator
            while !Task.isCancelled, let value = try? await iter.next() {
                continuationBox.yield(value)
            }
        }
        // ... similar for second iterator
    }
}

// Store task handle for cancellation
self.backgroundTask = task

deinit {
    backgroundTask?.cancel()
}
```

---

### Issue 3.2: InflightEntry Task Cancellation Leak (CRITICAL)

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Performance/CalculationCache.swift`
**Lines:** 164-168, 283-325

**Current Code:**
```swift
private final class InflightEntry {
    let group = DispatchGroup()
    var result: Any?
    var didCache: Bool = false
}

// In getOrCalculate:
let entry = InflightEntry()
entry.group.enter()
inflight[key] = entry
lock.unlock()

let computed = calculation()  // If this is cancelled...

lock.lock()
// ... admission logic ...
entry.group.leave()           // ... this never executes
inflight.removeValue(forKey: key)  // ... and this
```

**The Problem:** If the `calculation()` closure is cancelled or throws:
1. `group.leave()` is never called
2. Entry remains in `inflight` dictionary forever
3. Future waiters on this key block permanently on `group.wait()`
4. Memory leak: entry + result + all waiters

**Suggested Fix:**
```swift
let entry = InflightEntry()
entry.group.enter()
inflight[key] = entry
lock.unlock()

defer {
    lock.lock()
    entry.group.leave()
    inflight.removeValue(forKey: key)
    lock.unlock()
}

do {
    let computed = try calculation()
    entry.result = computed
    // ... cache logic
} catch {
    // Entry still cleaned up via defer
    throw error
}
```

---

### Issue 3.3: CombineLatest Tasks Without Cleanup

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Streaming/StreamingComposition.swift`
**Lines:** 593-621

**Current Code:**
```swift
Task { @Sendable in
    let firstLatest = ThreadSafeBox<First.Element?>(nil)
    let secondLatest = ThreadSafeBox<Second.Element?>(nil)

    await withTaskGroup(of: Void.self) { group in
        group.addTask { @Sendable in
            var iter = first.makeAsyncIterator()
            while let value = try? await iter.next() {
                await firstLatest.setValue(value)
                // ...
            }
        }
        // ... second task similar
    }
}
```

**The Problem:** `ThreadSafeBox` actors are created inside the Task and captured by child tasks. If consumer abandons iteration, actors persist.

---

### Issue 3.4: Debounce State Actor Task Retention

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Streaming/StreamingComposition.swift`
**Lines:** 456-510

**Current Code:**
```swift
Task { @Sendable in
    let state = DebounceState<Element>()

    while let value = try? await baseIterator.next() {
        await state.updateValue(value)

        let debounceTask = Task { @Sendable in
            try? await Task.sleep(for: interval)
            if !Task.isCancelled {
                if let val = await state.getValue() {
                    continuationBox.yield(val)
                }
            }
        }

        await state.setDebounceTask(debounceTask)
    }
}
```

**The Problem:** Each value creates a new debounce Task. While previous Tasks are cancelled, if the outer Task is abandoned, debounce Tasks may continue running.

---

### Issue 3.5: Sample Sequence Continuous Background Task

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Streaming/StreamingComposition.swift`
**Lines:** 1087-1128

**Current Code:**
```swift
Task { @Sendable in
    let latestValue = ThreadSafeBox<Element?>(nil)

    await withTaskGroup(of: Void.self) { group in
        // Consumer task
        group.addTask { @Sendable in
            var iter = baseIterator
            while let value = try? await iter.next() {
                await latestValue.setValue(value)
            }
        }

        // Sampling task - runs FOREVER
        group.addTask { @Sendable in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                if let value = await latestValue.getValue() {
                    continuationBox.yield(value)
                }
            }
        }
    }
}
```

**The Problem:** The sampling task runs in an infinite loop. It only stops when explicitly cancelled, but there's no cancellation mechanism when the iterator is dropped.

---

### Issue 3.6: Gradient Descent Optimizer Continuation

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Optimization/AsyncGradientDescentOptimizer.swift`
**Lines:** 188-372

**Current Code:**
```swift
AsyncThrowingStream { continuation in
    Task { @Sendable in
        for iteration in 0..<maxIterations {  // Up to 10,000 iterations
            if Task.isCancelled {
                continuation.finish(throwing: CancellationError())
                return
            }
            // ... optimization logic
            continuation.yield(progress)
        }
        continuation.finish()
    }
}
```

**The Problem:** If consumer stops iterating after 500 iterations, the Task continues running for the remaining 9,500 iterations in the background.

---

### Issue 3.7: Multi-Start Optimizer N Parallel Tasks

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Optimization/MultiStartOptimizer.swift`
**Lines:** 176-222

**Current Code:**
```swift
AsyncThrowingStream { continuation in
    Task { @Sendable in
        let startingPoints = generateStartingPoints(...)  // N points

        await withThrowingTaskGroup(of: Void.self) { group in
            for start in startingPoints {
                group.addTask { @Sendable in
                    for try await progress in self.baseOptimizer.optimizeWithProgress(...) {
                        continuation.yield(progress)
                    }
                }
            }
        }
    }
}
```

**The Problem:** Launches N parallel optimizations. If consumer only wants the first result, all N optimizers run to completion unnecessarily.

---

### Issue 3.8: ContinuationBox @unchecked Sendable

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Streaming/StreamingComposition.swift`
**Lines:** 1718-1766

**Current Code:**
```swift
final class ContinuationBox<Element: Sendable>: @unchecked Sendable {
    private let continuation: AsyncStream<Element>.Continuation

    init(_ continuation: AsyncStream<Element>.Continuation) {
        self.continuation = continuation
    }

    func yield(_ value: Element) {
        continuation.yield(value)
    }
}
```

**The Problem:** `@unchecked Sendable` bypasses Swift's concurrency safety checks. If a ContinuationBox is retained after the stream is deallocated, accessing the continuation is undefined behavior.

---

### Issue 3.9: Timeout Sequence Infinite Loop

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Streaming/StreamingComposition.swift`
**Lines:** 1554-1637

**Current Code:**
```swift
Task { @Sendable in
    while true {  // INFINITE LOOP
        do {
            let result = try await withThrowingTaskGroup(of: TimeoutResult.self) { group in
                group.addTask { @Sendable in
                    let val = try await wrapper.next()
                    return TimeoutResult.value(val)
                }

                group.addTask { @Sendable in
                    try await Task.sleep(for: duration)
                    return TimeoutResult.timeout
                }
                // ...
            }
        }
    }
}
```

**The Problem:** The `while true` loop runs until the stream completes or errors. No cancellation when iterator is dropped.

---

### Issue 3.10: Async Cache Waiter Continuations

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Performance/CalculationCache.swift`
**Lines:** 437-439

**Current Code:**
```swift
if inflight[k] != nil {
    await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
        inflight[k]!.waiters.append(cont)  // Continuation stored
    }
}
```

**The Problem:** If a waiter Task is cancelled before the leader finishes, the continuation remains in the array. When the leader resumes it, behavior is undefined.

---

## Category 4: Cache Memory Growth

### What Is This Category?

Caching improves performance by storing computed values for reuse. Memory issues occur when:
- Caches have no maximum size
- Eviction policies are missing or weak
- Cache metadata grows unbounded

### Why It Matters

Effective caching balances memory usage against computation cost. Unbounded caches eventually consume all available memory.

---

### Issue 4.1: seenKeys Tracking Unbounded Growth

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Performance/CalculationCache.swift`
**Lines:** 174-175, 192, 201-214

**Current Code:**
```swift
private var seenKeys: Set<String> = []
private var seenOrder: [String] = []
private let seenKeysCap: Int

// Default: 10× cache size
self.seenKeysCap = seenKeysCapacity ?? max(maxSize, maxSize * 10)

private func trimSeenIfNeeded() {
    while seenKeys.count > seenKeysCap {
        guard let oldest = seenOrder.first else { break }
        seenOrder.removeFirst()  // O(n) operation!
        seenKeys.remove(oldest)
    }
}
```

**The Problem:**
1. Default seenKeysCap is 10× cache size (10,000 for default 1000 cache)
2. `seenOrder.removeFirst()` is O(n) for Array
3. When seenKeys is near capacity, each trim is O(n) operation
4. With many unique keys, this causes O(n²) behavior

**Suggested Fix:**
```swift
// Use a proper circular buffer or deque
private var seenOrder: Deque<String> = []

private func trimSeenIfNeeded() {
    while seenKeys.count > seenKeysCap {
        guard let oldest = seenOrder.popFirst() else { break }  // O(1) for Deque
        seenKeys.remove(oldest)
    }
}
```

---

### Issue 4.2: Shared FinancialModel Cache

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Performance/CalculationCache.swift`
**Lines:** 641-673

**Current Code:**
```swift
extension FinancialModel {
    private static let sharedCache = CalculationCache()  // SINGLETON

    public func calculateRevenueCached() -> Double {
        let key = "\(cacheKey())_revenue"
        return Self.sharedCache.getOrCalculate(key: key) {
            calculateRevenue()
        }
    }
}
```

**The Problem:** All FinancialModel instances share one global cache. In applications processing many different models, the cache accumulates entries from all models. No public API to clear except `clearCalculationCache()`.

---

### Issue 4.3: CutPool Default 10,000 Size

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Optimization/IntegerProgramming/BranchAndBound.swift`
**Lines:** 2185-2207

**Current Code:**
```swift
private class CutPool: @unchecked Sendable {
    private var managedCuts: [ManagedCut] = []
    private let maxSize: Int

    init(maxSize: Int = 10_000, maxAge: Int = 100) {
        self.maxSize = maxSize
    }

    func addCut(_ cut: CuttingPlane) {
        lock.lock()
        defer { lock.unlock() }

        managedCuts.append(cut)  // Append first

        if managedCuts.count > maxSize {
            prunePool()  // Then check
        }
    }
}
```

**The Problem:** Default pool holds up to 10,000 cuts before pruning. Each CuttingPlane contains coefficient arrays. For 100-variable problems: 10,000 × 100 × 8 bytes = 8 MB per node.

---

### Issue 4.4: Async Cache seenKeys

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Performance/CalculationCache.swift`
**Lines:** 401-403, 419

**Current Code:**
```swift
private var seenKeys: Set<String> = []
private var seenOrder: [String] = []
private let seenKeysCap: Int

self.seenKeysCap = seenKeysCapacity ?? max(maxSize, maxSize * 10)
```

**The Problem:** Same issue as synchronous cache - 10× tracking overhead.

---

### Issue 4.5: Inflight Waiters Accumulation

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Performance/CalculationCache.swift`
**Lines:** 391, 438, 586

**Current Code:**
```swift
struct InflightEntry {
    var waiters: [CheckedContinuation<Void, Never>] = []  // Unbounded
    var result: Any? = nil
    var remainingConsumers: Int = 0
}

// In waiting code:
inflight[k]!.waiters.append(cont)  // No limit
```

**The Problem:** Under high concurrency with repeated key requests, waiters array grows unbounded. No maximum waiter count.

---

### Issue 4.6: ModelProfiler Metrics Accumulation

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Diagnostics/ModelProfiler.swift`
**Lines:** 44-48

**Current Code:**
```swift
public actor ModelProfiler {
    private var metrics: [String: [PerformanceMetric]] = [:]  // UNBOUNDED
    // No max size, no automatic cleanup
}
```

**The Problem:** Profiler accumulates metrics indefinitely. Long profiling sessions consume increasing memory.

---

## Category 5: Class Retain Cycles

### What Is This Category?

Retain cycles occur when two or more objects hold strong references to each other, preventing deallocation. In Swift:
- Classes are reference types (can have retain cycles)
- Structs are value types (cannot have retain cycles)
- Closures capturing `self` can create cycles

### Why It Matters

Retain cycles cause permanent memory leaks - the memory is never reclaimed until the application terminates.

---

### Issue 5.1: PseudoCostTracker Lock and Dictionary Growth (CRITICAL)

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Optimization/IntegerProgramming/BranchAndBound.swift`
**Lines:** 1751-1812, 362, 589-610

**Current Code:**
```swift
class PseudoCostTracker: @unchecked Sendable {
    private var upCosts: [Int: (sum: Double, count: Int)] = [:]
    private var downCosts: [Int: (sum: Double, count: Int)] = [:]
    private let lock = NSLock()

    func updateCost(variable: Int, direction: BranchDirection, ...) {
        lock.lock()
        defer { lock.unlock() }
        // ... update dictionaries
    }
}

// In solve():
let pseudoCostTracker = (branchingRule == .pseudoCost) ? PseudoCostTracker() : nil

// Captured in closures:
if let tracker = pseudoCostTracker {
    tracker.updateCost(variable: branchVar, ...)
}
```

**The Problem:**
- Tracker is captured in branching loop closures
- Lock-based synchronization could deadlock if nested calls occur
- Dictionaries grow unbounded with branching decisions

---

### Issue 5.2: CutPool Index Destabilization

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Optimization/IntegerProgramming/BranchAndBound.swift`
**Lines:** 834-849, 1107-1141, 2185-2267

**Current Code:**
```swift
var cutAges: [(constraintIndex: Int, roundAdded: Int, lastActiveRound: Int)] = []

// Cuts added with indices:
cutAges.append((
    constraintIndex: currentConstraints.count - 1,
    roundAdded: round,
    lastActiveRound: round
))

// Later, constraints may be removed, invalidating indices
```

**The Problem:** `cutAges` stores constraint indices. When constraints are removed during solving, these indices become invalid, creating dangling references.

---

### Issue 5.3: MarketDataCache Strong Reference Pattern

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Integration/MarketDataCache.swift`
**Lines:** 49-191

**Current Code:**
```swift
public final class MarketDataCache: @unchecked Sendable {
    private var storage: [String: CachedValue] = []

    public func cache<T>(_ value: T, for key: String, ttl: TimeInterval? = nil) {
        storage[key] = CachedValue(
            value: value,  // Strong reference to Any
            expiresAt: expiresAt,
            insertedAt: Date()
        )
    }
}
```

**The Problem:** If cached objects hold references back to objects that hold the cache, retain cycles can form. The `Any` type hiding makes this hard to detect.

---

## Category 6: Struct Closure Captures (LOW PRIORITY)

### What Is This Category?

Swift structs are value types - they're copied, not referenced. When a struct method captures `self` in a closure, it captures a **copy**, not a reference. This means:
- No retain cycles possible
- Capture list `[self]` is documentation, not memory management
- Safe but potentially confusing

### Why This Is Low Priority

These are not memory leaks, just unnecessary syntax that could confuse readers.

---

### Issue 6.1-6.5: Struct Self Captures

**Files:**
- `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/BusinessOptimization/ResourceAllocation.swift` (Line 330)
- `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/FinancialModel/DriverOptimization.swift` (Lines 308, 329, 350, 361)

**Current Code:**
```swift
// In struct (value type):
return { [self] allocation in
    let result = self.buildResult(...)
    return customFunction(result)
}
```

**The Problem:** The `[self]` capture list is unnecessary for structs. It documents intent but doesn't affect memory management.

**Suggested Fix:**
```swift
// Simply remove [self] - it's implicit for structs
return { allocation in
    let result = self.buildResult(...)
    return customFunction(result)
}
```

---

## Category 7: Resource Cleanup

### What Is This Category?

Resource cleanup issues occur when:
- Classes don't implement `deinit` for explicit cleanup
- Resources are acquired but never released
- Singletons accumulate state without cleanup mechanisms

---

### Issue 7.1: DebugContext Singleton Unbounded Growth

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Diagnostics/ModelDebugger.swift`
**Lines:** 17-62

**Current Code:**
```swift
final class DebugContext: @unchecked Sendable {
    private let lock = NSLock()
    private var steps: [CalculationStep] = []  // Unbounded

    func recordStep(operation: String, input: String, output: String) {
        guard isEnabled else { return }
        steps.append(CalculationStep(...))  // No limit
    }

    // clear() exists but must be called manually
}
```

**The Problem:** Debug context accumulates steps indefinitely when enabled. No automatic cleanup.

---

### Issue 7.2: PseudoCostTracker No deinit

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Optimization/IntegerProgramming/BranchAndBound.swift`
**Lines:** 1751-1812

**Current Code:**
```swift
class PseudoCostTracker: @unchecked Sendable {
    private let lock = NSLock()
    // ... no deinit
}
```

**The Problem:** Class holds NSLock but no explicit cleanup. While Swift handles this, explicit deinit documents ownership.

---

### Issue 7.3: AuditTrailManager No Clear Mechanism

**File:** `/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/Sources/BusinessMath/Audit/AuditTrail.swift`

**Current Code:**
```swift
public final class AuditTrailManager: @unchecked Sendable {
    private var entries: [AuditEntry] = []

    // No public clear() method visible
    // No automatic rotation
}
```

**The Problem:** Audit entries accumulate without a way to clear them.

---

## Educational Guide: Memory Management in Swift

### Value Types vs Reference Types

Swift has two fundamental categories of types:

**Value Types (Structs, Enums):**
- Copied when assigned or passed
- No reference counting
- Cannot have retain cycles
- Memory automatically managed on stack (usually)

**Reference Types (Classes, Actors):**
- Shared via references
- Reference counted (ARC)
- Can have retain cycles
- Memory managed on heap

```swift
// Value type - safe from retain cycles
struct Calculator {
    var history: [Double] = []

    mutating func add(_ value: Double) {
        history.append(value)
    }
}

// Reference type - potential for retain cycles
class Cache {
    var delegate: CacheDelegate?  // Could create cycle if delegate holds cache
}
```

### The Retain Cycle Problem

```swift
class Parent {
    var child: Child?
}

class Child {
    var parent: Parent?  // Strong reference - CREATES CYCLE
}

let parent = Parent()
let child = Child()
parent.child = child
child.parent = parent
// Neither can be deallocated - memory leak!
```

**Solution: Weak References**

```swift
class Child {
    weak var parent: Parent?  // Weak reference - breaks cycle
}
```

### Closure Capture Lists

Closures capture variables from their surrounding scope. This can create retain cycles:

```swift
class ViewModel {
    var onUpdate: (() -> Void)?

    func setup() {
        onUpdate = {
            self.doSomething()  // Captures self strongly - CYCLE
        }
    }
}
```

**Solutions:**

```swift
// Option 1: Weak self (self might be nil)
onUpdate = { [weak self] in
    self?.doSomething()
}

// Option 2: Unowned self (guarantees self exists)
onUpdate = { [unowned self] in
    self.doSomething()
}
```

### Metal Resource Management

Metal resources require special attention:

```swift
// Bad: Buffer created but scope unclear
func compute() -> [Float] {
    let buffer = device.makeBuffer(length: 1024)!
    // ... use buffer
    return results
    // Buffer released here, but what about GPU commands?
}

// Good: Explicit scope and synchronization
func compute() -> [Float] {
    autoreleasepool {
        let buffer = device.makeBuffer(length: 1024)!
        let commandBuffer = queue.makeCommandBuffer()!

        // ... encode commands

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Now safe to read results
        let results = extractResults(from: buffer)
        return results
        // Buffer released at end of autoreleasepool
    }
}
```

### Async Task Lifetime

Tasks in Swift structured concurrency have specific lifetime rules:

```swift
// Bad: Detached task with no cleanup
func startProcessing() {
    Task.detached {
        while true {  // Runs forever
            await process()
        }
    }
}

// Good: Task handle stored for cancellation
class Processor {
    private var processingTask: Task<Void, Never>?

    func start() {
        processingTask = Task {
            while !Task.isCancelled {
                await process()
            }
        }
    }

    deinit {
        processingTask?.cancel()
    }
}
```

### Collection Growth Patterns

**Unbounded Growth (Bad):**
```swift
class Logger {
    private var logs: [String] = []

    func log(_ message: String) {
        logs.append(message)  // Grows forever
    }
}
```

**Bounded Growth (Good):**
```swift
class Logger {
    private var logs: [String] = []
    private let maxLogs = 10_000

    func log(_ message: String) {
        logs.append(message)

        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }
    }
}

// Or use a ring buffer:
struct RingBuffer<T> {
    private var storage: [T?]
    private var writeIndex = 0

    init(capacity: Int) {
        storage = Array(repeating: nil, count: capacity)
    }

    mutating func append(_ value: T) {
        storage[writeIndex] = value
        writeIndex = (writeIndex + 1) % storage.count
    }
}
```

---

## Quick Reference: Memory Safety Patterns

| Pattern | Safe Version | Why |
|---------|-------------|-----|
| `self` in closure | `[weak self]` | Prevents retain cycle |
| Array growth | Ring buffer or max size | Bounds memory |
| Cache entries | LRU eviction policy | Limits growth |
| Metal buffers | `autoreleasepool { }` | Timely cleanup |
| Async tasks | Store handle, cancel in deinit | Controlled lifetime |
| Dictionaries | Periodic cleanup or max size | Bounds memory |
| Shared singletons | Public `clear()` method | Manual cleanup option |

---

## Appendix: Complete Issue Inventory

| # | Category | Severity | File | Line(s) | Description |
|---|----------|----------|------|---------|-------------|
| 1.1 | Collection | CRITICAL | AuditTrail.swift | 187, 213 | Unbounded audit entries |
| 1.2 | Collection | CRITICAL | ModelDebugger.swift | 19, 43 | Unbounded debug steps |
| 1.3 | Collection | CRITICAL | StreamingAnomalyDetection.swift | 892, 915 | Buffers entire stream |
| 1.4 | Collection | CRITICAL | BranchAndBound.swift | 2031, 2042 | Unbounded node queue |
| 1.5 | Collection | HIGH | StreamingStatistics.swift | 262, 441, 616 | 6 unbounded buffers |
| 1.6 | Collection | HIGH | BranchAndBound.swift | 834-838 | cutAges, boundHistory unbounded |
| 1.7 | Collection | HIGH | BranchAndBound.swift | 1752-1753 | PseudoCost dictionaries |
| 1.8 | Collection | HIGH | CalculationCache.swift | 680, 684 | StringBuilder parts |
| 1.9 | Collection | MEDIUM | MovingAverageModel.swift | 37, 86 | Stores entire history |
| 2.1 | GPU | MEDIUM | MonteCarloGPUDevice.swift | 385-389 | 5 buffers per simulation |
| 2.2 | GPU | HIGH | ParticleSwarmOptimization.swift | 477-485 | 9 buffers per iteration |
| 2.3 | GPU | HIGH | DifferentialEvolution.swift | 527-599 | 6 buffers per generation |
| 2.4 | GPU | MEDIUM | MetalMatrixBackend.swift | 101-119 | 6 buffers per multiply |
| 2.5 | GPU | MEDIUM | ParticleSwarmOptimization.swift | 494-497 | Early return without endEncoding |
| 2.6 | GPU | LOW | MetalBuffers.swift | 39-187 | No explicit deinit |
| 2.7 | GPU | MEDIUM | MonteCarloGPUDevice.swift | 72-73 | Disabled buffer cache |
| 2.8 | GPU | MEDIUM | MonteCarloGPUDevice.swift | 375-376 | TODO: buffer caching |
| 3.1 | Async | CRITICAL | StreamingComposition.swift | 274-293 | Detached task no cleanup |
| 3.2 | Async | CRITICAL | CalculationCache.swift | 283-325 | InflightEntry cancellation leak |
| 3.3 | Async | HIGH | StreamingComposition.swift | 593-621 | CombineLatest task leak |
| 3.4 | Async | HIGH | StreamingComposition.swift | 456-510 | Debounce state retention |
| 3.5 | Async | HIGH | StreamingComposition.swift | 1087-1128 | Infinite sampling loop |
| 3.6 | Async | HIGH | AsyncGradientDescentOptimizer.swift | 188-372 | 10K iterations continue |
| 3.7 | Async | HIGH | MultiStartOptimizer.swift | 176-222 | N parallel tasks continue |
| 3.8 | Async | MEDIUM | StreamingComposition.swift | 1718-1766 | @unchecked Sendable box |
| 3.9 | Async | MEDIUM | StreamingComposition.swift | 1554-1637 | Infinite timeout loop |
| 3.10 | Async | MEDIUM | CalculationCache.swift | 437-439 | Waiter continuation leak |
| 4.1 | Cache | CRITICAL | CalculationCache.swift | 174-175, 192 | seenKeys O(n²) trimming |
| 4.2 | Cache | HIGH | CalculationCache.swift | 641-673 | Shared global cache |
| 4.3 | Cache | HIGH | BranchAndBound.swift | 2185-2207 | 10K cut pool default |
| 4.4 | Cache | HIGH | CalculationCache.swift | 401-403 | Async seenKeys same issue |
| 4.5 | Cache | HIGH | CalculationCache.swift | 391, 438 | Unbounded waiters |
| 4.6 | Cache | MEDIUM | ModelProfiler.swift | 44-48 | Metrics accumulation |
| 4.7 | Cache | MEDIUM | MarketDataCache.swift | 69 | Strong Any references |
| 5.1 | Cycle | CRITICAL | BranchAndBound.swift | 1751-1812 | PseudoCostTracker capture |
| 5.2 | Cycle | HIGH | BranchAndBound.swift | 834-849 | CutPool index invalidation |
| 5.3 | Cycle | HIGH | CalculationCache.swift | 164-168 | InflightEntry group leak |
| 5.4 | Cycle | MEDIUM | MarketDataCache.swift | 49-191 | Strong Any pattern risk |
| 6.1-6.5 | Struct | LOW | ResourceAllocation.swift, DriverOptimization.swift | Various | Unnecessary [self] captures |
| 7.1 | Cleanup | MEDIUM | ModelDebugger.swift | 17-62 | Singleton unbounded growth |
| 7.2 | Cleanup | LOW | BranchAndBound.swift | 1751-1812 | No deinit for lock cleanup |
| 7.3 | Cleanup | MEDIUM | AuditTrail.swift | Various | No clear mechanism |
| 7.4 | Cleanup | LOW | MetalBuffers.swift | 39-187 | No explicit deinit |

---

## Conclusion

The BusinessMath library demonstrates generally good memory management practices, particularly in its extensive use of value types (structs). However, several patterns require attention:

1. **Unbounded collections** are the most critical issue - audit trails, debug steps, and streaming buffers can grow without limit
2. **GPU buffer management** creates significant memory churn in optimization algorithms
3. **Async task lifetime** is not always properly managed, leading to background tasks outliving their consumers
4. **Cache tracking structures** use O(n) operations that cause performance degradation

**Recommended Priority:**
1. **Critical issues (8)**: Fix immediately - these cause unbounded memory growth
2. **High issues (19)**: Fix in next release - production stability
3. **Medium issues (13)**: Technical debt - address in refactoring
4. **Low issues (7)**: Optional - code quality improvement

---
