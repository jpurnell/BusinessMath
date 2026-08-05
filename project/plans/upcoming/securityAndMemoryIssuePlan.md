# BusinessMath Security & Memory Issue Implementation Plan

**Created:** March 9, 2026
**Sources:** Security Audit + Memory Audit v2.0.0-beta.6
**Combined Issues:** 104 (67 security + 47 memory - 10 overlapping = 104 unique)
**Estimated Phases:** 10

---

## How to Use This Document

This plan merges the security and memory audits into a single implementation roadmap. Issues are organized by:
1. **Criticality** - Fix the most dangerous issues first
2. **Dependency** - Some fixes require shared infrastructure
3. **Locality** - Related fixes in the same file are grouped together

Work through phases in order. Check off items as completed.

---

## Quick Reference: Issue Categories

| Category | Source | Count | What Goes Wrong |
|----------|--------|-------|-----------------|
| Force Unwraps | Security | 25 | App crashes immediately |
| Division by Zero | Security | 16 | Returns infinity/NaN or crashes |
| Numeric Overflow | Security | 10 | Numbers wrap around incorrectly |
| Unbounded Collections | Memory | 9 | Memory grows until exhaustion |
| GPU Buffer Leaks | Memory | 8 | GPU memory pressure/slowdown |
| Async Task Retention | Memory | 10 | Background tasks never stop |
| Cache Growth | Memory | 7 | Caches consume all memory |
| Iteration Limits | Security | 7 | App freezes/hangs |
| Randomness | Security | 8 | Predictable "random" results |
| Retain Cycles | Memory | 4 | Permanent memory leaks |
| Resource Cleanup | Memory | 4 | Resources never released |

**Note:** ~10 issues appear in both audits (marked with ⚡). These are counted once but tagged for both concerns.

---

## Pre-Implementation Setup

### Phase 0: Shared Infrastructure

Before fixing individual issues, create reusable components.

#### 0.1 Error Types

**EXISTING FILE:** `Sources/BusinessMath/Error Handling/BusinessMathError.swift`

The existing `BusinessMathError` enum already provides most needed cases:
- ✅ `invalidInput(message:value:expectedRange:)` - for type mismatches, missing params
- ✅ `divisionByZero(context:)` - exact match
- ✅ `calculationFailed(operation:reason:suggestions:)` - for convergence failures
- ✅ `numericalInstability(message:suggestions:)` - exact match
- ✅ `insufficientData(required:actual:context:)` - for minimum sample sizes
- ✅ `mismatchedDimensions(message:expected:actual:)` - for array size issues
- ✅ `outOfRange(value:min:max:context:)` - for boundary violations

**ADD only these 2 new cases:**

```
[ ] FILE: Sources/BusinessMath/Error Handling/BusinessMathError.swift

Add to enum (in appropriate section):
    // MARK: - Resource Errors (E400-E499)

    /// Resource limit exceeded (iterations, memory, etc.)
    case resourceExhausted(resource: String, limit: Int, context: String)

    /// Memory limit exceeded for collection
    case collectionLimitExceeded(collection: String, limit: Int, context: String)

Add to errorDescription:
    case .resourceExhausted(let resource, let limit, let context):
        return "\(resource) limit exceeded (\(limit)) in \(context)"

    case .collectionLimitExceeded(let collection, let limit, let context):
        return "\(collection) exceeded maximum size (\(limit)) in \(context)"

Add to recoverySuggestion:
    case .resourceExhausted:
        return "Consider using smaller problem sizes or adjusting algorithm parameters"

    case .collectionLimitExceeded:
        return "The collection has grown too large. Consider clearing old data or using streaming processing."

Add to code:
    case .resourceExhausted: return "E400"
    case .collectionLimitExceeded: return "E401"
```

#### 0.2 Ring Buffer Implementation

Many issues require replacing unbounded arrays with fixed-size ring buffers.

