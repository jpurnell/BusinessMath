//
//  ManufacturingModel.swift
//  BusinessMath
//
//  Created on October 31, 2025.
//

import Foundation
import RealModule

/// A financial model template for Manufacturing businesses.
///
/// This model handles key manufacturing metrics including:
/// - Production capacity and utilization
/// - Unit cost calculation (materials, labor, overhead)
/// - Contribution margin analysis
/// - Break-even analysis (units and revenue)
/// - Production efficiency
/// - Overhead allocation
/// - Profit projections
///
/// Example:
/// ```swift
/// let model = ManufacturingModel(
///     productionCapacity: 10_000,
///     sellingPricePerUnit: 50,
///     directMaterialCostPerUnit: 15,
///     directLaborCostPerUnit: 10,
///     monthlyOverhead: 150_000
/// )
///
/// let breakEven = model.calculateBreakEvenUnits()
/// let profit = model.calculateProfit(unitsProduced: 8_000)
/// let projection = model.project(months: 12, unitsPerMonth: 8_000)
/// ```
public struct ManufacturingModel: Sendable {
    // MARK: - Properties

    /// Production capacity (units per month)
    public let productionCapacity: Double

    /// Actual production level (units per month)
    public let actualProduction: Double?

    /// Selling price per unit
    public let sellingPricePerUnit: Double

    /// Direct material cost per unit
    public let directMaterialCostPerUnit: Double

    /// Direct labor cost per unit
    public let directLaborCostPerUnit: Double

    /// Monthly overhead (fixed costs)
    public let monthlyOverhead: Double

    /// Target production level (optional, for efficiency calculations)
    public let targetProduction: Double?

    // MARK: - Initialization

    public init(
        productionCapacity: Double,
        sellingPricePerUnit: Double,
        directMaterialCostPerUnit: Double,
        directLaborCostPerUnit: Double,
        monthlyOverhead: Double,
        targetProduction: Double? = nil
    ) {
        self.productionCapacity = productionCapacity
        self.actualProduction = nil
        self.sellingPricePerUnit = sellingPricePerUnit
        self.directMaterialCostPerUnit = directMaterialCostPerUnit
        self.directLaborCostPerUnit = directLaborCostPerUnit
        self.monthlyOverhead = monthlyOverhead
        self.targetProduction = targetProduction
    }

    /// Convenience initializer with simplified parameter names and actual production.
    ///
    /// Example:
    /// ```swift
    /// let model = ManufacturingModel(
    ///     productionCapacity: 10_000,
    ///     actualProduction: 8_500,
    ///     materialCostPerUnit: 15.0,
    ///     laborCostPerUnit: 10.0,
    ///     overheadCosts: 50_000,
    ///     sellingPricePerUnit: 50.0
    /// )
    /// ```
    public init(
        productionCapacity: Double,
        actualProduction: Double,
        materialCostPerUnit: Double,
        laborCostPerUnit: Double,
        overheadCosts: Double,
        sellingPricePerUnit: Double
    ) {
        self.productionCapacity = productionCapacity
        self.actualProduction = actualProduction
        self.sellingPricePerUnit = sellingPricePerUnit
        self.directMaterialCostPerUnit = materialCostPerUnit
        self.directLaborCostPerUnit = laborCostPerUnit
        self.monthlyOverhead = overheadCosts
        self.targetProduction = nil
    }

    // MARK: - Computed Properties

    /// Variable cost per unit (direct materials + direct labor)
    private var variableCostPerUnit: Double {
        directMaterialCostPerUnit + directLaborCostPerUnit
    }

    // MARK: - Unit Cost Calculations

    /// Calculate total unit cost using stored actual production.
    ///
    /// Unit Cost = Direct Materials + Direct Labor + (Overhead / Units Produced)
    ///
    /// - Returns: Total cost per unit based on actualProduction, or 0 if not set
    public func calculateUnitCost() -> Double {
        guard let production = actualProduction, production > 0 else { return 0 }
        let overheadPerUnit = monthlyOverhead / production
        return variableCostPerUnit + overheadPerUnit
    }

    /// Calculate total unit cost at a given capacity utilization.
    ///
    /// Unit Cost = Direct Materials + Direct Labor + (Overhead / Units Produced)
    ///
    /// - Parameter capacityUtilization: Utilization percentage (0.0 to 1.0)
    /// - Returns: Total cost per unit
    public func calculateUnitCost(atCapacityUtilization capacityUtilization: Double) -> Double {
        let unitsProduced = productionCapacity * capacityUtilization
        let overheadPerUnit = monthlyOverhead / unitsProduced
        return variableCostPerUnit + overheadPerUnit
    }

    /// Calculate overhead per unit for a given production level.
    ///
    /// - Parameter production: Number of units produced
    /// - Returns: Overhead cost per unit
    public func calculateOverheadPerUnit(atProduction production: Double) -> Double {
        return monthlyOverhead / production
    }

    // MARK: - Contribution Margin

