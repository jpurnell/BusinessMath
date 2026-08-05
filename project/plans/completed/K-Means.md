# K-Means Clustering Implementation Plan

**Created:** 2026-01-28
**Status:** Planning
**Location:** `Sources/BusinessMath/Optimization/Heuristic/`
**Estimated Effort:** Large (L) - 8-12 hours including GPU acceleration
**Dependencies:** VectorSpace protocol (complete)

---

## Overview

Implement K-Means clustering algorithm as a generic heuristic optimization method for BusinessMath library. The implementation will leverage the existing VectorSpace protocol to provide clustering capabilities for any vector type (VectorN, Vector2D, Vector3D).

### Key Features
- Generic over VectorSpace protocol
- Multiple initialization strategies (K-Means++, random, Forgy)
- GPU acceleration for large-scale clustering (thousands of variables)
- Multiple distance metrics (Euclidean, Manhattan, Chebyshev)
- Convergence detection with configurable tolerance
- Elbow method for optimal k determination
- Comprehensive test coverage with deterministic testing

---

## Goals

1. **Generic Design**: Work with any type conforming to VectorSpace protocol
2. **Performance**: GPU-accelerated for clustering thousands of data points
3. **Robustness**: Multiple initialization strategies to avoid local optima
4. **Usability**: Simple API with sensible defaults
5. **Quality**: 100% test coverage, fully documented with DocC
6. **Integration**: Fits naturally alongside NelderMead, PSO, Simulated Annealing

---

## File Structure

```
Sources/BusinessMath/Optimization/Heuristic/
├── ClusteringTypes.swift           (~150 lines)
├── InitializationStrategies.swift  (~100 lines)
└── KMeansClustering.swift          (~250 lines + GPU code)

Tests/BusinessMathTests/Optimization Tests/Heuristic Tests/
├── ClusteringTypesTests.swift      (~100 lines)
├── InitializationTests.swift       (~100 lines)
└── KMeansTests.swift               (~200 lines)
```

---

## Architecture

### 1. ClusteringTypes.swift

Core types for clustering operations.

#### Types to Implement

```swift
/// Represents a cluster of data points
public struct Cluster<V: VectorSpace>: Equatable where V: Equatable {
    /// Centroid of the cluster
    public let centroid: V

    /// Indices of data points assigned to this cluster
    public let memberIndices: Set<Int>

    /// Number of points in the cluster
    public var size: Int { memberIndices.count }
}

/// Result of a clustering operation
public struct ClusteringResult<V: VectorSpace>: Equatable where V: Equatable {
    /// The clusters identified
    public let clusters: [Cluster<V>]

    /// Assignment of each data point to cluster index
    public let assignments: [Int]

    /// Total within-cluster sum of squares (WCSS)
    public let wcss: Double

    /// Number of iterations performed
    public let iterations: Int

    /// Whether the algorithm converged
    public let converged: Bool
}

/// Distance metric for clustering
public enum DistanceMetric {
    case euclidean
    case manhattan
    case chebyshev

    public func distance<V: VectorSpace>(_ a: V, _ b: V) -> Double {
        switch self {
        case .euclidean:
            return a.distance(to: b)
        case .manhattan:
            return a.manhattanDistance(to: b)
        case .chebyshev:
            return a.chebyshevDistance(to: b)
        }
    }
}

/// Errors that can occur during clustering
public enum ClusteringError: Error, Equatable {
    /// Requested more clusters than data points
    case tooManyClusters(k: Int, dataPoints: Int)

    /// Empty dataset provided
    case emptyDataset

    /// Invalid number of clusters (k must be >= 1)
    case invalidK(k: Int)

    /// Empty cluster created during iteration
    case emptyCluster(iteration: Int)
}
```

**Design Notes:**
- Use `Set<Int>` for member indices (O(1) lookup)
- Store WCSS (within-cluster sum of squares) for quality assessment
- Track convergence and iteration count for diagnostics

---

### 2. InitializationStrategies.swift