```
[ ] FILE: Sources/BusinessMath/Core/Collections/RingBuffer.swift

Create generic RingBuffer<T> with:
- init(capacity: Int)
- mutating func append(_ element: T)
- var count: Int
- subscript(index: Int) -> T
- func toArray() -> [T]
- var first: T?
- var last: T?
```

#### 0.3 Deque Implementation (or import Swift Collections)

```
[ ] OPTION A: Add swift-collections package dependency for Deque<T>
[ ] OPTION B: Create minimal Deque implementation for O(1) removeFirst()
```

---

## Phase 1: Critical Security Issues (5 issues)

These are **active bugs** producing wrong answers or guaranteed crashes.

### 1.1 Integer Division Bug [SILENT BUG]

```
[ ] FILE: Sources/BusinessMath/Statistics/Probability Distribution/standardErrorProbabilistic.swift
    LINE: 58

    FIND:    if T(n/total) <= T(Int(5) / Int(100))
    REPLACE: if T(n/total) <= T(5) / T(100)

    TEST: Write regression test comparing old vs new behavior
```

### 1.2 Fisher's Z Boundary [CRASH]

```
[ ] FILE: Sources/BusinessMath/Statistics/Probability Distribution/fisherR.swift
    LINE: 28

    ADD guard before calculation:
      guard r > T(-1) && r < T(1) else {
          throw BusinessMathError.invalidInput(
              message: "Fisher's Z requires correlation strictly between -1 and 1, got \(r)"
          )
      }

    UPDATE: Function signature → throwing
    UPDATE: All call sites must handle throw
```

### 1.3 Weak RNG Deprecation [PREDICTABILITY]

```
[ ] FILE: Sources/BusinessMath/Optimization/Heuristic/GeneticAlgorithm.swift
    LINES: 788-800

    ADD deprecation warning:
      @available(*, deprecated, message: "For testing only - not suitable for production")
```

### 1.4 Random Normalization Bug [WRONG RANGE]

```
[ ] FILE: Sources/BusinessMath/Optimization/Heuristic/SimulatedAnnealing.swift
    LINE: 239
    FIND:    Double(rng.next() >> 32) / Double(UInt32.max)
    REPLACE: Double(rng.next() >> 32) / Double(1 << 32)

[ ] FILE: Sources/BusinessMath/Optimization/Heuristic/GeneticAlgorithm.swift
    LINES: 322-323, 506, 514
    APPLY SAME FIX
```

### 1.5 Obfuscated Bernoulli Code [CONFUSING]

```
[ ] FILE: Sources/BusinessMath/Statistics/Probability Distribution/bernoulliTrial.swift
    LINE: 29
    FIND:    if T(Int(Double.random(in: 0...1) * 1000000000 / 1000000000)) < p
    REPLACE: if Double.random(in: 0..<1) < Double(p)
```

---

## Phase 2: Critical Memory Issues (8 issues)

These cause **unbounded memory growth** in production.

### 2.1 Audit Trail Entry Accumulation ⚡

```
[ ] FILE: Sources/BusinessMath/Audit/AuditTrail.swift
    LINES: 187, 213

    ADD size limiting:
      private let maxEntries: Int = 100_000

      func record(_ entry: AuditEntry) {
          lock.lock()
          defer { lock.unlock() }
          entries.append(entry)
          if entries.count > maxEntries {
              entries.removeFirst(entries.count - maxEntries)
          }
      }

    OR: Replace with RingBuffer<AuditEntry>

    ALSO ADD: Public clear() method for manual cleanup
```

### 2.2 Debug Steps Accumulation ⚡

```
[ ] FILE: Sources/BusinessMath/Diagnostics/ModelDebugger.swift
    LINES: 19, 43-48

    ADD size limiting:
      private let maxSteps: Int = 10_000

      if steps.count >= maxSteps {
          steps.removeFirst()
      }
```

