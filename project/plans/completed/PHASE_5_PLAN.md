# Phase 5: Business Applications - Implementation Plan

**Created:** 2025-12-04
**Status:** Planning
**Goal:** Create domain-specific optimization APIs for common business problems

---

## Overview

Phase 5 builds on the constrained optimization framework (Phase 4) to create accessible, business-focused APIs. Each module solves a specific category of business optimization problems with ergonomic, type-safe interfaces.

---

## Priority 1: Resource Allocation Optimizer

### Business Problems Solved
1. **Budget Allocation:** Distribute limited budget across departments/projects
2. **Capital Budgeting:** Select projects to fund given capital constraints
3. **Marketing Mix:** Allocate marketing spend across channels
4. **Workforce Allocation:** Assign employees to projects/tasks

### Core API Design

```swift
// Projects/options to allocate to
struct AllocationOption {
    let id: String
    let name: String
    let expectedValue: Double           // NPV, ROI, revenue, etc.
    let resourceRequirements: [String: Double]  // "budget": 100000, "headcount": 5
    let strategicValue: Double?         // Optional strategic importance
    let dependencies: Set<String>?      // IDs of prerequisite options
}

// Allocation constraints
enum AllocationConstraint {
    case totalBudget(Double)                    // Max total budget
    case resourceLimit(resource: String, limit: Double)  // Max of any resource
    case minimumAllocation(optionId: String, amount: Double)
    case maximumAllocation(optionId: String, amount: Double)
    case requiredOption(optionId: String)       // Must include this option
    case excludedOption(optionId: String)       // Cannot include this option
    case dependency(optionId: String, requires: String)  // If A, then B
    case mutuallyExclusive([String])            // Only one from this set
}

// Objective function
enum AllocationObjective {
    case maximizeValue                   // Maximize sum of values
    case maximizeValuePerDollar         // Maximize value/cost ratio
    case maximizeWeightedValue(strategicWeight: Double)  // Blend value + strategic
    case maximizeRiskAdjustedValue(riskDiscount: Double)
    case custom((AllocationResult) -> Double)
}

// Optimizer
struct ResourceAllocationOptimizer {
    func optimize(
        options: [AllocationOption],
        objective: AllocationObjective = .maximizeValue,
        constraints: [AllocationConstraint]
    ) throws -> AllocationResult
}

// Result
struct AllocationResult {
    let allocations: [String: Double]    // optionId -> allocation amount
    let selectedOptions: [AllocationOption]  // Fully funded options
    let totalValue: Double
    let totalResourcesUsed: [String: Double]
    let shadowPrices: [String: Double]?  // Constraint shadow prices
    let converged: Bool
}
```

### Implementation Steps
1. ✅ Define data structures (`AllocationOption`, constraints, objectives)
2. ✅ Implement `ResourceAllocationOptimizer` core logic
3. ✅ Map business constraints to multivariate constraints
4. ✅ Create comprehensive tests (10-15 tests)
5. ✅ Add documentation with examples

### Test Scenarios
- Simple budget allocation (3 projects, 1 budget)
- Multi-resource allocation (budget + headcount)
- Required and excluded options
- Mutually exclusive options
- Dependencies between projects
- Strategic value weighting
- Shadow price interpretation

---

## Priority 2: Production Planning Optimizer

### Business Problems Solved
1. **Production Scheduling:** Determine production quantities to maximize profit
2. **Multi-Product Optimization:** Optimize product mix given constraints
3. **Inventory Management:** Balance production vs holding costs
4. **Supply Chain:** Optimize supplier selection and order quantities

### Core API Design

```swift
// Product to manufacture
struct Product {
    let id: String
    let name: String
    let pricePerUnit: Double
    let variableCostPerUnit: Double
    let demand: ProductDemand
    let resourceRequirements: [String: Double]  // "machineTime": 2.5, "labor": 1.0
}

enum ProductDemand {
    case unlimited
    case fixed(Double)
    case range(min: Double, max: Double)
    case priceElastic(slope: Double, intercept: Double)  // demand = intercept - slope * price
}

// Production constraints
enum ProductionConstraint {
    case resourceCapacity(resource: String, capacity: Double)
    case minimumProduction(productId: String, quantity: Double)
    case maximumProduction(productId: String, quantity: Double)
    case productionRatio(productA: String, productB: String, ratio: Double)  // A:B ratio
    case setupCost(productId: String, fixedCost: Double, threshold: Double)
}

// Objective
enum ProductionObjective {
    case maximizeProfit                  // Revenue - costs
    case maximizeRevenue
    case maximizeMargin                  // (Revenue - costs) / Revenue
    case minimizeCosts
    case maximizeUtilization            // Use resources efficiently
}

// Optimizer
struct ProductionPlanningOptimizer {
    func optimize(
        products: [Product],
        resources: [String: Double],     // Available resources
        objective: ProductionObjective = .maximizeProfit,
        constraints: [ProductionConstraint] = []
    ) throws -> ProductionPlan
}

// Result
struct ProductionPlan {
    let productionQuantities: [String: Double]
    let revenue: Double
    let costs: Double
    let profit: Double
    let resourceUtilization: [String: Double]  // % of each resource used
    let shadowPrices: [String: Double]?
    let converged: Bool
}
```

