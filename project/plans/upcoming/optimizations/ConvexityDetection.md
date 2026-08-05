# Phase 4: Automatic Convexity Detection

**Priority**: ⭐⭐⭐⭐ (Tier 2)
**Effort**: 2-3 weeks
**Status**: Not Started
**Dependencies**: [SQP.md](./SQP.md), [InteriorPoint.md](./InteriorPoint.md)
**Target Completion**: Week 13 of Q3 2026

---

## Overview

Automatically detect when optimization problems are convex, enabling **10-100× speedup** by using specialized convex solvers.

**Key Insight**: Many finance problems are naturally convex:
- Portfolio optimization (quadratic risk)
- Risk minimization (CVaR is convex)
- Regression problems (least squares)

But users write them as general nonlinear problems! Automatic detection enables:
1. **Faster solving**: Convex QP solver >> general NLP solver
2. **Global optimum guarantee**: Convex problems have unique global minimum
3. **Better UX**: "It just works fast" without user needing to know convexity

**Marketing**: "Automatic optimization - BusinessMath detects problem structure and selects optimal algorithm"

---

## Algorithm Overview

### Convexity Detection Strategies

**1. Symbolic Analysis** (preferred, Week 1-2):
- Analyze objective/constraint expression trees
- Apply convexity rules:
  - `x²` is convex
  - `log(x)` is concave
  - `exp(x)` is convex
  - Sum of convex functions is convex
  - Composition rules (chain rule for convexity)

**2. Numerical Testing** (fallback, Week 1):
- Sample random points, check Hessian positive semidefinite
- If H ≽ 0 at all sampled points → likely convex

**3. User Annotation** (always available):
```swift
.convex { x in ... }  // User asserts convexity
```

---

## Implementation Plan

### File Structure

```
Sources/BusinessMath/Optimization/
├── ConvexityDetection/
│   ├── ConvexityAnalyzer.swift         (main analyzer)
│   ├── ExpressionTree.swift            (symbolic expression representation)
│   ├── ConvexityRules.swift            (composition rules)
│   └── NumericalConvexityTest.swift    (Hessian sampling)
└── ConvexOptimizer.swift               (dispatch to correct solver)

Tests/BusinessMathTests/Optimization Tests/
└── ConvexityDetectionTests.swift

Sources/BusinessMath/BusinessMath.docc/
└── 5.29-ConvexOptimizationTutorial.md
```

### Phase 4.1: Expression Tree (Week 1)

**Goal**: Represent objective functions symbolically

```swift
/// Symbolic representation of mathematical expressions
public indirect enum Expression {
    // Variables
    case variable(index: Int)
    case constant(Double)

    // Arithmetic
    case add(Expression, Expression)
    case subtract(Expression, Expression)
    case multiply(Expression, Expression)
    case divide(Expression, Expression)

    // Functions
    case power(Expression, exponent: Double)
    case exp(Expression)
    case log(Expression)
    case sqrt(Expression)
    case square(Expression)

    // Norms
    case norm2(Expression)  // L2 norm (convex)
    case abs(Expression)    // L1 norm (convex)

    /// Analyze convexity of this expression
    public func analyzeConvexity() -> ConvexityProperty
}

public enum ConvexityProperty {
    case convex
    case concave
    case affine       // Both convex and concave
    case unknown      // Cannot determine
}
```

**Convexity Rules**:
```swift
extension Expression {
    public func analyzeConvexity() -> ConvexityProperty {
        switch self {
        case .variable, .constant:
            return .affine

        case .add(let e1, let e2):
            let c1 = e1.analyzeConvexity()
            let c2 = e2.analyzeConvexity()
            if c1 == .convex && c2 == .convex { return .convex }
            if c1 == .concave && c2 == .concave { return .concave }
            return .unknown

        case .multiply(let e1, let e2):
            // Convexity of product depends on signs and monotonicity
            // Conservative: unknown unless special cases
            return .unknown

        case .square(let e):
            // x² is always convex
            return .convex

        case .exp(let e):
            if e.analyzeConvexity() == .convex || e.analyzeConvexity() == .affine {
                return .convex  // exp(convex) is convex
            }
            return .unknown

        case .log(let e):
            if e.analyzeConvexity() == .concave || e.analyzeConvexity() == .affine {
                return .concave  // log(concave) is concave
            }
            return .unknown

        case .norm2:
            return .convex  // L2 norm always convex

        // ... more rules
        }
    }
}
```

### Phase 4.2: DSL for Expression Building (Week 1-2)

**Goal**: Let users write objectives that build expression trees

```swift
/// Convex optimization DSL
///
/// Example:
/// ```swift
/// let optimizer = ConvexOptimizer()
///
/// let result = try optimizer.minimize {
///     let w = $0  // Weight vector
///     return 0.5 * w.quadraticForm(covarianceMatrix)  // Portfolio variance
/// } subjectTo: {
///     w.sum().equals(1.0)      // Budget constraint
///     w.allGreaterThan(0.0)    // Non-negativity
/// }
/// ```
public struct ConvexOptimizer {