### 2.3 Streaming Anomaly Detection Buffers Entire Stream

```
[ ] FILE: Sources/BusinessMath/Streaming/StreamingAnomalyDetection.swift
    LINES: 892, 894, 912-916

    REFACTOR: Change from buffering entire stream to windowed processing

    REPLACE:
      private var allValues: [Double] = []
    WITH:
      private var window: RingBuffer<Double>
      private let windowSize: Int = 10_000

    UPDATE: Binary segmentation to work on rolling window
```

### 2.4 Branch-and-Bound Node Queue ⚡

```
[ ] FILE: Sources/BusinessMath/Optimization/IntegerProgramming/BranchAndBound.swift
    LINES: 2031, 2041-2043

    ADD pruning:
      private let maxNodes: Int = 100_000

      mutating func insert(_ node: BranchNode<V>) {
          heap.append(node)
          siftUp(from: heap.count - 1)
          if heap.count > maxNodes {
              pruneWorstNodes()
          }
      }
```

### 2.5 Streaming Statistics Buffers (6 instances)

```
[ ] FILE: Sources/BusinessMath/Streaming/StreamingStatistics.swift
    LINES: 262, 441, 616, 707, 806, 1095

    REPLACE all 6 unbounded buffers with RingBuffer:
      private var buffer: RingBuffer<Double>

      init(windowSize: Int = 1000) {
          self.buffer = RingBuffer(capacity: windowSize)
      }
```

### 2.6 InflightEntry Task Cancellation Leak

```
[ ] FILE: Sources/BusinessMath/Performance/CalculationCache.swift
    LINES: 164-168, 283-325

    WRAP calculation in defer for cleanup:
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
      } catch {
          throw error  // defer still runs
      }
```

### 2.7 Detached Tasks Without Lifecycle Management

```
[ ] FILE: Sources/BusinessMath/Streaming/StreamingComposition.swift
    LINES: 274-293

    STORE task handle for cancellation:
      private var backgroundTask: Task<Void, Never>?

      // In init or setup:
      backgroundTask = Task { @Sendable in
          await withTaskGroup(of: Void.self) { group in
              group.addTask { @Sendable in
                  while !Task.isCancelled, let value = try? await iter.next() {
                      continuationBox.yield(value)
                  }
              }
          }
      }

      deinit {
          backgroundTask?.cancel()
      }
```

### 2.8 seenKeys O(n²) Trimming

```
[ ] FILE: Sources/BusinessMath/Performance/CalculationCache.swift
    LINES: 174-175, 192, 201-214

    REPLACE Array with Deque:
      private var seenOrder: Deque<String> = []

      private func trimSeenIfNeeded() {
          while seenKeys.count > seenKeysCap {
              guard let oldest = seenOrder.popFirst() else { break }  // O(1)
              seenKeys.remove(oldest)
          }
      }
```

---

## Phase 3: Division by Zero (16 issues)

### 3.1 Correlation Coefficients

```
[ ] FILE: Sources/BusinessMath/Statistics/Descriptors/Covariance and Correlation/correlation coefficient/sample correlation coefficient.swift
    LINE: 53

    ADD guard:
      let denominator = T.sqrt(xDenom) * T.sqrt(yDenom)
      guard denominator > T.ulpOfOne else {
          throw BusinessMathError.undefinedStatistic(
              message: "Correlation undefined: one or both variables have zero variance"
          )
      }
      return numerator / denominator

[ ] FILE: Sources/BusinessMath/Statistics/Descriptors/Covariance and Correlation/correlation coefficient/population correlation coefficient.swift
    LINE: 43
    APPLY SAME PATTERN
```

### 3.2 Contraharmonic Mean

```
[ ] FILE: Sources/BusinessMath/Statistics/Descriptors/Central Tendency/contraharmonicMean.swift
    LINES: 33, 55

    ADD zero-sum guards to both versions
```

### 3.3 Logarithmic Mean

