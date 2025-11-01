# Optimization and Numerical Solvers

Learn how to find optimal values and solve equations using BusinessMath's optimization toolkit.

## Overview

BusinessMath provides powerful optimization algorithms for finding optimal solutions to business problems. Whether you need to maximize profits, minimize costs, or solve complex equations, these tools help you find the best answer.

This guide covers:
- Finding zeros of functions with Newton-Raphson
- Maximizing or minimizing objectives with Gradient Descent
- Allocating limited capital across investment opportunities
- Solving real-world business optimization problems

## Newton-Raphson: Goal Seek for Any Function

The Newton-Raphson method finds values where a function equals a target (often zero). It's like Excel's Goal Seek but works with any mathematical function.

### Finding Break-Even Points

```swift
import BusinessMath

// Revenue function: R(price) = price × quantity(price)
// quantity(price) = 10000 - 50×price
// Cost = $50,000 fixed + $20 per unit

func profit(price: Double) -> Double {
    let quantity = 10000 - 50 * price
    let revenue = price * quantity
    let cost = 50000 + 20 * quantity
    return revenue - cost
}

let optimizer = NewtonRaphsonOptimizer<Double>()

// Find price where profit = $100,000
let result = optimizer.optimize(
    objective: { profit(price: $0) - 100000 },
    initialValue: 200.0
)

print("Optimal price: $\(result.optimalValue)")
print("Profit at that price: $\(profit(price: result.optimalValue))")
```

### Solving Yield to Maturity

```swift
// Bond: $1000 face value, 5% coupon, 8 years, trading at $920
// Find yield to maturity

func bondPriceError(yield: Double) -> Double {
    let coupon = 50.0  // $50 annual
    let faceValue = 1000.0
    let years = 8
    let marketPrice = 920.0

    // Calculate PV of bond at this yield
    let pvCoupons = presentValueAnnuity(
        payment: coupon,
        rate: yield,
        periods: years,
        type: .ordinary
    )
    let pvFace = presentValue(
        futureValue: faceValue,
        rate: yield,
        periods: years
    )

    let calculatedPrice = pvCoupons + pvFace
    return calculatedPrice - marketPrice
}

let ytmResult = optimizer.optimize(
    objective: bondPriceError,
    initialValue: 0.06  // Start with 6% guess
)

print("Yield to maturity: \(ytmResult.optimalValue * 100)%")
```

## Gradient Descent: Finding Optimal Values

Gradient Descent finds maximum or minimum values of functions. It's perfect for optimization problems where you want the "best" solution.

### Maximizing Profit

```swift
// Profit function: revenue - costs
// Revenue = price × quantity, where quantity = f(price, marketing)
// Costs = fixed + variable

func profitFunction(_ variables: [Double]) -> Double {
    let price = variables[0]
    let marketing = variables[1]

    // Demand model: more marketing = more sales, but diminishing returns
    let baseDemand = 1000.0
    let priceElasticity = -2.0
    let marketingEffect = sqrt(marketing / 10000.0)

    let quantity = baseDemand * pow(price / 100, priceElasticity) * (1 + marketingEffect)
    let revenue = price * quantity

    let fixedCosts = 50000.0
    let variableCost = 30.0
    let costs = fixedCosts + variableCost * quantity + marketing

    return revenue - costs
}

let gradientOptimizer = GradientDescentOptimizer<Double>(
    learningRate: 0.01,
    maxIterations: 1000
)

let profitResult = gradientOptimizer.optimize(
    objective: profitFunction,
    initialValues: [100.0, 20000.0]  // Start: $100 price, $20k marketing
)

print("Optimal price: $\(profitResult.optimalValues[0])")
print("Optimal marketing spend: $\(profitResult.optimalValues[1])")
print("Maximum profit: $\(profitResult.objectiveValue)")
```

### Portfolio Allocation

