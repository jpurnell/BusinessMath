# BusinessMath Library - Examples

This directory contains comprehensive examples demonstrating the BusinessMath library's capabilities.

## Quick Start

The fastest way to get started with BusinessMath:

```swift
import BusinessMath

// Create a financial model
let model = FinancialModel {
    Revenue {
        Product("SaaS Subscriptions")
            .price(99)
            .customers(1000)
    }

    Costs {
        Fixed("Salaries", 50_000)
        Variable("Cloud Costs", 0.15)
    }
}

// Calculate metrics
let profit = model.calculateProfit()
print("Profit: $\(profit)")
```

## Core Features

### 1. Financial Modeling

Build declarative financial models using a SwiftUI-style DSL:

```swift
let model = FinancialModel {
    Revenue {
        Product("Enterprise").price(999).quantity(100)
        Product("Pro").price(299).quantity(500)
        Product("Basic").price(99).quantity(2000)
    }

    Costs {
        Fixed("Engineering", 200_000)
        Fixed("Marketing", 150_000)
        Variable("Payment Processing", 0.029)
        Variable("Support", 0.05)
    }
}

let revenue = model.calculateRevenue()  // Total revenue
let costs = model.calculateCosts(revenue: revenue)  // Total costs
let profit = model.calculateProfit()  // Net profit
```

### 2. Model Inspection

Analyze and validate financial models:

```swift
let inspector = ModelInspector(model: model)

// List all components
let revenues = inspector.listRevenueSources()
let costs = inspector.listCostDrivers()

// Validate structure
let validation = inspector.validateStructure()
if !validation.isValid {
    for issue in validation.issues {
        print("Issue: \(issue)")
    }
}

// Generate comprehensive summary
print(inspector.generateSummary())
```

### 3. Calculation Tracing

Track calculation steps for debugging and documentation:

```swift
let trace = CalculationTrace(model: model)
let profit = trace.calculateProfit()

// View all calculation steps
for step in trace.steps {
    print(step.description)
}

// Or get formatted output
print(trace.formatTrace())
```

### 4. Data Export

Export models and results to CSV and JSON:

```swift
let exporter = DataExporter(model: model)

// Export to CSV
let csv = exporter.exportToCSV()
print(csv)

// Export to JSON (with optional metadata)
let json = exporter.exportToJSON(includeMetadata: true)
print(json)
```

### 5. Time Series Analysis

Work with time series data:

```swift
let sales = TimeSeries<Double>(
    periods: [.year(2021), .year(2022), .year(2023)],
    values: [100_000, 125_000, 150_000]
)

// Validate data quality
let validation = sales.validate(detectOutliers: true)
if validation.isValid {
    print("Data is clean")
}

// Export time series
let exporter = TimeSeriesExporter(series: sales)
let csv = exporter.exportToCSV()
```

### 6. Investment Analysis

Evaluate investment opportunities:

```swift
let investment = Investment {
    InitialCost(50_000)
    CashFlows {
        [
            CashFlow(period: 1, amount: 20_000),
            CashFlow(period: 2, amount: 25_000),
            CashFlow(period: 3, amount: 30_000)
        ]
    }
    DiscountRate(0.10)
}

print("NPV: $\(investment.npv)")
print("IRR: \(investment.irr! * 100)%")
print("Payback: \(investment.paybackPeriod!) periods")
```

## Complete Workflow Example

Here's a complete workflow showing how to build, validate, analyze, and export a financial model:

