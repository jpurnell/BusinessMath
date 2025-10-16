//
//  IntegrationExample.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

/// # Operational Drivers Integration Example
///
/// This file demonstrates how to build a complete business model using all
/// operational driver capabilities: probabilistic inputs, time-varying behavior,
/// constraints, operators, and Monte Carlo simulation.
///
/// ## Business Scenario: SaaS Company Financial Model
///
/// We'll model a growing SaaS company with:
/// - **Seasonal revenue** patterns (Q4 boost from enterprise buying cycles)
/// - **Growing customer base** (30% annual growth with uncertainty)
/// - **Variable pricing** (average $100/user/month with market fluctuations)
/// - **Scaling costs** (fixed infrastructure + variable per-user costs)
/// - **Headcount growth** (must be positive integers)
/// - **Uncertainty** throughout the model
///
/// ## Model Structure
///
/// ```
/// Revenue = Users × Price/User
///   ├─ Users: Growing seasonally (Q4 spike), constrained to positive integers
///   └─ Price/User: Triangular distribution ($80-$120, mode $100)
///
/// Costs = Fixed Costs + Variable Costs + Payroll
///   ├─ Fixed Costs: $50k/month growing 3% annually (inflation)
///   ├─ Variable Costs: $20/user/month × Users
///   └─ Payroll: Headcount × Avg Salary
///       ├─ Headcount: Growing with Users (1 employee per 50 users), rounded
///       └─ Avg Salary: $10k/month with normal uncertainty
///
/// Profit = Revenue - Costs
/// ```
///
/// ## Usage Example
///
/// ```swift
/// import BusinessMath
///
/// // Create the model
/// let model = SaaSFinancialModel()
///
/// // Project over 4 quarters
/// let quarters = Period.year(2025).quarters()
///
/// // Run deterministic projection (expected path)
/// let expectedProfit = model.profit.project(periods: quarters)
///
/// // Run Monte Carlo simulation (10,000 scenarios)
/// let profitProjection = DriverProjection(driver: model.profit, periods: quarters)
/// let results = profitProjection.projectMonteCarlo(iterations: 10_000)
///
/// // Analyze uncertainty
/// for (period, stats) in results.statistics {
///     print("\(period.label):")
///     print("  Expected Profit: $\(Int(stats.mean))")
///     print("  Std Dev: $\(Int(stats.stdDev))")
///     print("  P5-P95 Range: $\(Int(results.percentiles[period]!.p5)) to $\(Int(results.percentiles[period]!.p95))")
/// }
/// ```
public struct SaaSFinancialModel {

	// MARK: - Revenue Drivers

	/// Number of paying users (SaaS subscriptions).
	///
	/// Characteristics:
	/// - Grows 30% annually with 10% uncertainty
	/// - Q4 seasonal boost (15% higher due to enterprise renewals)
	/// - Constrained to positive integers (can't have fractional users)
	/// - Base: 1,000 users in Q1 2025
	///
	/// ## Implementation Details
	///
	/// Uses `TimeVaryingDriver` for:
	/// - Annual growth trend
	/// - Quarterly seasonality
	///
	/// Then applies constraints:
	/// - `.positive()` ensures no negative users
	/// - `.rounded()` ensures integer values
	///
	/// **Note**: Chaining constraints creates nested types, which Swift infers automatically.
	public let users: ConstrainedDriver<ConstrainedDriver<TimeVaryingDriver<Double>>>

	/// Average revenue per user per month.
	///
	/// Characteristics:
	/// - Triangular distribution: $80 (low) - $120 (high), mode $100
	/// - Represents pricing variability across customer segments
	/// - Constrained to positive values (no negative pricing)
	///
	/// ## Why Triangular Distribution?
	///
	/// Triangular is ideal when you have:
	/// - Minimum and maximum bounds (contract limits)
	/// - A most likely value (standard pricing tier)
	/// - Asymmetric distribution (more customers near standard price)
	public let pricePerUser: ConstrainedDriver<ProbabilisticDriver<Double>>

	/// Total monthly recurring revenue.
	///
	/// Formula: `Revenue = Users × Price/User`
	///
	/// This driver automatically combines uncertainty from both inputs:
	/// - User count uncertainty (growth + seasonality)
	/// - Pricing uncertainty (market fluctuations)
	///
	/// Result: Revenue distribution that captures full uncertainty
	public let revenue: ProductDriver<Double>

	// MARK: - Cost Drivers

