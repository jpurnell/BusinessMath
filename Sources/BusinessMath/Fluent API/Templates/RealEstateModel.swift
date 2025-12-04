//
//  RealEstateModel.swift
//  BusinessMath
//
//  Created on December 2, 2025.
//

import Foundation
import Numerics

/// A financial model template for real estate investments
///
/// This model handles key real estate investment metrics including:
/// - Purchase price and financing
/// - Rental income projections
/// - Operating expenses
/// - Mortgage payments
/// - Property appreciation
/// - Tax benefits (depreciation)
/// - Cash flow analysis
/// - Return metrics (Cash-on-Cash, IRR, Equity Multiple)
///
/// Example:
/// ```swift
/// let model = RealEstateModel(
///     purchasePrice: 500_000,
///     downPaymentPercentage: 0.25,
///     interestRate: 0.055,
///     loanTermYears: 30,
///     annualRent: 36_000,
///     vacancyRate: 0.05,
///     annualOperatingExpenses: 12_000,
///     annualAppreciationRate: 0.03
/// )
///
/// let cashFlow = model.projectCashFlow(years: 10)
/// let coc = model.calculateCashOnCashReturn(year: 1)
/// let irr = model.calculateIRR(holdingPeriodYears: 10)
/// ```
public struct RealEstateModel: Sendable {

    // MARK: - Properties

    /// Purchase price of the property
    public let purchasePrice: Double

    /// Down payment as percentage of purchase price (0.0 to 1.0)
    public let downPaymentPercentage: Double

    /// Annual interest rate on mortgage (0.0 to 1.0)
    public let interestRate: Double

    /// Loan term in years
    public let loanTermYears: Int

    /// Expected annual rental income (gross)
    public let annualRent: Double

    /// Vacancy rate (percentage of time property is vacant, 0.0 to 1.0)
    public let vacancyRate: Double

    /// Annual operating expenses (property management, maintenance, insurance, property taxes)
    public let annualOperatingExpenses: Double

    /// Annual appreciation rate (0.0 to 1.0)
    public let annualAppreciationRate: Double

    /// Closing costs as percentage of purchase price (optional, defaults to 3%)
    public let closingCostsPercentage: Double

    /// Annual rent increase rate (optional, defaults to 2.5%)
    public let rentGrowthRate: Double

    /// Property depreciation period in years (for tax purposes, defaults to 27.5 for residential)
    public let depreciationPeriodYears: Double

    /// Marginal tax rate for investor (optional, defaults to 0.24)
    public let taxRate: Double

    // MARK: - Initialization

    public init(
        purchasePrice: Double,
        downPaymentPercentage: Double,
        interestRate: Double,
        loanTermYears: Int,
        annualRent: Double,
        vacancyRate: Double = 0.05,
        annualOperatingExpenses: Double,
        annualAppreciationRate: Double,
        closingCostsPercentage: Double = 0.03,
        rentGrowthRate: Double = 0.025,
        depreciationPeriodYears: Double = 27.5,
        taxRate: Double = 0.24
    ) {
        self.purchasePrice = purchasePrice
        self.downPaymentPercentage = downPaymentPercentage
        self.interestRate = interestRate
        self.loanTermYears = loanTermYears
        self.annualRent = annualRent
        self.vacancyRate = vacancyRate
        self.annualOperatingExpenses = annualOperatingExpenses
        self.annualAppreciationRate = annualAppreciationRate
        self.closingCostsPercentage = closingCostsPercentage
        self.rentGrowthRate = rentGrowthRate
        self.depreciationPeriodYears = depreciationPeriodYears
        self.taxRate = taxRate
    }

    // MARK: - Computed Properties

    /// Down payment amount
    public var downPayment: Double {
        purchasePrice * downPaymentPercentage
    }

    /// Loan amount
    public var loanAmount: Double {
        purchasePrice * (1 - downPaymentPercentage)
    }

    /// Closing costs amount
    public var closingCosts: Double {
        purchasePrice * closingCostsPercentage
    }

    /// Total initial investment (down payment + closing costs)
    public var initialInvestment: Double {
        downPayment + closingCosts
    }

