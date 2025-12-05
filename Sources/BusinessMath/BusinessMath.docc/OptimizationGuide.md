# Optimization and Numerical Solvers

Learn how to find optimal values and solve equations using BusinessMath's comprehensive optimization toolkit.

## Overview

BusinessMath provides a complete optimization framework built across 5 progressive phases, from foundational root-finding to sophisticated business optimization modules. Whether you need to find breakeven points, optimize portfolios, or solve complex constrained business problems, these tools provide production-ready solutions.

This guide covers:
- **Phase 1**: Goal-seeking (root-finding) for breakeven and target analysis
- **Phase 2**: Vector operations foundation for multivariate problems
- **Phase 3**: Multivariate optimization algorithms (gradient descent, Newton-Raphson)
- **Phase 4**: Constrained optimization with equality and inequality constraints
- **Phase 5**: Business-specific optimization modules (resource allocation, production planning, driver optimization)

## Phase 1: Goal-Seeking (Root-Finding)

Goal-seeking finds where a function equals a target value. Perfect for breakeven analysis, IRR calculation, and target seeking.

### Finding Break-Even Points

```swift
import BusinessMath

// Profit function with demand curve
func profit(price: Double) -> Double {
    let quantity = 10000 - 1000 * price
    let revenue = price * quantity
    let fixedCosts = 20000.0
    let variableCost = 5.0
    let totalCosts = fixedCosts + variableCost * quantity
    return revenue - totalCosts
}

// Find where profit = 0 (breakeven)
let breakevenPrice = try goalSeek(
    function: profit,
    target: 0.0,
    guess: 10.0,
    tolerance: 0.01
)

print("Breakeven price: $\(String(format: "%.2f", breakevenPrice))")
```

### Internal Rate of Return (IRR)

```swift
let cashFlows = [-1000.0, 200.0, 300.0, 400.0, 500.0]

func npv(rate: Double) -> Double {
    var npv = 0.0
    for (t, cf) in cashFlows.enumerated() {
        npv += cf / pow(1 + rate, Double(t))
    }
    return npv
}

// Find rate where NPV = 0
let irr = try goalSeek(
    function: npv,
    target: 0.0,
    guess: 0.10
)

print("IRR: \(String(format: "%.2f%%", irr * 100))")
```

### With Constraints

```swift
let optimizer = GoalSeekOptimizer<Double>(
    target: 0.0,
    tolerance: 0.01
)

let minPriceConstraint = Constraint<Double>(
    type: .greaterThanOrEqual,
    bound: 5.0
)

let result = optimizer.optimize(
    objective: profit,
    constraints: [minPriceConstraint],
    initialValue: 10.0,
    bounds: (lower: 0.0, upper: 100.0)
)

if result.converged {
    print("Breakeven with constraints: $\(result.optimalValue)")
}
```

**Learn more:** See `Instruction Set/PHASE_1_TUTORIAL.md` and `Examples/GoalSeekExample.swift`

## Phase 2: Vector Operations

The VectorSpace protocol provides generic vector operations for multivariate optimization.

### Working with Vectors

```swift
import BusinessMath

// Create vectors
let v = VectorN([3.0, 4.0])
let w = VectorN([1.0, 2.0])

// Basic operations
let sum = v + w              // [4, 6]
let scaled = 2.0 * v         // [6, 8]

// Norms and distances
print(v.norm)                // 5.0
print(v.distance(to: w))     // 2.828...
print(v.dot(w))              // 11.0 (3×1 + 4×2)

// Projections
let projection = v.projection(onto: w)
let rejection = v.rejection(from: w)
// v = projection + rejection
```

### Portfolio Weights Example

```swift
// Portfolio with 4 assets
var weights = VectorN([0.25, 0.30, 0.25, 0.20])

// Normalize to sum to 1
if abs(weights.sum - 1.0) > 0.001 {
    weights = weights / weights.sum
}

// Expected returns
let returns = VectorN([0.12, 0.15, 0.10, 0.18])

// Portfolio return (weighted average)
let portfolioReturn = weights.dot(returns)
print("Portfolio return: \(portfolioReturn * 100)%")
```