	/// Fixed infrastructure costs (servers, software, facilities).
	///
	/// Characteristics:
	/// - Base: $50,000/month in 2025
	/// - Grows 3% annually (inflation adjustment)
	/// - Deterministic growth (no uncertainty)
	///
	/// ## Implementation
	///
	/// Uses `TimeVaryingDriver.withGrowth()` factory method for
	/// simple inflation-adjusted cost modeling.
	public let fixedCosts: TimeVaryingDriver<Double>

	/// Variable costs per user (hosting, bandwidth, support).
	///
	/// Characteristics:
	/// - $20 per user per month
	/// - Scales linearly with user count
	/// - Fixed rate (no uncertainty in unit cost)
	///
	/// Formula: `Variable Costs = $20 × Users`
	public let variableCostPerUser: DeterministicDriver<Double>

	/// Total variable costs.
	///
	/// Inherits uncertainty from user count driver.
	public let variableCosts: ProductDriver<Double>

	/// Number of employees.
	///
	/// Characteristics:
	/// - Ratio: 1 employee per 50 users
	/// - Constrained to positive integers
	/// - Grows/shrinks with user base
	///
	/// Formula: `Headcount = Users / 50`
	///
	/// ## Constraints Applied
	///
	/// 1. `.positive()` - Can't have negative employees
	/// 2. `.rounded()` - Can't have fractional employees
	///
	/// **Note**: Chaining constraints creates nested types, which Swift infers automatically.
	public let headcount: ConstrainedDriver<ConstrainedDriver<ProductDriver<Double>>>

	/// Average monthly salary per employee.
	///
	/// Characteristics:
	/// - Mean: $10,000/month
	/// - Std Dev: $1,000 (10% uncertainty for role mix)
	/// - Normal distribution (symmetric around mean)
	///
	/// ## Why Normal Distribution?
	///
	/// Salaries across a team tend to be normally distributed:
	/// - Most employees near the average
	/// - Fewer at very high or very low ends
	/// - Symmetric around mean salary
	public let avgSalary: ProbabilisticDriver<Double>

	/// Total monthly payroll.
	///
	/// Formula: `Payroll = Headcount × Avg Salary`
	///
	/// Combines uncertainty from:
	/// - Headcount variability (driven by user growth)
	/// - Salary variability (role mix)
	public let payroll: ProductDriver<Double>

	/// Total monthly costs.
	///
	/// Formula: `Total Costs = Fixed + Variable + Payroll`
	///
	/// Aggregates all cost components with their respective uncertainties.
	public let totalCosts: SumDriver<Double>

	// MARK: - Profit

	/// Monthly profit (EBITDA).
	///
	/// Formula: `Profit = Revenue - Total Costs`
	///
	/// This is the key output metric that incorporates:
	/// - All revenue uncertainty (users, pricing)
	/// - All cost uncertainty (headcount, salaries)
	/// - Time-varying behavior (seasonality, growth)
	/// - All constraints (positive values, integers)
	///
	/// ## Monte Carlo Analysis
	///
	/// When projected with Monte Carlo simulation, this driver produces:
	/// - Mean expected profit per period
	/// - Standard deviation (uncertainty/risk)
	/// - Percentiles (P5, P25, P50, P75, P95)
	/// - Min/max outcomes
	///
	/// Use these statistics for:
	/// - **Budget planning**: Use P25 or P50 for conservative targets
	/// - **Risk assessment**: Check P5 for worst-case scenarios
	/// - **Upside potential**: Check P95 for best-case scenarios
	public let profit: SumDriver<Double>

	// MARK: - Initialization

