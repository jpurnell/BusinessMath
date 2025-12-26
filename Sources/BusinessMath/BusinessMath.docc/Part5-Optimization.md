# Part V: Optimization

Find optimal solutions using mathematical optimization and operations research.

## Overview

Part V introduces mathematical optimization—the systematic search for the best solution among many alternatives. While earlier parts taught you to model, analyze, and simulate, Part V teaches you to *optimize*: maximize returns, minimize costs, allocate resources efficiently, and find the best decisions subject to constraints.

Optimization is where BusinessMath becomes truly powerful. Instead of manually trying different scenarios to find good solutions, you can mathematically guarantee finding optimal solutions. Whether you're allocating capital across investments, scheduling resources, or constructing efficient portfolios, optimization provides rigorous, defensible answers.

This part takes you from simple goal-seeking (find the growth rate that achieves target revenue) through portfolio optimization (find the efficient frontier) to advanced techniques like integer programming and robust optimization. The journey progresses from fundamental concepts through increasingly sophisticated applications.

## What You'll Learn

- **Goal Seeking & Root Finding**: Solve for unknown inputs that achieve target outputs
- **Unconstrained Optimization**: Find maxima and minima using gradient descent and Newton methods
- **Constrained Optimization**: Optimize subject to equality and inequality constraints
- **Portfolio Optimization**: Modern Portfolio Theory, efficient frontier, and risk parity
- **Integer Programming**: Optimization with discrete decision variables
- **Advanced Techniques**: Parallel multi-start, adaptive algorithm selection, robust optimization

## Chapters in This Part

### Fundamentals
- <doc:5.1-OptimizationGuide> - Comprehensive guide from goal-seeking through business optimization
- <doc:5.2-PortfolioOptimizationGuide> - Modern Portfolio Theory and efficient portfolios

### Deep Dive: Optimization Phases
This progressive tutorial series builds optimization capabilities from first principles:

**Phase 1-2: Foundations**
- <doc:5.3-CoreOptimization> - Goal-seeking API, root-finding, and constraint builders
- <doc:5.4-VectorOperations> - Vector mathematics for multivariate problems

**Phase 3-5: Core Algorithms**
- <doc:5.5-MultivariateOptimization> - Gradient descent and Newton-Raphson methods
- <doc:5.6-ConstrainedOptimization> - Equality and inequality constraints
- <doc:5.6-BusinessOptimization> - Resource allocation, production planning, financial model drivers

**Phase 6-7: Advanced Techniques**
- <doc:5.8-IntegerProgramming> - Branch-and-bound, branch-and-cut with cutting planes
- <doc:5.9-AdaptiveSelection> - Automatic algorithm selection based on problem characteristics
- <doc:5.10-ParallelOptimization> - Parallel multi-start for global optimum finding
- <doc:5.11-PerformanceBenchmarking> - Performance testing and optimization

**Phase 8: Specialized Applications**
- <doc:5.12-SparseMatrix> - Efficient sparse matrix operations for large-scale problems
- <doc:5.13-MultiPeriod> - Stochastic multi-period optimization
- <doc:5.14-RobustOptimization> - Optimization under uncertainty

### Specialized Topics
- <doc:5.15-InequalityConstraints> - Detailed treatment of inequality constraint handling

## Prerequisites

Optimization builds on everything you've learned:

- **Essential**: Time series (<doc:1.2-TimeSeries>), financial calculations (<doc:1.3-TimeValueOfMoney>)
- **Important**: Financial modeling (<doc:Part3-Modeling>) - You need models to optimize
- **Helpful**: Risk analytics (<doc:2.3-RiskAnalyticsGuide>) - For risk-aware optimization
- **For Advanced Topics**: Simulation (<doc:Part4-Simulation>) - For robust optimization

Basic calculus (derivatives) helps for understanding gradient-based methods, but isn't strictly required—the library handles the mathematics.

## Suggested Reading Order

### For Business Users (FP&A, Finance):
1. <doc:5.1-OptimizationGuide> - Start with business optimization section (Phase 5)
2. <doc:5.2-PortfolioOptimizationGuide> - Portfolio applications
3. <doc:5.3-CoreOptimization> - Goal-seeking for financial models
4. Stop here unless you need advanced techniques