    /// Monthly mortgage payment (principal + interest)
    public var monthlyMortgagePayment: Double {
        calculateMonthlyPayment()
    }

    /// Annual mortgage payment
    public var annualMortgagePayment: Double {
        monthlyMortgagePayment * 12
    }

    /// Building value for depreciation (purchase price minus land value, estimated at 20% of purchase)
    private var depreciableValue: Double {
        purchasePrice * 0.80
    }

    /// Annual depreciation deduction
    public var annualDepreciation: Double {
        depreciableValue / depreciationPeriodYears
    }

    // MARK: - Cash Flow Calculations

    /// Calculate effective rental income after vacancy
    ///
    /// - Parameter year: Year of operation (1-indexed)
    /// - Returns: Effective rental income
    public func effectiveRentalIncome(year: Int) -> Double {
        let adjustedRent = annualRent * pow(1 + rentGrowthRate, Double(year - 1))
        return adjustedRent * (1 - vacancyRate)
    }

    /// Calculate net operating income (NOI)
    ///
    /// - Parameter year: Year of operation (1-indexed)
    /// - Returns: Net operating income
    public func netOperatingIncome(year: Int) -> Double {
        let income = effectiveRentalIncome(year: year)
        return income - annualOperatingExpenses
    }

    /// Calculate mortgage interest portion for a given year
    ///
    /// - Parameter year: Year of operation (1-indexed)
    /// - Returns: Total interest paid in that year
    public func mortgageInterest(year: Int) -> Double {
        var remainingBalance = loanAmount
        let monthlyRate = interestRate / 12
        let monthlyPayment = monthlyMortgagePayment
        var totalInterest = 0.0

        let startMonth = (year - 1) * 12 + 1
        let endMonth = year * 12

        for month in 1...endMonth {
            let interestPayment = remainingBalance * monthlyRate
            let principalPayment = monthlyPayment - interestPayment
            remainingBalance -= principalPayment

            if month >= startMonth {
                totalInterest += interestPayment
            }
        }

        return totalInterest
    }

    /// Calculate before-tax cash flow
    ///
    /// - Parameter year: Year of operation (1-indexed)
    /// - Returns: Cash flow before taxes
    public func beforeTaxCashFlow(year: Int) -> Double {
        let noi = netOperatingIncome(year: year)
        return noi - annualMortgagePayment
    }

    /// Calculate taxable income
    ///
    /// - Parameter year: Year of operation (1-indexed)
    /// - Returns: Taxable income (can be negative)
    public func taxableIncome(year: Int) -> Double {
        let noi = netOperatingIncome(year: year)
        let interest = mortgageInterest(year: year)
        let depreciation = annualDepreciation

        return noi - interest - depreciation
    }

    /// Calculate tax impact (positive = owe taxes, negative = tax savings)
    ///
    /// - Parameter year: Year of operation (1-indexed)
    /// - Returns: Tax amount
    public func taxImpact(year: Int) -> Double {
        let taxableInc = taxableIncome(year: year)
        return taxableInc * taxRate
    }

    /// Calculate after-tax cash flow
    ///
    /// - Parameter year: Year of operation (1-indexed)
    /// - Returns: Cash flow after taxes
    public func afterTaxCashFlow(year: Int) -> Double {
        let beforeTax = beforeTaxCashFlow(year: year)
        let taxes = taxImpact(year: year)
        return beforeTax - taxes
    }

    /// Project cash flows over multiple years
    ///
    /// - Parameter years: Number of years to project
    /// - Returns: Time series of after-tax cash flows
    public func projectCashFlow(years: Int) -> TimeSeries<Double> {
        let periods = (1...years).map { Period.year($0) }
        let cashFlows = (1...years).map { afterTaxCashFlow(year: $0) }
        return TimeSeries(periods: periods, values: cashFlows)
    }

    // MARK: - Return Metrics

    /// Calculate cash-on-cash return for a given year
    ///
    /// - Parameter year: Year of operation (1-indexed)
    /// - Returns: Cash-on-cash return as percentage
    public func calculateCashOnCashReturn(year: Int) -> Double {
        let cashFlow = afterTaxCashFlow(year: year)
        return cashFlow / initialInvestment
    }

