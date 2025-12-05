//
//  DriverOptimizationExample.swift
//  BusinessMath Examples
//
//  Demonstrates financial target seeking using DriverOptimizer
//

import Foundation
@testable import BusinessMath

/// Example: SaaS company optimizing MRR
func saasTargetSeekingExample() throws {
    print("=== SaaS MRR Target Seeking Example ===\n")

    // Current state
    print("Current State:")
    print("  Price per seat: $50/month")
    print("  Monthly churn rate: 5.0%")
    print("  New customers per month: 100")
    print("  Current MRR: ~$100,000")
    print()

    print("Goal: Reach $150,000 MRR while maintaining healthy unit economics\n")

    // Define operational drivers
    let drivers = [
        OptimizableDriver(
            name: "price_per_seat",
            currentValue: 50,
            range: 40...70,
            changeConstraint: .percentageChange(max: 0.20)  // Max 20% price change
        ),
        OptimizableDriver(
            name: "monthly_churn_rate",
            currentValue: 0.05,
            range: 0.02...0.08,
            changeConstraint: .absoluteChange(max: 0.015)  // Max 1.5% absolute change
        ),
        OptimizableDriver(
            name: "new_customers_monthly",
            currentValue: 100,
            range: 80...150
        )
    ]

    // Define targets
    let targets = [
        FinancialTarget(
            metric: "mrr",
            target: .minimum(150_000),
            weight: 2.0  // High priority
        ),
        FinancialTarget(
            metric: "customer_count",
            target: .minimum(2000),
            weight: 1.0
        ),
        FinancialTarget(
            metric: "ltv_cac_ratio",
            target: .minimum(3.0),  // Healthy unit economics
            weight: 1.5
        )
    ]

    // SaaS financial model
    let saasModel: ([String: Double]) -> [String: Double] = { driverValues in
        let price = driverValues["price_per_seat"]!
        let churn = driverValues["monthly_churn_rate"]!
        let newCustomers = driverValues["new_customers_monthly"]!

        // Steady-state calculations
        let customers = newCustomers / churn
        let mrr = customers * price

        // Unit economics
        let avgLifetimeMonths = 1.0 / churn
        let ltv = price * avgLifetimeMonths * 0.70  // 70% gross margin
        let cac = 75.0  // Assumed customer acquisition cost
        let ltvCacRatio = ltv / cac

        return [
            "mrr": mrr,
            "customer_count": customers,
            "ltv_cac_ratio": ltvCacRatio,
            "ltv": ltv
        ]
    }

    // Optimize to hit targets
    let optimizer = DriverOptimizer(maxIterations: 300)
    let result = try optimizer.optimize(
        drivers: drivers,
        targets: targets,
        model: saasModel,
        objective: .minimizeChange  // Prefer minimal changes
    )

    // Display results
    print("Optimization Results:")
    print("  Feasible: \(result.feasible ? "✓ Yes" : "✗ No")")
    print("  Converged: \(result.converged)")
    print("  Iterations: \(result.iterations)")
    print()

    print("Recommended Changes:")
    print(String(repeating: "-", count: 70))
    for driver in drivers {
        let current = driver.currentValue
        let optimized = result.optimizedDrivers[driver.name]!
        let change = result.driverChanges[driver.name]!
        let percentChange = (change / current) * 100

        let displayName = driver.name.replacingOccurrences(of: "_", with: " ").capitalized
        print(String(format: "  %-30s %10.2f → %10.2f (%+.1f%%)",
                      displayName, current, optimized, percentChange))
    }
    print(String(repeating: "-", count: 70))
    print()

    print("Target Achievement:")
    for target in targets {
        let achieved = result.achievedMetrics[target.metric]!
        let fulfilled = result.targetsFulfilled[target.metric]!
        let symbol = fulfilled ? "✓" : "✗"

        let displayName = target.metric.replacingOccurrences(of: "_", with: " ").uppercased()

        switch target.target {
        case .minimum(let min):
            print(String(format: "  %s %-25s %12.0f (target: ≥ %.0f)",
                          symbol, displayName, achieved, min))
        case .maximum(let max):
            print(String(format: "  %s %-25s %12.0f (target: ≤ %.0f)",
                          symbol, displayName, achieved, max))
        case .exact(let value):
            print(String(format: "  %s %-25s %12.0f (target: = %.0f)",
                          symbol, displayName, achieved, value))
        case .range(let min, let max):
            print(String(format: "  %s %-25s %12.0f (target: %.0f-%.0f)",
                          symbol, displayName, achieved, min, max))
        }
    }
    print()

    // Action plan
    print("Recommended Action Plan:")
    let priceChange = result.driverChanges["price_per_seat"]!
    let churnChange = result.driverChanges["monthly_churn_rate"]!
    let newCustomersChange = result.driverChanges["new_customers_monthly"]!

    if abs(priceChange) > 2 {
        let direction = priceChange > 0 ? "increase" : "decrease"
        print("  1. \(direction.capitalized) pricing by \(Int(abs(priceChange)))%")
    }

    if abs(churnChange) > 0.005 {
        if churnChange < 0 {
            print("  2. Implement churn reduction initiatives (target: \(abs(churnChange * 100))% improvement)")
        }
    }

    if abs(newCustomersChange) > 5 {
        let direction = newCustomersChange > 0 ? "increase" : "decrease"
        print("  3. \(direction.capitalized) customer acquisition to ~\(Int(result.optimizedDrivers["new_customers_monthly"]!)) per month")
    }

    print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: E-commerce conversion optimization
func ecommerceConversionExample() throws {
    print("=== E-commerce Conversion Optimization Example ===\n")

    print("Current State:")
    print("  Product price: $100")
    print("  Conversion rate: 3.0%")
    print("  Monthly traffic: 10,000 visitors")
    print("  Current revenue: ~$30,000/month")
    print()

    print("Goal: Achieve $45,000 monthly revenue with at least 400 orders\n")

    // Define drivers
    let drivers = [
        OptimizableDriver(
            name: "product_price",
            currentValue: 100,
            range: 80...150
        ),
        OptimizableDriver(
            name: "conversion_rate",
            currentValue: 0.03,
            range: 0.02...0.05,
            changeConstraint: .percentageChange(max: 0.30)
        ),
        OptimizableDriver(
            name: "monthly_traffic",
            currentValue: 10_000,
            range: 8_000...15_000
        )
    ]

    // Define targets
    let targets = [
        FinancialTarget(
            metric: "revenue",
            target: .minimum(45_000),
            weight: 2.0
        ),
        FinancialTarget(
            metric: "orders",
            target: .minimum(400),
            weight: 1.0
        ),
        FinancialTarget(
            metric: "aov",  // Average order value
            target: .minimum(100),
            weight: 1.0
        )
    ]

    // E-commerce model with price elasticity
    let ecommerceModel: ([String: Double]) -> [String: Double] = { values in
        let price = values["product_price"]!
        let baseConversion = values["conversion_rate"]!
        let traffic = values["monthly_traffic"]!

        // Price elasticity effect (higher price reduces conversion)
        let priceChange = (price - 100) / 100
        let elasticity = -0.3  // 30% conversion reduction per 100% price increase
        let conversionImpact = 1.0 + (elasticity * priceChange)
        let effectiveConversion = baseConversion * max(0.5, conversionImpact)

        // Calculate metrics
        let orders = traffic * effectiveConversion
        let revenue = orders * price
        let aov = price  // Single product per order

        return [
            "revenue": revenue,
            "orders": orders,
            "aov": aov
        ]
    }

    // Optimize
    let optimizer = DriverOptimizer()
    let result = try optimizer.optimize(
        drivers: drivers,
        targets: targets,
        model: ecommerceModel
    )

    // Display results
    print("Optimization Results:")
    print("  Status: \(result.feasible ? "✓ Feasible" : "✗ Infeasible")")
    print()

    print("Optimized Strategy:")
    for driver in drivers {
        let current = driver.currentValue
        let optimized = result.optimizedDrivers[driver.name]!
        let change = result.driverChanges[driver.name]!
        let percentChange = abs(change / current * 100)

        let displayName = driver.name.replacingOccurrences(of: "_", with: " ").capitalized
        let arrow = change > 0 ? "↑" : (change < 0 ? "↓" : "→")

        print(String(format: "  %-25s %s %.0f (%.1f%% change)",
                      displayName, arrow, optimized, percentChange))
    }
    print()

    print("Projected Results:")
    let revenue = result.achievedMetrics["revenue"]!
    let orders = result.achievedMetrics["orders"]!
    let aov = result.achievedMetrics["aov"]!

    print(String(format: "  Monthly Revenue: $%.0f", revenue))
    print(String(format: "  Monthly Orders: %.0f", orders))
    print(String(format: "  Average Order Value: $%.0f", aov))

    print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Multi-objective financial planning
func multiObjectiveExample() throws {
    print("=== Multi-Objective Financial Planning Example ===\n")

    print("Scenario: Balance growth, profitability, and cash efficiency\n")

    // Simplified business drivers
    let drivers = [
        OptimizableDriver(
            name: "growth_rate",
            currentValue: 0.15,  // 15% monthly growth
            range: 0.10...0.25
        ),
        OptimizableDriver(
            name: "gross_margin",
            currentValue: 0.60,  // 60% margin
            range: 0.50...0.70
        ),
        OptimizableDriver(
            name: "sales_efficiency",  // Revenue per sales dollar
            currentValue: 4.0,
            range: 3.0...6.0
        )
    ]

    // Multiple competing targets
    let targets = [
        FinancialTarget(
            metric: "mrr_growth",
            target: .minimum(0.20),  // 20% growth
            weight: 1.5  // Growth is important
        ),
        FinancialTarget(
            metric: "profit_margin",
            target: .minimum(0.25),  // 25% profit margin
            weight: 2.0  // Profitability is very important
        ),
        FinancialTarget(
            metric: "magic_number",  // SaaS efficiency metric
            target: .minimum(0.75),
            weight: 1.0
        )
    ]

    // Financial model
    let model: ([String: Double]) -> [String: Double] = { values in
        let growth = values["growth_rate"]!
        let margin = values["gross_margin"]!
        let efficiency = values["sales_efficiency"]!

        // Higher growth typically means lower margins (more spend)
        let profitMargin = margin - (growth * 0.5)

        // Magic number = New ARR / Sales & Marketing spend
        let magicNumber = efficiency * margin

        return [
            "mrr_growth": growth,
            "profit_margin": max(0, profitMargin),
            "magic_number": magicNumber
        ]
    }

    let optimizer = DriverOptimizer()
    let result = try optimizer.optimize(
        drivers: drivers,
        targets: targets,
        model: model
    )

    print("Balanced Strategy:")
    for (name, value) in result.optimizedDrivers.sorted(by: { $0.key < $1.key }) {
        let current = drivers.first { $0.name == name }!.currentValue
        let change = result.driverChanges[name]!
        let percentChange = (change / current) * 100

        let displayName = name.replacingOccurrences(of: "_", with: " ").capitalized

        print(String(format: "  %-25s %.2f (%+.1f%%)", displayName, value, percentChange))
    }
    print()

    print("Target Achievement:")
    var allTargetsMet = true
    for target in targets {
        let achieved = result.achievedMetrics[target.metric]!
        let met = result.targetsFulfilled[target.metric]!
        allTargetsMet = allTargetsMet && met

        let symbol = met ? "✓" : "✗"
        let displayName = target.metric.replacingOccurrences(of: "_", with: " ").uppercased()

        if case .minimum(let min) = target.target {
            print(String(format: "  %s %-25s %.2f (target: ≥ %.2f)",
                          symbol, displayName, achieved, min))
        }
    }
    print()

    if allTargetsMet {
        print("✓ All targets achieved with balanced approach!")
    } else {
        print("⚠️  Some targets not met - may need to adjust priorities or ranges")
    }

    print("\n" + String(repeating: "=", count: 50) + "\n")
}

// Run examples
print("\n")
print("BusinessMath - Driver Optimization Examples")
print(String(repeating: "=", count: 50))
print("\n")

try saasTargetSeekingExample()
try ecommerceConversionExample()
try multiObjectiveExample()

print("Examples complete!")