### Implementation Steps
1. Define data structures
2. Implement optimizer core
3. Handle setup costs (fixed + variable)
4. Demand modeling (elastic vs fixed)
5. Comprehensive tests (12-18 tests)
6. Documentation with manufacturing examples

---

## Priority 3: Financial Model Driver Optimization

### Business Problems Solved
1. **Target Seeking:** What operational changes achieve financial goals?
2. **Multi-Objective:** Balance growth, profitability, and cash flow
3. **Scenario Generation:** Create realistic scenarios that hit targets
4. **Sensitivity:** Which drivers have most impact on targets?

### Core API Design

```swift
// Driver to optimize
struct OptimizableDriver {
    let name: String
    let currentValue: Double
    let range: ClosedRange<Double>       // Feasible range
    let changeConstraint: DriverChangeConstraint?
}

enum DriverChangeConstraint {
    case absoluteChange(max: Double)     // |new - current| ≤ max
    case percentageChange(max: Double)   // |new/current - 1| ≤ max
    case stepSize(Double)                // Granular changes only
}

// Financial targets
struct FinancialTarget {
    let metric: String                   // "revenue", "EBITDA", "FCF"
    let target: TargetValue
    let weight: Double                   // Multi-objective weight
}

enum TargetValue {
    case exact(Double)
    case minimum(Double)
    case maximum(Double)
    case range(Double, Double)
}

// Optimizer
struct DriverOptimizer {
    func optimize(
        drivers: [OptimizableDriver],
        targets: [FinancialTarget],
        model: @escaping ([String: Double]) -> [String: Double],  // drivers -> metrics
        objective: DriverObjective = .minimizeChange
    ) throws -> DriverOptimization
}

enum DriverObjective {
    case minimizeChange              // Smallest changes to hit targets
    case minimizeCost               // Weighted by cost to change
    case maximizeFeasibility        // Ensure targets achievable
}

// Result
struct DriverOptimization {
    let optimizedDrivers: [String: Double]
    let driverChanges: [String: Double]     // Change from current
    let achievedMetrics: [String: Double]
    let targetsFulfilled: [String: Bool]
    let feasible: Bool
}
```

### Implementation Steps
1. Define driver and target structures
2. Implement optimizer with model callback
3. Constraint mapping (ranges, change limits)
4. Multi-objective weighting
5. Integration tests with FinancialModel
6. Documentation with SaaS/retail examples

---

## Shared Infrastructure

### Constraint Conversion Utilities
```swift
extension MultivariateConstraint where V == VectorN<Double> {
    // Convert business constraints to optimization constraints
    static func fromAllocationConstraint(_ constraint: AllocationConstraint, ...) -> [Self]
    static func fromProductionConstraint(_ constraint: ProductionConstraint, ...) -> [Self]
    static func fromDriverConstraint(_ constraint: DriverChangeConstraint, ...) -> [Self]
}
```

### Common Patterns
1. **Builder pattern** for complex configurations
2. **Result types** with rich diagnostics
3. **Shadow prices** exposed for sensitivity analysis
4. **Convergence diagnostics** for troubleshooting
5. **Default values** for common cases

---

## Testing Strategy

### Test Categories
1. **Unit tests:** Individual constraint/objective conversions (20-30 tests)
2. **Integration tests:** Full optimization workflows (15-20 tests)
3. **Real-world scenarios:** Based on actual business problems (5-10 tests)
4. **Edge cases:** Infeasible, unbounded, degenerate cases (10-15 tests)
5. **Performance:** Large-scale problems (3-5 benchmarks)

**Target:** 50-80 new tests for Phase 5

---

## Documentation Requirements

For each optimizer:
1. **Overview:** What business problems it solves
2. **Quick Start:** Simplest possible example (5 lines)
3. **Detailed Example:** Real-world scenario with constraints
4. **API Reference:** All types and methods documented
5. **Troubleshooting:** Common issues and solutions

---

## Success Criteria

Phase 5 is complete when:
- ✅ All three optimizers implemented and tested
- ✅ 50+ new tests, all passing
- ✅ Comprehensive documentation with examples
- ✅ Integration with existing BusinessMath features
- ✅ Performance acceptable for typical problems (<1s for 10-20 variables)
- ✅ No new compiler warnings
- ✅ Clean build and test suite

---

## Estimated Timeline

- **Priority 1 (Resource Allocation):** 6-8 hours
  - Design: 1 hour
  - Implementation: 3-4 hours
  - Tests: 2-3 hours

- **Priority 2 (Production Planning):** 8-10 hours
  - Design: 1-2 hours
  - Implementation: 4-5 hours
  - Tests: 3 hours

- **Priority 3 (Driver Optimization):** 6-8 hours
  - Design: 1 hour
  - Implementation: 3-4 hours
  - Tests: 2-3 hours
  - Integration: 1 hour (with FinancialModel)

**Total:** 20-26 hours

---

## Next Steps

1. Start with Priority 1: Resource Allocation
2. Create directory structure
3. Implement core types
4. Implement optimizer
5. Write comprehensive tests
6. Move to Priority 2, then Priority 3