```swift
// 1. Build the model
let model = FinancialModel {
    Revenue {
        Product("Product A").price(100).quantity(500)
        Product("Product B").price(200).quantity(200)
    }

    Costs {
        Fixed("Salaries", 50_000)
        Fixed("Rent", 10_000)
        Variable("COGS", 0.35)
    }
}

// 2. Validate before use
let inspector = ModelInspector(model: model)
let validation = inspector.validateStructure()

guard validation.isValid else {
    print("Model validation failed:")
    for issue in validation.issues {
        print("  • \(issue)")
    }
    return
}

// 3. Calculate metrics
let profit = model.calculateProfit()
print("Profit: $\(profit)")

// 4. Trace calculations for documentation
let trace = CalculationTrace(model: model)
_ = trace.calculateProfit()
print(trace.formatTrace())

// 5. Export for reporting
let exporter = DataExporter(model: model)
let csv = exporter.exportToCSV()
let json = exporter.exportToJSON()

// Save to files
try? csv.write(toFile: "model.csv", atomically: true, encoding: .utf8)
try? json.write(toFile: "model.json", atomically: true, encoding: .utf8)
```

## Best Practices

### Always Validate Models

```swift
let inspector = ModelInspector(model: model)
let validation = inspector.validateStructure()

if validation.isValid {
    // Safe to use model
    let profit = model.calculateProfit()
} else {
    // Handle validation errors
    for issue in validation.issues {
        print("Error: \(issue)")
    }
}
```

### Use Tracing for Debugging

When calculations don't match expectations, use tracing to understand what's happening:

```swift
let trace = CalculationTrace(model: model)
let profit = trace.calculateProfit()

if profit < expectedProfit {
    print("Calculation steps:")
    for step in trace.steps {
        print("  \(step.description)")
    }
}
```

### Validate Time Series Data

Always validate time series data before analysis:

```swift
let validation = timeSeries.validate(detectOutliers: true)

if !validation.isValid {
    print("Data quality issues detected:")
    for error in validation.errors {
        print("  • \(error.message)")
    }
}
```

## Running the Examples

To run the examples in this directory:

```swift
// In your Swift file
import BusinessMath

// Run all examples
runAllExamples()

// Or run individual examples
example1_BasicFinancialModel()
example2_ModelInspection()
example3_CalculationTracing()
// etc.
```

## Performance Considerations

The library is optimized for performance:

- Models with 100+ components calculate in <1ms
- Time series with 1000+ data points validate instantly
- Export operations are memory efficient
- Thread-safe for concurrent operations

Example with large dataset:

```swift
// Build model with 100 components
var model = FinancialModel()
for i in 1...100 {
    model.revenueComponents.append(
        RevenueComponent(name: "Product \(i)", amount: Double(i * 1000))
    )
}

// Efficient calculation
let profit = model.calculateProfit()  // Completes in <1ms
```

## Error Handling

The library provides comprehensive error handling:

```swift
// Time series validation
let validation = timeSeries.validate()
if !validation.isValid {
    for error in validation.errors {
        print("\(error.severity): \(error.message)")
        print("Suggestions:")
        for suggestion in error.suggestions {
            print("  - \(suggestion)")
        }
    }
}

// Model validation
let modelValidation = inspector.validateStructure()
if !modelValidation.isValid {
    for issue in modelValidation.issues {
        print("Issue: \(issue)")
    }
}
```

## Integration with Other Tools

### Export for Excel Analysis

```swift
let exporter = DataExporter(model: model)
let csv = exporter.exportToCSV()
try csv.write(toFile: "model.csv", atomically: true, encoding: .utf8)
// Open in Excel/Numbers
```

### Export for Web Applications

```swift
let exporter = DataExporter(model: model)
let json = exporter.exportToJSON()
// Send JSON to web API or frontend
```

### Integration with Reporting Tools

```swift
let trace = CalculationTrace(model: model)
_ = trace.calculateProfit()
let report = trace.formatTrace()
// Include in PDF/HTML reports
```

## Case Studies

### Reid's Raisins Decision Analysis

**File:** `ReidsRaisinsDemo.swift`
**Tutorial:** See `Sources/BusinessMath/BusinessMath.docc/ReidsRaisinsExample.md`

