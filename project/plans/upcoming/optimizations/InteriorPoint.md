# Phase 2: Interior Point Methods

**Priority**: ⭐⭐⭐⭐⭐ (Highest - Tier 1)
**Effort**: 3-4 weeks
**Status**: Not Started
**Dependencies**: None
**Target Completion**: Week 7 of Q2 2026

---

## Overview

Interior Point Methods (IPM) are **modern algorithms for large-scale optimization**. They scale to problems where Simplex struggles (10,000+ variables).

**Problem Classes**:
1. Linear Programming (LP)
2. Convex Quadratic Programming (QP)
3. Semidefinite Programming (SDP) - future extension

**Why Interior Point?**
1. **Scales to large problems**: O(n³) vs Simplex's exponential worst-case
2. **Polynomial time guarantee**: Proven polynomial complexity
3. **Modern standard**: What commercial solvers use for large-scale
4. **Warm-start capable**: Can start from previous solution (important for multi-period)

**Marketing Value**: "Scales to institutional portfolios with 10,000+ securities"

---

## Algorithm Overview

### Core Idea

Interior Point methods stay **inside the feasible region** and approach the boundary as they optimize. They use **barrier functions** to prevent leaving the feasible region.

**For LP**: `min cᵀx subject to Ax=b, x≥0`

Replace `x≥0` with logarithmic barrier:
```
min cᵀx - μ·Σ log(xᵢ)  subject to Ax=b
```

As μ→0, solution approaches LP optimum from interior.

### Primal-Dual Interior Point Algorithm

Most efficient variant solves primal and dual simultaneously:

**Primal**: `min cᵀx  s.t. Ax=b, x≥0`
**Dual**: `max bᵀy  s.t. Aᵀy+s=c, s≥0`

**KKT Conditions** (optimality):
```
Ax = b           (primal feasibility)
Aᵀy + s = c     (dual feasibility)
XSe = μe        (complementarity, perturbed)
x, s > 0        (positivity)
```

Where X=diag(x), S=diag(s), e=[1,1,...,1]

**Newton Step**: Solve KKT system for (Δx, Δy, Δs), take step, reduce μ, repeat.

---

## Implementation Plan

### File Structure

```
Sources/BusinessMath/Optimization/LinearProgramming/
├── InteriorPointSolver.swift        (main LP solver)
├── InteriorPointQPSolver.swift      (extends to QP)
└── BarrierFunction.swift            (logarithmic barrier)

Tests/BusinessMathTests/Optimization Tests/
└── InteriorPointTests.swift

Sources/BusinessMath/BusinessMath.docc/
└── 5.27-InteriorPointTutorial.md
```

### Phase 2.1: LP Interior Point (Weeks 1-2)

**Implementation**: Primal-dual path-following method

```swift
/// Interior Point solver for linear programming
///
/// Solves problems of the form:
/// ```
/// minimize cᵀx
/// subject to:
///     Ax = b   (equality constraints)
///     x ≥ 0    (non-negativity)
/// ```
///
/// ## Algorithm
///
/// Primal-dual path-following method:
/// 1. Initialize feasible (x, y, s) with x,s > 0
/// 2. Compute Newton direction from perturbed KKT system
/// 3. Line search maintaining positivity x,s > 0
/// 4. Reduce barrier parameter μ
/// 5. Repeat until duality gap < tolerance
///
/// ## Performance
///
/// - **Time complexity**: O(n³) per iteration (Cholesky factorization)
/// - **Typical iterations**: 20-50 regardless of problem size
/// - **Scales to**: n=10,000+ variables
///
/// ## Example
///
/// ```swift
/// let solver = InteriorPointSolver()
///
/// // Portfolio optimization: min risk subject to budget
/// let result = try solver.solve(
///     objective: riskVector,          // c
///     equalityMatrix: weightsMatrix,  // A
///     equalityRHS: [1.0],            // b (Σw=1)
///     bounds: (lower: zeros, upper: ones)
/// )
///
/// print("Optimal weights: \(result.solution)")
/// print("Solved in \(result.iterations) iterations")
/// ```
public struct InteriorPointSolver: Sendable {

    /// Convergence tolerance for duality gap
    public let tolerance: Double

    /// Maximum iterations
    public let maxIterations: Int

    /// Initial barrier parameter
    public let initialMu: Double

    /// Barrier reduction factor (typical: 0.1-0.2)
    public let muReduction: Double

    public init(
        tolerance: Double = 1e-8,
        maxIterations: Int = 100,
        initialMu: Double = 1.0,
        muReduction: Double = 0.1
    )

