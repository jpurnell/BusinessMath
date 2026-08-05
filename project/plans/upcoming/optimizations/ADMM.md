# Phase 5: ADMM - Alternating Direction Method of Multipliers

**Priority**: ⭐⭐⭐⭐ (Tier 2)
**Effort**: 3-4 weeks
**Status**: Not Started
**Dependencies**: [ConvexityDetection.md](./ConvexityDetection.md)
**Target Completion**: Week 17 of Q3 2026

---

## Overview

ADMM is a **modern parallel/distributed optimization algorithm** for convex problems with separable structure.

**Key Advantages**:
1. **Decomposition**: Split large problem into smaller subproblems
2. **Parallelization**: Solve subproblems independently
3. **Robustness**: Converges even with approximate subproblem solutions
4. **Trendy**: Popular in ML/statistics community

**Use Cases**:
- Multi-period portfolio optimization with coupling constraints
- Distributed optimization (multiple actors)
- Large-scale Lasso/Ridge regression
- Consensus optimization

**Marketing**: "Modern parallel optimization using Swift 6 structured concurrency"

---

## Algorithm Overview

### Problem Form

ADMM solves problems with **separable structure**:
```
minimize f(x) + g(z)
subject to: Ax + Bz = c
```

Where:
- `f(x)` and `g(z)` are convex functions over different variables
- Variables x and z are **coupled** only through linear constraint

### ADMM Iterations

```
1. x-update: x^(k+1) = argmin_x { f(x) + (ρ/2)||Ax + Bz^k - c + u^k||² }
2. z-update: z^(k+1) = argmin_z { g(z) + (ρ/2)||Ax^(k+1) + Bz - c + u^k||² }
3. dual-update: u^(k+1) = u^k + (Ax^(k+1) + Bz^(k+1) - c)
```

**Key Parameters**:
- `ρ`: Augmentation parameter (penalty weight)
- `u`: Scaled dual variable

**Convergence**: Proven for convex f, g under mild conditions.

---

## Implementation Plan

### File Structure

```
Sources/BusinessMath/Optimization/
├── ADMM/
│   ├── ADMMOptimizer.swift              (main algorithm)
│   ├── ADMMSubproblem.swift             (subproblem abstraction)
│   ├── ConsensusADMM.swift              (consensus variant)
│   └── ParallelADMM.swift               (parallel execution)

Tests/BusinessMathTests/Optimization Tests/
└── ADMMTests.swift

Sources/BusinessMath/BusinessMath.docc/
└── 5.30-ADMMTutorial.md
```

### Phase 5.1: Basic ADMM (Week 1-2)

```swift
/// ADMM optimizer for problems with separable structure
///
/// Solves:
/// ```
/// minimize f(x) + g(z)
/// subject to: Ax + Bz = c
/// ```
///
/// ## Algorithm
///
/// Alternating minimization with augmented Lagrangian:
/// 1. Minimize over x with z fixed
/// 2. Minimize over z with x fixed
/// 3. Update dual variables
///
/// ## Performance
///
/// - Converges even with inexact subproblem solutions
/// - Parallelizable (x and z updates independent within iteration)
/// - Typical iterations: 100-1000 (slower than Newton, but robust)
///
/// ## Example
///
/// ```swift
/// let admm = ADMMOptimizer()
///
/// // Lasso regression: min ||Ax-b||² + λ||x||₁
/// let result = try admm.solve(
///     xSubproblem: { x, zFixed, u in leastSquares(A, b, x, zFixed, u) },
///     zSubproblem: { z, xFixed, u in softThreshold(z, λ, xFixed, u) },
///     coupling: (A: A, B: -I, c: zeros)
/// )
/// ```
public struct ADMMOptimizer {

    /// Augmentation parameter (ρ)
    public let rho: Double

    /// Convergence tolerance
    public let tolerance: Double

    /// Maximum iterations
    public let maxIterations: Int

    public init(
        rho: Double = 1.0,
        tolerance: Double = 1e-4,
        maxIterations: Int = 1000
    )

    /// Solve ADMM problem
    public func solve(
        xSubproblem: @escaping (Vector, Vector, Vector) throws -> Vector,
        zSubproblem: @escaping (Vector, Vector, Vector) throws -> Vector,
        coupling: (A: Matrix, B: Matrix, c: Vector),
        initialX: Vector,
        initialZ: Vector
    ) throws -> ADMMResult
}

public struct ADMMResult {
    public let x: Vector
    public let z: Vector
    public let dualVariable: Vector
    public let iterations: Int
    public let converged: Bool
    public let primalResidual: Double
    public let dualResidual: Double
}
```

**Iteration Implementation**:
```swift
public func solve(...) throws -> ADMMResult {
    var x = initialX
    var z = initialZ
    var u = Vector(repeating: 0.0, count: coupling.c.count)

    for iteration in 0..<maxIterations {
        // x-update
        x = try xSubproblem(x, z, u)

        // z-update
        z = try zSubproblem(z, x, u)

        // Primal residual: Ax + Bz - c
        let primalResidual = coupling.A * x + coupling.B * z - coupling.c

        // Dual residual: ρAᵀB(z^(k+1) - z^k)
        let dualResidual = rho * coupling.A.transpose() * coupling.B * (z - z_old)

        // u-update
        u = u + primalResidual

        // Check convergence
        if primalResidual.norm() < tolerance && dualResidual.norm() < tolerance {
            return ADMMResult(x: x, z: z, dualVariable: u, iterations: iteration, converged: true, ...)
        }

        z_old = z
    }

    // Did not converge
    return ADMMResult(x: x, z: z, dualVariable: u, iterations: maxIterations, converged: false, ...)
}
```

### Phase 5.2: Consensus ADMM (Week 2)

**Consensus variant**: Multiple agents agree on shared variable

```
minimize Σᵢ fᵢ(xᵢ)
subject to: xᵢ = z for all i  (consensus constraint)
```

**Use case**: Distributed portfolio optimization where each agent manages subset of assets

```swift
/// Consensus ADMM for distributed optimization
///
/// Each agent i solves local problem over xᵢ, agents coordinate on shared z.
public struct ConsensusADMM {