A complete decision analysis case study demonstrating:
- Profit modeling with complex cost structures (in-house vs outsourced processing)
- Base-case scenario analysis with detailed breakdowns
- Breakeven analysis using Newton-Raphson optimization
- Sensitivity tables for pricing decisions
- Tornado charts for parameter impact analysis

**Key Results:**
- Base-case profit: $448,125 at $2.20 raisin price
- Breakeven grape price: $0.44 (47% safety margin)
- Top risk drivers: Raisin price and grape market price (each ±$485k impact)

**To use this example:**

```swift
import BusinessMath

// Create the profit model
var model = ReidsRaisinsModel(
    contractQuantity: 1_000_000,
    raisinPrice: 2.20,
    openMarketPrice: 0.30
)

// Calculate base-case profit
let profit = model.calculateProfit()

// Run breakeven analysis
let optimizer = NewtonRaphsonOptimizer<Double>()
let breakevenPrice = optimizer.optimize(
    objective: { price in
        var m = model
        m.openMarketPrice = price
        return m.calculateProfit()
    },
    initialValue: 0.30
)
```

This case study demonstrates the full power of BusinessMath for real-world business decisions.

### Phase 1: Goal-Seeking Examples

**Core enhancements** demonstrating goal-seeking (root-finding) capabilities:

#### Goal-Seeking (`GoalSeekExample.swift`)

Demonstrates finding where functions equal target values (root-finding vs. optimization):

**Example 1: Basic Goal-Seeking**
- Find x where x² = 4
- Shows Newton-Raphson convergence
- Demonstrates multiple roots (±2)
- Effect of initial guess on solution

**Example 2: Breakeven Analysis**
- Product pricing with demand curve
- Find price where profit = 0
- Calculate breakeven quantity
- Profit function with fixed and variable costs

**Example 3: Internal Rate of Return (IRR)**
- Find discount rate where NPV = 0
- Multi-period cash flow analysis
- Verify solution accuracy
- Show NPV at various discount rates

**Example 4: Target Seeking**
- SaaS business targeting specific MRR
- Find required customer count
- Steady-state analysis with churn
- Multi-variable target seeking

**Example 5: Equation Solving**
- Solve e^x - 2x - 3 = 0
- Solve cos(x) = x
- Solve x³ - 2x - 5 = 0
- Numerical solutions with verification

**Example 6: Constrained Goal-Seeking**
- Use `GoalSeekOptimizer` with constraints
- Minimum price constraints
- Bounds enforcement
- Convergence diagnostics

**Example 7: Error Handling**
- Division by zero errors
- Convergence failures
- Proper error recovery patterns
- Robust error handling

**Example 8: Multiple Roots**
- Functions with multiple solutions
- Effect of initial guess
- Finding different roots
- Root verification

```swift
import BusinessMath

// Find breakeven price
func profit(price: Double) -> Double {
    let quantity = 10000 - 1000 * price
    let revenue = price * quantity
    let costs = 20000 + 5 * quantity
    return revenue - costs
}

let breakevenPrice = try goalSeek(
    function: profit,
    target: 0.0,
    guess: 10.0,
    tolerance: 0.01
)

print("Breakeven: $\(breakevenPrice)")
```

### Running Phase 1 Examples

```bash
# Goal-seeking examples
swift Examples/GoalSeekExample.swift
```

### Phase 1 Documentation

For comprehensive documentation on Phase 1 features, see:
- **Tutorial**: `Instruction Set/PHASE_1_TUTORIAL.md` - Complete guide to goal-seeking
- **Source**: `Sources/BusinessMath/Solver/GoalSeek.swift` - Goal-seek function
- **Source**: `Sources/BusinessMath/Optimization/GoalSeekOptimizer.swift` - Optimizer class
- **Errors**: `Sources/BusinessMath/Errors/GoalSeekError.swift` - Error types

### Phase 2: VectorSpace Foundation Examples

**Generic vector operations** foundation for multivariate optimization:

