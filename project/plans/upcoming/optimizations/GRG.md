# Phase 6: GRG - Generalized Reduced Gradient

**Priority**: ⭐⭐⭐ (Tier 3 - Excel Parity)
**Effort**: 2-3 weeks
**Status**: Not Started
**Dependencies**: None
**Target Completion**: Week 20 of Q4 2026

---

## Overview

GRG (Generalized Reduced Gradient) is the **algorithm behind Excel Solver's nonlinear optimization**. Implementing it provides Excel Solver parity for users migrating from Excel.

**Historical Context**:
- Developed by Leon Lasdon & Warren in 1970s
- Excel Solver uses GRG2 (licensed from Frontline Systems)
- We'll implement the original public domain algorithm

**Problem Class**: Same as SQP
```
minimize f(x)
subject to:
    h_i(x) = 0  (equality constraints)
    g_j(x) ≤ 0  (inequality constraints)
    lb ≤ x ≤ ub (bounds)
```

**Key Difference from SQP**:
- SQP: Solves QP subproblems
- GRG: Uses **reduced gradient projection** directly on constraint manifold

**Why Implement GRG?**
1. ✅ **Excel parity**: Users familiar with Excel Solver expect it
2. ✅ **Marketing**: "Excel Solver compatible"
3. ✅ **Educational**: Classic algorithm, different approach than SQP
4. ❌ **Not better than SQP**: SQP generally superior in performance

**Recommendation**: Implement *after* SQP so we can position:
- GRG = "Excel-compatible, traditional method"
- SQP = "Modern, recommended method"

---

## Algorithm Overview

### Core Idea

GRG maintains feasibility by projecting gradient onto the **tangent space** of the constraint manifold.

**Variables Partition**:
- **Basic variables**: Determined by constraints (dependent)
- **Non-basic variables**: Free to vary (independent)

Similar to Simplex's basic/non-basic, but for nonlinear case.

### High-Level Algorithm

```
1. Choose partition: basic (B) and non-basic (N) variables
2. For current feasible point (xB, xN):
   a. Compute reduced gradient: ∇̃f = ∇f - ∇h·(∇hB)⁻¹·∇fB
   b. Search direction: d = -∇̃f (projected onto tangent space)
   c. Line search maintaining feasibility
   d. Update (xB, xN) along feasible direction
3. Repeat until ||∇̃f|| < tolerance
```

**Key Challenge**: Maintaining feasibility throughout optimization (vs SQP which may violate temporarily).

---

## Implementation Plan

### File Structure

```
Sources/BusinessMath/Optimization/Algorithms/
├── GRGOptimizer.swift                  (main GRG algorithm)
├── ReducedGradient.swift               (gradient projection)
└── BasicNonbasicPartition.swift        (variable partitioning)

Tests/BusinessMathTests/Optimization Tests/
└── GRGOptimizerTests.swift

Sources/BusinessMath/BusinessMath.docc/
└── 5.31-GRGTutorial.md
```

### Phase 6.1: Variable Partitioning (Week 1)

**Goal**: Partition variables into basic/non-basic sets

```swift
/// Partition of variables into basic (dependent) and non-basic (independent)
public struct VariablePartition {
    /// Indices of basic variables (determined by constraints)
    public let basicIndices: [Int]

    /// Indices of non-basic variables (free)
    public let nonbasicIndices: [Int]

    /// Total number of variables
    public let dimension: Int

    /// Create partition (initially, basic = first m variables)
    public init(
        dimension: Int,
        numberOfConstraints: Int
    ) {
        self.dimension = dimension
        self.basicIndices = Array(0..<numberOfConstraints)
        self.nonbasicIndices = Array(numberOfConstraints..<dimension)
    }

    /// Update partition by pivoting (swap basic/non-basic)
    public mutating func pivot(enteringIndex: Int, leavingIndex: Int)
}
```

### Phase 6.2: Reduced Gradient Computation (Week 1)

**Reduced Gradient Formula**:
```
∇̃f_N = ∇f_N - ∇h_N^T·(∇h_B)^(-1)·∇f_B
```

Where:
- ∇f_N = gradient w.r.t. non-basic variables
- ∇f_B = gradient w.r.t. basic variables
- ∇h_N, ∇h_B = constraint Jacobian partitioned

