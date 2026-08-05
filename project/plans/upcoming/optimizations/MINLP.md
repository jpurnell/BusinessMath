# Phase 3: MINLP - Mixed-Integer Nonlinear Programming

**Priority**: ⭐⭐⭐⭐⭐ (Highest - Tier 1)
**Effort**: 2-3 weeks
**Status**: Not Started
**Dependencies**: [SQP.md](./SQP.md) - uses SQP as NLP solver
**Target Completion**: Week 10 of Q2 2026

---

## Overview

MINLP extends optimization to problems with:
- **Nonlinear** objectives and constraints
- **Integer** and continuous variables mixed

**Problem Form**:
```
minimize f(x, y)
subject to:
    h_i(x, y) = 0  (equality constraints)
    g_j(x, y) ≤ 0  (inequality constraints)
    x ∈ ℝⁿ         (continuous variables)
    y ∈ ℤᵐ         (integer variables)
```

**Why MINLP?**
1. **Rare capability**: Few open-source solvers handle MINLP
2. **Natural extension**: Leverage existing branch-and-bound + SQP
3. **Real-world problems**: Facility location with nonlinear shipping costs, production scheduling with setup costs
4. **Marketing power**: "Full MINLP solver" differentiates from competitors

---

## Algorithm Overview

### Branch-and-Bound with Nonlinear Relaxation

Replace Simplex relaxation (for MILP) with SQP relaxation (for MINLP):

```
1. Relax integer variables: yᵢ ∈ [lb, ub] instead of yᵢ ∈ ℤ
2. Solve relaxed NLP using SQP → get lower bound
3. If solution has integer y → check feasibility, update incumbent
4. Otherwise, branch on fractional yⱼ: create two subproblems
   - Left: yⱼ ≤ ⌊yⱼ⌋
   - Right: yⱼ ≥ ⌈yⱼ⌉
5. Repeat until all nodes pruned
```

**Key Difference from MILP**:
- Relaxation solver: SQP instead of Simplex
- May not get valid lower bounds if problem is non-convex!
- Need convexity detection or accept heuristic bounds

---

## Implementation Plan

### File Structure

```
Sources/BusinessMath/Optimization/IntegerProgramming/
├── MINLPSolver.swift                   (main MINLP solver)
└── NonlinearRelaxationSolver.swift     (already exists, extend)

Tests/BusinessMathTests/Optimization Tests/
└── MINLPSolverTests.swift

Sources/BusinessMath/BusinessMath.docc/
└── 5.28-MINLPTutorial.md
```

### Phase 3.1: MINLP Solver (Week 1-2)

**Implementation**: Extend existing `BranchAndBound` framework

```swift
/// Mixed-Integer Nonlinear Programming solver
///
/// Solves problems with both integer/binary variables and nonlinear objectives/constraints.
///
/// ## Algorithm
///
/// Branch-and-bound with nonlinear relaxation:
/// 1. Relax integer constraints → NLP
/// 2. Solve NLP with SQP
/// 3. Branch on fractional integer variables
/// 4. Prune nodes by bound comparison
///
/// ## Limitations
///
/// - **Convexity**: Only guarantees global optimum for convex problems
/// - **Non-convex**: May find local optima or good feasible solutions
/// - **Scale**: n < 500 variables, m < 50 integer typical
///
/// ## Example
///
/// ```swift
/// let solver = MINLPSolver()
///
/// // Facility location: place k facilities to minimize nonlinear shipping cost
/// let result = try solver.solve(
///     objective: { x in nonlinearShippingCost(x) },
///     integerVariables: facilityLocations,  // Binary: facility open/closed
///     continuousVariables: shipmentAmounts,  // Continuous: how much to ship
///     constraints: [.capacityConstraints, .demandConstraints]
/// )
/// ```
public struct MINLPSolver<V: VectorSpace> where V.Scalar: Real {

    /// Underlying NLP solver for relaxations
    private let nlpSolver: SQPOptimizer<V>

    /// Branch-and-bound parameters
    public let maxNodes: Int
    public let absoluteGap: V.Scalar
    public let relativeGap: V.Scalar

    public init(
        nlpTolerance: V.Scalar = V.Scalar(1e-6),
        nlpMaxIterations: Int = 100,
        maxNodes: Int = 10_000,
        absoluteGap: V.Scalar = V.Scalar(1e-4),
        relativeGap: V.Scalar = V.Scalar(1e-3)
    ) {
        self.nlpSolver = SQPOptimizer(
            tolerance: nlpTolerance,
            maxIterations: nlpMaxIterations
        )
        self.maxNodes = maxNodes
        self.absoluteGap = absoluteGap
        self.relativeGap = relativeGap
    }

    /// Solve MINLP problem
    public func solve(
        objective: @escaping (V) -> V.Scalar,
        from initialGuess: V,
        integerSpec: IntegerSpecification<V>,
        constraints: [MultivariateConstraint<V>]
    ) throws -> MINLPResult<V>
}

