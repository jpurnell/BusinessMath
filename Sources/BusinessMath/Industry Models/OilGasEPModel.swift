//
//  OilGasEPModel.swift
//  BusinessMath
//
//  Created by Justin Purnell on 4/15/26.
//

import Foundation
import Numerics

// MARK: - WellProductionProfile

/// Production profile for a single well.
///
/// Encapsulates the daily production rate for a well over time, expressed in
/// barrels of oil equivalent per day (BOEPD). Provides convenience methods
/// to compute total production for a given period by multiplying the daily
/// rate by the number of calendar days in that period.
///
/// ## Example
///
/// ```swift
/// let periods = [
///     Period.month(year: 2026, month: 1),
///     Period.month(year: 2026, month: 2),
///     Period.month(year: 2026, month: 3)
/// ]
/// let dailyRates = TimeSeries<Double>(
///     periods: periods,
///     values: [100.0, 95.0, 90.0]
/// )
///
/// let well = WellProductionProfile(
///     name: "Permian Basin Well #1",
///     dailyProduction: dailyRates
/// )
///
/// // January has 31 days, so total = 100 * 31 = 3100 BOE
/// let janProduction = well.production(for: periods[0])
/// ```
public struct WellProductionProfile: Sendable {

    /// The human-readable name of this well.
    public let name: String

    /// Monthly production volumes in barrels of oil equivalent per day (BOEPD).
    public let dailyProduction: TimeSeries<Double>

    /// Creates a new well production profile.
    ///
    /// - Parameters:
    ///   - name: The well name.
    ///   - dailyProduction: A time series of daily production rates (BOEPD).
    public init(name: String, dailyProduction: TimeSeries<Double>) {
        self.name = name
        self.dailyProduction = dailyProduction
    }

    /// Computes total production for a period in BOE.
    ///
    /// Multiplies the daily production rate for the period by the number of
    /// calendar days in that period. Returns zero if the period has no
    /// associated production rate.
    ///
    /// - Parameter period: The time period to compute production for.
    /// - Returns: Total barrels of oil equivalent produced in the period.
    public func production(for period: Period) -> Double {
        guard let dailyRate = dailyProduction[period] else {
            return 0.0
        }
        let daysCount = Double(period.days().count)
        return dailyRate * daysCount
    }
}

// MARK: - OilGasEPModel

/// E&P company financial model that projects financial statements from
/// well-level production, commodity prices, operating expenses, and hedging.
///
/// `OilGasEPModel` is the flagship industry template for Exploration & Production
/// companies. It builds a complete three-statement model (Income Statement,
/// Balance Sheet, Cash Flow Statement) linked through ``StatementIntegration``.
///
/// ## Revenue Calculation
///
/// For each period:
/// ```
/// Revenue = Total Production (BOE) x Commodity Price + Hedge Settlements
/// ```
///
/// ## Expense Structure
///
/// - **LOE (Lease Operating Expense)**: Variable cost per BOE
/// - **DD&A (Depreciation, Depletion & Amortization)**: Fixed rate on PP&E
/// - **G&A (General & Administrative)**: Fixed cost per period
/// - **Taxes**: Applied to pre-tax income (zero if pre-tax income is negative)
///
/// ## Example
///
/// ```swift
/// let entity = Entity(id: "EP-001", name: "Basin Energy Corp")
/// let periods = [
///     Period.month(year: 2026, month: 1),
///     Period.month(year: 2026, month: 2),
///     Period.month(year: 2026, month: 3)
/// ]
///
/// let well = WellProductionProfile(
///     name: "Well #1",
///     dailyProduction: TimeSeries(periods: periods, values: [100, 95, 90])
/// )
///
/// let model = OilGasEPModel(
///     entity: entity,
///     wells: [well],
///     commodityPriceName: "WTI",
///     leaseOperatingExpensePerBOE: 15.0,
///     generalAndAdminExpense: 50_000.0,
///     depreciationRate: 0.01,
///     initialPPE: 10_000_000.0,
///     initialCash: 500_000.0,
///     taxRate: 0.21,
///     hedgingProgram: nil
/// )
///
/// let prices = TimeSeries(periods: periods, values: [70.0, 72.0, 68.0])
/// let integration = model.project(periods: periods, commodityPrices: prices)
/// ```
public struct OilGasEPModel: Sendable {

