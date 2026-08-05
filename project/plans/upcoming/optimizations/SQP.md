# Phase 1: SQP - Sequential Quadratic Programming

**Priority**: ⭐⭐⭐⭐⭐ (Highest - Tier 1)
**Effort**: 2-3 weeks
**Status**: Not Started
**Dependencies**: None (uses existing infrastructure)
**Target Completion**: Week 3 of Q2 2026

---

## Overview

Sequential Quadratic Programming (SQP) is **the industry standard algorithm** for nonlinear constrained optimization. It is used by:
- MATLAB's `fmincon` (default algorithm)
- SciPy's `scipy.optimize.minimize` with `method='SLSQP'`
- Commercial solvers: SNOPT, IPOPT (variant), KNITRO

**Problem Class**: Nonlinear programming (NLP)
```
minimize f(x)
subject to:
    h_i(x) = 0  (equality constraints)
    g_j(x) ≤ 0  (inequality constraints)
    lb ≤ x ≤ ub (bounds)
```

**Why SQP?**
1. **Better than Augmented Lagrangian**: Typically converges in fewer iterations with superlinear convergence
2. **Industry standard**: What professionals expect and use
3. **Well-understood**: Extensive literature, proven robustness
4. **Natural fit**: Solves a quadratic program (QP) at each iteration - we can implement QP solver or use penalties

---

## Algorithm Overview

### Core Idea

SQP treats the NLP as a **sequence of quadratic programming (QP) subproblems**:

At iteration k:
1. Build a quadratic approximation to the Lagrangian
2. Linearize the constraints
3. Solve the resulting QP to get search direction
4. Take a step along that direction
5. Update Lagrange multipliers

### Mathematical Formulation

**Lagrangian**:
```
L(x, λ, μ) = f(x) + Σᵢ λᵢ·hᵢ(x) + Σⱼ μⱼ·gⱼ(x)
```

**QP Subproblem at iteration k** (solve for step d):
```
minimize   ∇f(xₖ)ᵀd + ½dᵀBₖd
subject to:
    hᵢ(xₖ) + ∇hᵢ(xₖ)ᵀd = 0        (linearized equality constraints)
    gⱼ(xₖ) + ∇gⱼ(xₖ)ᵀd ≤ 0        (linearized inequality constraints)
```

Where:
- `Bₖ` = Hessian approximation (updated via BFGS)
- `d` = search direction (solution to QP)
- `xₖ₊₁ = xₖ + αₖ·d` (with line search parameter αₖ)

**Lagrange Multiplier Update**:
The QP multipliers become the next estimates: `λₖ₊₁`, `μₖ₊₁` from QP dual solution.

### High-Level Pseudocode

```swift
func SQP(objective, constraints, x0, λ0, μ0):
    x = x0
    λ = λ0  // Equality multipliers
    μ = μ0  // Inequality multipliers
    B = I   // Initial Hessian approximation (identity)

    for k in 1...maxIterations:
        // 1. Evaluate at current point
        f = objective(x)
        ∇f = gradient(objective, x)
        h = evaluate_equality_constraints(x)
        g = evaluate_inequality_constraints(x)
        ∇h = jacobian(equality_constraints, x)
        ∇g = jacobian(inequality_constraints, x)

        // 2. Check convergence
        if KKT_conditions_satisfied(∇f, ∇h, ∇g, h, g, λ, μ):
            return success(x, λ, μ)

        // 3. Solve QP subproblem
        (d, λ_new, μ_new) = solve_QP(
            Q: B,
            c: ∇f,
            A_eq: ∇h,
            b_eq: -h,
            A_ineq: ∇g,
            b_ineq: -g
        )

        // 4. Line search on merit function
        α = line_search_merit(x, d, λ, μ)

        // 5. Update position and multipliers
        x_new = x + α * d
        λ = λ_new
        μ = μ_new

        // 6. Update Hessian approximation (BFGS)
        s = x_new - x
        y = ∇L(x_new) - ∇L(x)
        B = BFGS_update(B, s, y)

        x = x_new

    return failure(x, λ, μ)
```

---

## Implementation Plan

### File Structure