	/// Creates a complete SaaS financial model with all drivers configured.
	///
	/// All parameters are pre-configured with realistic assumptions for a
	/// growing SaaS business. This serves as both a working example and a
	/// template for building your own models.
	public init() {
		// ─────────────────────────────────────────────────────────────
		// REVENUE DRIVERS
		// ─────────────────────────────────────────────────────────────

		// Users: Growing + Seasonal
		// Base: 1000 users in Q1 2025
		// Growth: 30% annual with 10% uncertainty
		// Seasonal: Q4 gets 15% boost
		let baseUsers = TimeVaryingDriver<Double>(name: "Users (Base)") { period in
			// Annual growth component (30% per year)
			let yearsSince2025 = Double(period.year - 2025)
			let growthMultiplier = pow(1.30, yearsSince2025)

			// Seasonal component (Q4 boost)
			let seasonalMultiplier: Double
			if period.type == .quarterly && period.quarter == 4 {
				seasonalMultiplier = 1.15  // 15% Q4 boost
			} else {
				seasonalMultiplier = 1.0
			}

			// Base users in Q1 2025
			let baseValue = 1000.0

			// Combined value
			let expectedValue = baseValue * growthMultiplier * seasonalMultiplier

			// Add 10% uncertainty
			let stdDev = expectedValue * 0.10
			return ProbabilisticDriver<Double>.normal(
				name: "Users",
				mean: expectedValue,
				stdDev: stdDev
			).sample(for: period)
		}

		// Apply constraints: positive integers only
		self.users = baseUsers.positive().rounded()

		// Price per user: Triangular distribution
		// Low: $80, High: $120, Mode: $100
		self.pricePerUser = ProbabilisticDriver<Double>.triangular(
			name: "Price/User",
			low: 80.0,
			high: 120.0,
			base: 100.0
		).positive()

		// Revenue = Users × Price/User
		self.revenue = users * pricePerUser

		// ─────────────────────────────────────────────────────────────
		// COST DRIVERS
		// ─────────────────────────────────────────────────────────────

		// Fixed costs: $50k/month growing 3% annually
		self.fixedCosts = TimeVaryingDriver.withGrowth(
			name: "Fixed Costs",
			baseValue: 50_000.0,
			annualGrowthRate: 0.03,
			baseYear: 2025
		)

		// Variable cost per user: $20/user/month
		self.variableCostPerUser = DeterministicDriver(
			name: "Variable Cost/User",
			value: 20.0
		)

		// Total variable costs = $20 × Users
		self.variableCosts = users * variableCostPerUser

		// Headcount: 1 employee per 50 users
		let employeesPerUser = DeterministicDriver<Double>(
			name: "Employees/User Ratio",
			value: 1.0 / 50.0
		)
		let baseHeadcount = users * employeesPerUser

		// Apply constraints: positive integers
		self.headcount = baseHeadcount.positive().rounded()

		// Average salary: $10k/month with 10% std dev
		self.avgSalary = ProbabilisticDriver<Double>.normal(
			name: "Avg Salary",
			mean: 10_000.0,
			stdDev: 1_000.0
		)

		// Payroll = Headcount × Avg Salary
		self.payroll = headcount * avgSalary

		// Total costs = Fixed + Variable + Payroll
		self.totalCosts = fixedCosts + variableCosts + payroll

		// ─────────────────────────────────────────────────────────────
		// PROFIT
		// ─────────────────────────────────────────────────────────────

		// Profit = Revenue - Total Costs
		self.profit = revenue - totalCosts
	}

	// MARK: - Projection Methods

	/// Projects all model components over specified periods.
	///
	/// Returns deterministic projections (single expected path) for all drivers.
	///
	/// - Parameter periods: Time periods to project over
	/// - Returns: Dictionary of time series for each model component
	///
	/// ## Example
	///
	/// ```swift
	/// let model = SaaSFinancialModel()
	/// let quarters = Period.year(2025).quarters()
	/// let projections = model.projectDeterministic(periods: quarters)
	///
	/// print("Q1 Users: \(projections["users"]![quarters[0]]!)")
	/// print("Q1 Revenue: $\(projections["revenue"]![quarters[0]]!)")
	/// print("Q1 Profit: $\(projections["profit"]![quarters[0]]!)")
	/// ```
	public func projectDeterministic(periods: [Period]) -> [String: TimeSeries<Double>] {
		return [
			"users": DriverProjection(driver: users, periods: periods).project(),
			"pricePerUser": DriverProjection(driver: pricePerUser, periods: periods).project(),
			"revenue": DriverProjection(driver: revenue, periods: periods).project(),
			"fixedCosts": DriverProjection(driver: fixedCosts, periods: periods).project(),
			"variableCosts": DriverProjection(driver: variableCosts, periods: periods).project(),
			"headcount": DriverProjection(driver: headcount, periods: periods).project(),
			"payroll": DriverProjection(driver: payroll, periods: periods).project(),
			"totalCosts": DriverProjection(driver: totalCosts, periods: periods).project(),
			"profit": DriverProjection(driver: profit, periods: periods).project()
		]
	}