```
[ ] FILE: Sources/BusinessMath/Statistics/Descriptors/Central Tendency/logarithmicMean.swift
    LINE: 34

    ADD:
      guard x > T.zero && y > T.zero else {
          throw BusinessMathError.invalidInput(message: "Logarithmic mean requires positive values")
      }
      // Handle x ≈ y case
      if abs(x - y) < T.ulpOfOne * max(abs(x), abs(y)) * T(100) {
          return (x + y) / T(2)
      }
```

### 3.4 Harmonic Mean

```
[ ] FILE: Sources/BusinessMath/Statistics/Descriptors/Central Tendency/harmonicMean.swift
    LINE: 32
    ADD: Reject arrays containing zero
```

### 3.5 Coefficient of Skewness

```
[ ] FILE: Sources/BusinessMath/Statistics/Descriptors/Skewness/cSkew.swift
    LINE: 36
    ADD: Guard against zero standard deviation
```

### 3.6 Financial Ratios (3 files)

```
[ ] FILE: Sources/BusinessMath/Ratios/CurrentRatio.swift
    LINES: 24-27
    CHANGE: Return Result<T, RatioError> instead of misleading zero

[ ] FILE: Sources/BusinessMath/Ratios/QuickRatio.swift
    LINES: 28-32
    APPLY SAME PATTERN

[ ] FILE: Sources/BusinessMath/Ratios/DebtToEquity.swift
    LINES: 24-28
    APPLY SAME PATTERN
```

### 3.7 Working Capital Turnover

```
[ ] FILE: Sources/BusinessMath/Financial Statements/BalanceSheet.swift
    LINES: 710, 716
    ADD: Guard against zero/negative working capital
```

### 3.8 T-Distribution Variance

```
[ ] FILE: Sources/BusinessMath/Statistics/Descriptors/Dispersion Around the Mean/variance/t-distribution.swift
    LINE: 40
    ADD:
      guard values.count > 3 else {
          throw BusinessMathError.insufficientData(
              message: "T-distribution variance requires at least 4 values"
          )
      }
```

### 3.9 Weighted Average fatalError

```
[ ] FILE: Sources/BusinessMath/Statistics/Descriptors/Central Tendency/weightedAverage.swift
    LINE: 48
    CHANGE: fatalError → throw BusinessMathError.divisionByZero
```

---

## Phase 4: Force Unwraps & Type Safety (25 issues)

### 4.1-4.15 Force Unwrap Fixes

See detailed list in security audit. Key files:

```
[ ] percentileLocation.swift (lines 37-38)
[ ] descriptives.swift (line 63)
[ ] mode.swift (line 18)
[ ] DebtCovenants.swift (lines 409, 484, 489, 501)
[ ] SimulatedAnnealing.swift (lines 236, 266)
[ ] GeneticAlgorithm.swift (lines 559, 569, 631-632, 654)
[ ] ParticleSwarmOptimization.swift (lines 432-434, 443, 450, 460, 562-563)
[ ] DifferentialEvolution.swift (lines 520, 588-589, 665)
[ ] BranchAndBound.swift (lines 329, 338, 344, 348, 429, 453, 499, 541, 628, 662)
[ ] StandardTemplates.swift (lines 307-310, 444-447)
[ ] VectorSpace.swift (line 1022)
[ ] MultiPeriodOptimizer.swift (lines 37, 40, 374)
[ ] UncertaintySet.swift (line 330)
[ ] Scenario.swift (line 194)
[ ] SimplexSolver.swift (lines 539, 555, 568)
```

**Pattern for all:**
```swift
// FIND:    value as! Type
// REPLACE: guard let typed = value as? Type else { throw ... }

// FIND:    array.first!
// REPLACE: guard let first = array.first else { throw ... }
```

---

## Phase 5: GPU Buffer Management (8 issues)

### 5.1 Monte Carlo GPU Buffers