```
Sources/BusinessMath/Optimization/Algorithms/
├── SQPOptimizer.swift               (main implementation)
├── QPSolver.swift                   (quadratic programming solver)
└── MeritFunction.swift              (L1 merit function for line search)

Tests/BusinessMathTests/Optimization Tests/
└── SQPOptimizerTests.swift         (comprehensive test suite)

Sources/BusinessMath/BusinessMath.docc/
└── 5.26-SQPOptimizationTutorial.md (tutorial)
```

### Phase 1.1: QP Solver (Week 1)

**Why First**: SQP requires solving a QP at each iteration. This is the foundational capability.

**Implementation**: Active-set QP solver for small-medium problems

```swift
/// Solves quadratic programming problems of the form:
///
/// minimize   ½xᵀQx + cᵀx
/// subject to:
///     Aₑq·x = bₑq   (equality constraints)
///     Aᵢₙₑq·x ≤ bᵢₙₑq (inequality constraints)
public struct QPSolver<V: VectorSpace> where V.Scalar: Real {

    public init(
        tolerance: V.Scalar = V.Scalar(1e-6),
        maxIterations: Int = 1000
    )

    /// Solve QP using active-set method
    public func solve(
        Q: [[V.Scalar]],          // n×n Hessian matrix (symmetric)
        c: V,                      // n×1 linear term
        equalityConstraints: [(A: [V.Scalar], b: V.Scalar)] = [],
        inequalityConstraints: [(A: [V.Scalar], b: V.Scalar)] = [],
        bounds: (lower: V, upper: V)? = nil
    ) throws -> QPResult<V>
}

public struct QPResult<V: VectorSpace> where V.Scalar: Real {
    public let solution: V              // Optimal x
    public let objectiveValue: V.Scalar // ½xᵀQx + cᵀx at optimum
    public let equalityMultipliers: [V.Scalar]
    public let inequalityMultipliers: [V.Scalar]
    public let activeSet: Set<Int>      // Active inequality constraint indices
    public let iterations: Int
    public let converged: Bool
}
```

**Active-Set Algorithm**:
1. Start with a feasible point (find initial feasible or use penalty)
2. Solve equality-constrained QP for current working set
3. Check KKT conditions
4. If violated, add/remove constraints from working set
5. Iterate until optimal

**Test Cases**:
- Unconstrained QP (should match analytical solution)
- Equality-constrained QP
- Inequality-constrained QP with known active set
- Portfolio optimization QP: `min ½wᵀΣw` subject to `Σw=1, w≥0`

**References**:
- Nocedal & Wright, Chapter 16 "Quadratic Programming"
- Gill & Murray active-set method

---

### Phase 1.2: Merit Function (Week 1)

**Why**: SQP needs a merit function for line search to ensure global convergence. Can't just use objective f(x) because we need to balance objective improvement vs constraint satisfaction.

**Implementation**: L1 exact penalty merit function

```swift
/// L1 exact penalty merit function for SQP line search
///
/// φ(x; ρ) = f(x) + ρ·(Σᵢ|hᵢ(x)| + Σⱼ max(0, gⱼ(x)))
///
/// Where ρ is the penalty parameter (must be sufficiently large)
public struct L1MeritFunction<V: VectorSpace> where V.Scalar: Real {
    private let objective: (V) -> V.Scalar
    private let equalityConstraints: [(V) -> V.Scalar]
    private let inequalityConstraints: [(V) -> V.Scalar]
    public private(set) var penaltyParameter: V.Scalar

    public init(
        objective: @escaping (V) -> V.Scalar,
        equalityConstraints: [(V) -> V.Scalar],
        inequalityConstraints: [(V) -> V.Scalar],
        initialPenalty: V.Scalar = V.Scalar(1)
    )

    /// Evaluate merit function at point x
    public func evaluate(at x: V) -> V.Scalar {
        var merit = objective(x)

        // Add equality constraint violations: |h(x)|
        for h in equalityConstraints {
            merit = merit + penaltyParameter * abs(h(x))
        }

        // Add inequality constraint violations: max(0, g(x))
        for g in inequalityConstraints {
            merit = merit + penaltyParameter * max(V.Scalar(0), g(x))
        }

        return merit
    }

    /// Update penalty parameter (increase if needed for descent)
    public mutating func updatePenalty(
        lagrangeMultipliers: [V.Scalar],
        margin: V.Scalar = V.Scalar(0.1)
    ) {
        // Choose ρ > ||λ|| + margin to ensure descent property
        let maxMultiplier = lagrangeMultipliers.map { abs($0) }.max() ?? V.Scalar(0)
        let requiredPenalty = maxMultiplier + margin

        if penaltyParameter < requiredPenalty {
            penaltyParameter = requiredPenalty
        }
    }
}
```