#### VectorSpace Operations (`VectorSpaceExample.swift`)

Demonstrates the VectorSpace protocol and vector types:

**Example 1: Vector2D Operations**
- Create and manipulate 2D vectors
- Basic arithmetic (addition, scaling, negation)
- Norms and distances
- Dot product and cross product (2D pseudo-cross)
- Rotation and angle calculation

**Example 2: Vector3D Operations**
- 3D vector arithmetic
- Norms and dot products
- True 3D cross product (returns vector)
- Triple products (scalar and vector)
- Perpendicularity verification

**Example 3: VectorN Operations**
- Variable-dimension vectors
- Element access and indexing
- Statistical operations (sum, mean, std dev)
- Element-wise operations (Hadamard product, division)
- Range and bounds

**Example 4: Distance Metrics**
- Euclidean distance (L2 norm)
- Manhattan distance (L1 norm)
- Chebyshev distance (L∞ norm)
- Cosine similarity
- Practical distance comparisons

**Example 5: Projections and Orthogonality**
- Project vectors onto other vectors
- Rejection (perpendicular component)
- Vector decomposition
- Orthogonality testing
- Parallelism testing

**Example 6: Vector Construction**
- Standard construction methods
- Factory methods (ones, basis vectors)
- Linear and log spacing
- Manipulation (append, concatenate, slice)

**Example 7: Functional Operations**
- Map (element-wise transformations)
- Filter (selective extraction)
- Reduce (aggregation)
- ZipWith (combine two vectors)

**Example 8: Portfolio Weights Application**
- Real-world portfolio weights
- Weight normalization
- Expected return calculation
- Risk contribution analysis

**Example 9: Normalization**
- Unit vector normalization
- Feature normalization techniques
- Min-max scaling
- Z-score standardization

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
print(v.dot(w))              // 11.0

// Projections
let proj = v.projection(onto: w)
let rej = v.rejection(from: w)
// v = proj + rej (decomposition)
```

### Running Phase 2 Examples

```bash
# VectorSpace examples
swift Examples/VectorSpaceExample.swift
```

### Phase 2 Documentation

For comprehensive documentation on Phase 2 features, see:
- **Tutorial**: `Instruction Set/PHASE_2_TUTORIAL.md` - Complete VectorSpace guide
- **Source**: `Sources/BusinessMath/Optimization/Vector/VectorSpace.swift` - Protocol and implementations
- **Source**: `Sources/BusinessMath/Optimization/Constraint.swift` - MultivariateConstraint
- **Tests**: `Tests/BusinessMathTests/Optimization Tests/VectorSpaceTests.swift` - Comprehensive tests

### Phase 3: Multivariate Optimization Examples

**NEW!** Two comprehensive examples demonstrating Phase 3's multivariate optimization capabilities:

#### 1. General Optimization Methods (`OptimizationExample.swift`)

Demonstrates various optimization algorithms for multivariate functions:

**Example 1: Gradient Descent Comparison**
- Compares Basic GD, Momentum GD, and Adam optimizer
- Uses challenging Rosenbrock function (non-convex landscape)
- Shows convergence speed and iteration counts
- Demonstrates when to use each optimizer

**Example 2: Newton-Raphson Methods**
- Compares Full Newton vs. BFGS (quasi-Newton)
- Demonstrates quadratic convergence on smooth functions
- Shows the power of second-order methods
- 3-dimensional optimization example

**Example 3: Parameter Fitting**
- Least squares curve fitting (y = ax² + bx + c)
- Uses BFGS for efficient optimization
- Demonstrates practical application to data fitting
- Shows how to recover true parameters from noisy data

**Example 4: High-Dimensional Optimization**
- 10-dimensional sphere function minimization
- Demonstrates scalability of Adam optimizer
- Shows convergence in high dimensions

```swift
import BusinessMath