```swift
// Find optimal allocation weights to maximize Sharpe ratio
let returns: [[Double]] = [
    [0.08, 0.10, 0.12, 0.15, 0.09],  // Stock A monthly returns
    [0.05, 0.06, 0.04, 0.08, 0.05],  // Stock B
    [0.03, 0.04, 0.03, 0.03, 0.04]   // Bonds
]

func portfolioSharpe(_ weights: [Double]) -> Double {
    // Calculate portfolio return and risk
    var portfolioReturns: [Double] = []

    for month in 0..<5 {
        var monthReturn = 0.0
        for asset in 0..<3 {
            monthReturn += weights[asset] * returns[asset][month]
        }
        portfolioReturns.append(monthReturn)
    }

    let avgReturn = mean(portfolioReturns)
    let stdDev = standardDeviation(portfolioReturns)
    let riskFreeRate = 0.02 / 12  // 2% annual = 0.167% monthly

    return (avgReturn - riskFreeRate) / stdDev
}

// Optimize with constraint: weights sum to 1
let allocationResult = gradientOptimizer.optimize(
    objective: portfolioSharpe,
    initialValues: [0.33, 0.33, 0.34]  // Start with equal weights
)

print("Optimal allocation:")
print("  Stock A: \(allocationResult.optimalValues[0] * 100)%")
print("  Stock B: \(allocationResult.optimalValues[1] * 100)%")
print("  Bonds: \(allocationResult.optimalValues[2] * 100)%")
```

## Capital Allocation: Investment Selection

When you have limited capital and multiple investment opportunities, capital allocation algorithms help you choose the best combination.

### Greedy Algorithm

The greedy approach selects projects in order of highest ROI until capital runs out.

```swift
struct Project {
    let name: String
    let cost: Double
    let npv: Double

    var profitabilityIndex: Double {
        npv / cost
    }
}

let projects = [
    Project(name: "Website Redesign", cost: 50000, npv: 80000),
    Project(name: "New Product Line", cost: 200000, npv: 280000),
    Project(name: "Marketing Campaign", cost: 30000, npv: 45000),
    Project(name: "Equipment Upgrade", cost: 100000, npv: 135000),
    Project(name: "Warehouse Expansion", cost: 150000, npv: 195000)
]

let allocation = CapitalAllocator.greedyAllocation(
    projects: projects,
    budget: 300000
)

print("Selected projects:")
for project in allocation.selectedProjects {
    print("  \(project.name): Cost $\(project.cost), NPV $\(project.npv)")
}
print("Total NPV: $\(allocation.totalNPV)")
print("Capital used: $\(allocation.capitalUsed)")
```

### Optimal Allocation

For more complex scenarios, use integer programming to find the truly optimal combination.

```swift
// Same projects, but now we can select fractional investments
let optimalAllocation = CapitalAllocator.optimalAllocation(
    projects: projects,
    budget: 300000,
    allowFractional: false  // Integer programming: all or nothing
)

print("\nOptimal selection:")
for project in optimalAllocation.selectedProjects {
    print("  \(project.name): NPV $\(project.npv)")
}
print("Total NPV: $\(optimalAllocation.totalNPV)")
```

## Practical Tips

### Choosing Initial Values

Start with reasonable business assumptions:
```swift
// For prices: use market average
initialValue: 100.0

// For percentages: use industry benchmarks
initialValue: 0.08  // 8% return

// For quantities: use current volume
initialValue: 1000.0
```

### Setting Tolerances

Balance precision with computation time:
```swift
// High precision (slower)
let optimizer = NewtonRaphsonOptimizer<Double>(
    tolerance: 0.0001,
    maxIterations: 100
)

// Standard precision (faster)
let quickOptimizer = NewtonRaphsonOptimizer<Double>(
    tolerance: 0.01,
    maxIterations: 50
)
```

### Handling Convergence Issues

If optimization doesn't converge:
1. Try different initial values
2. Increase max iterations
3. Check your objective function for discontinuities
4. Normalize your inputs (scale to similar ranges)

## Next Steps

- Explore <doc:ForecastingGuide> for predicting future values with optimized parameters
- Learn <doc:PortfolioOptimizationGuide> for Modern Portfolio Theory optimization
- See <doc:ScenarioAnalysisGuide> for optimizing across multiple scenarios

## See Also

- ``NewtonRaphsonOptimizer``
- ``GradientDescentOptimizer``
- ``CapitalAllocator``
- ``OptimizationResult``
- ``Constraint``