**Learn more:** See `Instruction Set/PHASE_2_TUTORIAL.md` and `Examples/VectorSpaceExample.swift`

## Phase 3: Multivariate Optimization

Find optimal values for functions of multiple variables using gradient descent or Newton-Raphson methods.

### Gradient Descent Variants

```swift
import BusinessMath

// Minimize Rosenbrock function
let rosenbrock: (VectorN<Double>) -> Double = { v in
    let x = v[0], y = v[1]
    let a = 1 - x
    let b = y - x*x
    return a*a + 100*b*b
}

// Adam optimizer (fastest for most problems)
let optimizer = AdamOptimizer<VectorN<Double>>(
    learningRate: 0.01,
    maxIterations: 10000
)

let result = try optimizer.minimize(
    rosenbrock,
    from: VectorN([0.0, 0.0])
)

print("Solution: \(result.solution.toArray())")  // ~[1, 1]
print("Iterations: \(result.iterations)")
```

### Newton-Raphson (BFGS)

For smooth functions, BFGS converges faster:

```swift
let bfgs = MultivariateNewtonRaphson<VectorN<Double>>(
    method: .bfgs,
    maxIterations: 50
)

let result = try bfgs.minimize(
    quadraticFunction,
    from: VectorN([5.0, 5.0, 5.0])
)

print("Converged in \(result.iterations) iterations")
```

### Portfolio Optimization

```swift
let optimizer = PortfolioOptimizer()

let expectedReturns = VectorN([0.12, 0.15, 0.18, 0.05])
let covariance = [
    [0.04, 0.01, 0.02, 0.00],
    [0.01, 0.09, 0.03, 0.01],
    [0.02, 0.03, 0.16, 0.02],
    [0.00, 0.01, 0.02, 0.01]
]

// Maximum Sharpe ratio
let portfolio = try optimizer.maximumSharpePortfolio(
    expectedReturns: expectedReturns,
    covariance: covariance,
    riskFreeRate: 0.02,
    constraintSet: .longOnly
)

print("Sharpe Ratio: \(portfolio.sharpeRatio)")
print("Weights: \(portfolio.weights)")
print("Volatility: \(portfolio.volatility * 100)%")
```

**Learn more:** See `Instruction Set/PHASE_3_TUTORIAL.md`, `Examples/OptimizationExample.swift`, and `Examples/PortfolioOptimizationExample.swift`

## Phase 4: Constrained Optimization

Optimize with equality and inequality constraints using augmented Lagrangian methods.

### Equality Constraints

```swift
import BusinessMath

// Minimize x² + y² subject to x + y = 1
let objective: (VectorN<Double>) -> Double = { v in
    v[0]*v[0] + v[1]*v[1]
}

let optimizer = ConstrainedOptimizer<VectorN<Double>>()

let result = try optimizer.minimize(
    objective,
    from: VectorN([0.0, 1.0]),
    subjectTo: [
        .equality { v in v[0] + v[1] - 1.0 }
    ]
)

print("Solution: \(result.solution.toArray())")  // ~[0.5, 0.5]

// Shadow price (Lagrange multiplier)
if let lambda = result.lagrangeMultipliers?.first {
    print("Shadow price: \(lambda)")
}
```

### Inequality Constraints

```swift
// Portfolio with leverage limit
let portfolioOptimizer = InequalityOptimizer<VectorN<Double>>()

let result = try portfolioOptimizer.minimize(
    portfolioVariance,
    from: VectorN([0.4, 0.4, 0.2]),
    subjectTo: [
        // Target return: portfolio return ≥ 10%
        .inequality { w in
            let ret = w.dot(expectedReturns)
            return 0.10 - ret  // ≤ 0 means ret ≥ 10%
        },
        // Fully invested
        .equality { w in w.sum() - 1.0 },
        // Long-only (no short-selling)
        .inequality { w in -w[0] },  // w[0] ≥ 0
        .inequality { w in -w[1] },  // w[1] ≥ 0
        .inequality { w in -w[2] }   // w[2] ≥ 0
    ]
)

print("Optimal weights: \(result.solution.toArray())")
```