**Line Search Integration**:
```swift
// In SQP iteration:
let merit = L1MeritFunction(objective, equalityConstraints, inequalityConstraints)
merit.updatePenalty(lagrangeMultipliers: λ)

let α = backtrackingLineSearch(
    function: { t in merit.evaluate(at: x + t * direction) },
    initialValue: 1.0,
    sufficientDecrease: 1e-4  // Armijo constant
)
```

**Test Cases**:
- Merit function decreases along feasible descent direction
- Penalty parameter update ensures descent
- Line search with merit function converges

---

### Phase 1.3: SQP Main Algorithm (Week 2)

**Implementation**: Full SQP optimizer

```swift
/// Sequential Quadratic Programming optimizer for nonlinear constrained optimization
///
/// Solves problems of the form:
/// ```
/// minimize f(x)
/// subject to:
///     hᵢ(x) = 0  for i = 1..mₑ   (equality constraints)
///     gⱼ(x) ≤ 0  for j = 1..mᵢ   (inequality constraints)
/// ```
///
/// ## Algorithm
///
/// SQP iteratively solves quadratic programming (QP) subproblems that approximate
/// the original NLP. At each iteration k:
///
/// 1. Build QP subproblem by quadratically approximating the Lagrangian and linearizing constraints
/// 2. Solve QP to get search direction and updated multipliers
/// 3. Line search on L1 merit function to ensure global convergence
/// 4. Update Hessian approximation via BFGS
///
/// ## Performance
///
/// - **Convergence**: Superlinear near optimum (faster than augmented Lagrangian)
/// - **Typical iterations**: 10-50 for well-scaled problems
/// - **Memory**: O(n²) for dense Hessian approximation
///
/// ## Example
///
/// ```swift
/// let optimizer = SQPOptimizer<VectorN<Double>>()
///
/// // Minimize portfolio variance with budget constraint
/// let result = try optimizer.minimize(
///     { weights in portfolioVariance(weights) },
///     from: VectorN([0.33, 0.33, 0.34]),
///     subjectTo: [
///         .equality({ w in w.sum() - 1.0 }),  // Σw = 1
///         .nonNegativity(dimension: 3)         // w ≥ 0
///     ]
/// )
///
/// print("Optimal weights: \(result.solution)")
/// print("Minimum variance: \(result.objectiveValue)")
/// print("Converged in \(result.iterations) iterations")
/// ```
public struct SQPOptimizer<V: VectorSpace> where V.Scalar: Real {

    /// Convergence tolerance for KKT conditions
    public let tolerance: V.Scalar

    /// Maximum number of SQP iterations
    public let maxIterations: Int

    /// QP solver for subproblems
    private let qpSolver: QPSolver<V>

    /// Whether to record optimization history
    public let recordHistory: Bool

    public init(
        tolerance: V.Scalar = V.Scalar(1e-6),
        maxIterations: Int = 100,
        qpTolerance: V.Scalar = V.Scalar(1e-8),
        qpMaxIterations: Int = 1000,
        recordHistory: Bool = false
    ) {
        self.tolerance = tolerance
        self.maxIterations = maxIterations
        self.qpSolver = QPSolver(
            tolerance: qpTolerance,
            maxIterations: qpMaxIterations
        )
        self.recordHistory = recordHistory
    }

    // MARK: - Public API