```swift
/// Compute reduced gradient for GRG algorithm
public struct ReducedGradientComputer {

    /// Compute reduced gradient at current point
    ///
    /// Returns gradient projected onto tangent space of constraints
    public func computeReducedGradient(
        objectiveGradient: Vector,
        constraintJacobian: Matrix,
        partition: VariablePartition
    ) throws -> Vector {

        let ∇f = objectiveGradient
        let ∇h = constraintJacobian

        // Partition gradient and Jacobian
        let ∇f_B = partition.basicIndices.map { ∇f[$0] }
        let ∇f_N = partition.nonbasicIndices.map { ∇f[$0] }

        let ∇h_B = extractColumns(∇h, partition.basicIndices)
        let ∇h_N = extractColumns(∇h, partition.nonbasicIndices)

        // Solve: ∇h_B^T · λ = ∇f_B
        let λ = try solveLinearSystem(∇h_B.transpose(), ∇f_B)

        // Reduced gradient: ∇̃f_N = ∇f_N - ∇h_N^T · λ
        let ∇̃f_N = ∇f_N - (∇h_N.transpose() * λ)

        // Expand to full dimension (zeros for basic variables)
        var reducedGradient = Vector(repeating: 0.0, count: partition.dimension)
        for (i, idx) in partition.nonbasicIndices.enumerated() {
            reducedGradient[idx] = ∇̃f_N[i]
        }

        return reducedGradient
    }
}
```

### Phase 6.3: GRG Main Algorithm (Week 2)

```swift
/// Generalized Reduced Gradient optimizer
///
/// Excel Solver-compatible algorithm for nonlinear constrained optimization.
///
/// ## Algorithm
///
/// GRG maintains feasibility by:
/// 1. Partitioning variables into basic (dependent) and non-basic (free)
/// 2. Computing reduced gradient (projection onto constraint tangent space)
/// 3. Moving along feasible direction
/// 4. Updating partition as needed
///
/// ## Comparison to SQP
///
/// - **GRG**: Classic algorithm, Excel Solver compatible
/// - **SQP**: Modern algorithm, generally faster convergence
///
/// **Use GRG when**:
/// - Migrating from Excel Solver
/// - Need strict feasibility throughout
/// - Comparing with Excel results
///
/// **Use SQP when**:
/// - Want fastest convergence
/// - Don't need Excel compatibility
///
/// ## Example
///
/// ```swift
/// let grg = GRGOptimizer<VectorN<Double>>()
///
/// let result = try grg.minimize(
///     portfolioVariance,
///     from: VectorN([0.33, 0.33, 0.34]),
///     subjectTo: [
///         .budgetConstraint,  // Σw = 1
///         .nonNegativity(dimension: 3)
///     ]
/// )
/// ```
public struct GRGOptimizer<V: VectorSpace> where V.Scalar: Real {

    public let tolerance: V.Scalar
    public let maxIterations: Int
    public let recordHistory: Bool

    public init(
        tolerance: V.Scalar = V.Scalar(1e-6),
        maxIterations: Int = 1000,
        recordHistory: Bool = false
    )

    /// Minimize objective subject to constraints
    public func minimize(
        _ objective: @escaping (V) -> V.Scalar,
        from initialGuess: V,
        subjectTo constraints: [MultivariateConstraint<V>]
    ) throws -> GRGResult<V> {

        // Separate constraint types
        let equalityConstraints = constraints.filter { $0.isEquality }
        let inequalityConstraints = constraints.filter { $0.isInequality }

        // Initial variable partition
        var partition = VariablePartition(
            dimension: V.dimension,
            numberOfConstraints: equalityConstraints.count
        )

        var x = initialGuess
        var history: [(Int, V, V.Scalar)]? = recordHistory ? [] : nil

        // Find initial feasible point
        x = try findFeasiblePoint(x, constraints: constraints)

        // Main GRG loop
        for iteration in 0..<maxIterations {

            // Evaluate at current point
            let f = objective(x)
            let ∇f = try numericalGradient(objective, at: x)

            // Evaluate constraints
            let h_values = equalityConstraints.map { $0.evaluate(at: x) }
            let g_values = inequalityConstraints.map { $0.evaluate(at: x) }

            // Constraint Jacobian
            let ∇h = try equalityConstraints.map { c in
                try numericalGradient({ x in c.evaluate(at: x) }, at: x)
            }

            // Compute reduced gradient
            let reducedGradient = try ReducedGradientComputer().computeReducedGradient(
                objectiveGradient: ∇f,
                constraintJacobian: ∇h,
                partition: partition
            )

            // Record history
            if recordHistory {
                history!.append((iteration, x, f))
            }

            // Check convergence
            if reducedGradient.norm() < tolerance {
                return GRGResult(
                    solution: x,
                    objectiveValue: f,
                    iterations: iteration + 1,
                    converged: true,
                    history: history
                )
            }

            // Search direction (negative reduced gradient)
            let direction = reducedGradient.scaled(by: V.Scalar(-1))

            // Line search along feasible direction
            let α = try feasibleLineSearch(
                objective: objective,
                x: x,
                direction: direction,
                constraints: constraints
            )

            // Update position
            x = x + direction.scaled(by: α)

            // Update partition if needed (basic variable at bound)
            updatePartitionIfNeeded(&partition, x, ∇h)
        }

        // Did not converge
        return GRGResult(
            solution: x,
            objectiveValue: objective(x),
            iterations: maxIterations,
            converged: false,
            history: history
        )
    }