public struct MINLPResult<V: VectorSpace> where V.Scalar: Real {
    public let solution: V
    public let objectiveValue: V.Scalar
    public let lowerBound: V.Scalar
    public let gap: V.Scalar
    public let nodesExplored: Int
    public let converged: Bool
    public let timeLimitReached: Bool
}
```

**Relaxation Solver**:
```swift
private func solveRelaxation(
    objective: @escaping (V) -> V.Scalar,
    bounds: (lower: V, upper: V),
    constraints: [MultivariateConstraint<V>]
) throws -> SQPResult<V> {

    // Convert bounds to inequality constraints
    let boundConstraints = convertBoundsToConstraints(bounds)

    // Solve NLP relaxation using SQP
    return try nlpSolver.minimize(
        objective,
        from: midpoint(bounds.lower, bounds.upper),
        subjectTo: constraints + boundConstraints
    )
}
```

**Branching Strategy** (same as MILP):
```swift
private func selectBranchingVariable(
    solution: V,
    integerSpec: IntegerSpecification<V>
) -> Int? {
    var maxFractionality = V.Scalar(0)
    var branchIndex: Int? = nil

    for idx in integerSpec.integerIndices {
        let value = solution.component(at: idx)
        let fractionality = min(value - floor(value), ceil(value) - value)

        if fractionality > V.Scalar(1) / V.Scalar(1000) && fractionality > maxFractionality {
            maxFractionality = fractionality
            branchIndex = idx
        }
    }

    return branchIndex
}
```

### Phase 3.2: Convexity Handling (Week 2)

**Challenge**: Non-convex MINLP relaxations may not give valid lower bounds.

**Solutions**:
1. **Detect convexity** → if convex, bounds are valid
2. **Assume convexity** → document limitation
3. **Convex underestimators** → advanced, defer to Phase 8 (Global Optimization)

**For Phase 3, assume convexity or accept heuristic**:
```swift
public enum MINLPMode {
    case assumeConvex  // Trust relaxation bounds (default)
    case heuristic     // Don't use bounds for pruning, just find feasible
}

public init(
    // ...
    mode: MINLPMode = .assumeConvex
)
```

### Phase 3.3: Testing (Week 2-3)

**Test Cases**:

```swift
func testFacilityLocation() {
    // Place k facilities to minimize transportation cost
    // Binary: facility open/closed
    // Continuous: customer-to-facility assignment
    // Nonlinear: cost ~ distance²

    let solver = MINLPSolver<VectorN<Double>>()

    let objective: (VectorN<Double>) -> Double = { x in
        // x[0..k-1]: binary facility indicators
        // x[k..n-1]: continuous shipment amounts
        computeNonlinearShippingCost(x)
    }

    let integerSpec = IntegerSpecification(
        integerIndices: Array(0..<numFacilities),
        types: Array(repeating: .binary, count: numFacilities)
    )

    let result = try solver.solve(
        objective: objective,
        from: initialGuess,
        integerSpec: integerSpec,
        constraints: [.capacityConstraints, .demandSatisfaction]
    )

    XCTAssertTrue(result.converged)
    // Verify facility variables are 0 or 1
    for i in 0..<numFacilities {
        XCTAssert(abs(result.solution[i] - 0.0) < 1e-3 || abs(result.solution[i] - 1.0) < 1e-3)
    }
}

func testPortfolioWithTransactionCosts() {
    // Portfolio rebalancing with fixed transaction costs
    // Binary: trade or not trade
    // Continuous: amount to trade
    // Nonlinear: quadratic risk

    let objective: (VectorN<Double>) -> Double = { x in
        // Risk (quadratic) + transaction costs (piecewise linear via binary)
        portfolioRisk(x) + transactionCosts(x)
    }

    let result = try solver.solve(objective, ...)

    // Should choose to rebalance only high-impact assets
}

func testProductionScheduling() {
    // Production with setup costs and nonlinear production costs
    // Binary: produce product or not
    // Continuous: quantity to produce
    // Nonlinear: economies of scale in production

    let objective: (VectorN<Double>) -> Double = { x in
        setupCosts(x) + nonlinearProductionCosts(x)
    }

    // ...
}
```

### Phase 3.4: Documentation (Week 3)

**Tutorial**: `5.28-MINLPTutorial.md`

Topics:
- When MINLP is needed (vs MILP or NLP alone)
- Facility location with nonlinear costs (full example)
- Portfolio rebalancing with fixed transaction costs
- Production scheduling with economies of scale
- Convexity assumptions and limitations
- Performance characteristics

---

## Success Criteria

### Functional
- ✅ Solves convex MINLP problems to global optimum
- ✅ Finds good feasible solutions for non-convex MINLP
- ✅ Handles n=100 variables, m=20 integer typical
- ✅ Integrates with existing `IntegerSpecification` infrastructure

### Performance
- ✅ **< 10 seconds for 50-variable convex MINLP**
- ✅ Explores < 1000 nodes for typical problems
- ✅ NLP relaxations solve in < 1 second each

### Quality
- ✅ Integer variables within 1e-6 of integers at solution
- ✅ Gap < 1% for convex problems
- ✅ Finds feasible solutions for non-convex problems

---

## References

### Papers
1. **Bonami et al. (2008)**: "An Algorithmic Framework for Convex MINLP" - Bonmin solver
2. **Belotti et al. (2013)**: "Mixed-Integer Nonlinear Optimization" - Survey
3. **Leyffer (2001)**: "Integrating SQP and Branch-and-Bound for MINLP" - Algorithm foundation

### Reference Implementations
1. **Bonmin** (COIN-OR) - Open-source convex MINLP
2. **Couenne** (COIN-OR) - Global non-convex MINLP
3. **SCIP** - Mixed-integer solver with NLP extension
4. **BARON** - Commercial global MINLP solver

### Test Problems
1. **MINLPLib**: http://www.minlplib.org/ - Library of MINLP test problems

---

## Next Steps

After Phase 3 completion:
1. Update [Roadmap.md](./Roadmap.md) - Tier 1 complete!
2. Decision point: Continue to Tier 2 or ship v2.0?
3. If continuing: Proceed to [ConvexityDetection.md](./ConvexityDetection.md)
