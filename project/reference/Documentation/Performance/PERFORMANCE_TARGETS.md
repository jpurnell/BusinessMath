# PERFORMANCE_TARGETS.md

## I. Optimization Philosophy

The primary objective is to maintain the existing **sub-millisecond calculation speed** for core financial operations while eliminating known performance bottlenecks to support large-scale enterprise financial modeling (10K+ period Time Series analysis).

All new feature implementations must adhere to the **O(n) or better** complexity standard, leveraging O(1) lookups where possible.

## II. Performance Baselines (Must Maintain)

The AI Code Generator must ensure that no optimization or new feature implementation causes regression against these established performance metrics:

| Metric | Target | Status & Source |
| :--- | :--- | :--- |
| **Financial Calculations (NPV, IRR)** | **< 1ms** per operation | ⚡ Excellent [1, 2] |
| **Large Model Calculation** | **< 0.02ms** (150 components) | ⚡ Excellent [3, 4] |
| **Complete Forecast Workflow** | **< 50ms** (typical size) | ⚡ Excellent [2, 5] |
| **Time Series Random Access** | **O(1)** (via Dictionary lookup) | 🚀 Very Good [6] |
| **Memory Efficiency** | **Zero Leaks** for large model batches | ✅ Pass [3, 4] |

## III. High-Priority Optimization Targets

These targets address identified architectural bottlenecks (O(n²) complexity) which currently limit scalability for very large datasets (10K+ periods) [6, 7].

### Target 1: Time Series Initialization Complexity Reduction
*   **Current Bottleneck:** Duplicate period detection within `TimeSeries.init(periods:values:)` currently executes at **O(n²)** complexity [6].
*   **Goal:** Refactor duplicate detection and initialization to **O(n)** complexity (single pass with dictionary tracking).
*   **Expected Impact:** **10x to 50x speedup** for the creation of Time Series with > 10,000 periods [8].
*   **Files:** `TimeSeries.swift`

### Target 2: Temporal Lookup Optimization
*   **Current Bottleneck:** `Period.next()` and related projection methods rely heavily on repeated, expensive calls to `Calendar` instances, causing overhead during long projections [8, 9].
*   **Goal:** Optimize `Period.next()` by implementing **caching** of the `Calendar` instance or utilizing simpler arithmetic for common periods (e.g., monthly/quarterly arithmetic) [8].
*   **Expected Impact:** **5x to 10x speedup** for trend projections and amortization schedules covering 100+ periods [8].
*   **Files:** `Period.swift`, `PeriodArithmetic.swift`

## IV. Medium-Priority Optimization Targets

These targets focus on micro-optimizations within commonly used time series operations to improve performance for chained transformations.

### Target 3: Rolling Window Performance
*   **Current Bottleneck:** Rolling window operations (`movingAverage()`, `rollingSum()`) create intermediate array copies or lack optimal data structure management [10, 11].
*   **Goal:** Refactor rolling sum and average methods to employ a **circular buffer** or **running sum** methodology [8, 10].
*   **Expected Impact:** **2x to 3x speedup** for moving average and rolling sum calculations [8].
*   **Files:** `TimeSeriesAnalytics.swift`

### Target 4: Reduce Intermediate Copies
*   **Current Bottleneck:** Chained `TimeSeries` operations often implicitly create and destroy intermediate `TimeSeries` structs (due to immutability), incurring allocation overhead [8, 11].
*   **Goal:** Analyze high-usage chainable operations and implement strategies (e.g., lazy evaluation, copy-on-write internal collections, optimizing immutable return paths) to reduce unnecessary intermediate copying [8, 12].
*   **Expected Impact:** **20% to 30% speedup** for workflows involving heavy chaining of transformations [8].
*   **Files:** `TimeSeriesOperations.swift`