    /// Calculate contribution margin per unit.
    ///
    /// Contribution Margin = Selling Price - Variable Costs
    ///
    /// - Returns: Contribution margin per unit
    public func calculateContributionMargin() -> Double {
        return sellingPricePerUnit - variableCostPerUnit
    }

    /// Calculate contribution margin per unit (alias for calculateContributionMargin).
    ///
    /// Contribution Margin = Selling Price - Variable Costs
    ///
    /// - Returns: Contribution margin per unit
    public func calculateContributionMarginPerUnit() -> Double {
        return calculateContributionMargin()
    }

    /// Calculate contribution margin ratio.
    ///
    /// CM Ratio = Contribution Margin / Selling Price
    ///
    /// - Returns: Contribution margin ratio (percentage)
    public func calculateContributionMarginRatio() -> Double {
        return calculateContributionMarginPerUnit() / sellingPricePerUnit
    }

    // MARK: - Break-Even Analysis

    /// Calculate break-even units.
    ///
    /// Break-even Units = Fixed Costs / Contribution Margin per Unit
    ///
    /// - Returns: Number of units needed to break even
    public func calculateBreakEvenUnits() -> Double {
        return monthlyOverhead / calculateContributionMarginPerUnit()
    }

    /// Calculate break-even revenue.
    ///
    /// Break-even Revenue = Break-even Units * Selling Price
    ///
    /// - Returns: Revenue needed to break even
    public func calculateBreakEvenRevenue() -> Double {
        return calculateBreakEvenUnits() * sellingPricePerUnit
    }

    // MARK: - Capacity Utilization

    /// Calculate capacity utilization using stored actual production.
    ///
    /// Capacity Utilization = Actual Production / Production Capacity
    ///
    /// - Returns: Capacity utilization ratio (0.0 to 1.0+), or 0 if actualProduction is not set
    public func calculateCapacityUtilization() -> Double {
        guard let production = actualProduction else { return 0 }
        return production / productionCapacity
    }

    /// Calculate capacity utilization.
    ///
    /// Capacity Utilization = Actual Production / Production Capacity
    ///
    /// - Parameter actualProduction: Number of units actually produced
    /// - Returns: Capacity utilization ratio (0.0 to 1.0+)
    public func calculateCapacityUtilization(actualProduction: Double) -> Double {
        return actualProduction / productionCapacity
    }

    // MARK: - Production Efficiency

    /// Calculate production efficiency against target.
    ///
    /// Production Efficiency = Actual Production / Target Production
    ///
    /// - Parameter actualProduction: Number of units actually produced
    /// - Returns: Efficiency ratio, or 0 if no target is set
    public func calculateProductionEfficiency(actualProduction: Double) -> Double {
        guard let target = targetProduction else { return 0 }
        return actualProduction / target
    }

    // MARK: - Profit Calculations

    /// Calculate profit for a given production level.
    ///
    /// Profit = (Selling Price - Variable Cost) * Units - Fixed Costs
    ///
    /// - Parameter unitsProduced: Number of units produced and sold
    /// - Returns: Monthly profit
    public func calculateProfit(unitsProduced: Double) -> Double {
        let contributionMargin = calculateContributionMarginPerUnit()
        return (contributionMargin * unitsProduced) - monthlyOverhead
    }

    /// Calculate revenue for a given production level.
    ///
    /// - Parameter unitsProduced: Number of units produced and sold
    /// - Returns: Total revenue
    public func calculateRevenue(unitsProduced: Double) -> Double {
        return unitsProduced * sellingPricePerUnit
    }

    // MARK: - Comprehensive Projections

    /// Project revenue, profit, and unit cost over multiple months.
    ///
    /// - Parameters:
    ///   - months: Number of months to project
    ///   - unitsPerMonth: Units produced per month
    /// - Returns: Tuple containing time series for revenue, profit, and unit cost
    public func project(months: Int, unitsPerMonth: Double) -> (
        revenue: TimeSeries<Double>,
        profit: TimeSeries<Double>,
        unitCost: TimeSeries<Double>
    ) {
        let baseYear = 2025
        let periods = (1...months).map { monthIndex -> Period in
            let year = baseYear + (monthIndex - 1) / 12
            let month = ((monthIndex - 1) % 12) + 1
            return Period.month(year: year, month: month)
        }

        let capacityUtilization = unitsPerMonth / productionCapacity

        let revenueValues = Array(repeating: calculateRevenue(unitsProduced: unitsPerMonth), count: months)
        let profitValues = Array(repeating: calculateProfit(unitsProduced: unitsPerMonth), count: months)
        let unitCostValues = Array(repeating: calculateUnitCost(atCapacityUtilization: capacityUtilization), count: months)

        return (
            revenue: TimeSeries(periods: periods, values: revenueValues),
            profit: TimeSeries(periods: periods, values: profitValues),
            unitCost: TimeSeries(periods: periods, values: unitCostValues)
        )
    }
}
