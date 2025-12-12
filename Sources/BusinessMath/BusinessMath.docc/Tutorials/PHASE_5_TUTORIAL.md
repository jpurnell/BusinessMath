# Phase 5: Business Optimization - Complete Tutorial

**Created:** 2025-12-04
**Status:** Complete ✅

---

## Table of Contents

1. [Overview](#overview)
2. [Resource Allocation Optimizer](#resource-allocation-optimizer)
3. [Production Planning Optimizer](#production-planning-optimizer)
4. [Financial Model Driver Optimizer](#financial-model-driver-optimizer)
5. [Integration Examples](#integration-examples)
6. [Troubleshooting](#troubleshooting)
7. [Best Practices](#best-practices)

---

## Overview

Phase 5 delivers three production-ready business optimization modules that make sophisticated constrained optimization accessible through domain-specific APIs. Each optimizer builds on the constrained optimization framework from Phase 4.

### What's Included

- **Resource Allocation Optimizer**: Capital budgeting, project selection, budget allocation
- **Production Planning Optimizer**: Multi-product manufacturing optimization
- **Financial Model Driver Optimizer**: Target seeking for financial goals

### Design Philosophy

Each optimizer follows a consistent pattern:
1. **Input Types**: Business-focused data structures (projects, products, drivers)
2. **Constraints**: Domain-specific constraint enums
3. **Objectives**: Multiple objective functions to choose from
4. **Results**: Rich result types with diagnostics

---

## Resource Allocation Optimizer

### What Problems Does It Solve?

- **Capital Budgeting**: Which projects should we fund with limited capital?
- **Budget Allocation**: How should we distribute budget across departments?
- **Marketing Mix**: How should we allocate marketing spend across channels?
- **Workforce Planning**: How should we assign employees to projects?

### Quick Start (5 lines)

```swift
import BusinessMath

// Define investment options
let projects = [
    AllocationOption(
        id: "proj_a",
        name: "New Product Launch",
        expectedValue: 500_000,  // Expected NPV
        resourceRequirements: ["budget": 150_000]
    ),
    AllocationOption(
        id: "proj_b",
        name: "Marketing Campaign",
        expectedValue: 300_000,
        resourceRequirements: ["budget": 100_000]
    )
]

// Optimize allocation
let optimizer = ResourceAllocationOptimizer()
let result = try optimizer.optimize(
    options: projects,
    objective: .maximizeValue,
    constraints: [.totalBudget(200_000)]
)

print("Selected: \(result.selectedOptions.map { $0.name })")
print("Total value: $\(result.totalValue)")
```

### Core Types

#### AllocationOption
Represents a project, investment, or option to allocate resources to.

```swift
public struct AllocationOption {
    public let id: String                          // Unique identifier
    public let name: String                        // Human-readable name
    public let expectedValue: Double               // NPV, ROI, revenue to maximize
    public let resourceRequirements: [String: Double]  // Resources needed
    public let strategicValue: Double?             // Optional strategic score (0-10)
    public let dependencies: Set<String>?          // Required prerequisites
}
```

**Example:**
```swift
let project = AllocationOption(
    id: "digital_transformation",
    name: "Digital Transformation Initiative",
    expectedValue: 2_000_000,
    resourceRequirements: [
        "budget": 500_000,
        "headcount": 15,
        "quarters": 4
    ],
    strategicValue: 9.5,
    dependencies: ["infrastructure_upgrade"]
)
```

#### AllocationConstraint
Business constraints on resource allocation.

```swift
public enum AllocationConstraint {
    case totalBudget(Double)                        // Maximum total budget
    case resourceLimit(resource: String, limit: Double)  // Max of specific resource
    case minimumAllocation(optionId: String, amount: Double)  // Min funding
    case maximumAllocation(optionId: String, amount: Double)  // Max funding
    case requiredOption(optionId: String)           // Must select
    case excludedOption(optionId: String)           // Cannot select
    case dependency(optionId: String, requires: String)  // If A then B
    case mutuallyExclusive([String])                // Only one from set
}
```

#### AllocationObjective
Objective functions for optimization.

```swift
public enum AllocationObjective {
    case maximizeValue                  // Maximize sum of expected values
    case maximizeValuePerDollar         // Maximize efficiency (value/cost)
    case maximizeWeightedValue(strategicWeight: Double)  // Blend value + strategic
    case maximizeRiskAdjustedValue(riskDiscount: Double)  // Discount for risk
    case custom((AllocationResult) -> Double)  // Custom objective
}
```

### Detailed Example: Capital Budgeting

A company has 5 potential projects and $1M budget. Some projects have dependencies.

```swift
import BusinessMath

// Define all project options
let projects = [
    AllocationOption(
        id: "infrastructure",
        name: "Infrastructure Upgrade",
        expectedValue: 300_000,
        resourceRequirements: ["budget": 200_000, "headcount": 5],
        strategicValue: 8.0
    ),
    AllocationOption(
        id: "new_product",
        name: "New Product Launch",
        expectedValue: 800_000,
        resourceRequirements: ["budget": 400_000, "headcount": 10],
        strategicValue: 9.0,
        dependencies: ["infrastructure"]  // Requires infrastructure
    ),
    AllocationOption(
        id: "marketing",
        name: "Marketing Expansion",
        expectedValue: 400_000,
        resourceRequirements: ["budget": 250_000, "headcount": 3],
        strategicValue: 6.0
    ),
    AllocationOption(
        id: "cost_reduction",
        name: "Cost Reduction Initiative",
        expectedValue: 200_000,
        resourceRequirements: ["budget": 100_000, "headcount": 2],
        strategicValue: 7.0
    ),
    AllocationOption(
        id: "acquisition",
        name: "Strategic Acquisition",
        expectedValue: 1_000_000,
        resourceRequirements: ["budget": 600_000, "headcount": 8],
        strategicValue: 8.5
    )
]

// Define constraints
let constraints: [AllocationConstraint] = [
    .totalBudget(1_000_000),                      // $1M budget limit
    .resourceLimit(resource: "headcount", limit: 15),  // Max 15 people
    .requiredOption(optionId: "infrastructure"),  // Must upgrade infrastructure
    .mutuallyExclusive(["new_product", "acquisition"])  // Can't do both
]

// Optimize: balance financial value (70%) with strategic importance (30%)
let optimizer = ResourceAllocationOptimizer()
let result = try optimizer.optimize(
    options: projects,
    objective: .maximizeWeightedValue(strategicWeight: 0.3),
    constraints: constraints
)

// Print results
print("=== Optimal Capital Allocation ===")
print("Total Value: $\(Int(result.totalValue))")
print("Converged: \(result.converged)")
print()

print("Selected Projects:")
for option in result.selectedOptions {
    let allocation = result.allocations[option.id] ?? 0
    print("  • \(option.name) - \(Int(allocation * 100))% funded")
    print("    NPV: $\(Int(option.expectedValue))")
    print("    Budget: $\(Int(option.resourceRequirements["budget"] ?? 0))")
}

print()
print("Resource Usage:")
for (resource, used) in result.totalResourcesUsed {
    print("  • \(resource): \(Int(used))")
}
```

### Common Use Cases

#### 1. Marketing Channel Allocation
```swift
let channels = [
    AllocationOption(
        id: "google_ads",
        name: "Google Ads",
        expectedValue: 150_000,  // Expected revenue
        resourceRequirements: ["spend": 50_000]
    ),
    AllocationOption(
        id: "facebook_ads",
        name: "Facebook Ads",
        expectedValue: 120_000,
        resourceRequirements: ["spend": 40_000]
    ),
    AllocationOption(
        id: "content_marketing",
        name: "Content Marketing",
        expectedValue: 80_000,
        resourceRequirements: ["spend": 30_000]
    )
]

let result = try optimizer.optimize(
    options: channels,
    objective: .maximizeValuePerDollar,  // Maximize ROI
    constraints: [.totalBudget(100_000)]
)
```

#### 2. Department Budget Allocation
```swift
let departments = [
    AllocationOption(
        id: "engineering",
        name: "Engineering",
        expectedValue: 5_000_000,
        resourceRequirements: ["budget": 2_000_000],
        strategicValue: 9.0
    ),
    AllocationOption(
        id: "sales",
        name: "Sales",
        expectedValue: 3_000_000,
        resourceRequirements: ["budget": 1_000_000],
        strategicValue: 8.0
    ),
    // ... more departments
]

let constraints: [AllocationConstraint] = [
    .totalBudget(5_000_000),
    .minimumAllocation(optionId: "engineering", amount: 0.5),  // At least 50%
    .minimumAllocation(optionId: "sales", amount: 0.3)
]
```

---

## Production Planning Optimizer

### What Problems Does It Solve?

- **Production Scheduling**: What quantities should we produce?
- **Product Mix**: Which products should we prioritize?
- **Capacity Planning**: How can we maximize output given constraints?
- **Inventory Optimization**: Balance production costs vs holding costs

### Quick Start (5 lines)

```swift
import BusinessMath

// Define products to manufacture
let products = [
    ManufacturedProduct(
        id: "widget_a",
        name: "Widget A",
        pricePerUnit: 100,
        variableCostPerUnit: 45,
        demand: .unlimited,
        resourceRequirements: ["machine_hours": 2.0, "labor_hours": 1.0]
    ),
    ManufacturedProduct(
        id: "widget_b",
        name: "Widget B",
        pricePerUnit: 80,
        variableCostPerUnit: 30,
        demand: .unlimited,
        resourceRequirements: ["machine_hours": 1.5, "labor_hours": 1.5]
    )
]

// Optimize production plan
let optimizer = ProductionPlanningOptimizer()
let plan = try optimizer.optimize(
    products: products,
    resources: ["machine_hours": 1000, "labor_hours": 800],
    objective: .maximizeProfit
)

print("Optimal Production:")
for (productId, quantity) in plan.productionQuantities {
    print("  \(productId): \(Int(quantity)) units")
}
print("Total Profit: $\(Int(plan.profit))")
```

### Core Types

#### ManufacturedProduct
Represents a product to manufacture.

```swift
public struct ManufacturedProduct {
    public let id: String
    public let name: String
    public let pricePerUnit: Double
    public let variableCostPerUnit: Double
    public let demand: ProductDemand
    public let resourceRequirements: [String: Double]

    public var contributionMargin: Double {
        pricePerUnit - variableCostPerUnit
    }
}
```

#### ProductDemand
Demand constraints for a product.

```swift
public enum ProductDemand {
    case unlimited                      // Sell all we produce
    case fixed(Double)                  // Exact demand quantity
    case range(min: Double, max: Double)  // Demand range
}
```

#### ProductionObjective
Objective functions for production planning.

```swift
public enum ProductionObjective {
    case maximizeProfit        // Revenue - costs
    case maximizeRevenue       // Total revenue
    case maximizeMargin        // (Revenue - costs) / Revenue
    case minimizeCosts         // Minimize total costs
    case maximizeUtilization   // Use resources efficiently
}
```

### Detailed Example: Multi-Product Manufacturing

A manufacturer produces 3 product lines with different margins and resource requirements.

```swift
import BusinessMath

// Define product catalog
let products = [
    ManufacturedProduct(
        id: "deluxe",
        name: "Deluxe Model",
        pricePerUnit: 250,
        variableCostPerUnit: 120,
        demand: .range(min: 50, max: 300),  // Must sell 50-300 units
        resourceRequirements: [
            "assembly_hours": 4.0,
            "testing_hours": 2.0,
            "materials_kg": 5.0
        ]
    ),
    ManufacturedProduct(
        id: "standard",
        name: "Standard Model",
        pricePerUnit: 150,
        variableCostPerUnit: 70,
        demand: .range(min: 100, max: 500),
        resourceRequirements: [
            "assembly_hours": 2.0,
            "testing_hours": 1.0,
            "materials_kg": 3.0
        ]
    ),
    ManufacturedProduct(
        id: "economy",
        name: "Economy Model",
        pricePerUnit: 80,
        variableCostPerUnit: 35,
        demand: .unlimited,
        resourceRequirements: [
            "assembly_hours": 1.0,
            "testing_hours": 0.5,
            "materials_kg": 2.0
        ]
    )
]

// Define available resources (monthly capacity)
let resources = [
    "assembly_hours": 2000.0,
    "testing_hours": 1000.0,
    "materials_kg": 4000.0
]

// Add production constraints
let constraints: [ProductionConstraint] = [
    .minimumProduction(productId: "deluxe", quantity: 60),  // Contractual obligation
    .productionRatio(productA: "standard", productB: "economy", ratio: 0.5)  // 1:2 ratio
]

// Optimize for maximum profit
let optimizer = ProductionPlanningOptimizer(maxIterations: 300)
let plan = try optimizer.optimize(
    products: products,
    resources: resources,
    objective: .maximizeProfit,
    constraints: constraints
)

// Display results
print("=== Optimal Production Plan ===")
print("Converged: \(plan.converged) (\(plan.iterations) iterations)")
print()

print("Production Quantities:")
for (productId, quantity) in plan.productionQuantities.sorted(by: { $0.key < $1.key }) {
    let product = products.first { $0.id == productId }!
    let revenue = product.pricePerUnit * quantity
    let cost = product.variableCostPerUnit * quantity
    let profit = revenue - cost

    print("  • \(product.name): \(Int(quantity)) units")
    print("    Revenue: $\(Int(revenue)) | Cost: $\(Int(cost)) | Profit: $\(Int(profit))")
}

print()
print("Financial Summary:")
print("  Total Revenue: $\(Int(plan.revenue))")
print("  Total Costs: $\(Int(plan.costs))")
print("  Total Profit: $\(Int(plan.profit))")
print("  Margin: \(Int(plan.profit / plan.revenue * 100))%")

print()
print("Resource Utilization:")
for (resource, utilization) in plan.resourceUtilization.sorted(by: { $0.key < $1.key }) {
    let percentage = Int(utilization * 100)
    let bar = String(repeating: "█", count: percentage / 2)
    print("  • \(resource): \(percentage)% \(bar)")
}
```

### Common Use Cases

#### 1. Maximize Revenue (Sales-Driven)
```swift
let plan = try optimizer.optimize(
    products: products,
    resources: resources,
    objective: .maximizeRevenue  // Focus on top-line growth
)
```

#### 2. Minimize Costs (Efficiency-Driven)
```swift
// With minimum demand requirements
let constraints = products.enumerated().map { (i, product) in
    ProductionConstraint.minimumProduction(
        productId: product.id,
        quantity: 100  // Must produce at least 100 of each
    )
}

let plan = try optimizer.optimize(
    products: products,
    resources: resources,
    objective: .minimizeCosts,
    constraints: constraints
)
```

#### 3. Maximize Resource Utilization
```swift
// Useful when you want to keep machines/workers busy
let plan = try optimizer.optimize(
    products: products,
    resources: resources,
    objective: .maximizeUtilization
)

print("Machine utilization: \(plan.resourceUtilization["machine_hours"]! * 100)%")
```

---

## Financial Model Driver Optimizer

### What Problems Does It Solve?

- **Target Seeking**: What operational changes hit our revenue target?
- **Scenario Planning**: Create realistic scenarios that achieve goals
- **Sensitivity Analysis**: Which drivers have the most impact?
- **Multi-Objective Planning**: Balance growth, profitability, and cash flow

### Quick Start (5 lines)

```swift
import BusinessMath

// Define operational drivers
let drivers = [
    OptimizableDriver(
        name: "price",
        currentValue: 100,
        range: 80...120,
        changeConstraint: .percentageChange(max: 0.15)  // Max 15% change
    ),
    OptimizableDriver(
        name: "volume",
        currentValue: 1000,
        range: 800...1500
    )
]

// Define financial target
let targets = [
    FinancialTarget(
        metric: "revenue",
        target: .minimum(120_000),
        weight: 1.0
    )
]

// Optimize drivers to hit target
let optimizer = DriverOptimizer()
let result = try optimizer.optimize(
    drivers: drivers,
    targets: targets,
    model: { driverValues in
        let price = driverValues["price"]!
        let volume = driverValues["volume"]!
        return ["revenue": price * volume]
    }
)

print("Optimized Drivers:")
for (name, value) in result.optimizedDrivers {
    let change = result.driverChanges[name]!
    print("  \(name): \(value) (change: \(change > 0 ? "+" : "")\(Int(change)))")
}
print("Revenue: $\(Int(result.achievedMetrics["revenue"]!))")
```

### Core Types

#### OptimizableDriver
Represents an operational driver that can be optimized.

```swift
public struct OptimizableDriver {
    public let name: String
    public let currentValue: Double
    public let range: ClosedRange<Double>
    public let changeConstraint: DriverChangeConstraint?
}
```

#### DriverChangeConstraint
Constraints on how much a driver can change.

```swift
public enum DriverChangeConstraint {
    case absoluteChange(max: Double)      // |new - current| ≤ max
    case percentageChange(max: Double)    // |new/current - 1| ≤ max
    case stepSize(Double)                 // Granular changes
}
```

#### FinancialTarget
A financial metric target to achieve.

```swift
public struct FinancialTarget {
    public let metric: String
    public let target: TargetValue
    public let weight: Double  // For multi-objective optimization
}

public enum TargetValue {
    case exact(Double)
    case minimum(Double)
    case maximum(Double)
    case range(Double, Double)
}
```

### Detailed Example: SaaS MRR Optimization

A SaaS company wants to hit $60K MRR by optimizing price, churn, and new customer acquisition.

```swift
import BusinessMath

// Define SaaS operational drivers
let drivers = [
    OptimizableDriver(
        name: "price_per_seat",
        currentValue: 50,
        range: 40...70,
        changeConstraint: .percentageChange(max: 0.20)  // Max 20% price change
    ),
    OptimizableDriver(
        name: "monthly_churn_rate",
        currentValue: 0.05,  // 5% monthly churn
        range: 0.02...0.08,
        changeConstraint: .absoluteChange(max: 0.015)  // Max 1.5% change
    ),
    OptimizableDriver(
        name: "new_customers_per_month",
        currentValue: 100,
        range: 80...150
    )
]

// Define financial targets (multiple goals)
let targets = [
    FinancialTarget(
        metric: "mrr",
        target: .minimum(60_000),
        weight: 2.0  // High priority
    ),
    FinancialTarget(
        metric: "customer_count",
        target: .minimum(1000),
        weight: 1.0
    ),
    FinancialTarget(
        metric: "customer_lifetime_value",
        target: .minimum(1000),
        weight: 1.0
    )
]

// Define SaaS financial model
let saasModel: ([String: Double]) -> [String: Double] = { driverValues in
    let pricePerSeat = driverValues["price_per_seat"]!
    let churnRate = driverValues["monthly_churn_rate"]!
    let newCustomersMonthly = driverValues["new_customers_per_month"]!

    // Steady-state calculations
    let steadyStateCustomers = newCustomersMonthly / churnRate
    let mrr = steadyStateCustomers * pricePerSeat
    let avgLifetimeMonths = 1.0 / churnRate
    let ltv = pricePerSeat * avgLifetimeMonths * 0.7  // 70% gross margin

    return [
        "mrr": mrr,
        "customer_count": steadyStateCustomers,
        "customer_lifetime_value": ltv
    ]
}

// Optimize drivers to hit targets (minimize changes)
let optimizer = DriverOptimizer(maxIterations: 300)
let result = try optimizer.optimize(
    drivers: drivers,
    targets: targets,
    model: saasModel,
    objective: .minimizeChange  // Minimal changes from current
)

// Display results
print("=== SaaS MRR Optimization ===")
print("Feasible: \(result.feasible)")
print("Converged: \(result.converged) (\(result.iterations) iterations)")
print()

print("Optimized Drivers:")
for driver in drivers {
    let current = driver.currentValue
    let optimized = result.optimizedDrivers[driver.name]!
    let change = result.driverChanges[driver.name]!
    let percentChange = (change / current) * 100

    print("  • \(driver.name):")
    print("    Current: \(current)")
    print("    Optimized: \(String(format: "%.2f", optimized))")
    print("    Change: \(String(format: "%+.2f", change)) (\(String(format: "%+.1f", percentChange))%)")
}

print()
print("Achieved Metrics:")
for target in targets {
    let achieved = result.achievedMetrics[target.metric]!
    let fulfilled = result.targetsFulfilled[target.metric]!
    let symbol = fulfilled ? "✓" : "✗"

    print("  \(symbol) \(target.metric): \(String(format: "%.0f", achieved))")

    switch target.target {
    case .minimum(let min):
        print("    Target: ≥ \(String(format: "%.0f", min))")
    case .maximum(let max):
        print("    Target: ≤ \(String(format: "%.0f", max))")
    case .exact(let value):
        print("    Target: = \(String(format: "%.0f", value))")
    case .range(let min, let max):
        print("    Target: \(String(format: "%.0f", min)) - \(String(format: "%.0f", max))")
    }
}
```

### Common Use Cases

#### 1. E-commerce Conversion Optimization
```swift
let drivers = [
    OptimizableDriver(name: "product_price", currentValue: 100, range: 80...150),
    OptimizableDriver(name: "conversion_rate", currentValue: 0.03, range: 0.02...0.05),
    OptimizableDriver(name: "traffic", currentValue: 10_000, range: 8_000...15_000)
]

let targets = [
    FinancialTarget(metric: "revenue", target: .minimum(35_000), weight: 2.0),
    FinancialTarget(metric: "orders", target: .minimum(300), weight: 1.0)
]

let result = try optimizer.optimize(
    drivers: drivers,
    targets: targets,
    model: { values in
        let price = values["product_price"]!
        let conversion = values["conversion_rate"]!
        let traffic = values["traffic"]!

        // Price elasticity effect
        let priceImpact = 1.0 - (price - 100) / 200.0
        let effectiveConversion = conversion * max(0.5, priceImpact)

        let orders = traffic * effectiveConversion
        let revenue = orders * price

        return ["revenue": revenue, "orders": orders]
    }
)
```

#### 2. Cost-Weighted Optimization
When some drivers are more expensive to change than others:

```swift
let costs = [
    "price": 1.0,           // Easy to change
    "headcount": 50_000.0,  // Very expensive (hiring costs)
    "churn_rate": 10.0      // Moderate (requires programs)
]

let result = try optimizer.optimize(
    drivers: drivers,
    targets: targets,
    model: financialModel,
    objective: .minimizeCost(costs)  // Prefer changing cheaper drivers
)
```

---

## Integration Examples

### Using Multiple Optimizers Together

#### Scenario: Integrated Business Planning

First, allocate capital to projects. Then, optimize production for selected projects.

```swift
import BusinessMath

// Step 1: Capital Allocation
let projects = [
    AllocationOption(
        id: "product_a",
        name: "Product A Launch",
        expectedValue: 1_000_000,
        resourceRequirements: ["budget": 300_000]
    ),
    AllocationOption(
        id: "product_b",
        name: "Product B Launch",
        expectedValue: 800_000,
        resourceRequirements: ["budget": 250_000]
    )
]

let allocationOptimizer = ResourceAllocationOptimizer()
let allocation = try allocationOptimizer.optimize(
    options: projects,
    objective: .maximizeValue,
    constraints: [.totalBudget(400_000)]
)

// Step 2: Production Planning for selected products
let selectedProducts = allocation.selectedOptions.map { option -> ManufacturedProduct in
    // Convert allocation options to manufactured products
    ManufacturedProduct(
        id: option.id,
        name: option.name,
        pricePerUnit: 100,
        variableCostPerUnit: 45,
        demand: .unlimited,
        resourceRequirements: ["machine_hours": 2.0]
    )
}

let productionOptimizer = ProductionPlanningOptimizer()
let productionPlan = try productionOptimizer.optimize(
    products: selectedProducts,
    resources: ["machine_hours": 5000],
    objective: .maximizeProfit
)

// Step 3: Driver Optimization to hit production targets
let drivers = [
    OptimizableDriver(name: "yield_rate", currentValue: 0.95, range: 0.90...0.98),
    OptimizableDriver(name: "cycle_time_hours", currentValue: 2.0, range: 1.5...2.5)
]

let targets = [
    FinancialTarget(
        metric: "output_units",
        target: .minimum(2500),
        weight: 1.0
    )
]

let driverOptimizer = DriverOptimizer()
let driverResult = try driverOptimizer.optimize(
    drivers: drivers,
    targets: targets,
    model: { values in
        let yieldRate = values["yield_rate"]!
        let cycleTime = values["cycle_time_hours"]!
        let machineHours = 5000.0

        let output = (machineHours / cycleTime) * yieldRate
        return ["output_units": output]
    }
)

print("Integrated Plan:")
print("  Capital Allocated: $\(Int(allocation.totalValue))")
print("  Production Profit: $\(Int(productionPlan.profit))")
print("  Output Target Achieved: \(driverResult.feasible)")
```

### Integration with Financial Model

```swift
import BusinessMath

// Create a financial model
let model = FinancialModel(name: "SaaS Business")

// Add operational drivers
model.addDriver(OperationalDriver(
    name: "mrr",
    initialValue: 50_000,
    growth: .fixed(0.10)  // 10% monthly growth
))

// Use driver optimizer to find path to $100K MRR
let drivers = [
    OptimizableDriver(name: "price", currentValue: 50, range: 40...70),
    OptimizableDriver(name: "churn", currentValue: 0.05, range: 0.02...0.08)
]

let targets = [
    FinancialTarget(metric: "mrr", target: .exact(100_000), weight: 1.0)
]

let optimizer = DriverOptimizer()
let result = try optimizer.optimize(
    drivers: drivers,
    targets: targets,
    model: { values in
        let price = values["price"]!
        let churn = values["churn"]!
        let newCustomers = 150.0  // Fixed

        let steadyStateCustomers = newCustomers / churn
        let mrr = steadyStateCustomers * price

        return ["mrr": mrr]
    }
)

// Update model with optimized drivers
if result.feasible {
    model.setValue(result.optimizedDrivers["price"]!, forKey: "price")
    model.setValue(result.optimizedDrivers["churn"]!, forKey: "churn_rate")
}
```

---

## Troubleshooting

### Resource Allocation

**Problem: Optimizer returns no selected options**
```
Solution: Check if constraints are too restrictive. Try relaxing budget or resource limits.
```

**Problem: Required option not selected despite constraint**
```
Solution: The required option may be infeasible with other constraints. Check dependencies
and ensure sufficient budget for required options plus their prerequisites.
```

**Problem: All options get partial allocation**
```
Solution: This is expected behavior - allocation values range from 0 (none) to 1 (full).
Options with allocation > 0.01 are considered "selected". Use higher allocation thresholds
if you want binary decisions.
```

### Production Planning

**Problem: Utilization is low despite unlimited demand**
```
Solution: Check if variable costs exceed prices (negative contribution margin). The optimizer
won't produce products with negative margins even with unlimited demand.
```

**Problem: Minimum demand constraints not satisfied**
```
Solution: The problem may be infeasible. Check that available resources can support minimum
demand for all products. Try increasing resource capacity or relaxing constraints.
```

**Problem: Optimization doesn't converge**
```
Solution: Try increasing maxIterations when creating the optimizer:
  let optimizer = ProductionPlanningOptimizer(maxIterations: 500)

Also check for conflicting constraints (e.g., production ratio + minimum quantities).
```

### Driver Optimization

**Problem: Targets not achieved (feasible = false)**
```
Solution: The targets may be mathematically impossible with the given driver ranges and
constraints. Try:
  1. Widening driver ranges
  2. Relaxing change constraints
  3. Adjusting target values
  4. Adding more drivers to optimize
```

**Problem: Drivers don't change from current values**
```
Solution: Check that:
  1. Target is not already met with current drivers
  2. Change constraints aren't too tight (e.g., max 1% change)
  3. Driver ranges include current values
  4. Model function correctly uses driver values
```

**Problem: Optimization is slow**
```
Solution: Driver optimization uses iterative methods. For complex models:
  1. Start with fewer drivers (2-3)
  2. Simplify the model function
  3. Use wider convergence tolerances
  4. Increase maxIterations for complex problems
```

---

## Best Practices

### General Guidelines

1. **Start Simple**: Begin with a minimal example and gradually add complexity
2. **Validate Inputs**: Check that constraints are feasible before optimizing
3. **Test Edge Cases**: Try with extreme values to understand behavior
4. **Monitor Convergence**: Check the `converged` flag and `iterations` count
5. **Iterate**: Start with relaxed constraints and tighten as needed

### Resource Allocation

```swift
// Good: Clear, measurable expected values
AllocationOption(
    id: "proj1",
    expectedValue: 500_000,  // NPV over 3 years
    resourceRequirements: ["budget": 150_000]
)

// Better: Include strategic value for multi-objective optimization
AllocationOption(
    id: "proj1",
    expectedValue: 500_000,
    resourceRequirements: ["budget": 150_000],
    strategicValue: 8.5  // On 0-10 scale
)

// Best: Document dependencies clearly
AllocationOption(
    id: "proj1",
    expectedValue: 500_000,
    resourceRequirements: ["budget": 150_000],
    strategicValue: 8.5,
    dependencies: ["infrastructure_upgrade"]  // Clear prerequisite
)
```

### Production Planning

```swift
// Good: Use realistic demand constraints
ManufacturedProduct(
    id: "widget",
    demand: .range(min: 100, max: 500)  // Based on market research
)

// Better: Model contribution margin accurately
ManufacturedProduct(
    id: "widget",
    pricePerUnit: 100,
    variableCostPerUnit: 45,  // Include all variable costs
    demand: .range(min: 100, max: 500)
)

// Best: Include all resource constraints
ManufacturedProduct(
    id: "widget",
    pricePerUnit: 100,
    variableCostPerUnit: 45,
    demand: .range(min: 100, max: 500),
    resourceRequirements: [
        "machine_hours": 2.0,
        "labor_hours": 1.0,
        "raw_materials_kg": 3.5
    ]
)
```

### Driver Optimization

```swift
// Good: Use realistic driver ranges
OptimizableDriver(
    name: "price",
    currentValue: 100,
    range: 80...120  // ±20% is realistic
)

// Better: Add change constraints for realism
OptimizableDriver(
    name: "price",
    currentValue: 100,
    range: 80...120,
    changeConstraint: .percentageChange(max: 0.15)  // Max 15% change
)

// Best: Use multiple targets with priorities
let targets = [
    FinancialTarget(metric: "revenue", target: .minimum(100_000), weight: 2.0),
    FinancialTarget(metric: "margin", target: .minimum(0.40), weight: 1.0),
    FinancialTarget(metric: "customers", target: .minimum(500), weight: 1.0)
]
```

### Model Functions

```swift
// Good: Simple, clear model
let model: ([String: Double]) -> [String: Double] = { drivers in
    let price = drivers["price"]!
    let volume = drivers["volume"]!
    return ["revenue": price * volume]
}

// Better: Include business logic
let model: ([String: Double]) -> [String: Double] = { drivers in
    let price = drivers["price"]!
    let volume = drivers["volume"]!

    // Price elasticity: higher price reduces volume
    let elasticity = -0.5
    let priceChange = (price - 100) / 100
    let adjustedVolume = volume * (1 + elasticity * priceChange)

    return ["revenue": price * adjustedVolume]
}

// Best: Comprehensive financial model
let model: ([String: Double]) -> [String: Double] = { drivers in
    let price = drivers["price"]!
    let churn = drivers["churn_rate"]!
    let newCustomers = drivers["new_customers"]!

    // Steady-state metrics
    let customers = newCustomers / churn
    let mrr = customers * price
    let ltv = (price / churn) * 0.7  // 70% margin
    let cac = 50.0  // Assumed
    let ltvCacRatio = ltv / cac

    return [
        "mrr": mrr,
        "customers": customers,
        "ltv": ltv,
        "ltv_cac_ratio": ltvCacRatio
    ]
}
```

---

## Summary

Phase 5 delivers three powerful business optimization modules:

- **Resource Allocation**: Capital budgeting and project selection
- **Production Planning**: Multi-product manufacturing optimization
- **Driver Optimization**: Financial target seeking

Each optimizer:
- ✅ Uses domain-specific types and constraints
- ✅ Provides multiple objective functions
- ✅ Returns rich diagnostic results
- ✅ Builds on Phase 4's constrained optimization framework
- ✅ Handles real-world complexity with ease

**Next Steps:**
1. Try the quick start examples
2. Adapt detailed examples to your business
3. Experiment with different objectives and constraints
4. Integrate multiple optimizers for comprehensive planning

For more information, see the API reference documentation in each source file.