// Minimize Rosenbrock function using Adam
let rosenbrock: (VectorN<Double>) -> Double = { v in
    let x = v[0], y = v[1]
    let a = 1 - x
    let b = y - x*x
    return a*a + 100*b*b
}

let optimizer = AdamOptimizer<VectorN<Double>>(
    learningRate: 0.01,
    maxIterations: 10000
)

let result = try optimizer.minimize(rosenbrock, from: VectorN([0.0, 0.0]))
print("Solution: \(result.solution.components)")  // Should be close to [1, 1]
```

#### 2. Portfolio Optimization (`PortfolioOptimizationExample.swift`)

Demonstrates Modern Portfolio Theory and portfolio optimization:

**Example 1: Basic Portfolio Optimization**
- 4 assets with different risk/return profiles
- Minimum variance portfolio (lowest risk)
- Maximum Sharpe ratio portfolio (best risk-adjusted return)
- Target return portfolio (achieve 12% with minimum risk)

**Example 2: Efficient Frontier**
- Generates 20 portfolios along the efficient frontier
- Visualizes the risk-return trade-off
- Identifies min risk and max return portfolios
- Calculates Sharpe ratios for each portfolio

**Example 3: Risk Parity Portfolio**
- Equal risk contribution from each asset
- Balances portfolio risk across holdings
- Shows how to achieve diversification
- Displays risk contributions for each asset

**Example 4: Constrained Portfolios**
- Long-only (no short-selling)
- Long-short with 130/30 strategy (30% short, 130% long)
- Box constraints (position limits per asset)
- Demonstrates impact of constraints on Sharpe ratio

**Example 5: Real-World Portfolio**
- $1M portfolio with 5 asset classes
- Conservative, moderate, and aggressive allocations
- Shows dollar allocations per asset class
- Compares different investor risk profiles

```swift
import BusinessMath

let optimizer = PortfolioOptimizer(
    expectedReturns: [0.12, 0.15, 0.18, 0.05],
    covarianceMatrix: [
        [0.04, 0.01, 0.02, 0.00],
        [0.01, 0.09, 0.03, 0.01],
        [0.02, 0.03, 0.16, 0.02],
        [0.00, 0.01, 0.02, 0.01]
    ]
)

// Maximum Sharpe ratio portfolio
let portfolio = try optimizer.maximizeSharpe(
    riskFreeRate: 0.02,
    constraints: .longOnly
)

print("Sharpe Ratio: \(portfolio.sharpeRatio)")
print("Expected Return: \(portfolio.expectedReturn * 100)%")
print("Risk: \(portfolio.risk * 100)%")
print("Weights: \(portfolio.weights)")
```

### Running Phase 3 Examples

```bash
# General optimization examples
swift Examples/OptimizationExample.swift