Strategies for selecting initial centroids.

#### Protocol

```swift
/// Protocol for centroid initialization strategies
public protocol CentroidInitialization {
    /// Initialize k centroids from data points
    func initialize<V: VectorSpace>(
        data: [V],
        k: Int,
        distanceMetric: DistanceMetric,
        seed: UInt64?
    ) -> [V]
}
```

#### Implementations

**Random Initialization**
```swift
/// Randomly select k data points as initial centroids
public struct RandomInitialization: CentroidInitialization {
    public init() {}

    public func initialize<V: VectorSpace>(
        data: [V],
        k: Int,
        distanceMetric: DistanceMetric,
        seed: UInt64?
    ) -> [V]
}
```

**Forgy Initialization**
```swift
/// Randomly partition data and compute mean of each partition
public struct ForgyInitialization: CentroidInitialization {
    public init() {}

    public func initialize<V: VectorSpace>(
        data: [V],
        k: Int,
        distanceMetric: DistanceMetric,
        seed: UInt64?
    ) -> [V]
}
```

**K-Means++ Initialization**
```swift
/// K-Means++ initialization for better initial centroids
/// Selects centroids with probability proportional to distance from existing centroids
public struct KMeansPlusPlusInitialization: CentroidInitialization {
    public init() {}

    public func initialize<V: VectorSpace>(
        data: [V],
        k: Int,
        distanceMetric: DistanceMetric,
        seed: UInt64?
    ) -> [V]
}
```

**Design Notes:**
- K-Means++ reduces likelihood of poor local optima
- All strategies accept optional seed for deterministic testing
- Use seeded random number generator when seed provided

---

### 3. KMeansClustering.swift

Main K-Means algorithm implementation.

#### Public API

```swift
/// K-Means clustering algorithm
public struct KMeans<V: VectorSpace> where V: Equatable {
    /// Maximum iterations before stopping
    public let maxIterations: Int

    /// Convergence tolerance (centroid movement threshold)
    public let tolerance: Double

    /// Distance metric to use
    public let distanceMetric: DistanceMetric

    /// Initialization strategy
    public let initialization: CentroidInitialization

    /// Random seed for deterministic results
    public let seed: UInt64?

    /// Whether to use GPU acceleration
    public let useGPU: Bool

    public init(
        maxIterations: Int = 100,
        tolerance: Double = 1e-6,
        distanceMetric: DistanceMetric = .euclidean,
        initialization: CentroidInitialization = KMeansPlusPlusInitialization(),
        seed: UInt64? = nil,
        useGPU: Bool = true
    )

    /// Fit the model to data, finding k clusters
    public func fit(
        data: [V],
        k: Int
    ) throws -> ClusteringResult<V>

    /// Predict cluster assignments for new data points using existing centroids
    public func predict(
        data: [V],
        centroids: [V]
    ) -> [Int]

    /// Run K-Means for multiple k values and return WCSS for each
    /// Useful for elbow method to determine optimal k
    public func elbowMethod(
        data: [V],
        kRange: ClosedRange<Int>
    ) throws -> [(k: Int, wcss: Double)]
}
```

#### Algorithm Steps

**1. Assignment Step**
```swift
/// Assign each data point to nearest centroid
private func assignClusters(
    data: [V],
    centroids: [V]
) -> [Int]
```

**2. Update Step**
```swift
/// Compute new centroids as mean of assigned points
private func updateCentroids(
    data: [V],
    assignments: [Int],
    k: Int
) -> [V]
```

**3. Convergence Check**
```swift
/// Check if centroids have moved less than tolerance
private func hasConverged(
    oldCentroids: [V],
    newCentroids: [V]
) -> Bool
```

**4. WCSS Calculation**
```swift
/// Compute total within-cluster sum of squares
private func computeWCSS(
    data: [V],
    assignments: [Int],
    centroids: [V]
) -> Double
```

**Design Notes:**
- Use iterative refinement until convergence or max iterations
- Check for empty clusters and handle gracefully
- WCSS useful for quality assessment and elbow method