**Learn more:** See `Instruction Set/PHASE_4_TUTORIAL.md` and `Examples/ConstrainedOptimizationExample.swift`

## Phase 5: Business Optimization

Domain-specific optimization modules for common business problems.

### Resource Allocation

Optimize capital allocation across projects with dependencies and constraints:

```swift
import BusinessMath

let projects = [
    AllocationOption(
        id: "cloud_migration",
        name: "Cloud Migration",
        expectedValue: 400_000,
        resourceRequirements: ["budget": 250_000],
        strategicValue: 9.0
    ),
    // ... more projects
]

let optimizer = ResourceAllocationOptimizer()

let result = try optimizer.optimize(
    options: projects,
    objective: .maximizeWeightedValue(strategicWeight: 0.3),
    constraints: [
        .totalBudget(1_000_000),
        .requiredOption(optionId: "security_upgrade"),
        .mutuallyExclusive(["proj_a", "proj_b"])
    ]
)

print("Selected projects: \(result.selectedOptions.map { $0.name })")
print("Total value: $\(result.totalValue)")
```

### Production Planning

Optimize manufacturing across multiple products and resources:

```swift
let products = [
    ManufacturedProduct(
        id: "premium",
        pricePerUnit: 500,
        variableCostPerUnit: 280,
        demand: .range(min: 100, max: 400),
        resourceRequirements: [
            "assembly_hours": 5.0,
            "testing_hours": 3.0
        ]
    ),
    // ... more products
]

let optimizer = ProductionPlanningOptimizer()

let plan = try optimizer.optimize(
    products: products,
    resources: ["assembly_hours": 3000, "testing_hours": 2000],
    objective: .maximizeProfit,
    constraints: [.minimumProduction(productId: "premium", quantity: 120)]
)

print("Production quantities: \(plan.productionQuantities)")
print("Profit: $\(plan.profit)")
```

### Driver Optimization

Optimize operational drivers to hit financial targets:

```swift
let drivers = [
    OptimizableDriver(
        name: "price_per_seat",
        currentValue: 50,
        range: 40...70,
        changeConstraint: .percentageChange(max: 0.20)
    ),
    OptimizableDriver(
        name: "monthly_churn_rate",
        currentValue: 0.05,
        range: 0.02...0.08
    )
]

let targets = [
    FinancialTarget(metric: "mrr", target: .minimum(150_000), weight: 2.0),
    FinancialTarget(metric: "ltv_cac_ratio", target: .minimum(3.0), weight: 1.5)
]

let optimizer = DriverOptimizer()

let result = try optimizer.optimize(
    drivers: drivers,
    targets: targets,
    model: { driverValues in
        // Your financial model
        let price = driverValues["price_per_seat"]!
        let churn = driverValues["monthly_churn_rate"]!
        // ... calculate metrics
        return ["mrr": calculatedMRR, "ltv_cac_ratio": calculatedRatio]
    }
)

print("Optimized drivers: \(result.optimizedDrivers)")
print("All targets met: \(result.feasible)")
```

**Learn more:** See `Instruction Set/PHASE_5_TUTORIAL.md`, `Examples/ResourceAllocationExample.swift`, `Examples/ProductionPlanningExample.swift`, and `Examples/DriverOptimizationExample.swift`

## Choosing the Right Optimizer

| Problem Type | Phase | Optimizer | Use When |
|-------------|-------|-----------|----------|
| Root-finding | 1 | `goalSeek()` | Find where f(x) = target |
| Scalar optimization | 1 | `GoalSeekOptimizer` | 1D with constraints |
| Unconstrained multivariate | 3 | `AdamOptimizer` | General optimization |
| Smooth functions | 3 | `MultivariateNewtonRaphson` | Fast convergence needed |
| Portfolio optimization | 3 | `PortfolioOptimizer` | Mean-variance optimization |
| Equality constraints | 4 | `ConstrainedOptimizer` | h(x) = 0 constraints |
| Inequality constraints | 4 | `InequalityOptimizer` | g(x) ≤ 0 constraints |
| Project selection | 5 | `ResourceAllocationOptimizer` | Capital budgeting |
| Manufacturing | 5 | `ProductionPlanningOptimizer` | Multi-product planning |
| Target seeking | 5 | `DriverOptimizer` | Financial goal achievement |