    public func solve(
        agents: [Agent],
        initialZ: Vector
    ) throws -> ConsensusResult
}

public protocol Agent {
    /// Agent's local objective fᵢ(xᵢ)
    func localObjective(_ x: Vector) -> Double

    /// Solve local subproblem: min fᵢ(xᵢ) + (ρ/2)||xᵢ - z + uᵢ||²
    func solveLocal(z: Vector, u: Vector, rho: Double) throws -> Vector
}
```

### Phase 5.3: Parallel ADMM (Week 3)

Leverage Swift 6 structured concurrency:

```swift
/// Parallel ADMM using Swift structured concurrency
public actor ParallelADMM {

    public func solve(
        agents: [Agent],
        initialZ: Vector
    ) async throws -> ConsensusResult {

        var z = initialZ
        var u = agents.map { _ in Vector(repeating: 0.0, count: z.count) }

        for iteration in 0..<maxIterations {
            // Parallel x-updates (independent)
            let xUpdates = try await withThrowingTaskGroup(of: (Int, Vector).self) { group in
                for (i, agent) in agents.enumerated() {
                    group.addTask {
                        let xᵢ = try await agent.solveLocal(z: z, u: u[i], rho: rho)
                        return (i, xᵢ)
                    }
                }

                var results = [Int: Vector]()
                for try await (i, xᵢ) in group {
                    results[i] = xᵢ
                }
                return results
            }

            // z-update (aggregate)
            z = computeConsensus(xUpdates, u)

            // u-updates (parallel)
            u = updateDuals(xUpdates, z, u)

            // Check convergence
            if converged(...) {
                return ...
            }
        }
    }
}
```

### Phase 5.4: Applications (Week 3-4)

**Multi-Period Portfolio Optimization**:
```swift
// Optimize portfolio over T periods with transaction costs

// Variables:
// wₜ = portfolio weights at time t
// zₜ = auxiliary variables (trades)

// Objective:
// Σₜ [risk(wₜ) + transaction_cost(zₜ)]

// Coupling:
// wₜ = w_(t-1) + zₜ  (balance equation)

let admm = ADMMOptimizer()

let result = try admm.solve(
    xSubproblem: { wₜ, zₜ, u in
        // Minimize risk + augmented Lagrangian term
        minimizeRisk(wₜ, zₜ, u)
    },
    zSubproblem: { zₜ, wₜ, u in
        // Minimize transaction costs + augmented Lagrangian
        softThreshold(zₜ, transactionCostRate)
    },
    coupling: ...
)
```

**Lasso Regression**:
```swift
// min ||Ax - b||² + λ||x||₁

// Split: x = z, minimize ||Ax-b||² over x, λ||z||₁ over z

let result = try admm.solve(
    xSubproblem: { x, z, u in
        // Least squares: (AᵀA + ρI)x = Aᵀb + ρ(z - u)
        solve((AᵀA + ρI), Aᵀb + ρ*(z-u))
    },
    zSubproblem: { z, x, u in
        // Soft thresholding: z = S_{λ/ρ}(x + u)
        softThreshold(x + u, λ/rho)
    },
    coupling: (A: I, B: -I, c: zeros)
)
```

---

## Success Criteria

### Functional
- ✅ Solves Lasso, Ridge, Elastic Net problems
- ✅ Multi-period portfolio optimization with transaction costs
- ✅ Consensus ADMM for distributed optimization
- ✅ Parallel execution using Swift concurrency

### Performance
- ✅ Scales linearly with number of agents in parallel mode
- ✅ Lasso with n=10,000 variables in < 10 seconds
- ✅ Multi-period optimization (T=20 periods) in < 30 seconds

### Quality
- ✅ Converges to within 0.1% of centralized solution
- ✅ Primal and dual residuals < tolerance at convergence

---

## References

### Papers
1. **Boyd et al. (2011)**: "Distributed Optimization and Statistical Learning via ADMM" - Comprehensive tutorial
2. **Parikh & Boyd (2014)**: "Proximal Algorithms" - Foundation for subproblems

### Software
1. **ADMM by Boyd**: http://web.stanford.edu/~boyd/papers/admm/ - Reference implementations
2. **CVX with ADMM**: Many CVX problems can use ADMM backend

---

## Next Steps

After Phase 5:
1. Update [Roadmap.md](./Roadmap.md) - Tier 2 complete!
2. Proceed to [GRG.md](./GRG.md) for Excel parity (Phase 6)