---

## GPU Acceleration Strategy

### Approach

For large-scale clustering (thousands of data points), GPU acceleration provides significant performance improvement by parallelizing distance calculations and assignments.

### Implementation Options

**Option 1: Metal Performance Shaders (Recommended)**
- Native Apple GPU acceleration
- Works on all Apple platforms (macOS, iOS, tvOS)
- Excellent performance for matrix operations
- No external dependencies

**Option 2: Accelerate Framework**
- Apple's SIMD and vector math framework
- CPU-optimized but multi-threaded
- Works on all Apple platforms
- Fallback when GPU unavailable

### Metal Shader Design

```swift
// GPU-accelerated distance computation
private func computeDistancesGPU(
    data: [V],
    centroids: [V]
) -> [[Double]]

// GPU-accelerated centroid updates
private func updateCentroidsGPU(
    data: [V],
    assignments: [Int],
    k: Int
) -> [V]
```

**Key Operations to Accelerate:**
1. **Distance Matrix Computation**: O(n*k*d) where n=points, k=clusters, d=dimensions
2. **Assignment Finding**: O(n*k) argmin operation
3. **Centroid Updates**: O(n*d) reduction by cluster

### Fallback Strategy

```swift
// Automatically detect GPU availability
// Fall back to CPU implementation if:
// - GPU not available
// - Data size too small to benefit from GPU overhead
// - useGPU = false explicitly set
```

### Performance Thresholds

- **Small data (n < 1000, k < 10)**: CPU implementation (overhead not worth it)
- **Medium data (1000 ≤ n < 10000)**: GPU beneficial for high-dimensional data (d > 10)
- **Large data (n ≥ 10000)**: GPU acceleration always beneficial

---

## Test-Driven Development Plan

### Phase 1: ClusteringTypes Tests (RED)

**File:** `ClusteringTypesTests.swift`

```swift
@Suite("Clustering Types Tests")
struct ClusteringTypesTests {
    @Test("Cluster creation and properties")
    func clusterCreation()

    @Test("ClusteringResult properties")
    func clusteringResultProperties()

    @Test("Distance metric calculations")
    func distanceMetrics()

    @Test("Error cases")
    func errorCases()
}
```

**Test Cases:**
- Cluster with member indices and centroid
- ClusteringResult with WCSS calculation
- Distance metrics (Euclidean, Manhattan, Chebyshev)
- Error handling (empty dataset, too many clusters, invalid k)

### Phase 2: Initialization Tests (RED)

**File:** `InitializationTests.swift`

```swift
@Suite("Centroid Initialization Tests")
struct InitializationTests {
    @Test("Random initialization is deterministic with seed")
    func randomInitializationDeterministic()

    @Test("K-Means++ initialization spreads centroids")
    func kMeansPlusPlusSpread()

    @Test("Forgy initialization")
    func forgyInitialization()

    @Test("Initialization with invalid k throws error")
    func invalidKThrows()
}
```

**Test Cases:**
- Random initialization produces consistent results with same seed
- K-Means++ produces more spread-out centroids than random
- Forgy initialization produces valid centroids
- All strategies handle edge cases (k=1, k=n)

### Phase 3: K-Means Algorithm Tests (RED)

**File:** `KMeansTests.swift`

```swift
@Suite("K-Means Clustering Tests")
struct KMeansTests {
    @Test("K-Means converges on simple 2D data")
    func simpleConvergence()

    @Test("K-Means with known cluster structure")
    func knownClusters()

    @Test("Predict assigns new points correctly")
    func prediction()

    @Test("Elbow method produces decreasing WCSS")
    func elbowMethod()

    @Test("Empty cluster handling")
    func emptyClusterHandling()

    @Test("GPU and CPU implementations produce same results",
          arguments: [true, false])
    func gpuCpuEquivalence(useGPU: Bool)

    @Test("Deterministic results with seed")
    func deterministicWithSeed()
}
```