	/// Runs Monte Carlo simulation for all model components.
	///
	/// Generates thousands of scenarios to quantify uncertainty in all outputs.
	///
	/// - Parameters:
	///   - periods: Time periods to project over
	///   - iterations: Number of Monte Carlo scenarios (default: 10,000)
	/// - Returns: Dictionary of projection results with full statistics
	///
	/// ## Example
	///
	/// ```swift
	/// let model = SaaSFinancialModel()
	/// let quarters = Period.year(2025).quarters()
	/// let results = model.projectMonteCarlo(periods: quarters, iterations: 10_000)
	///
	/// // Analyze Q1 profit uncertainty
	/// let q1 = quarters[0]
	/// let profitStats = results["profit"]!.statistics[q1]!
	/// let profitPctiles = results["profit"]!.percentiles[q1]!
	///
	/// print("Q1 Profit Analysis:")
	/// print("  Expected: $\(Int(profitStats.mean))")
	/// print("  Std Dev: $\(Int(profitStats.stdDev))")
	/// print("  Worst Case (P5): $\(Int(profitPctiles.p5))")
	/// print("  Median (P50): $\(Int(profitPctiles.p50))")
	/// print("  Best Case (P95): $\(Int(profitPctiles.p95))")
	/// ```
	public func projectMonteCarlo(
		periods: [Period],
		iterations: Int = 10_000
	) -> [String: ProjectionResults<Double>] {
		return [
			"users": DriverProjection(driver: users, periods: periods)
				.projectMonteCarlo(iterations: iterations),
			"pricePerUser": DriverProjection(driver: pricePerUser, periods: periods)
				.projectMonteCarlo(iterations: iterations),
			"revenue": DriverProjection(driver: revenue, periods: periods)
				.projectMonteCarlo(iterations: iterations),
			"fixedCosts": DriverProjection(driver: fixedCosts, periods: periods)
				.projectMonteCarlo(iterations: iterations),
			"variableCosts": DriverProjection(driver: variableCosts, periods: periods)
				.projectMonteCarlo(iterations: iterations),
			"headcount": DriverProjection(driver: headcount, periods: periods)
				.projectMonteCarlo(iterations: iterations),
			"payroll": DriverProjection(driver: payroll, periods: periods)
				.projectMonteCarlo(iterations: iterations),
			"totalCosts": DriverProjection(driver: totalCosts, periods: periods)
				.projectMonteCarlo(iterations: iterations),
			"profit": DriverProjection(driver: profit, periods: periods)
				.projectMonteCarlo(iterations: iterations)
		]
	}
}

// MARK: - Additional Examples

/// # Alternative Example: Retail Store Model
///
/// This example shows how to model a retail business with different characteristics.
///
/// ## Key Differences from SaaS Model
///
/// - **High seasonality**: 50% of revenue in Q4 (holiday shopping)
/// - **Inventory costs**: Variable based on sales volume
/// - **Store expansion**: Growing number of locations
/// - **Traffic uncertainty**: High variance in foot traffic
///
/// ```swift
/// public struct RetailStoreModel {
///     // Traffic per store (high seasonality)
///     let traffic = TimeVaryingDriver.withSeasonality(
///         name: "Traffic/Store",
///         baseValue: 10_000.0,
///         q1Multiplier: 0.8,
///         q2Multiplier: 0.9,
///         q3Multiplier: 1.0,
///         q4Multiplier: 1.8,  // 80% boost in Q4
///         stdDevPercentage: 0.20  // High uncertainty
///     )
///
///     // Number of stores (growing)
///     let storeCount = TimeVaryingDriver.withGrowth(
///         name: "Store Count",
///         baseValue: 10.0,
///         annualGrowthRate: 0.15,  // 15% new stores per year
///         baseYear: 2025
///     ).positive().rounded()
///
///     // Conversion rate (% who buy)
///     let conversionRate = ProbabilisticDriver<Double>.normal(
///         name: "Conversion Rate",
///         mean: 0.25,  // 25% average
///         stdDev: 0.05
///     ).clamped(min: 0.0, max: 1.0)
///
///     // Average transaction value
///     let avgTransaction = ProbabilisticDriver<Double>.triangular(
///         name: "Avg Transaction",
///         low: 30.0,
///         high: 100.0,
///         base: 50.0
///     ).positive()
///
///     // Total transactions = Traffic × Stores × Conversion Rate
///     let transactions = traffic * storeCount * conversionRate
///
///     // Revenue = Transactions × Avg Transaction
///     let revenue = transactions * avgTransaction
///
///     // Cost of Goods Sold (70% of revenue)
///     let cogsRate = DeterministicDriver<Double>(name: "COGS %", value: 0.70)
///     let cogs = revenue * cogsRate
///
///     // Store operating costs
///     let costPerStore = DeterministicDriver<Double>(name: "Cost/Store", value: 20_000.0)
///     let operatingCosts = storeCount * costPerStore
///
///     // Gross profit = Revenue - COGS - Operating
///     let grossProfit = revenue - cogs - operatingCosts
/// }
/// ```

