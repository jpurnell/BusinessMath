# Online Anomaly Detection Algorithms Implementation Plan

**Created:** March 9, 2026
**Status:** Future Enhancement
**Priority:** Feature Enhancement
**Estimated Effort:** 20-30 hours

---

## Background

### Current State

`StreamingAnomalyDetection.swift` uses **binary segmentation** for change point detection. This algorithm:

1. Collects the **entire stream** into memory
2. Recursively finds optimal split points
3. Returns all detected breakpoints

```swift
// Current implementation (lines 892-916)
private var allValues: [Double] = []      // Buffers entire stream!

public mutating func next() async throws -> Breakpoint? {
    if !hasCollected {
        while let value = try await iterator.next() {
            allValues.append(value)  // Memory grows with stream size
        }
        hasCollected = true
        breakpoints = performBinarySegmentation(values: allValues, ...)
    }
    // ...
}
```

### Problem

This defeats the purpose of streaming:
- **Memory:** O(n) where n is stream length
- **Latency:** No results until stream completes
- **Server use:** Cannot process infinite/long-running streams

### Immediate Fix (Security/Memory Plan)

Add a maximum buffer size with informative error. This prevents OOM but doesn't solve the fundamental limitation.

---

## Proposed Solution: Online Change Point Detection

Implement true streaming algorithms that:
1. Process data point-by-point
2. Use fixed O(1) or O(window) memory
3. Emit change points as they're detected
4. Handle infinite streams

### Algorithm Options

| Algorithm | Memory | Latency | Detection Quality | Complexity |
|-----------|--------|---------|-------------------|------------|
| **CUSUM** | O(1) | Immediate | Good for shifts | Simple |
| **EWMA** | O(1) | Immediate | Good for gradual | Simple |
| **PELT** | O(window) | Window-delayed | Excellent | Medium |
| **BOCPD** | O(run length) | Moderate | Excellent | Complex |
| **Sliding Window** | O(window) | Window-delayed | Good | Simple |

**Recommended:** Implement CUSUM (simple) and BOCPD (quality) to cover both use cases.

---

## Algorithm Details

### 1. CUSUM (Cumulative Sum Control Chart)

Detects shifts in mean by accumulating deviations from a target.

```
Mathematical Formulation:
─────────────────────────
Let μ₀ = target mean (estimated from training data)
Let σ = standard deviation
Let k = allowable slack (typically 0.5σ)
Let h = decision threshold

Upper CUSUM: S⁺ₙ = max(0, S⁺ₙ₋₁ + (xₙ - μ₀ - k))
Lower CUSUM: S⁻ₙ = max(0, S⁻ₙ₋₁ + (μ₀ - k - xₙ))

Change detected when: S⁺ₙ > h or S⁻ₙ > h
```

**Implementation:**
```swift
public struct CUSUMDetector: OnlineAnomalyDetector {
    private var targetMean: Double
    private var stdDev: Double
    private var slack: Double      // k
    private var threshold: Double  // h

    private var upperSum: Double = 0
    private var lowerSum: Double = 0
    private var index: Int = 0

    public mutating func update(_ value: Double) -> ChangePoint? {
        upperSum = max(0, upperSum + (value - targetMean - slack))
        lowerSum = max(0, lowerSum + (targetMean - slack - value))

        index += 1

        if upperSum > threshold {
            let cp = ChangePoint(index: index, direction: .increase, magnitude: upperSum)
            upperSum = 0  // Reset after detection
            return cp
        }

        if lowerSum > threshold {
            let cp = ChangePoint(index: index, direction: .decrease, magnitude: lowerSum)
            lowerSum = 0
            return cp
        }

        return nil
    }
}
```

**Pros:** O(1) memory, immediate detection, well-understood
**Cons:** Requires known target mean, sensitive to parameter tuning

---

### 2. BOCPD (Bayesian Online Change Point Detection)

Models probability of change point at each position using Bayesian inference.

```
Mathematical Formulation:
─────────────────────────
Let r = "run length" (time since last change point)
Let P(rₙ | x₁:ₙ) = probability of run length r at time n

Recursive update:
  P(rₙ = 0 | x₁:ₙ) ∝ P(xₙ | rₙ₋₁) × P(change) × P(rₙ₋₁ | x₁:ₙ₋₁)
  P(rₙ = rₙ₋₁ + 1 | x₁:ₙ) ∝ P(xₙ | rₙ₋₁) × (1 - P(change)) × P(rₙ₋₁ | x₁:ₙ₋₁)

Change detected when: max(P(rₙ = 0)) exceeds threshold
```