```
[ ] FILE: Sources/BusinessMath/Simulation/MonteCarlo/GPU/MonteCarloGPUDevice.swift
    LINES: 385-389

    WRAP in autoreleasepool:
      autoreleasepool {
          guard let rngStates = device.makeBuffer(...) else { return nil }
          // ... other buffers
          let result = executeKernel(...)
          return result
      }
```

### 5.2 Particle Swarm 9 Buffers Per Iteration

```
[ ] FILE: Sources/BusinessMath/Optimization/Heuristic/ParticleSwarmOptimization.swift
    LINES: 477-485

    REFACTOR to buffer pool:
      final class PSOBufferPool {
          private var velocities: MTLBuffer
          private var positions: MTLBuffer
          // Pre-allocated, reused each iteration

          func update(data: [Float]) {
              // Copy into existing buffer
          }
      }
```

### 5.3 Differential Evolution 6 Buffers Per Generation

```
[ ] FILE: Sources/BusinessMath/Optimization/Heuristic/DifferentialEvolution.swift
    LINES: 527-599
    APPLY SAME buffer pool pattern
```

### 5.4 Metal Matrix Operations

```
[ ] FILE: Sources/BusinessMath/Statistics/Regression/MatrixOperations/MetalMatrixBackend.swift
    LINES: 101-119
    APPLY autoreleasepool pattern
```

### 5.5 Early Return Without endEncoding

```
[ ] FILE: Sources/BusinessMath/Optimization/Heuristic/ParticleSwarmOptimization.swift
    LINES: 494-497

    ADD defer:
      guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
          return nil
      }
      defer { encoder.endEncoding() }
```

### 5.6 MetalBuffers deinit

```
[ ] FILE: Sources/BusinessMath/Optimization/Heuristic/GPU/MetalBuffers.swift
    LINES: 39-187

    ADD explicit deinit:
      deinit {
          #if DEBUG
          print("MetalBuffers deallocating")
          #endif
      }
```

### 5.7-5.8 Re-enable Buffer Caching

```
[ ] FILE: Sources/BusinessMath/Simulation/MonteCarlo/GPU/MonteCarloGPUDevice.swift
    LINES: 72-73, 375-376

    TODO: Investigate and fix buffer caching data staleness issue
    Then re-enable caching for performance
```

---

## Phase 6: Async Task Lifetime (10 issues)

### 6.1 CombineLatest Tasks

```
[ ] FILE: Sources/BusinessMath/Streaming/StreamingComposition.swift
    LINES: 593-621

    ADD cancellation checking:
      while !Task.isCancelled, let value = try? await iter.next()

    STORE task handle for cleanup
```

### 6.2 Debounce State Actor

```
[ ] FILE: Sources/BusinessMath/Streaming/StreamingComposition.swift
    LINES: 456-510

    ENSURE debounce tasks cancelled when outer task cancelled
```

### 6.3 Sample Sequence Infinite Loop

```
[ ] FILE: Sources/BusinessMath/Streaming/StreamingComposition.swift
    LINES: 1087-1128

    ADD cancellation:
      while !Task.isCancelled {
          try? await Task.sleep(for: interval)
          // ...
      }
```

### 6.4 Gradient Descent Optimizer

```
[ ] FILE: Sources/BusinessMath/Optimization/AsyncGradientDescentOptimizer.swift
    LINES: 188-372

    CHECK cancellation more frequently:
      for iteration in 0..<maxIterations {
          if Task.isCancelled {
              continuation.finish()
              return
          }
          // Check after each major computation too
      }
```

### 6.5 Multi-Start Optimizer

```
[ ] FILE: Sources/BusinessMath/Optimization/MultiStartOptimizer.swift
    LINES: 176-222

    ADD early termination when first result found (if desired)
    OR add cancellation support for all parallel tasks
```

### 6.6 ContinuationBox @unchecked Sendable