    /// Minimize an objective function subject to constraints
    ///
    /// - Parameters:
    ///   - objective: Function to minimize f: V → ℝ
    ///   - initialGuess: Starting point for optimization
    ///   - constraints: Equality and inequality constraints
    /// - Returns: Optimization result with solution, multipliers, and convergence info
    /// - Throws: `OptimizationError` if optimization fails or QP subproblems infeasible
    public func minimize(
        _ objective: @escaping (V) -> V.Scalar,
        from initialGuess: V,
        subjectTo constraints: [MultivariateConstraint<V>]
    ) throws -> SQPResult<V> {

        // Separate constraints by type
        let equalityConstraints = constraints.filter { $0.isEquality }
        let inequalityConstraints = constraints.filter { $0.isInequality }

        // Initialize
        var x = initialGuess
        var B = identityMatrix(dimension: V.dimension) // Hessian approx
        var λ = [V.Scalar](repeating: V.Scalar(0), count: equalityConstraints.count)
        var μ = [V.Scalar](repeating: V.Scalar(0), count: inequalityConstraints.count)

        var history: [(Int, V, V.Scalar, V.Scalar)]? = recordHistory ? [] : nil

        // Merit function for line search
        var merit = L1MeritFunction(
            objective: objective,
            equalityConstraints: equalityConstraints.map { c in { x in c.evaluate(at: x) } },
            inequalityConstraints: inequalityConstraints.map { c in { x in c.evaluate(at: x) } },
            initialPenalty: V.Scalar(1)
        )

        // Main SQP loop
        for iteration in 0..<maxIterations {

            // 1. Evaluate current point
            let f = objective(x)
            let ∇f = try numericalGradient(objective, at: x)

            let h_values = equalityConstraints.map { $0.evaluate(at: x) }
            let g_values = inequalityConstraints.map { $0.evaluate(at: x) }

            let ∇h = try equalityConstraints.map { c in
                try numericalGradient({ x in c.evaluate(at: x) }, at: x)
            }
            let ∇g = try inequalityConstraints.map { c in
                try numericalGradient({ x in c.evaluate(at: x) }, at: x)
            }

            // 2. Check KKT conditions
            let kkt_violation = computeKKTViolation(∇f, ∇h, ∇g, h_values, g_values, λ, μ)

            if recordHistory {
                let max_constraint_viol = max(
                    h_values.map { abs($0) }.max() ?? V.Scalar(0),
                    g_values.map { max(V.Scalar(0), $0) }.max() ?? V.Scalar(0)
                )
                history!.append((iteration, x, f, max_constraint_viol))
            }

            if kkt_violation < tolerance {
                return SQPResult(
                    solution: x,
                    objectiveValue: f,
                    equalityMultipliers: λ,
                    inequalityMultipliers: μ,
                    iterations: iteration + 1,
                    converged: true,
                    history: history,
                    kktViolation: kkt_violation
                )
            }

            // 3. Build and solve QP subproblem
            let qpResult = try solveQPSubproblem(
                B: B,
                ∇f: ∇f,
                h_values: h_values,
                g_values: g_values,
                ∇h: ∇h,
                ∇g: ∇g
            )

            let direction = qpResult.solution
            λ = qpResult.equalityMultipliers
            μ = qpResult.inequalityMultipliers

            // 4. Update merit function penalty parameter
            merit.updatePenalty(lagrangeMultipliers: λ + μ)

            // 5. Line search
            let α = backtrackingLineSearch(
                function: { t in merit.evaluate(at: x + direction.scaled(by: t)) },
                initialValue: V.Scalar(1),
                sufficientDecrease: V.Scalar(1) / V.Scalar(10_000)
            )

            // 6. Update position
            let x_new = x + direction.scaled(by: α)

            // 7. Update Hessian approximation (BFGS)
            let s = x_new - x
            let ∇L_old = computeLagrangianGradient(x, ∇f, ∇h, ∇g, λ, μ)
            let ∇L_new = try computeLagrangianGradient(
                x_new,
                try numericalGradient(objective, at: x_new),
                try equalityConstraints.map { c in try numericalGradient({ x in c.evaluate(at: x) }, at: x_new) },
                try inequalityConstraints.map { c in try numericalGradient({ x in c.evaluate(at: x) }, at: x_new) },
                λ,
                μ
            )
            let y = ∇L_new - ∇L_old

            B = bfgsUpdate(B: B, s: s, y: y)

            x = x_new
        }

        // Did not converge
        let final_f = objective(x)
        let final_kkt = computeKKTViolation(...)

        return SQPResult(
            solution: x,
            objectiveValue: final_f,
            equalityMultipliers: λ,
            inequalityMultipliers: μ,
            iterations: maxIterations,
            converged: false,
            history: history,
            kktViolation: final_kkt
        )
    }

    /// Maximize an objective function subject to constraints
    public func maximize(
        _ objective: @escaping (V) -> V.Scalar,
        from initialGuess: V,
        subjectTo constraints: [MultivariateConstraint<V>]
    ) throws -> SQPResult<V> {
        let result = try minimize({ -objective($0) }, from: initialGuess, subjectTo: constraints)
        return result.negated()
    }