    public func minimize<V: VectorSpace>(
        @ExpressionBuilder _ objective: (ExpressionVariable<V>) -> Expression,
        @ConstraintBuilder subjectTo constraints: () -> [ConvexConstraint]
    ) throws -> ConvexOptimizationResult<V> where V.Scalar == Double {

        // 1. Build expression tree from closure
        let expr = objective(ExpressionVariable())

        // 2. Analyze convexity
        let convexity = expr.analyzeConvexity()

        guard convexity == .convex || convexity == .affine else {
            throw OptimizationError.notConvex("Objective is not convex")
        }

        // 3. Dispatch to appropriate solver
        return try dispatchToSolver(objective: expr, constraints: constraints())
    }

    private func dispatchToSolver(
        objective: Expression,
        constraints: [ConvexConstraint]
    ) throws -> ConvexOptimizationResult<V> {

        // Detect problem type and use specialized solver
        if isQuadratic(objective) && areLinear(constraints) {
            // QP → use Interior Point QP solver
            return try solveAsQP(objective, constraints)
        } else if isLinear(objective) && areLinear(constraints) {
            // LP → use Interior Point LP solver
            return try solveAsLP(objective, constraints)
        } else {
            // General convex → use SQP (with convexity guarantee)
            return try solveAsSQP(objective, constraints)
        }
    }
}
```

### Phase 4.3: Numerical Fallback (Week 2)

For closures that can't be analyzed symbolically:

```swift
/// Test convexity numerically by sampling Hessian
public struct NumericalConvexityTester {

    public func testConvexity(
        function: @escaping (VectorN<Double>) -> Double,
        domain: (lower: VectorN<Double>, upper: VectorN<Double>),
        samples: Int = 100
    ) -> Bool {

        for _ in 0..<samples {
            let point = randomPoint(in: domain)

            // Compute Hessian numerically
            let H = numericalHessian(function, at: point)

            // Check if positive semidefinite
            if !isPositiveSemidefinite(H) {
                return false  // Found non-PSD Hessian → not convex
            }
        }

        return true  // All samples had PSD Hessian → likely convex
    }

    private func isPositiveSemidefinite(_ matrix: [[Double]]) -> Bool {
        // Compute eigenvalues, check all ≥ 0
        let eigenvalues = computeEigenvalues(matrix)
        return eigenvalues.allSatisfy { $0 >= -1e-8 }  // Small negative tolerance
    }
}
```

### Phase 4.4: Testing & Examples (Week 3)

```swift
func testPortfolioDetectedAsConvex() {
    let optimizer = ConvexOptimizer()

    let Σ = covarianceMatrix()  // 3×3

    let result = try optimizer.minimize { w in
        0.5 * w.quadraticForm(Σ)  // Convex quadratic
    } subjectTo: {
        w.sum().equals(1.0)
        w.allGreaterThan(0.0)
    }

    // Should automatically use Interior Point QP solver
    XCTAssertTrue(result.usedInteriorPoint)
    XCTAssertLessThan(result.solveTime, 0.1)  // Fast!
}

func testNonConvexDetected() {
    let optimizer = ConvexOptimizer()

    XCTAssertThrowsError(
        try optimizer.minimize { x in
            x[0] * x[0] * x[0] - x[1]  // x³ is not convex!
        }
    ) { error in
        XCTAssert(error is OptimizationError)
    }
}

func testAutomaticDispatch() {
    // Test that problems are dispatched to optimal solver

    // LP detected → Interior Point LP
    let lpResult = try optimizer.minimize { x in
        x.sum()  // Linear
    } subjectTo: {
        x.allGreaterThan(0.0)
    }
    XCTAssertTrue(lpResult.solverUsed == .interiorPointLP)

    // QP detected → Interior Point QP
    let qpResult = try optimizer.minimize { x in
        x.quadraticForm(Q)  // Quadratic
    } subjectTo: {
        x.sum().equals(1.0)
    }
    XCTAssertTrue(qpResult.solverUsed == .interiorPointQP)

    // General convex → SQP
    let convexResult = try optimizer.minimize { x in
        x.map { exp($0) }.sum()  // exp is convex
    } subjectTo: {
        x.sum().equals(1.0)
    }
    XCTAssertTrue(convexResult.solverUsed == .sqp)
}
```

---

## Success Criteria

### Functional
- ✅ Detects convexity for portfolio optimization (quadratic)
- ✅ Detects convexity for risk minimization (CVaR)
- ✅ Rejects non-convex problems with clear error
- ✅ Dispatches to optimal solver automatically

### Performance
- ✅ Detection overhead < 100ms
- ✅ **10-100× speedup** vs general NLP solver for detected convex problems
- ✅ Portfolio optimization (1000 assets) < 1 second

### UX
- ✅ CVX-style DSL for readable problem specification
- ✅ Clear error messages when not convex
- ✅ Optional user annotations for ambiguous cases

---

## References

### Textbooks
1. **Boyd & Vandenberghe (2004)**: "Convex Optimization" - Definitive reference
2. **Grant & Boyd (2008)**: "Graph Implementations for Nonsmooth Convex Programs" - CVX implementation

### Software
1. **CVX (MATLAB)**: http://cvxr.com/cvx/ - Disciplined convex programming
2. **CVXPY (Python)**: https://www.cvxpy.org/ - Python convex optimization
3. **Convex.jl (Julia)**: https://github.com/JuliaOpt/Convex.jl

---

## Next Steps

After Phase 4:
1. Update [Roadmap.md](./Roadmap.md)
2. Proceed to [ADMM.md](./ADMM.md) for Phase 5