# Portfolio optimization examples
swift Examples/PortfolioOptimizationExample.swift
```

### Phase 3 Documentation

For comprehensive documentation on Phase 3 optimization features, see:
- **Tutorial**: `Instruction Set/PHASE_3_TUTORIAL.md` - Complete guide with algorithm details
- **Source**: `Sources/BusinessMath/Optimization/` - Multivariate optimizers
- **Source**: `Sources/BusinessMath/PortfolioOptimization/` - Portfolio optimization
- **Tests**: `Tests/BusinessMathTests/Multivariate Optimization Tests/` - Comprehensive test coverage

### Phase 4: Constrained Optimization Examples

**NEW!** Comprehensive examples demonstrating Phase 4's constrained optimization framework:

#### Constrained Optimization (`ConstrainedOptimizationExample.swift`)

Demonstrates equality and inequality constrained optimization:

**Example 1: Equality-Constrained Optimization**
- Minimize x² + y² subject to x + y = 1
- Find point on line closest to origin
- Shows Lagrange multipliers (shadow prices)
- Demonstrates analytical vs. numerical solutions

**Example 2: Inequality-Constrained Optimization**
- Minimize (x - 2)² + (y - 2)² subject to x + y ≤ 2, x ≥ 0, y ≥ 0
- Find point in feasible region closest to (2, 2)
- Shows active vs. inactive constraints
- Demonstrates KKT conditions

**Example 3: Box-Constrained Optimization**
- Minimize Rosenbrock function with bounds
- Demonstrates simple bounds: -2 ≤ x ≤ 2, -1 ≤ y ≤ 3
- Shows when constraints are active vs. inactive

**Example 4: Constrained Least Squares**
- Fit y = a + bx to data with non-negativity constraints
- Demonstrates practical application to curve fitting
- Shows how constraints affect fitted parameters

**Example 5: Resource Allocation with Budget Constraint**
- Maximize utility U(x, y, z) = √x + √y + √z
- Subject to budget constraint: x + 2y + 3z = 100
- Shows Lagrange multiplier interpretation (marginal utility per dollar)
- Demonstrates optimal resource allocation

**Example 6: Portfolio with Leverage Constraint**
- Minimize variance subject to target return
- Leverage limit and full investment constraints
- Demonstrates financial optimization with multiple constraints
- Shows Sharpe ratio calculation

**Example 7: Unconstrained vs. Constrained Comparison**
- Same objective, different constraint sets
- Shows how constraints affect optimal solutions
- Demonstrates the value of constraint modeling

```swift
import BusinessMath

// Minimize f(x, y) = x² + y² subject to x + y = 1
let objective: (VectorN<Double>) -> Double = { v in
    let x = v[0], y = v[1]
    return x*x + y*y
}

let optimizer = ConstrainedOptimizer<VectorN<Double>>()

let result = try optimizer.minimize(
    objective,
    from: VectorN([0.0, 1.0]),
    subjectTo: [
        .equality { v in v[0] + v[1] - 1.0 }
    ]
)

print("Solution: (\(result.solution[0]), \(result.solution[1]))")
print("Lagrange multiplier: \(result.lagrangeMultipliers?.first ?? 0)")
```

### Running Phase 4 Examples

```bash
# Constrained optimization examples
swift Examples/ConstrainedOptimizationExample.swift
```

### Phase 4 Documentation

For comprehensive documentation on Phase 4 constrained optimization features, see:
- **Tutorial**: `Instruction Set/PHASE_4_TUTORIAL.md` - Complete guide with constraint types
- **Source**: `Sources/BusinessMath/Optimization/ConstrainedOptimization.swift` - Framework implementation
- **Tests**: `Tests/BusinessMathTests/Constrained Optimization Tests/` - Comprehensive test coverage

### Phase 5: Business Optimization Examples

**NEW!** Three comprehensive optimization examples demonstrating Phase 5's business optimization modules:

#### 1. Resource Allocation (`ResourceAllocationExample.swift`)

Demonstrates capital budgeting and project selection optimization:

**Example 1: Technology Company Capital Budgeting**
- 5 potential projects with dependencies and strategic importance
- $1M budget constraint
- Resource limits (headcount, quarters)
- Required projects (compliance)
- Mutual exclusivity constraints
- Weighted optimization (70% financial, 30% strategic)

**Example 2: Marketing Budget Allocation**
- Multi-channel marketing optimization
- ROI maximization across Google Ads, Facebook, LinkedIn, Content, and Influencer marketing
- Minimum allocation constraints for critical channels
- Shows channel-by-channel ROI analysis

```swift
import BusinessMath

let projects = [
    AllocationOption(
        id: "cloud_migration",
        name: "Cloud Infrastructure Migration",
        expectedValue: 400_000,
        resourceRequirements: ["budget": 250_000, "headcount": 8],
        strategicValue: 9.0
    ),
    // ... more projects
]