**Test Data:**
- Simple 2D clusters (easy to visualize)
- 3D clusters (VectorN)
- High-dimensional data (d > 10)
- Known cluster structure for validation

**Validation Strategy:**
- Compare results to known clustering (e.g., sklearn)
- Verify WCSS decreases with iterations
- Ensure convergence detection works correctly
- GPU and CPU produce identical results (within floating point tolerance)

---

## Implementation Phases

### Phase 1: Core Types (2 hours)

**Tasks:**
1. Write tests for ClusteringTypes
2. Implement `Cluster`, `ClusteringResult`, `DistanceMetric`, `ClusteringError`
3. Verify all tests pass

**Acceptance Criteria:**
- [ ] All ClusteringTypes tests pass
- [ ] 100% code coverage for types
- [ ] Complete DocC documentation

### Phase 2: Initialization Strategies (2 hours)

**Tasks:**
1. Write tests for initialization strategies
2. Implement `CentroidInitialization` protocol
3. Implement Random, Forgy, K-Means++ initialization
4. Verify all tests pass

**Acceptance Criteria:**
- [ ] All initialization tests pass
- [ ] Deterministic with seed
- [ ] K-Means++ demonstrably better than random

### Phase 3: CPU K-Means Algorithm (3 hours)

**Tasks:**
1. Write tests for K-Means algorithm
2. Implement `KMeans` struct with CPU-only implementation
3. Implement fit(), predict(), elbowMethod()
4. Verify all tests pass

**Acceptance Criteria:**
- [ ] All K-Means tests pass (with useGPU=false)
- [ ] Convergence works correctly
- [ ] Handles empty clusters gracefully
- [ ] Elbow method produces valid results

### Phase 4: GPU Acceleration (3-4 hours)

**Tasks:**
1. Implement Metal shader for distance computation
2. Implement GPU-accelerated assignment step
3. Implement GPU-accelerated centroid update
4. Add GPU/CPU equivalence tests
5. Benchmark GPU vs CPU performance

**Acceptance Criteria:**
- [ ] GPU implementation passes all tests
- [ ] GPU and CPU produce identical results (within tolerance)
- [ ] GPU faster than CPU for large datasets
- [ ] Graceful fallback to CPU when GPU unavailable

### Phase 5: Documentation & Examples (1-2 hours)

**Tasks:**
1. Complete DocC documentation for all public APIs
2. Add mathematical formulas to documentation
3. Create playground examples
4. Add usage examples to documentation

**Acceptance Criteria:**
- [ ] 100% DocC coverage
- [ ] Mathematical formulas documented
- [ ] At least 3 complete examples
- [ ] Examples run successfully in playground

---

## API Usage Examples

### Example 1: Simple 2D Clustering

```swift
import BusinessMath

// Create 2D data points
let data: [Vector2D] = [
    Vector2D(x: 1.0, y: 1.0),
    Vector2D(x: 1.5, y: 2.0),
    Vector2D(x: 3.0, y: 4.0),
    Vector2D(x: 5.0, y: 7.0),
    Vector2D(x: 3.5, y: 5.0),
    Vector2D(x: 4.5, y: 5.0),
    Vector2D(x: 3.5, y: 4.5)
]

// Create K-Means instance
let kmeans = KMeans<Vector2D>(
    maxIterations: 100,
    tolerance: 1e-6,
    distanceMetric: .euclidean,
    initialization: KMeansPlusPlusInitialization(),
    seed: 12345,
    useGPU: true
)

// Fit to find 2 clusters
let result = try kmeans.fit(data: data, k: 2)

print("Converged: \(result.converged)")
print("Iterations: \(result.iterations)")
print("WCSS: \(result.wcss)")

for (index, cluster) in result.clusters.enumerated() {
    print("Cluster \(index): \(cluster.size) points")
    print("  Centroid: \(cluster.centroid)")
}

// Predict cluster for new point
let newPoint = Vector2D(x: 2.0, y: 3.0)
let assignment = kmeans.predict(
    data: [newPoint],
    centroids: result.clusters.map { $0.centroid }
)
print("New point assigned to cluster: \(assignment[0])")
```