    // MARK: - Private Helpers

    private func solveQPSubproblem(
        B: [[V.Scalar]],
        ∇f: V,
        h_values: [V.Scalar],
        g_values: [V.Scalar],
        ∇h: [V],
        ∇g: [V]
    ) throws -> QPResult<V> {
        // Build QP:
        // min ∇fᵀd + ½dᵀBd
        // s.t. hᵢ + ∇hᵢᵀd = 0
        //      gⱼ + ∇gⱼᵀd ≤ 0

        let eqConstraints = zip(h_values, ∇h).map { (h, ∇h) in
            (A: ∇h.toArray(), b: -h)  // ∇hᵀd = -h (linearized equality)
        }

        let ineqConstraints = zip(g_values, ∇g).map { (g, ∇g) in
            (A: ∇g.toArray(), b: -g)  // ∇gᵀd ≤ -g (linearized inequality)
        }

        return try qpSolver.solve(
            Q: B,
            c: ∇f,
            equalityConstraints: eqConstraints,
            inequalityConstraints: ineqConstraints
        )
    }

    private func computeKKTViolation(
        _ ∇f: V,
        _ ∇h: [V],
        _ ∇g: [V],
        _ h_values: [V.Scalar],
        _ g_values: [V.Scalar],
        _ λ: [V.Scalar],
        _ μ: [V.Scalar]
    ) -> V.Scalar {
        // KKT conditions:
        // 1. Stationarity: ∇f + Σλᵢ∇hᵢ + Σμⱼ∇gⱼ = 0
        // 2. Primal feasibility: h = 0, g ≤ 0
        // 3. Dual feasibility: μ ≥ 0
        // 4. Complementarity: μⱼ·gⱼ = 0

        var violation = V.Scalar(0)

        // Stationarity
        var stationarity = ∇f
        for (i, grad) in ∇h.enumerated() {
            stationarity = stationarity + grad.scaled(by: λ[i])
        }
        for (j, grad) in ∇g.enumerated() {
            stationarity = stationarity + grad.scaled(by: μ[j])
        }
        violation = max(violation, stationarity.norm())

        // Primal feasibility
        let primal_viol = max(
            h_values.map { abs($0) }.max() ?? V.Scalar(0),
            g_values.map { max(V.Scalar(0), $0) }.max() ?? V.Scalar(0)
        )
        violation = max(violation, primal_viol)

        // Dual feasibility (μ ≥ 0)
        let dual_viol = μ.map { max(V.Scalar(0), -$0) }.max() ?? V.Scalar(0)
        violation = max(violation, dual_viol)

        // Complementarity (μⱼ·gⱼ ≈ 0)
        let comp_viol = zip(μ, g_values).map { abs($0 * $1) }.max() ?? V.Scalar(0)
        violation = max(violation, comp_viol)

        return violation
    }
}
```

**Result Type**:
```swift
public struct SQPResult<V: VectorSpace> where V.Scalar: Real {
    public let solution: V
    public let objectiveValue: V.Scalar
    public let equalityMultipliers: [V.Scalar]
    public let inequalityMultipliers: [V.Scalar]
    public let iterations: Int
    public let converged: Bool
    public let history: [(Int, V, V.Scalar, V.Scalar)]?
    public let kktViolation: V.Scalar

    func negated() -> SQPResult<V>  // For maximize
}
```

---

### Phase 1.4: Testing (Week 2)

**Test Suite** (`SQPOptimizerTests.swift`):

```swift
class SQPOptimizerTests: XCTestCase {

    // MARK: - Unconstrained (should match BFGS)

    func testUnconstrainedRosenbrock() {
        let optimizer = SQPOptimizer<VectorN<Double>>()

        let result = try optimizer.minimize(
            rosenbrock,
            from: VectorN([-1.2, 1.0]),
            subjectTo: []  // No constraints
        )

        XCTAssertTrue(result.converged)
        XCTAssertEqual(result.solution[0], 1.0, accuracy: 1e-4)
        XCTAssertEqual(result.solution[1], 1.0, accuracy: 1e-4)
        XCTAssertLessThan(result.objectiveValue, 1e-6)
    }