## Practical Tips

### Initial Values

Start with reasonable business assumptions:
```swift
// For prices: use market average
initialValue: 100.0

// For weights: equal allocation
initialWeights: VectorN(repeating: 1.0/n, count: n)

// For rates: industry benchmarks
initialValue: 0.08  // 8% return
```

### Tolerances

Balance precision with computation time:
```swift
// High precision (slower)
tolerance: 0.0001

// Standard precision (faster)
tolerance: 0.01

// Business decisions (fastest)
tolerance: 0.05
```

### Convergence Issues

If optimization doesn't converge:
1. Try different initial values
2. Increase max iterations
3. Check objective function for discontinuities
4. Normalize inputs to similar scales
5. Provide analytical gradients (Phase 4)

### Constraints

Use pre-built helpers for common constraints:
```swift
// Sum to one (portfolio weights, probabilities)
.equality { v in v.sum() - 1.0 }

// Non-negativity
.inequality { v in -v[i] }  // v[i] ≥ 0

// Box constraints
.inequality { v in v[i] - upper }  // v[i] ≤ upper
.inequality { v in lower - v[i] }  // v[i] ≥ lower
```

## Complete Documentation

### Phase 1: Core Enhancements
- **Tutorial**: `Instruction Set/PHASE_1_TUTORIAL.md`
- **Examples**: `Examples/GoalSeekExample.swift`
- **Topics**: Goal-seeking, breakeven analysis, IRR, error handling

### Phase 2: VectorSpace Foundation
- **Tutorial**: `Instruction Set/PHASE_2_TUTORIAL.md`
- **Examples**: `Examples/VectorSpaceExample.swift`
- **Topics**: Vector operations, distance metrics, projections, functional programming

### Phase 3: Multivariate Optimization
- **Tutorial**: `Instruction Set/PHASE_3_TUTORIAL.md`
- **Examples**: `Examples/OptimizationExample.swift`, `Examples/PortfolioOptimizationExample.swift`
- **Topics**: Gradient descent, Newton-Raphson, BFGS, portfolio optimization, efficient frontier

### Phase 4: Constrained Optimization
- **Tutorial**: `Instruction Set/PHASE_4_TUTORIAL.md`
- **Examples**: `Examples/ConstrainedOptimizationExample.swift`
- **Topics**: Equality/inequality constraints, Lagrange multipliers, barrier methods, KKT conditions

### Phase 5: Business Optimization
- **Tutorial**: `Instruction Set/PHASE_5_TUTORIAL.md`
- **Examples**: `Examples/ResourceAllocationExample.swift`, `Examples/ProductionPlanningExample.swift`, `Examples/DriverOptimizationExample.swift`
- **Topics**: Capital budgeting, production planning, financial target seeking

## Next Steps

- Explore <doc:PortfolioOptimizationGuide> for detailed portfolio optimization techniques
- Learn <doc:ScenarioAnalysisGuide> for optimizing across multiple scenarios
- See <doc:RiskAnalyticsGuide> for comprehensive risk analysis

## See Also

### Phase 1
- ``goalSeek(function:target:guess:tolerance:maxIterations:)``
- ``GoalSeekOptimizer``
- ``GoalSeekError``

### Phase 2
- ``VectorSpace``
- ``VectorN``
- ``Vector2D``
- ``Vector3D``
- ``MultivariateConstraint``

### Phase 3
- ``MultivariateGradientDescent``
- ``MomentumGradientDescent``
- ``AdamOptimizer``
- ``MultivariateNewtonRaphson``
- ``PortfolioOptimizer``

### Phase 4
- ``ConstrainedOptimizer``
- ``InequalityOptimizer``

### Phase 5
- ``ResourceAllocationOptimizer``
- ``ProductionPlanningOptimizer``
- ``DriverOptimizer``