    /// Solve LP using primal-dual interior point method
    public func solve(
        objective c: [Double],           // n×1
        equalityMatrix A: [[Double]],    // m×n
        equalityRHS b: [Double],         // m×1
        bounds: (lower: [Double], upper: [Double])? = nil
    ) throws -> InteriorPointResult
}

public struct InteriorPointResult {
    public let solution: [Double]         // Primal optimal x
    public let dualEquality: [Double]     // Dual variables y
    public let dualBounds: [Double]       // Dual variables s
    public let objectiveValue: Double
    public let dualityGap: Double
    public let iterations: Int
    public let converged: Bool
}
```

**KKT System Solution** (core of each iteration):
```swift
// Solve:
// [  0   Aᵀ   I  ] [Δx]   [rhs_primal]
// [  A   0    0  ] [Δy] = [rhs_dual  ]
// [  S   0    X  ] [Δs]   [rhs_comp  ]
//
// Where X=diag(x), S=diag(s)
//
// Reduce to smaller system via elimination:
// (A·D·Aᵀ)Δy = ...   (normal equations form)
// Where D = X·S⁻¹

private func solveKKTSystem(
    A: [[Double]],
    x: [Double],
    s: [Double],
    rhs_primal: [Double],
    rhs_dual: [Double],
    rhs_comp: [Double]
) throws -> (Δx: [Double], Δy: [Double], Δs: [Double]) {

    // Form D = X·S⁻¹
    let D = zip(x, s).map { $0 / $1 }

    // Form normal equations matrix: M = A·D·Aᵀ
    let M = formNormalEquations(A, D)

    // Form RHS
    let rhs = ... // Complex elimination

    // Solve M·Δy = rhs via Cholesky factorization
    let Δy = choleskyS olve(M, rhs)

    // Back-substitute for Δx, Δs
    let Δx = ...
    let Δs = ...

    return (Δx, Δy, Δs)
}
```

**Line Search** (maintain positivity):
```swift
private func lineSearch(
    x: [Double], s: [Double],
    Δx: [Double], Δs: [Double],
    fraction: Double = 0.99
) -> Double {
    // Find maximum α such that x + α·Δx > 0, s + α·Δs > 0

    var α_primal = Double.infinity
    for i in 0..<x.count {
        if Δx[i] < 0 {
            α_primal = min(α_primal, -x[i] / Δx[i])
        }
    }

    var α_dual = Double.infinity
    for i in 0..<s.count {
        if Δs[i] < 0 {
            α_dual = min(α_dual, -s[i] / Δs[i])
        }
    }

    // Take fraction of maximum step to stay interior
    return fraction * min(α_primal, α_dual, 1.0)
}
```

### Phase 2.2: Sparse Matrix Support (Week 2)

Large-scale problems need sparse matrix storage:

```swift
/// Sparse matrix in compressed sparse row (CSR) format
public struct SparseMatrix {
    public let rows: Int
    public let cols: Int
    public let values: [Double]
    public let columnIndices: [Int]
    public let rowPointers: [Int]

    /// Multiply sparse matrix by dense vector: y = Ax
    public func multiply(_ x: [Double]) -> [Double]

    /// Transpose multiply: y = Aᵀx
    public func transposeMultiply(_ x: [Double]) -> [Double]
}

// Update InteriorPointSolver to accept SparseMatrix
extension InteriorPointSolver {
    public func solve(
        objective c: [Double],
        equalityMatrixSparse A: SparseMatrix,
        equalityRHS b: [Double],
        bounds: (lower: [Double], upper: [Double])? = nil
    ) throws -> InteriorPointResult
}
```

### Phase 2.3: Convex QP Extension (Week 3)

Extend to quadratic programming:

```swift
/// Interior Point solver for convex quadratic programming
///
/// Solves:
/// ```
/// minimize ½xᵀQx + cᵀx
/// subject to:
///     Ax = b
///     x ≥ 0
/// ```
/// where Q is positive semidefinite
public struct InteriorPointQPSolver {