```
[ ] FILE: Sources/BusinessMath/Streaming/StreamingComposition.swift
    LINES: 1718-1766

    REVIEW: Consider safer pattern or document risks
```

### 6.7 Timeout Sequence Infinite Loop

```
[ ] FILE: Sources/BusinessMath/Streaming/StreamingComposition.swift
    LINES: 1554-1637

    ADD cancellation check in while true loop
```

### 6.8 Async Cache Waiter Continuations

```
[ ] FILE: Sources/BusinessMath/Performance/CalculationCache.swift
    LINES: 437-439

    ADD: Handle cancelled waiters gracefully
```

---

## Phase 7: Numeric Precision & Overflow (10 issues)

### 7.1 Integer Overflow in SimulatedAnnealing

```
[ ] FILE: Sources/BusinessMath/Optimization/Heuristic/SimulatedAnnealing.swift
    LINE: 236

    ADD overflow check:
      guard abs(deltaEDouble) < Double(Int.max) / 1_000_000 else {
          // Use Double arithmetic instead
      }
```

### 7.2 Integer Overflow in PSO

```
[ ] FILE: Sources/BusinessMath/Optimization/Heuristic/ParticleSwarmOptimization.swift
    LINES: 514-519
    APPLY SAME overflow check pattern
```

### 7.3 Profitability Index Magic Number

```
[ ] FILE: Sources/BusinessMath/Time Series/TVM/NPV.swift
    LINES: 300-321

    CHANGE: Return error instead of 1,000,000
```

### 7.4 Skewness/Kurtosis Precision

```
[ ] FILE: Sources/BusinessMath/Statistics/Descriptors/Skewness/skew.swift
    LINES: 71, 105
[ ] FILE: Sources/BusinessMath/Statistics/Descriptors/Kurtosis/kurt.swift
    LINES: 72, 75

    ADD minimum stdDev threshold
```

### 7.5 Geometric Mean Silent NaN

```
[ ] FILE: Sources/BusinessMath/Statistics/Descriptors/Central Tendency/geometricMean.swift
    LINES: 56-59

    CHANGE: Throw error instead of returning NaN
```

---

## Phase 8: Cache & Collection Limits (7 issues)

### 8.1 Cut Ages and History ⚡

```
[ ] FILE: Sources/BusinessMath/Optimization/IntegerProgramming/BranchAndBound.swift
    LINES: 834-838, 1172-1194

    ADD size limits:
      let maxHistorySize = 100
      if boundHistory.count > maxHistorySize {
          boundHistory.removeFirst(boundHistory.count - maxHistorySize)
      }
```

### 8.2 PseudoCostTracker Dictionaries ⚡

```
[ ] FILE: Sources/BusinessMath/Optimization/IntegerProgramming/BranchAndBound.swift
    LINES: 1751-1812

    ADD: Maximum entries or LRU eviction
```

### 8.3 CutPool Size

```
[ ] FILE: Sources/BusinessMath/Optimization/IntegerProgramming/BranchAndBound.swift
    LINES: 2185-2207

    REDUCE default maxSize or make configurable:
      init(maxSize: Int = 1_000, maxAge: Int = 100)  // Down from 10_000
```

### 8.4 Shared FinancialModel Cache

```
[ ] FILE: Sources/BusinessMath/Performance/CalculationCache.swift
    LINES: 641-673

    ADD: Documentation warning about global cache behavior
    CONSIDER: Per-model caches or explicit cache management API
```

### 8.5 Inflight Waiters

```
[ ] FILE: Sources/BusinessMath/Performance/CalculationCache.swift
    LINES: 391, 438, 586

    ADD: Maximum waiter count with rejection
```

### 8.6 ModelProfiler Metrics

```
[ ] FILE: Sources/BusinessMath/Diagnostics/ModelProfiler.swift
    LINES: 44-48

    ADD: Maximum metrics per operation, automatic cleanup
```