### Example 2: High-Dimensional Clustering with Elbow Method

```swift
import BusinessMath

// Create high-dimensional data
let dimension = 50
var data: [VectorN] = []
for _ in 0..<1000 {
    let values = (0..<dimension).map { _ in Double.random(in: 0...1) }
    data.append(VectorN(values))
}

// Use elbow method to find optimal k
let kmeans = KMeans<VectorN>(useGPU: true)
let elbowData = try kmeans.elbowMethod(data: data, kRange: 1...10)

print("k\tWCSS")
for (k, wcss) in elbowData {
    print("\(k)\t\(wcss)")
}

// Find elbow point (biggest drop in WCSS)
var maxDecrease = 0.0
var optimalK = 2
for i in 1..<elbowData.count {
    let decrease = elbowData[i-1].wcss - elbowData[i].wcss
    if decrease > maxDecrease {
        maxDecrease = decrease
        optimalK = elbowData[i].k
    }
}

print("Optimal k: \(optimalK)")

// Cluster with optimal k
let result = try kmeans.fit(data: data, k: optimalK)
print("Final WCSS: \(result.wcss)")
```

### Example 3: Customer Segmentation

```swift
import BusinessMath

// Customer features: [age, income, spending_score]
let customers: [VectorN] = [
    VectorN([25, 50000, 80]),
    VectorN([30, 60000, 70]),
    VectorN([50, 100000, 40]),
    VectorN([45, 90000, 45]),
    VectorN([28, 55000, 75]),
    VectorN([35, 70000, 60])
]

// Cluster customers into segments
let kmeans = KMeans<VectorN>(
    initialization: KMeansPlusPlusInitialization(),
    seed: 42
)

let result = try kmeans.fit(data: customers, k: 3)

// Analyze segments
for (index, cluster) in result.clusters.enumerated() {
    print("Segment \(index + 1):")
    print("  Size: \(cluster.size) customers")
    print("  Average profile: \(cluster.centroid.coordinates)")

    // Find customers in this segment
    let members = cluster.memberIndices.sorted()
    print("  Customer IDs: \(members)")
}
```

---

## Mathematical Background

### K-Means Algorithm

K-Means minimizes the within-cluster sum of squares (WCSS):

```
WCSS = Σ(k=1 to K) Σ(x∈Cₖ) ||x - μₖ||²
```

where:
- K = number of clusters
- Cₖ = set of points in cluster k
- μₖ = centroid of cluster k
- x = data point
- ||·|| = distance metric (usually Euclidean)

### Algorithm Steps

1. **Initialize**: Select k initial centroids using chosen strategy
2. **Assignment**: Assign each point to nearest centroid
   ```
   c(x) = argmin(k) ||x - μₖ||²
   ```
3. **Update**: Recompute centroids as mean of assigned points
   ```
   μₖ = (1/|Cₖ|) Σ(x∈Cₖ) x
   ```
4. **Repeat**: Steps 2-3 until convergence or max iterations

### Convergence

Convergence occurs when centroid movement is below tolerance:
```
max(k) ||μₖ^(new) - μₖ^(old)|| < ε
```

### K-Means++ Initialization

K-Means++ selects centroids sequentially with probability proportional to squared distance from nearest existing centroid:

```
P(x) ∝ min(k) ||x - μₖ||²
```

This spreads centroids out, reducing likelihood of poor local optima.

---

## Performance Considerations

### Time Complexity

- **Initialization**: O(n·k·d) for K-Means++
- **Assignment step**: O(n·k·d)
- **Update step**: O(n·d)
- **Overall per iteration**: O(n·k·d)
- **Total**: O(i·n·k·d) where i = iterations

### Space Complexity

- **Data storage**: O(n·d)
- **Centroids**: O(k·d)
- **Assignments**: O(n)
- **Total**: O(n·d + k·d) ≈ O(n·d)