    /// The entity that owns this E&P operation.
    public let entity: Entity

    /// The wells in the production portfolio.
    public let wells: [WellProductionProfile]

    /// The name of the commodity price series (e.g., "WTI", "Brent").
    public let commodityPriceName: String

    /// Lease operating expense per barrel of oil equivalent.
    public let leaseOperatingExpensePerBOE: Double

    /// General and administrative expense per period (fixed).
    public let generalAndAdminExpense: Double

    /// Depreciation rate as a fraction of PP&E per period.
    public let depreciationRate: Double

    /// Initial property, plant & equipment value.
    public let initialPPE: Double

    /// Initial cash balance.
    public let initialCash: Double

    /// Effective tax rate applied to pre-tax income.
    public let taxRate: Double

    /// Optional hedging program for commodity price risk management.
    public let hedgingProgram: HedgingProgram<Double>?

    /// Creates a new E&P financial model.
    ///
    /// - Parameters:
    ///   - entity: The entity that owns the operation.
    ///   - wells: The wells in the production portfolio.
    ///   - commodityPriceName: Name of the commodity (e.g., "WTI").
    ///   - leaseOperatingExpensePerBOE: Variable operating cost per BOE.
    ///   - generalAndAdminExpense: Fixed G&A expense per period.
    ///   - depreciationRate: DD&A rate as fraction of PP&E per period.
    ///   - initialPPE: Starting PP&E value.
    ///   - initialCash: Starting cash balance.
    ///   - taxRate: Effective tax rate (0.0 to 1.0).
    ///   - hedgingProgram: Optional hedging program.
    public init(
        entity: Entity,
        wells: [WellProductionProfile],
        commodityPriceName: String,
        leaseOperatingExpensePerBOE: Double,
        generalAndAdminExpense: Double,
        depreciationRate: Double,
        initialPPE: Double,
        initialCash: Double,
        taxRate: Double,
        hedgingProgram: HedgingProgram<Double>?
    ) {
        self.entity = entity
        self.wells = wells
        self.commodityPriceName = commodityPriceName
        self.leaseOperatingExpensePerBOE = leaseOperatingExpensePerBOE
        self.generalAndAdminExpense = generalAndAdminExpense
        self.depreciationRate = depreciationRate
        self.initialPPE = initialPPE
        self.initialCash = initialCash
        self.taxRate = taxRate
        self.hedgingProgram = hedgingProgram
    }