let optimizer = ResourceAllocationOptimizer()
let result = try optimizer.optimize(
    options: projects,
    objective: .maximizeWeightedValue(strategicWeight: 0.3),
    constraints: [.totalBudget(1_000_000), .requiredOption(optionId: "security_upgrade")]
)

print("Selected: \(result.selectedOptions.map { $0.name })")
print("Total value: $\(result.totalValue)")
```

#### 2. Production Planning (`ProductionPlanningExample.swift`)

Demonstrates multi-product manufacturing optimization:

**Example 1: Electronics Manufacturing**
- 3 product lines (Premium, Standard, Budget)
- Multiple resource constraints (assembly, testing, components)
- Demand ranges for each product
- Minimum production requirements (contracts)
- Detailed profit and utilization analysis

**Example 2: Objective Function Comparison**
- Shows how different objectives yield different optimal solutions
- Compares maximizing profit vs. revenue vs. margin
- Demonstrates the importance of choosing the right objective

**Example 3: Bottleneck Analysis**
- Identifies resource bottlenecks
- Shows resource utilization percentages
- Provides recommendations for capacity expansion

```swift
import BusinessMath

let products = [
    ManufacturedProduct(
        id: "premium",
        name: "Premium Model",
        pricePerUnit: 500,
        variableCostPerUnit: 280,
        demand: .range(min: 100, max: 400),
        resourceRequirements: [
            "assembly_hours": 5.0,
            "testing_hours": 3.0,
            "components_units": 50.0
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

print("Production: \(plan.productionQuantities)")
print("Profit: $\(plan.profit)")
```

#### 3. Driver Optimization (`DriverOptimizationExample.swift`)

Demonstrates financial target seeking through operational driver optimization:

**Example 1: SaaS MRR Target Seeking**
- Optimize price, churn rate, and customer acquisition to hit $150K MRR
- Multi-target optimization (MRR, customer count, LTV:CAC ratio)
- Change constraints (realistic limits on how much each driver can change)
- Comprehensive action plan generation

**Example 2: E-commerce Conversion Optimization**
- Optimize product price, conversion rate, and traffic
- Price elasticity modeling (higher price reduces conversion)
- Balance revenue goals with order volume targets

**Example 3: Multi-Objective Financial Planning**
- Balance competing objectives: growth, profitability, efficiency
- Demonstrates trade-offs between different goals
- Shows how to weight different targets by importance

```swift
import BusinessMath

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
        range: 0.02...0.08,
        changeConstraint: .absoluteChange(max: 0.015)
    ),
    // ... more drivers
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
        // Your financial model here
        return ["mrr": ..., "ltv_cac_ratio": ...]
    }
)

print("Optimized drivers: \(result.optimizedDrivers)")
print("Targets met: \(result.feasible)")
```

### Running Phase 5 Examples

All Phase 5 examples are runnable Swift files. To execute them:

```bash
# Resource allocation example
swift Examples/ResourceAllocationExample.swift

# Production planning example
swift Examples/ProductionPlanningExample.swift

# Driver optimization example
swift Examples/DriverOptimizationExample.swift
```

Or compile and run from within your project:

```swift
import BusinessMath

// The examples are executable and will print formatted output
// showing optimization results, resource utilization, and recommendations
```

### Phase 5 Documentation

For comprehensive documentation on Phase 5 optimization features, see:
- **Tutorial**: `Instruction Set/PHASE_5_TUTORIAL.md` - Complete guide with API reference
- **Plan**: `Instruction Set/PHASE_5_PLAN.md` - Implementation details and design decisions
- **Tests**: `Tests/BusinessMathTests/Business Optimization Tests/` - 40 comprehensive tests

## Additional Resources

- See `QuickStart.swift` for runnable examples
- See `ReidsRaisinsDemo.swift` for a complete case study
- All examples are tested in `DocumentationExamplesTests.swift`
- Full API documentation available in source files

## Support

For issues, questions, or feature requests, please refer to the main repository documentation.

---

© 2025 BusinessMath Library