### 8.7 MovingAverageModel History

```
[ ] FILE: Sources/BusinessMath/Forecasting/MovingAverageModel.swift
    LINES: 37, 86

    CHANGE: Only store last `window` values, not entire history
```

---

## Phase 9: Iteration Limits (7 issues - partial overlap with Phase 2)

### 9.1 Gamma Variate Recursion ⚡

```
[ ] FILE: Sources/BusinessMath/Simulation/distributionGamma.swift
    LINES: 81-85

    CONVERT recursion to iteration with limit
```

### 9.2 Gamma Distribution Unbounded Loop ⚡

```
[ ] FILE: Sources/BusinessMath/Simulation/distributionGamma.swift
    LINES: 93-129

    ADD iteration limit:
      let maxIterations = 10_000
      for _ in 0..<maxIterations {
          // acceptance-rejection sampling
          if accepted { return result }
      }
      throw BusinessMathError.convergenceFailure(...)
```

### 9.3 Geometric Distribution

```
[ ] FILE: Sources/BusinessMath/Simulation/distributionGeometric.swift
    LINES: 39-53

    REPLACE loop with closed-form:
      return Int(T.log(u) / T.log(T(1) - p))
```

### 9.4 Streaming Change Point Detection ⚡

```
[ ] FILE: Sources/BusinessMath/Streaming/StreamingForecasting.swift
    LINE: 947

    ADD: Maximum iterations per call, yield periodically
```

---

## Phase 10: Cleanup & Low Priority (12 issues)

### 10.1 Randomness Consistency (remaining items)

```
[ ] FILE: Sources/BusinessMath/Optimization/Heuristic/SimulatedAnnealingTypes.swift
    LINES: 114-132
    RENAME: seededDefault → testConfiguration

[ ] FILES: boxMuellerSeed.swift, boxMuellerTransform.swift, distributionNormal.swift
    CHANGE: Default parameters to optional with lazy evaluation
```

### 10.2 Array Bounds Safety

```
[ ] FILE: Sources/BusinessMath/Statistics/Regression/MultipleLinearRegression.swift
    LINES: 219, 277, 407
    ADD: Guard array.isEmpty before array[0]
```

### 10.3 Struct Closure Captures (cosmetic)

```
[ ] FILE: Sources/BusinessMath/BusinessOptimization/ResourceAllocation.swift
    LINE: 330
[ ] FILE: Sources/BusinessMath/FinancialModel/DriverOptimization.swift
    LINES: 308, 329, 350, 361

    REMOVE: Unnecessary [self] captures in struct closures
```

### 10.4 Retain Cycle Risks

```
[ ] FILE: Sources/BusinessMath/Integration/MarketDataCache.swift
    LINES: 49-191
    REVIEW: Document Any type risks, consider weak references
```

### 10.5 Add deinit for Documentation

```
[ ] FILE: Sources/BusinessMath/Optimization/IntegerProgramming/BranchAndBound.swift
    PseudoCostTracker - add deinit

[ ] FILE: Sources/BusinessMath/Optimization/Heuristic/GPU/MetalBuffers.swift
    Add explicit deinit (covered in Phase 5.6)
```

---

## Implementation Strategy

### Recommended Order

| Phase | Focus | Issues | Priority |
|-------|-------|--------|----------|
| 0 | Infrastructure | 3 | Do first |
| 1 | Critical Security | 5 | Immediate |
| 2 | Critical Memory | 8 | Immediate |
| 3 | Division by Zero | 16 | High |
| 4 | Force Unwraps | 25 | High |
| 5 | GPU Buffers | 8 | Medium |
| 6 | Async Tasks | 10 | Medium |
| 7 | Numeric Precision | 10 | Medium |
| 8 | Cache Limits | 7 | Medium |
| 9 | Iteration Limits | 7 | Medium |
| 10 | Cleanup | 12 | Low |

### Estimated Effort