    /// Projects financial statements for the given periods at given commodity prices.
    ///
    /// Builds a complete three-statement model by computing revenue, expenses,
    /// net income, balance sheet positions, and cash flows for each period.
    ///
    /// - Parameters:
    ///   - periods: The projection periods (must be non-empty).
    ///   - commodityPrices: A time series of commodity prices by period.
    /// - Returns: A ``StatementIntegration`` linking IS, BS, and CF statements.
    public func project(
        periods: [Period],
        commodityPrices: TimeSeries<Double>
    ) -> StatementIntegration<Double> {
        // Compute per-period values
        var revenueValues: [Double] = []
        var loeValues: [Double] = []
        var ddaValues: [Double] = []
        var gaValues: [Double] = []
        var taxValues: [Double] = []
        var netIncomeValues: [Double] = []
        var hedgeSettlementValues: [Double] = []

        // Balance sheet tracking
        var cashValues: [Double] = []
        var ppeValues: [Double] = []
        var retainedEarningsValues: [Double] = []

        var runningCash = initialCash
        var runningPPE = initialPPE
        var runningRE: Double = 0.0

        // Compute hedge settlements if a program exists
        let hedgeSettlements: TimeSeries<Double>?
        if let program = hedgingProgram {
            hedgeSettlements = program.totalSettlements(realizedPrices: commodityPrices)
        } else {
            hedgeSettlements = nil
        }

        for period in periods {
            // 1. Total production across all wells
            var totalProduction: Double = 0.0
            for well in wells {
                totalProduction += well.production(for: period)
            }

            // 2. Commodity price for this period
            let price = commodityPrices[period] ?? 0.0

            // 3. Revenue = production * price
            var periodRevenue = totalProduction * price

            // 4. Hedge settlements (added to revenue / other income)
            let hedgeSettlement = hedgeSettlements?[period] ?? 0.0
            periodRevenue += hedgeSettlement
            hedgeSettlementValues.append(hedgeSettlement)

            // 5. LOE = production * per-BOE cost
            let periodLOE = totalProduction * leaseOperatingExpensePerBOE

            // 6. DD&A = depreciation rate * PP&E
            let periodDDA = depreciationRate * runningPPE

            // 7. G&A = fixed per period
            let periodGA = generalAndAdminExpense

            // 8. Pre-tax income
            let preTaxIncome = periodRevenue - periodLOE - periodDDA - periodGA

            // 9. Tax (only on positive income)
            let periodTax: Double
            if preTaxIncome > 0.0 {
                periodTax = preTaxIncome * taxRate
            } else {
                periodTax = 0.0
            }

            // 10. Net income
            let periodNetIncome = preTaxIncome - periodTax

            // Store income statement values
            revenueValues.append(periodRevenue)
            loeValues.append(periodLOE)
            ddaValues.append(periodDDA)
            gaValues.append(periodGA)
            taxValues.append(periodTax)
            netIncomeValues.append(periodNetIncome)

            // Update balance sheet
            // Cash = prior cash + net income + DD&A (add back non-cash)
            // Simplified: operating cash flow = net income + DD&A
            let operatingCF = periodNetIncome + periodDDA
            runningCash += operatingCF
            runningPPE -= periodDDA
            runningRE += periodNetIncome

            cashValues.append(runningCash)
            ppeValues.append(runningPPE)
            retainedEarningsValues.append(runningRE)
        }

        // Build accounts and statements
        // Using do/catch to handle throwing Account inits safely
        // Since we control all inputs, these should not fail, but we handle gracefully

        let integration: StatementIntegration<Double>
        do {
            integration = try buildStatements(
                periods: periods,
                revenueValues: revenueValues,
                loeValues: loeValues,
                ddaValues: ddaValues,
                gaValues: gaValues,
                taxValues: taxValues,
                cashValues: cashValues,
                ppeValues: ppeValues,
                retainedEarningsValues: retainedEarningsValues,
                netIncomeValues: netIncomeValues
            )
        } catch {
            // Fallback: return empty statements if account creation fails
            // This should not happen with valid inputs
            let emptyTS = TimeSeries<Double>(periods: periods, values: Array(repeating: 0.0, count: periods.count))
            let fallbackAccount = try? Account<Double>(
                entity: entity,
                name: "Fallback",
                incomeStatementRole: .revenue,
                timeSeries: emptyTS
            )
            let fallbackBSAccount = try? Account<Double>(
                entity: entity,
                name: "Fallback Asset",
                balanceSheetRole: .cashAndEquivalents,
                timeSeries: emptyTS
            )
            let fallbackCFAccount = try? Account<Double>(
                entity: entity,
                name: "Fallback CF",
                cashFlowRole: .netIncome,
                timeSeries: emptyTS
            )

            let is_ = try? IncomeStatement(entity: entity, periods: periods, accounts: [fallbackAccount].compactMap { $0 })
            let bs_ = try? BalanceSheet(entity: entity, periods: periods, accounts: [fallbackBSAccount].compactMap { $0 })
            let cf_ = try? CashFlowStatement(entity: entity, periods: periods, accounts: [fallbackCFAccount].compactMap { $0 })

            if let is_ = is_, let bs_ = bs_, let cf_ = cf_ {
                return StatementIntegration(incomeStatement: is_, balanceSheet: bs_, cashFlowStatement: cf_)
            }
            // Last resort - this path should never be reached
            fatalError("Failed to create fallback statements: \(error)")
        }

        return integration
    }

    // MARK: - Private Helpers