    // MARK: - Equality Constraints

    func testEqualityConstrainedQuadratic() {
        // min ½(x² + y²)  s.t.  x + y = 1
        // Analytical solution: x = y = 0.5, f = 0.25

        let optimizer = SQPOptimizer<VectorN<Double>>()

        let objective: (VectorN<Double>) -> Double = { v in
            0.5 * (v[0]*v[0] + v[1]*v[1])
        }

        let result = try optimizer.minimize(
            objective,
            from: VectorN([0.0, 0.0]),
            subjectTo: [
                .equality({ v in v[0] + v[1] - 1.0 })
            ]
        )

        XCTAssertTrue(result.converged)
        XCTAssertEqual(result.solution[0], 0.5, accuracy: 1e-5)
        XCTAssertEqual(result.solution[1], 0.5, accuracy: 1e-5)
        XCTAssertEqual(result.objectiveValue, 0.25, accuracy: 1e-6)
    }

    // MARK: - Inequality Constraints

    func testInequalityConstrainedQuadratic() {
        // min ½(x² + y²)  s.t.  x + y ≥ 1  (i.e., -(x+y-1) ≤ 0)
        // Solution: x = y = 0.5 (constraint active)

        let optimizer = SQPOptimizer<VectorN<Double>>()

        let objective: (VectorN<Double>) -> Double = { v in
            0.5 * (v[0]*v[0] + v[1]*v[1])
        }

        let result = try optimizer.minimize(
            objective,
            from: VectorN([0.0, 0.0]),
            subjectTo: [
                .inequality({ v in -(v[0] + v[1] - 1.0) })  // x+y ≥ 1
            ]
        )

        XCTAssertTrue(result.converged)
        XCTAssertEqual(result.solution[0], 0.5, accuracy: 1e-4)
        XCTAssertEqual(result.solution[1], 0.5, accuracy: 1e-4)
        XCTAssertGreaterThan(result.inequalityMultipliers[0], 0)  // Active
    }

    // MARK: - Portfolio Optimization

    func testPortfolioOptimization() {
        // min ½wᵀΣw  s.t.  Σw = 1, w ≥ 0

        let Σ = [
            [0.04, 0.01, 0.02],
            [0.01, 0.09, 0.03],
            [0.02, 0.03, 0.16]
        ]

        let objective: (VectorN<Double>) -> Double = { w in
            var variance = 0.0
            for i in 0..<3 {
                for j in 0..<3 {
                    variance += 0.5 * w[i] * Σ[i][j] * w[j]
                }
            }
            return variance
        }

        let optimizer = SQPOptimizer<VectorN<Double>>()

        let result = try optimizer.minimize(
            objective,
            from: VectorN([0.33, 0.33, 0.34]),
            subjectTo: [
                .budgetConstraint,  // Σw = 1
                .nonNegativity(dimension: 3)  // w ≥ 0
            ]
        )

        XCTAssertTrue(result.converged)
        XCTAssertEqual(result.solution.sum(), 1.0, accuracy: 1e-4)
        XCTAssertTrue(result.solution.toArray().allSatisfy { $0 >= -1e-6 })

        // Should be heavily weighted to asset 0 (lowest variance)
        XCTAssertGreaterThan(result.solution[0], 0.5)
    }

    // MARK: - Nonlinear Constraints

    func testNonlinearConstraint() {
        // min x²+y²  s.t.  x²+y² ≥ 1 (circle constraint)
        // Solution: any point on unit circle, e.g. (1/√2, 1/√2)

        let optimizer = SQPOptimizer<VectorN<Double>>()

        let objective: (VectorN<Double>) -> Double = { v in
            v[0]*v[0] + v[1]*v[1]
        }

        let result = try optimizer.minimize(
            objective,
            from: VectorN([0.5, 0.5]),
            subjectTo: [
                .inequality({ v in -(v[0]*v[0] + v[1]*v[1] - 1.0) })  // x²+y² ≥ 1
            ]
        )

        XCTAssertTrue(result.converged)
        let radius = sqrt(result.solution[0]*result.solution[0] +
                         result.solution[1]*result.solution[1])
        XCTAssertEqual(radius, 1.0, accuracy: 1e-4)
    }

    // MARK: - CUTEst Benchmark Problems