    /// Calculate property value at a given year
    ///
    /// - Parameter year: Year of operation (1-indexed)
    /// - Returns: Estimated property value
    public func propertyValue(atYear year: Int) -> Double {
        return purchasePrice * pow(1 + annualAppreciationRate, Double(year))
    }

    /// Calculate remaining loan balance at a given year
    ///
    /// - Parameter year: Year of operation (1-indexed)
    /// - Returns: Remaining mortgage balance
    public func loanBalance(atYear year: Int) -> Double {
        var balance = loanAmount
        let monthlyRate = interestRate / 12
        let monthlyPayment = monthlyMortgagePayment

        let months = year * 12

        for _ in 1...months {
            let interestPayment = balance * monthlyRate
            let principalPayment = monthlyPayment - interestPayment
            balance -= principalPayment
        }

        return max(balance, 0)
    }

    /// Calculate equity at a given year
    ///
    /// - Parameter year: Year of operation (1-indexed)
    /// - Returns: Owner's equity (property value - loan balance)
    public func equity(atYear year: Int) -> Double {
        let value = propertyValue(atYear: year)
        let balance = loanBalance(atYear: year)
        return value - balance
    }

    /// Calculate sale proceeds (after costs)
    ///
    /// - Parameters:
    ///   - year: Year of sale
    ///   - sellingCostsPercentage: Selling costs as percentage of sale price (default 6%)
    /// - Returns: Net proceeds from sale
    public func saleProceeds(year: Int, sellingCostsPercentage: Double = 0.06) -> Double {
        let salePrice = propertyValue(atYear: year)
        let sellingCosts = salePrice * sellingCostsPercentage
        let remainingLoan = loanBalance(atYear: year)

        return salePrice - sellingCosts - remainingLoan
    }

    /// Calculate IRR for a given holding period
    ///
    /// - Parameters:
    ///   - holdingPeriodYears: Number of years to hold property
    ///   - sellingCostsPercentage: Selling costs as percentage (default 6%)
    /// - Returns: Internal rate of return
    public func calculateIRR(holdingPeriodYears: Int, sellingCostsPercentage: Double = 0.06) -> Double? {
        var cashFlows: [Double] = [-initialInvestment]

        for year in 1...holdingPeriodYears {
            if year == holdingPeriodYears {
                // Final year includes sale proceeds
                let annualCF = afterTaxCashFlow(year: year)
                let proceeds = saleProceeds(year: year, sellingCostsPercentage: sellingCostsPercentage)
                cashFlows.append(annualCF + proceeds)
            } else {
                cashFlows.append(afterTaxCashFlow(year: year))
            }
        }

        return try? irr(cashFlows: cashFlows)
    }

    /// Calculate equity multiple
    ///
    /// - Parameters:
    ///   - holdingPeriodYears: Number of years to hold property
    ///   - sellingCostsPercentage: Selling costs as percentage (default 6%)
    /// - Returns: Equity multiple (total return / initial investment)
    public func calculateEquityMultiple(holdingPeriodYears: Int, sellingCostsPercentage: Double = 0.06) -> Double {
        var totalCashFlow = 0.0

        for year in 1...holdingPeriodYears {
            totalCashFlow += afterTaxCashFlow(year: year)
        }

        let proceeds = saleProceeds(year: holdingPeriodYears, sellingCostsPercentage: sellingCostsPercentage)
        totalCashFlow += proceeds

        return totalCashFlow / initialInvestment
    }

    /// Calculate cap rate (year 1 NOI / purchase price)
    ///
    /// - Returns: Capitalization rate
    public func calculateCapRate() -> Double {
        let year1NOI = netOperatingIncome(year: 1)
        return year1NOI / purchasePrice
    }

    // MARK: - Private Helpers

    /// Calculate monthly mortgage payment using standard amortization formula
    private func calculateMonthlyPayment() -> Double {
        let principal = loanAmount
        let monthlyRate = interestRate / 12
        let numberOfPayments = Double(loanTermYears * 12)

        if monthlyRate == 0 {
            return principal / numberOfPayments
        }

        let factor = pow(1 + monthlyRate, numberOfPayments)
        return principal * (monthlyRate * factor) / (factor - 1)
    }
}