### For Quantitative Analysts:
1. <doc:5.1-OptimizationGuide> - Complete overview
2. <doc:5.3-CoreOptimization> through <doc:5.6-BusinessOptimization> - Core sequence
3. <doc:5.2-PortfolioOptimizationGuide> - Portfolio applications
4. Advanced phases as needed

### For Optimization Specialists:
- Read the Phase tutorials sequentially from 5.3 through 5.14
- Each phase builds on previous phases
- Complete all phases for comprehensive understanding

### For Portfolio Managers:
1. <doc:5.2-PortfolioOptimizationGuide> - Start here
2. <doc:5.1-OptimizationGuide> - Understand the optimization framework
3. <doc:5.14-RobustOptimization> - Robustness under uncertainty
4. <doc:2.3-RiskAnalyticsGuide> - Risk measurement

## Key Concepts

### Goal Seeking

Find input values that achieve target outputs:

```swift
let targetRevenue = 1_000_000.0

// Define revenue model as a function of growth rate
let revenueFunction = { (growthRate: Double) -> Double in
    let baseRevenue = 800_000.0
    return baseRevenue * (1 + growthRate)
}

let requiredGrowthRate = try goalSeek(
    function: revenueFunction,
    target: targetRevenue,
    guess: 0.10
)
// What growth rate do we need to hit $1M revenue?
```

### Constrained Optimization

Optimize subject to real-world constraints:

```swift
// Maximize expected return subject to budget and risk constraints
let optimizer = InequalityOptimizer<VectorN<Double>>()

let totalBudget = 100_000.0
let maxRisk = 0.20

let objective = { (capital: VectorN<Double>) -> Double in
    // Calculate expected return (minimize negative return to maximize)
    let weights = capital.toArray().map { $0 / totalBudget }
    let expectedReturn = zip(weights, [0.08, 0.12, 0.15]).map(*).reduce(0, +)
    return -expectedReturn  // Negate to maximize
}

let constraints: [MultivariateConstraint<VectorN<Double>>] = [
    .equality { v in v.toArray().reduce(0, +) - totalBudget },  // Budget constraint
    .inequality { v in  // Risk constraint
        let weights = v.toArray().map { $0 / totalBudget }
        let variance = /* calculate portfolio variance */
        return sqrt(variance) - maxRisk
    }
]

let result = try optimizer.minimize(objective, from: VectorN([30_000, 40_000, 30_000]), constraints: constraints)
let optimalAllocation = result.solution
```

### Portfolio Optimization

Construct efficient portfolios using Modern Portfolio Theory:

```swift
let returns = VectorN([0.08, 0.12, 0.15])
let covMatrix = [
    [0.04, 0.01, 0.02],
    [0.01, 0.09, 0.03],
    [0.02, 0.03, 0.16]
]

let optimizer = PortfolioOptimizer()

// Minimum variance portfolio
let minVar = try optimizer.minimumVariancePortfolio(
    expectedReturns: returns,
    covariance: covMatrix
)

// Maximum Sharpe ratio
let maxSharpe = try optimizer.maximumSharpePortfolio(
    expectedReturns: returns,
    covariance: covMatrix,
    riskFreeRate: 0.02
)

// Efficient frontier
let frontier = try optimizer.efficientFrontier(
    expectedReturns: returns,
    covariance: covMatrix,
    numberOfPoints: 50
)
```

### Integer Programming

Optimize with discrete decisions (yes/no, count, selection):

```swift
// Select projects to maximize NPV subject to budget constraint
let projectNPVs = [50_000.0, 75_000.0, 60_000.0, 90_000.0]
let projectCosts = [20_000.0, 35_000.0, 25_000.0, 40_000.0]
let budget = 80_000.0


// Constraint: total cost <= budget
let constraints: [MultivariateConstraint<VectorN<Double>>] = [
	.inequality { v in
		let cost = zip(v.toArray(), projectCosts).map(*).reduce(0, +)
		return cost - budget
	}
]

// Integer specification: all variables are binary (0 or 1)
let integerSpec = IntegerProgramSpecification.allBinary(dimension: projectNPVs.count)

let solver = BranchAndBoundSolver<VectorN<Double>>()
let result = try solver.solve(
	objective: { (selected: VectorN<Double>) -> Double in
		let npv = zip(selected.toArray(), projectNPVs).map(*).reduce(0, +)
	 return -npv  // Negate to maximize
 }, // Objective: maximize total NPV (minimize negative NPV)
	from: VectorN([0, 0, 0, 0]),
	subjectTo: constraints,
	integerSpec: integerSpec,
	minimize: true  // Minimize negative NPV = maximize NPV
)

let selectedProjects = result.solution

```