    func testHS71() {
        // Hock-Schittkowski problem 71
        // min x₁x₄(x₁+x₂+x₃)+x₃
        // s.t. x₁x₂x₃x₄ ≥ 25
        //      x₁²+x₂²+x₃²+x₄² = 40
        //      1 ≤ xᵢ ≤ 5
        //
        // Known solution: x* = [1, 4.743, 3.821, 1.379], f* = 17.014

        let optimizer = SQPOptimizer<VectorN<Double>>()

        let objective: (VectorN<Double>) -> Double = { x in
            x[0]*x[3]*(x[0]+x[1]+x[2]) + x[2]
        }

        let result = try optimizer.minimize(
            objective,
            from: VectorN([1.0, 5.0, 5.0, 1.0]),
            subjectTo: [
                .inequality({ x in -(x[0]*x[1]*x[2]*x[3] - 25.0) }),  // ≥ 25
                .equality({ x in x[0]*x[0] + x[1]*x[1] + x[2]*x[2] + x[3]*x[3] - 40.0 })
                // Bounds handled by explicit inequality constraints
            ]
        )

        XCTAssertTrue(result.converged)
        XCTAssertEqual(result.objectiveValue, 17.014, accuracy: 0.01)
    }

    // MARK: - Performance Benchmark

    func testPerformanceVsAugmentedLagrangian() {
        // Compare SQP vs current Augmented Lagrangian on same problem

        let objective: (VectorN<Double>) -> Double = { v in
            rosenbrock(v)
        }

        let constraints = [
            MultivariateConstraint<VectorN<Double>>.equality({ v in v[0] + v[1] - 2.0 })
        ]

        // SQP
        let sqp = SQPOptimizer<VectorN<Double>>()
        let sqpResult = try sqp.minimize(objective, from: VectorN([0.0, 0.0]), subjectTo: constraints)

        // Augmented Lagrangian
        let al = ConstrainedOptimizer<VectorN<Double>>()
        let alResult = try al.minimize(objective, from: VectorN([0.0, 0.0]), subjectTo: constraints)

        // Both should converge to same solution
        XCTAssertEqual(sqpResult.objectiveValue, alResult.objectiveValue, accuracy: 1e-3)

        // SQP should take fewer iterations (superlinear convergence)
        XCTAssertLessThan(sqpResult.iterations, alResult.iterations * 0.7)

        print("SQP: \(sqpResult.iterations) iterations")
        print("Augmented Lagrangian: \(alResult.iterations) iterations")
    }
}
```

**Benchmark Suite** (compare to reference implementations):
1. CUTEst test problems (HS series)
2. Portfolio optimization problems
3. Engineering design problems (pressure vessel, etc.)
4. Comparison to MATLAB `fmincon`, SciPy `SLSQP`

---

### Phase 1.5: Documentation (Week 3)

**Tutorial**: `5.26-SQPOptimizationTutorial.md`

Outline:
```markdown
# Sequential Quadratic Programming (SQP)

## What is SQP?

Industry-standard algorithm for nonlinear constrained optimization...

## When to Use SQP

- Nonlinear objectives and constraints
- Both equality and inequality constraints
- Smooth (differentiable) functions
- Medium-scale problems (n < 1,000)

**Use SQP over Augmented Lagrangian when:**
- You need fast convergence (fewer iterations)
- Constraints are moderately nonlinear
- You want to match MATLAB/SciPy behavior

**Use Augmented Lagrangian when:**
- Constraints are highly nonlinear
- Robustness more important than speed
- QP subproblems might be ill-conditioned

## Basic Example: Portfolio Optimization

[Full example with covariance matrix, budget constraint, non-negativity]

## Understanding the Algorithm

[Explanation of QP subproblems, merit function, BFGS Hessian]

## Advanced Example: Constrained Rosenbrock

[Show SQP converging faster than augmented Lagrangian]

## Performance Tuning

[QP tolerance, line search parameters, Hessian initialization]

## Troubleshooting

- QP subproblem infeasible → initial guess violates constraints
- Slow convergence → try better initial Hessian or tighten QP tolerance
- Line search fails → merit function penalty parameter too small

## Comparison to Other Methods

[Table: SQP vs Augmented Lagrangian vs Interior Point vs GRG]

## References