**Implementation:**
```swift
public struct BOCPDDetector: OnlineAnomalyDetector {
    private var runLengthProbabilities: [Double] = [1.0]
    private var sufficientStatistics: [GaussianSuffStats] = [.init()]
    private let hazardRate: Double  // P(change) at each step
    private let threshold: Double

    public mutating func update(_ value: Double) -> ChangePoint? {
        let n = runLengthProbabilities.count

        // Compute predictive probabilities for each run length
        var predictiveProbs = [Double](repeating: 0, count: n)
        for r in 0..<n {
            predictiveProbs[r] = sufficientStatistics[r].predictive(value)
        }

        // Growth probabilities (no change)
        var growthProbs = [Double](repeating: 0, count: n + 1)
        for r in 0..<n {
            growthProbs[r + 1] = runLengthProbabilities[r] * predictiveProbs[r] * (1 - hazardRate)
        }

        // Change point probability (reset to r=0)
        var changePointMass: Double = 0
        for r in 0..<n {
            changePointMass += runLengthProbabilities[r] * predictiveProbs[r] * hazardRate
        }
        growthProbs[0] = changePointMass

        // Normalize
        let evidence = growthProbs.reduce(0, +)
        runLengthProbabilities = growthProbs.map { $0 / evidence }

        // Update sufficient statistics
        var newStats = [GaussianSuffStats](repeating: .init(), count: n + 1)
        newStats[0] = .init()  // Fresh start
        for r in 0..<n {
            newStats[r + 1] = sufficientStatistics[r].updated(with: value)
        }
        sufficientStatistics = newStats

        // Detect if change point probability high
        if runLengthProbabilities[0] > threshold {
            return ChangePoint(
                index: /* current index */,
                probability: runLengthProbabilities[0]
            )
        }

        return nil
    }
}

private struct GaussianSuffStats {
    var n: Int = 0
    var sum: Double = 0
    var sumSquares: Double = 0

    var mean: Double { n > 0 ? sum / Double(n) : 0 }
    var variance: Double {
        guard n > 1 else { return 1 }  // Prior variance
        return (sumSquares - sum * sum / Double(n)) / Double(n - 1)
    }

    func predictive(_ x: Double) -> Double {
        // Student-t predictive distribution
        let mu = mean
        let sigma = sqrt(variance * (1 + 1/Double(max(n, 1))))
        return studentTPDF(x, mu: mu, sigma: sigma, df: Double(max(n - 1, 1)))
    }

    func updated(with x: Double) -> GaussianSuffStats {
        var copy = self
        copy.n += 1
        copy.sum += x
        copy.sumSquares += x * x
        return copy
    }
}
```

**Pros:** Principled Bayesian approach, excellent detection quality
**Cons:** O(max run length) memory, more complex

---

### 3. Sliding Window Comparison

Compares statistics between two adjacent windows.

```swift
public struct SlidingWindowDetector: OnlineAnomalyDetector {
    private var buffer: RingBuffer<Double>
    private let windowSize: Int
    private let threshold: Double  // t-test or KS threshold

    public mutating func update(_ value: Double) -> ChangePoint? {
        buffer.append(value)

        guard buffer.count >= 2 * windowSize else { return nil }

        let leftWindow = buffer.slice(0..<windowSize)
        let rightWindow = buffer.slice(windowSize..<2*windowSize)

        let testStatistic = twoSampleTTest(leftWindow, rightWindow)

        if abs(testStatistic) > threshold {
            return ChangePoint(index: buffer.totalSeen - windowSize, statistic: testStatistic)
        }

        return nil
    }
}
```

**Pros:** Intuitive, configurable sensitivity
**Cons:** O(2*window) memory, delayed detection by windowSize

---

## API Design

### Protocol-Based Abstraction

```swift
/// An algorithm that detects change points from streaming data.
public protocol OnlineAnomalyDetector: Sendable {
    associatedtype Configuration: Sendable

    /// Initialize with configuration
    init(configuration: Configuration)

    /// Process next value, potentially returning a detected change point
    mutating func update(_ value: Double) -> ChangePoint?

    /// Reset detector state (e.g., after confirmed change)
    mutating func reset()

    /// Current detector state summary
    var diagnostics: DetectorDiagnostics { get }
}

/// A detected change point in the stream
public struct ChangePoint: Sendable {
    public let index: Int
    public let timestamp: Date?
    public let confidence: Double
    public let direction: ChangeDirection?
    public let magnitude: Double?
}

public enum ChangeDirection: String, Sendable {
    case increase
    case decrease
    case varianceChange
    case unknown
}
```

### AsyncSequence Integration

```swift
/// Streaming change point detection
public struct AsyncChangePointSequence<Base: AsyncSequence>: AsyncSequence
where Base.Element == Double {
    public typealias Element = ChangePoint

    private let base: Base
    private let detector: any OnlineAnomalyDetector

    public struct AsyncIterator: AsyncIteratorProtocol {
        var baseIterator: Base.AsyncIterator
        var detector: any OnlineAnomalyDetector
        var index: Int = 0

        public mutating func next() async throws -> ChangePoint? {
            while let value = try await baseIterator.next() {
                index += 1
                if let changePoint = detector.update(value) {
                    return changePoint
                }
            }
            return nil
        }
    }
}

// Usage
let dataStream: AsyncStream<Double> = ...
let changePoints = dataStream.detectChangePoints(using: .cusum(threshold: 5.0))

for await changePoint in changePoints {
    print("Change detected at index \(changePoint.index)")
}
```