### GPU Acceleration Impact

For n=10,000 points, k=10 clusters, d=50 dimensions:
- **CPU**: ~2-5 seconds per iteration
- **GPU**: ~0.1-0.3 seconds per iteration
- **Speedup**: ~10-50x for large datasets

---

## Quality Assurance

### Test Coverage Goals
- [ ] Line coverage: 100%
- [ ] Branch coverage: 95%+
- [ ] All public APIs tested
- [ ] Edge cases covered
- [ ] GPU and CPU paths tested

### Documentation Goals
- [ ] 100% DocC coverage
- [ ] All public APIs documented
- [ ] Mathematical formulas included
- [ ] Usage examples for each major feature
- [ ] Playground tutorial created

### Performance Goals
- [ ] CPU implementation handles n=10,000 in <30 seconds
- [ ] GPU implementation handles n=100,000 in <30 seconds
- [ ] GPU/CPU produce identical results (within 1e-10)
- [ ] Memory usage scales linearly with data size

---

## Integration with Existing Code

### Related Components

**Optimization Module:**
- NelderMead (local optimization)
- PSO (swarm optimization)
- Simulated Annealing (global optimization)
- **K-Means (clustering/partitioning)**

**VectorSpace Protocol:**
- VectorN (generic n-dimensional)
- Vector2D (2D specialized)
- Vector3D (3D specialized)

### Shared Patterns

- Generic over VectorSpace
- Seed parameter for deterministic testing
- Convergence detection with tolerance
- Iteration limits
- Result types with diagnostics

---

## Risks and Mitigations

### Risk 1: GPU Availability
**Mitigation:** Automatic fallback to CPU implementation

### Risk 2: Empty Clusters During Iteration
**Mitigation:** Detect and re-initialize empty cluster with furthest point from any centroid

### Risk 3: Poor Local Optima
**Mitigation:** K-Means++ initialization significantly reduces this risk

### Risk 4: GPU/CPU Result Divergence
**Mitigation:** Extensive testing to ensure identical results; use same random seed paths

---

## Success Criteria

Implementation is complete when:

- [ ] All tests pass (100% coverage)
- [ ] GPU and CPU produce identical results
- [ ] GPU demonstrates performance improvement for large datasets
- [ ] 100% DocC documentation coverage
- [ ] Playground tutorial complete and verified
- [ ] Code review approved
- [ ] Performance benchmarks meet goals
- [ ] Integrates seamlessly with existing optimization module

---

## References

### Academic
- Lloyd, S. (1982). "Least squares quantization in PCM"
- Arthur, D. & Vassilvitskii, S. (2007). "k-means++: The advantages of careful seeding"

### Implementation References
- sklearn.cluster.KMeans (Python reference implementation)
- Apple Metal Performance Shaders documentation
- Swift Numerics documentation

### Related BusinessMath Documentation
- VectorSpace protocol documentation
- Optimization module overview
- Test-driven development guidelines
- DocC documentation standards

---

## Timeline Estimate

| Phase | Task | Hours | Dependencies |
|-------|------|-------|--------------|
| 1 | ClusteringTypes | 2 | None |
| 2 | Initialization Strategies | 2 | Phase 1 |
| 3 | CPU K-Means | 3 | Phase 2 |
| 4 | GPU Acceleration | 4 | Phase 3 |
| 5 | Documentation & Examples | 2 | Phase 4 |
| **Total** | | **13** | |

**Note:** Timeline assumes familiarity with Metal and GPU programming. Add 2-4 hours if learning Metal from scratch.

---

## Next Steps

1. ✅ Create this implementation plan
2. ⬜ Review plan with stakeholder
3. ⬜ Begin Phase 1: ClusteringTypes tests (RED)
4. ⬜ Implement ClusteringTypes (GREEN)
5. ⬜ Continue through phases following TDD approach

---

**Plan Status:** ✅ Complete - Ready for implementation
**Last Updated:** 2026-01-28