## Real-World Applications

### Capital Allocation
Allocate limited capital across projects to maximize NPV subject to budget constraints and strategic requirements.

### Portfolio Construction
Build efficient portfolios that maximize return for given risk or minimize risk for target return. Implement Modern Portfolio Theory in practice.

### Resource Planning
Optimize production schedules, staffing levels, or inventory policies subject to capacity, demand, and cost constraints.

### Financial Model Calibration
Find parameter values that best fit historical data or achieve target outputs. Calibrate models to market prices.

### Risk-Aware Optimization
Optimize considering both expected returns and risk. Build robust solutions that perform well across scenarios.

## Optimization Algorithms

BusinessMath implements multiple algorithms, automatically selecting the best for your problem:

- **Simplex Method**: Linear programming
- **Gradient Descent**: Smooth unconstrained problems
- **Newton-Raphson**: Fast convergence for well-behaved problems
- **Quadratic Penalty**: Interior point solutions for inequality constraints
- **Branch-and-Bound**: Integer programming
- **Branch-and-Cut**: Enhanced integer programming with cutting planes

The adaptive selection system (<doc:5.9-AdaptiveSelection>) chooses algorithms based on problem characteristics.

## Performance Considerations

**Problem Size**: Optimization scales differently by problem type:
- Small problems (<10 variables): All methods work well
- Medium problems (10-100 variables): Gradient methods excel
- Large problems (>100 variables): Use sparse matrices (<doc:5.12-SparseMatrix>)

**Global vs. Local**:
- Local optimization finds nearby optima (fast)
- Global optimization finds best overall solution (slower)
- Use parallel multi-start (<doc:5.10-ParallelOptimization>) for global optimization

**Convergence**:
- Set appropriate tolerance for your application
- Financial models typically need 0.01% tolerance
- Engineering applications may need higher precision

## Common Pitfalls

**Non-Convex Problems**: May have multiple local optima. Use multi-start optimization or try different initial guesses.

**Infeasible Constraints**: If no solution satisfies all constraints, optimization fails. Review constraints for conflicts.

**Poor Scaling**: Variables with very different magnitudes (e.g., 0.01 vs. 1,000,000) can cause numerical issues. Normalize or rescale.

**Overconstraining**: Too many constraints may have no feasible solution. Start with essential constraints only.

## Next Steps

After mastering optimization:

- **Apply to Real Problems**: Use optimization in your financial models and business decisions
- **Combine with Simulation** (<doc:Part4-Simulation>) - Robust optimization under uncertainty
- **Build Applications** - Create decision support tools using optimization
- **Explore Case Studies** (<doc:Appendix-A-ReidsRaisinsExample>) - Real-world examples

## Common Questions

**When should I use optimization vs. just trying different scenarios?**

Use optimization when:
- The problem has many variables or constraints
- You need provably optimal solutions
- Manual search would be time-consuming
- The problem will be solved repeatedly

Manual scenarios work fine for simple problems or one-off analysis.

**How do I know if my optimization found the global optimum?**

For convex problems (linear, quadratic with constraints forming a convex set), any local optimum is global. For non-convex problems, use multi-start optimization or try from multiple initial points.

**What if my problem has no solution?**

Check your constraints for conflicts. Start with just the objective and add constraints one at a time. The conflict will reveal itself.

**Can I optimize discrete choices (select projects, choose locations)?**

Yes! Use integer programming (<doc:5.8-IntegerProgramming>) with binary variables (0 or 1) to model yes/no decisions.

## Related Topics

- <doc:Part3-Modeling> - Models to optimize
- <doc:Part4-Simulation> - Combine with robust optimization
- <doc:2.3-RiskAnalyticsGuide> - Risk metrics for risk-aware optimization
- <doc:2.1-DataTableAnalysis> - Sensitivity analysis complements optimization