### Factory Methods

```swift
extension AsyncSequence where Element == Double {
    /// Detect change points using CUSUM algorithm
    public func detectChangePoints(
        using method: ChangePointMethod = .cusum()
    ) -> AsyncChangePointSequence<Self> {
        AsyncChangePointSequence(base: self, method: method)
    }
}

public enum ChangePointMethod {
    case cusum(slack: Double = 0.5, threshold: Double = 5.0, targetMean: Double? = nil)
    case bocpd(hazardRate: Double = 0.01, threshold: Double = 0.5)
    case slidingWindow(size: Int = 100, threshold: Double = 2.0)
    case ewma(span: Int = 20, threshold: Double = 3.0)
}
```

---

## Implementation Phases

### Phase 1: Core Infrastructure (4 hours)

```
[ ] Create protocol hierarchy
    - OnlineAnomalyDetector protocol
    - ChangePoint struct
    - DetectorDiagnostics struct

[ ] Create AsyncChangePointSequence
    - Generic over base AsyncSequence
    - Proper cancellation handling

[ ] Create ChangePointMethod enum
    - Factory methods for each algorithm
```

### Phase 2: CUSUM Implementation (4 hours)

```
[ ] CUSUMDetector struct
    - Basic implementation
    - Auto-estimation of target mean (online)
    - Configurable slack and threshold

[ ] Tests
    - Known change point detection
    - False positive rate
    - Parameter sensitivity

[ ] Documentation
    - Mathematical background
    - Parameter tuning guide
```

### Phase 3: EWMA Implementation (3 hours)

```
[ ] EWMADetector struct
    - Exponentially weighted moving average
    - Control limits based on historical variance
    - Configurable span and threshold

[ ] Tests and documentation
```

### Phase 4: Sliding Window Implementation (4 hours)

```
[ ] SlidingWindowDetector struct
    - RingBuffer-based storage
    - Multiple test statistics (t-test, KS, etc.)
    - Configurable window size

[ ] Tests and documentation
```

### Phase 5: BOCPD Implementation (8 hours)

```
[ ] BOCPDDetector struct
    - Run length probability tracking
    - Gaussian sufficient statistics
    - Student-t predictive distribution
    - Pruning of low-probability run lengths

[ ] Tests
    - Comparison with known BOCPD implementations
    - Memory usage verification

[ ] Documentation
    - Mathematical derivation
    - Prior selection guide
```

### Phase 6: Integration & Migration (4 hours)

```
[ ] Update StreamingAnomalyDetection.swift
    - Deprecate buffering approach
    - Add online alternatives
    - Migration guide in documentation

[ ] Performance benchmarks
    - Throughput comparison
    - Memory comparison
    - Detection quality comparison

[ ] Integration tests
    - Real financial time series
    - Simulated change points
```

---

## Success Criteria

| Metric | Target |
|--------|--------|
| Memory usage | O(1) for CUSUM/EWMA, O(window) for others |
| Latency | <1ms per data point |
| Detection quality | ROC AUC > 0.9 on benchmark datasets |
| API usability | Seamless AsyncSequence integration |
| Documentation | Examples for each algorithm |

---

## Test Datasets

| Dataset | Source | Characteristics |
|---------|--------|-----------------|
| **Synthetic** | Generated | Known change points, controllable |
| **S&P 500** | Yahoo Finance | Real financial, regime changes |
| **Server metrics** | Public datasets | CPU/memory, anomalies |
| **UCR Archive** | UCR | Academic benchmark |

---

## References

1. **CUSUM:** Page, E.S. (1954). "Continuous Inspection Schemes"
2. **BOCPD:** Adams, R.P. & MacKay, D.J.C. (2007). "Bayesian Online Changepoint Detection"
3. **PELT:** Killick, R., Fearnhead, P., & Eckley, I.A. (2012). "Optimal Detection of Changepoints"
4. **Survey:** Aminikhanghahi, S. & Cook, D.J. (2017). "A Survey of Methods for Time Series Change Point Detection"

---

## Dependencies

- RingBuffer implementation (Phase 0 of security/memory fixes)
- Student-t distribution PDF (may need to implement)

---

## Future Enhancements

1. **Multivariate detection** — Handle multiple correlated streams
2. **Adaptive thresholds** — Self-tuning based on false positive rate
3. **GPU acceleration** — Batch processing for high-throughput streams
4. **Explanation** — Why was this point flagged as a change?

---

*Plan created March 9, 2026 — Future enhancement after correctness fixes*