| Phase | Complexity | Estimate |
|-------|------------|----------|
| 0 | Low | 1 hour |
| 1 | Low | 1-2 hours |
| 2 | High | 4-5 hours |
| 3 | Low | 2-3 hours |
| 4 | Medium (repetitive) | 4-6 hours |
| 5 | High | 4-5 hours |
| 6 | High | 4-5 hours |
| 7 | Medium | 2-3 hours |
| 8 | Medium | 3-4 hours |
| 9 | Medium | 2-3 hours |
| 10 | Low | 2-3 hours |
| **Total** | | **28-40 hours** |

### Testing Strategy

For each phase:
1. **Before fixing:** Write tests that trigger the issue (crash, wrong result, memory growth)
2. **After fixing:** Verify tests now pass (graceful error, correct result, bounded memory)
3. **Regression:** Run full test suite
4. **Memory:** For memory issues, use Instruments to verify no leaks

---

## Overlapping Issues Reference

Issues marked with ⚡ appear in both audits:

| Issue | Security ID | Memory ID | Fix Once In |
|-------|-------------|-----------|-------------|
| Branch & Bound histories | 4.4 | 1.6 | Phase 2/8 |
| Cut deduplication sets | 4.5 | 1.7 | Phase 8 |
| Streaming buffers | 4.6 | 1.5 | Phase 2 |
| Audit trail growth | - | 1.1 | Phase 2 |
| Debug steps growth | - | 1.2 | Phase 2 |
| Node queue growth | - | 1.4 | Phase 2 |
| Gamma recursion | 4.1 | - | Phase 9 |
| Gamma loop | 4.2 | - | Phase 9 |
| Change point detection | 4.6 | - | Phase 9 |

---

## Completion Checklist

```
[ ] Phase 0: Infrastructure
    [ ] BusinessMathError: Add 2 new cases (resourceExhausted, collectionLimitExceeded)
    [ ] RingBuffer implementation
    [ ] Deque (or package dependency)

[ ] Phase 1: Critical Security (5)
    [ ] 1.1-1.5 complete

[ ] Phase 2: Critical Memory (8)
    [ ] 2.1-2.8 complete

[ ] Phase 3: Division by Zero (16)
    [ ] 3.1-3.9 complete

[ ] Phase 4: Force Unwraps (25)
    [ ] All force unwraps replaced

[ ] Phase 5: GPU Buffers (8)
    [ ] 5.1-5.8 complete

[ ] Phase 6: Async Tasks (10)
    [ ] 6.1-6.8 complete

[ ] Phase 7: Numeric Precision (10)
    [ ] 7.1-7.5 complete

[ ] Phase 8: Cache Limits (7)
    [ ] 8.1-8.7 complete

[ ] Phase 9: Iteration Limits (7)
    [ ] 9.1-9.4 complete

[ ] Phase 10: Cleanup (12)
    [ ] 10.1-10.5 complete

[ ] Final verification
    [ ] Full test suite passes
    [ ] Instruments shows no memory leaks
    [ ] GPU memory stable under load
    [ ] Documentation updated
    [ ] Version bumped
```

---

## Glossary

| Term | Meaning |
|------|---------|
| **Ring Buffer** | Fixed-size circular array that overwrites oldest entries |
| **Deque** | Double-ended queue with O(1) operations at both ends |
| **ARC** | Automatic Reference Counting - Swift's memory management |
| **Retain Cycle** | Two objects holding strong references to each other |
| **autoreleasepool** | Scope that ensures timely cleanup of temporary objects |
| **MTLBuffer** | Metal GPU memory buffer |
| **AsyncStream** | Swift's async sequence for producing values over time |
| **Continuation** | Callback mechanism for bridging async/sync code |
| **ulpOfOne** | Unit in Last Place - smallest representable positive number |

---

*Plan generated from Security Audit + Memory Audit dated March 9, 2026*