    // MARK: - Private Helpers

    /// Find initial feasible point (Phase I)
    private func findFeasiblePoint(
        _ x: V,
        constraints: [MultivariateConstraint<V>]
    ) throws -> V {
        // Minimize constraint violation to get feasible starting point
        // Similar to Phase I in Simplex method
        // ... implementation ...
    }

    /// Line search maintaining feasibility
    private func feasibleLineSearch(
        objective: @escaping (V) -> V.Scalar,
        x: V,
        direction: V,
        constraints: [MultivariateConstraint<V>]
    ) throws -> V.Scalar {
        // Find step size that maintains feasibility and reduces objective
        // ... implementation ...
    }
}

public struct GRGResult<V: VectorSpace> where V.Scalar: Real {
    public let solution: V
    public let objectiveValue: V.Scalar
    public let iterations: Int
    public let converged: Bool
    public let history: [(Int, V, V.Scalar)]?

    func negated() -> GRGResult<V>  // For maximize
}
```

### Phase 6.4: Testing & Benchmarking (Week 2-3)

**Test Cases**:
```swift
func testGRGvsExcelSolver() {
    // Test problems from Excel Solver examples
    // Verify we get same results (within tolerance)

    let grg = GRGOptimizer<VectorN<Double>>()

    // Example: Portfolio optimization (Excel Solver standard example)
    let result = try grg.minimize(portfolioVariance, from: initialWeights, subjectTo: constraints)

    // Compare to known Excel Solver solution
    XCTAssertEqual(result.objectiveValue, excelSolution, accuracy: 1e-3)
}

func testGRGvsSQP() {
    // Compare GRG and SQP on same problems
    // SQP should be faster, same solution

    let grg = GRGOptimizer<VectorN<Double>>()
    let sqp = SQPOptimizer<VectorN<Double>>()

    let grgResult = try grg.minimize(objective, from: x0, subjectTo: constraints)
    let sqpResult = try sqp.minimize(objective, from: x0, subjectTo: constraints)

    // Same solution
    XCTAssertEqual(grgResult.objectiveValue, sqpResult.objectiveValue, accuracy: 1e-4)

    // SQP typically faster
    XCTAssertLessThan(sqpResult.iterations, grgResult.iterations * 0.7)

    print("GRG: \(grgResult.iterations) iterations")
    print("SQP: \(sqpResult.iterations) iterations")
}
```

### Phase 6.5: Documentation (Week 3)

**Tutorial**: `5.31-GRGTutorial.md`

Topics:
- Excel Solver migration guide
- When to use GRG vs SQP
- Reduced gradient concept explained
- Portfolio optimization example (matching Excel)
- Performance comparison: GRG vs SQP vs Augmented Lagrangian

---

## Success Criteria

### Functional
- ✅ Solves same problems as Excel Solver
- ✅ Maintains feasibility throughout optimization
- ✅ Handles equality and inequality constraints
- ✅ Works with `VectorN<Double>`

### Performance
- ✅ **Matches Excel Solver results** within 1e-3
- ✅ Converges in < 200 iterations typical
- ✅ < 2× slower than SQP (acceptable trade-off for Excel parity)

### Documentation
- ✅ Excel Solver migration guide
- ✅ Side-by-side comparison with Excel examples
- ✅ Clear guidance on when to use GRG vs SQP

---

## References

### Papers
1. **Lasdon, Waren, et al. (1978)**: "Design and Testing of a Generalized Reduced Gradient Code for Nonlinear Programming" - Original GRG paper
2. **Abadie & Carpentier (1969)**: "Generalization of the Wolfe Reduced Gradient Method" - Foundation

### Software
1. **Excel Solver** (GRG Nonlinear engine) - Reference implementation
2. **LSGRG2** - Original Lasdon implementation (public domain)

### Excel Documentation
1. Microsoft Excel Solver documentation
2. Frontline Systems Solver documentation (Excel's provider)

---

## Next Steps

After Phase 6:
1. Update [Roadmap.md](./Roadmap.md)
2. Excel migration guide complete
3. Optional: Proceed to Phase 7+ (Network Flow, Global, DP)

---

**Note**: GRG is lowest priority Tier 3. Consider implementing only if:
- Strong user demand for Excel parity
- Marketing requires "Excel Solver compatible" claim
- SQP proves insufficient for some use cases (unlikely)

Otherwise, position SQP as "better than Excel Solver's GRG" and skip GRG implementation.