- Nocedal & Wright (2006), Numerical Optimization, Chapter 18
- Boggs & Tolle (1995), "Sequential Quadratic Programming"
```

**Update Main Optimization Guide** (5.1-OptimizationGuide.md):
- Add SQP to algorithm selection flowchart
- Update recommended methods: "For constrained nonlinear problems, use SQP"
- Add performance comparison table

**Update Portfolio Optimization Guide** (5.2-PortfolioOptimizationGuide.md):
- Replace `InequalityOptimizer` examples with `SQPOptimizer`
- Show performance improvement

---

## Success Criteria

### Functional
- ✅ Passes all unit tests with >95% coverage
- ✅ Converges to correct solution on CUTEst benchmark problems
- ✅ Handles equality-only, inequality-only, and mixed constraints
- ✅ Works with `VectorN<Double>` and other `VectorSpace` types

### Performance
- ✅ **Converges in <50% iterations vs Augmented Lagrangian** on standard problems
- ✅ Achieves superlinear convergence rate near optimum
- ✅ QP subproblems solve in <100ms for n=100
- ✅ Handles problems with n=500 variables, m=100 constraints

### Quality
- ✅ KKT violation <1e-6 at convergence
- ✅ Constraint satisfaction <1e-6
- ✅ Solutions match MATLAB `fmincon` within 1e-4

### Documentation
- ✅ Complete tutorial with 3+ examples
- ✅ Algorithm explanation for non-experts
- ✅ Performance comparison to existing methods
- ✅ Troubleshooting guide

---

## References

### Academic Papers
1. **Wilson (1963)**: "A Simplex Method for Convex Programming" - Original SQP idea
2. **Han (1976)**: "Superlinearly Convergent Variable Metric Algorithms" - Proves superlinear convergence
3. **Powell (1978)**: "The Convergence of Variable Metric Methods" - L1 merit function
4. **Boggs & Tolle (1995)**: "Sequential Quadratic Programming" (SIAM Review) - Comprehensive survey

### Textbooks
1. **Nocedal & Wright (2006)**: "Numerical Optimization", Chapter 18 - Primary reference
2. **Fletcher (2013)**: "Practical Methods of Optimization", Chapter 10
3. **Gill, Murray, Wright (1981)**: "Practical Optimization" - Active-set QP methods

### Reference Implementations
1. **MATLAB `fmincon`** with `Algorithm='sqp'`
2. **SciPy `scipy.optimize.minimize`** with `method='SLSQP'` (Sequential Least Squares Programming)
3. **SNOPT** - Commercial solver using SQP
4. **NLOPT** - Open-source `NLOPT_LD_SLSQP` algorithm

### Test Problems
1. **CUTEst** test set: http://www.cuter.rl.ac.uk/Problems/mastsif.shtml
   - Hock-Schittkowski (HS) problems: HS71, HS100, etc.
2. **Schittkowski (1987)**: "More Test Examples for Nonlinear Programming Codes"

---

## Implementation Checklist

### Week 1: Foundations
- [ ] Implement `QPSolver` with active-set method
- [ ] Test QP solver on unconstrained, equality-constrained, inequality-constrained QPs
- [ ] Implement `L1MeritFunction`
- [ ] Test merit function with line search

### Week 2: Main Algorithm
- [ ] Implement `SQPOptimizer` main loop
- [ ] Implement KKT violation check
- [ ] Implement BFGS Hessian update
- [ ] Test on equality-constrained problems
- [ ] Test on inequality-constrained problems
- [ ] Test on mixed equality/inequality problems

### Week 3: Testing & Documentation
- [ ] Comprehensive test suite (10+ test cases)
- [ ] CUTEst benchmark problems
- [ ] Performance comparison to Augmented Lagrangian
- [ ] Write tutorial (5.26-SQPOptimizationTutorial.md)
- [ ] Update main optimization guide
- [ ] Update portfolio optimization guide
- [ ] Code review and polish

---

## Next Steps

After Phase 1 (SQP) completion:
1. **Immediate**: Update [Roadmap.md](./Roadmap.md) with completion status
2. **Decision**: Evaluate SQP performance, decide whether GRG still needed
3. **Next Phase**: Proceed to [InteriorPoint.md](./InteriorPoint.md) for Phase 2

---

**Ready to implement?** Start with Phase 1.1 (QP Solver) and work through sequentially. Each phase is independent enough to pause if needed.