    public func solve(
        quadraticObjective Q: [[Double]],  // n×n, symmetric positive semidefinite
        linearObjective c: [Double],       // n×1
        equalityMatrix A: [[Double]],      // m×n
        equalityRHS b: [Double],           // m×1
        bounds: (lower: [Double], upper: [Double])? = nil
    ) throws -> InteriorPointResult
}
```

**KKT System for QP** (modified):
```
[ Q   Aᵀ  I ] [Δx]   [gradient_residual]
[ A   0   0 ] [Δy] = [equality_residual ]
[ S   0   X ] [Δs]   [complementarity   ]
```

### Phase 2.4: Performance Benchmarks (Week 3)

**Test Cases**:

```swift
func testScalability() {
    // Test LP solver at increasing scales
    let sizes = [100, 500, 1_000, 5_000, 10_000]

    for n in sizes {
        // Random LP with n variables, n/2 constraints
        let (c, A, b) = generateRandomLP(variables: n, constraints: n/2)

        let start = Date()
        let result = try solver.solve(objective: c, equalityMatrix: A, equalityRHS: b)
        let elapsed = Date().timeIntervalSince(start)

        print("n=\(n): \(elapsed)s, \(result.iterations) iterations")

        // Verify solution
        XCTAssertTrue(result.converged)
        XCTAssertLessThan(result.dualityGap, 1e-6)
    }

    // Expected: ~O(n³) scaling for dense, better for sparse
}

func testComparisonToSimplex() {
    // Compare Interior Point vs Simplex at various scales

    let sizes = [100, 500, 1_000, 2_000]

    for n in sizes {
        let (c, A, b) = generateRandomLP(variables: n, constraints: n/2)

        // Interior Point
        let ipStart = Date()
        let ipResult = try interiorPointSolver.solve(objective: c, equalityMatrix: A, equalityRHS: b)
        let ipTime = Date().timeIntervalSince(ipStart)

        // Simplex
        let simplexStart = Date()
        let simplexResult = try simplexSolver.solve(objective: c, equalityMatrix: A, equalityRHS: b)
        let simplexTime = Date().timeIntervalSince(simplexStart)

        print("n=\(n): IP=\(ipTime)s vs Simplex=\(simplexTime)s (speedup: \(simplexTime/ipTime)×)")

        // Crossover point: interior point faster for n > ~1000
    }
}

func testLargeScalePortfolio() {
    // Test portfolio optimization with 10,000 securities

    let n = 10_000
    let returns = generateRandomReturns(count: n)
    let covariance = generateRandomCovariance(size: n)  // Sparse!

    // Minimize variance: min ½wᵀΣw
    // Subject to: Σw = 1, w ≥ 0

    let solver = InteriorPointQPSolver()

    let result = try solver.solve(
        quadraticObjective: covariance,
        linearObjective: Array(repeating: 0.0, count: n),
        equalityMatrix: [Array(repeating: 1.0, count: n)],  // Σw = 1
        equalityRHS: [1.0],
        bounds: (lower: Array(repeating: 0.0, count: n), upper: Array(repeating: 1.0, count: n))
    )

    print("10,000-asset portfolio optimized in \(result.iterations) iterations")
    XCTAssertLessThan(result.iterations, 100)  // Should be < 100 iterations
}
```

### Phase 2.5: Documentation (Week 4)

**Tutorial**: `5.27-InteriorPointTutorial.md`

Topics:
- When to use Interior Point vs Simplex
- Large-scale portfolio optimization example
- Sparse matrix usage
- QP extension for risk minimization
- Warm-starting for multi-period problems
- Performance characteristics

---

## Success Criteria

### Functional
- ✅ Solves LP with n=10,000 variables
- ✅ Handles sparse and dense matrices
- ✅ Extends to convex QP
- ✅ Warm-start capability from previous solution

### Performance
- ✅ **< 10 seconds for 10,000 variable LP**
- ✅ Faster than Simplex for n > 1,000
- ✅ < 50 iterations typical for well-scaled problems
- ✅ O(n³) per iteration complexity

### Quality
- ✅ Duality gap < 1e-8 at convergence
- ✅ Solutions match Simplex within 1e-6
- ✅ Numerically stable (Cholesky factorization)

---

## References

### Textbooks
1. **Wright (1997)**: "Primal-Dual Interior-Point Methods" - Comprehensive reference
2. **Boyd & Vandenberghe (2004)**: "Convex Optimization", Chapter 11
3. **Nocedal & Wright (2006)**: "Numerical Optimization", Chapter 14

### Papers
1. **Karmarkar (1984)**: "A New Polynomial-Time Algorithm for Linear Programming" - Original breakthrough
2. **Mehrotra (1992)**: "On the Implementation of a Primal-Dual Interior Point Method" - Predictor-corrector variant

### Reference Implementations
1. **MATLAB `linprog`** with `Algorithm='interior-point'`
2. **SciPy `linprog`** with `method='interior-point'`
3. **CVXOPT** - Python convex optimization with interior point
4. **MOSEK** - Commercial interior point solver

---

## Next Steps

After Phase 2 completion:
1. Update [Roadmap.md](./Roadmap.md) with status
2. Evaluate: Is large-scale performance sufficient or add GPU acceleration?
3. Proceed to [MINLP.md](./MINLP.md) for Phase 3