    /// Builds the three financial statements from computed period values.
    ///
    /// - Returns: A ``StatementIntegration`` linking IS, BS, and CF.
    /// - Throws: Account or statement validation errors.
    private func buildStatements(
        periods: [Period],
        revenueValues: [Double],
        loeValues: [Double],
        ddaValues: [Double],
        gaValues: [Double],
        taxValues: [Double],
        cashValues: [Double],
        ppeValues: [Double],
        retainedEarningsValues: [Double],
        netIncomeValues: [Double]
    ) throws -> StatementIntegration<Double> {

        // === Income Statement Accounts ===

        let revenueAccount = try Account<Double>(
            entity: entity,
            name: "\(commodityPriceName) Revenue",
            incomeStatementRole: .revenue,
            timeSeries: TimeSeries(periods: periods, values: revenueValues)
        )

        let loeAccount = try Account<Double>(
            entity: entity,
            name: "Lease Operating Expense",
            incomeStatementRole: .costOfGoodsSold,
            timeSeries: TimeSeries(periods: periods, values: loeValues)
        )

        let ddaAccount = try Account<Double>(
            entity: entity,
            name: "DD&A",
            incomeStatementRole: .depreciationAmortization,
            timeSeries: TimeSeries(periods: periods, values: ddaValues)
        )

        let gaAccount = try Account<Double>(
            entity: entity,
            name: "General & Administrative",
            incomeStatementRole: .generalAndAdministrative,
            timeSeries: TimeSeries(periods: periods, values: gaValues)
        )

        let taxAccount = try Account<Double>(
            entity: entity,
            name: "Income Tax Expense",
            incomeStatementRole: .incomeTaxExpense,
            timeSeries: TimeSeries(periods: periods, values: taxValues)
        )

        let incomeStatement = try IncomeStatement(
            entity: entity,
            periods: periods,
            accounts: [revenueAccount, loeAccount, ddaAccount, gaAccount, taxAccount]
        )

        // === Balance Sheet Accounts ===

        let cashAccount = try Account<Double>(
            entity: entity,
            name: "Cash and Equivalents",
            balanceSheetRole: .cashAndEquivalents,
            timeSeries: TimeSeries(periods: periods, values: cashValues)
        )

        let ppeAccount = try Account<Double>(
            entity: entity,
            name: "Property, Plant & Equipment",
            balanceSheetRole: .propertyPlantEquipment,
            timeSeries: TimeSeries(periods: periods, values: ppeValues)
        )

        let retainedEarningsAccount = try Account<Double>(
            entity: entity,
            name: "Retained Earnings",
            balanceSheetRole: .retainedEarnings,
            timeSeries: TimeSeries(periods: periods, values: retainedEarningsValues)
        )

        // Initial equity = initial cash + initial PP&E (constant across periods)
        let initialEquity = initialCash + initialPPE
        let apicValues = Array(repeating: initialEquity, count: periods.count)
        let apicAccount = try Account<Double>(
            entity: entity,
            name: "Additional Paid-In Capital",
            balanceSheetRole: .additionalPaidInCapital,
            timeSeries: TimeSeries(periods: periods, values: apicValues)
        )

        let balanceSheet = try BalanceSheet(
            entity: entity,
            periods: periods,
            accounts: [cashAccount, ppeAccount, retainedEarningsAccount, apicAccount]
        )

        // === Cash Flow Statement Accounts ===

        let cfNetIncomeAccount = try Account<Double>(
            entity: entity,
            name: "Net Income",
            cashFlowRole: .netIncome,
            timeSeries: TimeSeries(periods: periods, values: netIncomeValues)
        )

        let cfDDAAccount = try Account<Double>(
            entity: entity,
            name: "DD&A Addback",
            cashFlowRole: .depreciationAmortizationAddback,
            timeSeries: TimeSeries(periods: periods, values: ddaValues)
        )

        let cashFlowStatement = try CashFlowStatement(
            entity: entity,
            periods: periods,
            accounts: [cfNetIncomeAccount, cfDDAAccount]
        )

        return StatementIntegration(
            incomeStatement: incomeStatement,
            balanceSheet: balanceSheet,
            cashFlowStatement: cashFlowStatement
        )
    }
}