/// # Alternative Example: Manufacturing Company
///
/// This example demonstrates modeling a manufacturing business.
///
/// ## Unique Characteristics
///
/// - **Production capacity**: Hard constraints on units/month
/// - **Utilization rate**: % of capacity actually used
/// - **Material costs**: Commodity prices with volatility
/// - **Efficiency gains**: Improving over time (learning curve)
///
/// ```swift
/// public struct ManufacturingModel {
///     // Production capacity (units/month)
///     let capacity = TimeVaryingDriver.withGrowth(
///         name: "Production Capacity",
///         baseValue: 100_000.0,
///         annualGrowthRate: 0.10,  // 10% capacity expansion
///         baseYear: 2025
///     ).positive().rounded()
///
///     // Capacity utilization (70-90%)
///     let utilization = ProbabilisticDriver<Double>.normal(
///         name: "Utilization Rate",
///         mean: 0.80,
///         stdDev: 0.05
///     ).clamped(min: 0.0, max: 1.0)
///
///     // Actual production = Capacity × Utilization
///     let unitsProduced = capacity * utilization
///
///     // Selling price per unit
///     let pricePerUnit = ProbabilisticDriver<Double>.triangular(
///         name: "Price/Unit",
///         low: 45.0,
///         high: 55.0,
///         base: 50.0
///     ).positive()
///
///     // Revenue = Units × Price
///     let revenue = unitsProduced * pricePerUnit
///
///     // Material cost per unit (volatile commodity prices)
///     let materialCost = ProbabilisticDriver<Double>.normal(
///         name: "Material Cost/Unit",
///         mean: 20.0,
///         stdDev: 3.0  // High volatility
///     ).positive()
///
///     // Labor efficiency (improving 2% per year - learning curve)
///     let laborCostPerUnit = TimeVaryingDriver<Double>(name: "Labor Cost/Unit") { period in
///         let yearsSince2025 = Double(period.year - 2025)
///         let efficiencyGain = pow(0.98, yearsSince2025)  // 2% annual improvement
///         let baseCost = 15.0
///         return baseCost * efficiencyGain
///     }
///
///     // Total variable costs
///     let variableCostPerUnit = materialCost + laborCostPerUnit
///     let totalVariableCosts = unitsProduced * variableCostPerUnit
///
///     // Fixed factory overhead
///     let fixedOverhead = DeterministicDriver<Double>(
///         name: "Fixed Overhead",
///         value: 200_000.0
///     )
///
///     // Gross profit = Revenue - Variable - Fixed
///     let grossProfit = revenue - totalVariableCosts - fixedOverhead
/// }
/// ```

/// # Best Practices for Building Models
///
/// ## 1. Start Simple, Add Complexity Gradually
///
/// ```swift
/// // Start with deterministic
/// let revenue = users * pricePerUser
///
/// // Add uncertainty
/// let revenue = ProbabilisticDriver<Double>.normal(...) * DeterministicDriver(...)
///
/// // Add time variation
/// let revenue = TimeVaryingDriver(...) * ProbabilisticDriver<Double>.normal(...)
///
/// // Add constraints
/// let revenue = TimeVaryingDriver(...).positive() * ProbabilisticDriver<Double>.normal(...).positive()
/// ```
///
/// ## 2. Use Appropriate Distributions
///
/// - **Normal**: Symmetric uncertainty (salaries, operational metrics)
/// - **Triangular**: Bounded with mode (pricing, project durations)
/// - **Uniform**: Equal likelihood in range (random allocation)
///
/// ## 3. Apply Realistic Constraints
///
/// - Use `.positive()` for counts, prices, costs
/// - Use `.rounded()` for people, units, discrete quantities
/// - Use `.clamped(min:max:)` for rates, percentages, bounded values
///
/// ## 4. Validate Model Outputs
///
/// ```swift
/// // Run sanity checks
/// let results = model.projectMonteCarlo(periods: quarters, iterations: 10_000)
///
/// // Check if outputs are reasonable
/// let profitStats = results["profit"]!.statistics[quarters[0]]!
/// assert(profitStats.mean > 0, "Expected positive profit")
/// assert(profitStats.stdDev < profitStats.mean, "Std dev shouldn't exceed mean")
/// ```
///
/// ## 5. Document Assumptions
///
/// Always document:
/// - Distribution choices and parameters
/// - Growth rates and their sources
/// - Constraint rationales
/// - Key relationships and formulas
