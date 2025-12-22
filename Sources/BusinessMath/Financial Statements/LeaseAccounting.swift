import Foundation
import Numerics

/// Depreciation method for right-of-use asset
public enum DepreciationMethod {
    case straightLine
    case decliningBalance
}

/// Lease term specification
public enum LeaseTerm {
    case months(Int)
    case years(Int)
}

/// Type of discount rate used for lease
public enum DiscountRateType {
    case implicitRate
    case incrementalBorrowingRate
}

/// Represents a lease agreement for accounting purposes.
///
/// Under IFRS 16 and ASC 842, most leases must be recognized on the balance sheet
/// as a right-of-use (ROU) asset and lease liability.
public struct Lease {
    public let payments: [Double]
    public let periods: [Period]?
    public let discountRate: Double
    public let residualValue: Double
    public let startDate: Date?
    public let initialDirectCosts: Double
    public let prepaidAmount: Double
    public let depreciationMethod: DepreciationMethod
    public let variablePayments: TimeSeries<Double>?
    public let leaseTerm: LeaseTerm?
    public let underlyingAssetValue: Double?
    public let discountRateType: DiscountRateType
    public let fairValueOfAsset: Double?

    public init(
        payments: [Double],
        discountRate: Double,
        residualValue: Double = 0.0,
        startDate: Date? = nil,
        initialDirectCosts: Double = 0.0,
        prepaidAmount: Double = 0.0,
        depreciationMethod: DepreciationMethod = .straightLine,
        variablePayments: TimeSeries<Double>? = nil,
        leaseTerm: LeaseTerm? = nil,
        underlyingAssetValue: Double? = nil,
        discountRateType: DiscountRateType = .incrementalBorrowingRate,
        fairValueOfAsset: Double? = nil
    ) {
        self.payments = payments
        self.periods = nil
        self.discountRate = discountRate
        self.residualValue = residualValue
        self.startDate = startDate
        self.initialDirectCosts = initialDirectCosts
        self.prepaidAmount = prepaidAmount
        self.depreciationMethod = depreciationMethod
        self.variablePayments = variablePayments
        self.leaseTerm = leaseTerm
        self.underlyingAssetValue = underlyingAssetValue
        self.discountRateType = discountRateType
        self.fairValueOfAsset = fairValueOfAsset
    }

	public init(
        payments: TimeSeries<Double>,
        discountRate: Double,
        residualValue: Double = 0.0,
        startDate: Date? = nil,
        initialDirectCosts: Double = 0.0,
        prepaidAmount: Double = 0.0,
        depreciationMethod: DepreciationMethod = .straightLine,
        variablePayments: TimeSeries<Double>? = nil,
        leaseTerm: LeaseTerm? = nil,
        underlyingAssetValue: Double? = nil,
        discountRateType: DiscountRateType = .incrementalBorrowingRate,
        fairValueOfAsset: Double? = nil
    ) {
		self.payments = payments.valuesArray
        self.periods = payments.periods
		self.discountRate = discountRate
		self.residualValue = residualValue
        self.startDate = startDate ?? payments.periods.first?.startDate
        self.initialDirectCosts = initialDirectCosts
        self.prepaidAmount = prepaidAmount
        self.depreciationMethod = depreciationMethod
        self.variablePayments = variablePayments
        self.leaseTerm = leaseTerm
        self.underlyingAssetValue = underlyingAssetValue
        self.discountRateType = discountRateType
        self.fairValueOfAsset = fairValueOfAsset
	}

    /// Calculate present value of lease payments (lease liability)
    public func presentValue() -> Double {
        // Determine periodic discount rate based on payment frequency
        let periodicRate: Double
        if let periods = periods, let firstPeriod = periods.first {
            switch firstPeriod.type {
            case .monthly:
                periodicRate = discountRate / 12.0
            case .quarterly:
                periodicRate = discountRate / 4.0
            case .annual:
                periodicRate = discountRate
            case .daily:
                periodicRate = discountRate / 365.25
            }
        } else {
            // Default to annual if no period info
            periodicRate = discountRate
        }

        var pv = 0.0
        for (index, payment) in payments.enumerated() {
            let period = Double(index + 1)
            pv += payment / pow(1.0 + periodicRate, period)
        }

        // Add present value of residual
        if residualValue > 0 {
            let finalPeriod = Double(payments.count + 1)
            pv += residualValue / pow(1.0 + periodicRate, finalPeriod)
        }

        return pv
    }

    /// Calculate right-of-use asset value (typically equals lease liability)
    public func rightOfUseAsset() -> Double {
        // Apply exemptions
        if applyShortTermExemption || applyLowValueExemption {
            return 0.0
        }
        return presentValue() + initialDirectCosts + prepaidAmount
    }

    /// Internal detailed schedule
    /// Returns balance field as beginning balance (before payment)
    private func detailedSchedule() -> [(period: Period?, payment: Double, interest: Double, principal: Double, balance: Double)] {
        // Determine periodic discount rate
        let periodicRate: Double
        if let periods = periods, let firstPeriod = periods.first {
            switch firstPeriod.type {
            case .monthly:
                periodicRate = discountRate / 12.0
            case .quarterly:
                periodicRate = discountRate / 4.0
            case .annual:
                periodicRate = discountRate
            case .daily:
                periodicRate = discountRate / 365.25
            }
        } else {
            periodicRate = discountRate
        }

        var schedule: [(Period?, Double, Double, Double, Double)] = []
        var balance = presentValue()

        for (index, payment) in payments.enumerated() {
            let period: Period? = if let periods = periods, index < periods.count {
                periods[index]
            } else {
                nil
            }

            // Store beginning balance for this period
            let beginningBalance = balance

            let interest = balance * periodicRate
            let principal = payment - interest
            balance -= principal

            // Return beginning balance
            schedule.append((period, payment, interest, principal, beginningBalance))
        }

        return schedule
    }

    /// Generate amortization schedule for lease liability
    /// Returns balances for each period (first period shows initial balance,
    /// subsequent periods show ending balance after payment)
    public func liabilitySchedule() -> [Period: Double] {
        // Apply exemptions - return zero balances for all periods
        if applyShortTermExemption || applyLowValueExemption {
            var schedule: [Period: Double] = [:]
            if let periods = periods {
                for period in periods {
                    schedule[period] = 0.0
                }
            }
            return schedule
        }

        let detailed = detailedSchedule()
        var schedule: [Period: Double] = [:]

        for (index, entry) in detailed.enumerated() {
            if let period = entry.period {
                if index == 0 {
                    // First period: return beginning balance (initial liability)
                    schedule[period] = entry.balance
                } else {
                    // Subsequent periods: calculate ending balance
                    let endingBalance = entry.balance - entry.principal
                    schedule[period] = endingBalance
                }
            }
        }

        return schedule
    }

    /// Total lease cost over the term
    public var totalCost: Double {
        return payments.reduce(0.0, +)
    }

    /// Alias for presentValue() for compatibility
    public func presentValueOfPayments() -> Double {
        return presentValue()
    }

    /// Total undiscounted future payments
    public func totalFuturePayments() -> Double {
        return payments.reduce(0.0, +)
    }

    /// Calculate depreciation expense for a period
    public func depreciation(period: Period) -> Double {
        let rouAsset = rightOfUseAsset()
        let leaseTerm = Double(payments.count)
        return rouAsset / leaseTerm
    }

    /// Calculate interest expense for a period
    public func interestExpense(period: Period) -> Double {
        let schedule = detailedSchedule()
        for entry in schedule {
            if entry.period == period {
                return entry.interest
            }
        }
        return 0.0
    }

    /// Calculate principal reduction for a period
    public func principalReduction(period: Period) -> Double {
        let schedule = detailedSchedule()
        for entry in schedule {
            if entry.period == period {
                return entry.principal
            }
        }
        return 0.0
    }

    /// Generate maturity analysis showing payments by year
    public func maturityAnalysis() -> [String: Double] {
        var analysis: [String: Double] = [:]

        // Use periods if available to determine actual years
        if let periods = periods, let startPeriod = periods.first {
            let calendar = Calendar.current
            let startYear = calendar.component(.year, from: startPeriod.startDate)

            for (index, payment) in payments.enumerated() {
                if index < periods.count {
                    let period = periods[index]
                    let periodYear = calendar.component(.year, from: period.startDate)
                    let yearOffset = periodYear - startYear + 1
                    let key = "Year \(yearOffset)"
                    analysis[key, default: 0.0] += payment
                }
            }
        } else {
            // Fallback: assume monthly payments
            for (index, payment) in payments.enumerated() {
                let year = (index / 12) + 1
                let key = "Year \(year)"
                analysis[key, default: 0.0] += payment
            }
        }

        return analysis
    }

    /// Calculate carrying value (book value) of ROU asset for a period
    public func carryingValue(period: Period) -> Double {
        let rouAsset = rightOfUseAsset()
        let leaseTerm = Double(payments.count)
        let depreciationPerPeriod = rouAsset / leaseTerm

        // Find period index
        guard let periods = periods,
              let periodIndex = periods.firstIndex(of: period) else {
            return rouAsset
        }

        let periodsElapsed = Double(periodIndex + 1)
        let accumulatedDepreciation = depreciationPerPeriod * periodsElapsed
        return rouAsset - accumulatedDepreciation
    }

    /// Calculate total cash payment for a period (including variable payments)
    public func totalCashPayment(period: Period) -> Double {
        guard let periods = periods,
              let periodIndex = periods.firstIndex(of: period),
              periodIndex < payments.count else {
            return 0.0
        }

        var total = payments[periodIndex]

        // Add variable payment if exists
        if let varPayments = variablePayments,
           let varPayment = varPayments[period] {
            total += varPayment
        }

        return total
    }

    /// Check if this is a short-term lease (≤12 months)
    public var isShortTerm: Bool {
        // Only apply short-term classification if explicitly specified
        if let term = leaseTerm {
            switch term {
            case .months(let months):
                return months <= 12
            case .years(let years):
                return years <= 1
            }
        }
        // Without explicit term, don't assume short-term
        return false
    }

    /// Whether to apply short-term lease exemption
    public var applyShortTermExemption: Bool {
        return isShortTerm
    }

    /// Check if this is a low-value lease (< $5,000)
    public var isLowValue: Bool {
        if let assetValue = underlyingAssetValue {
            return assetValue < 5000.0
        }
        return false
    }

    /// Whether to apply low-value lease exemption
    public var applyLowValueExemption: Bool {
        return isLowValue
    }

    /// Effective interest rate used for the lease
    public var effectiveRate: Double {
        return discountRate
    }

    /// Extend the lease with additional payments
    public func extend(additionalPayments: TimeSeries<Double>) -> Lease {
        let newPayments = payments + additionalPayments.valuesArray
        let newPeriods = (periods ?? []) + additionalPayments.periods

        return Lease(
            payments: newPayments,
            discountRate: discountRate,
            residualValue: residualValue,
            startDate: startDate,
            initialDirectCosts: initialDirectCosts,
            prepaidAmount: prepaidAmount,
            periods: newPeriods,
            depreciationMethod: depreciationMethod,
            variablePayments: variablePayments,
            leaseTerm: leaseTerm,
            underlyingAssetValue: underlyingAssetValue,
            discountRateType: discountRateType,
            fairValueOfAsset: fairValueOfAsset
        )
    }

    /// Modify the lease with new payment terms
    public func modify(newPayments: TimeSeries<Double>, atPeriod: Period) -> Lease {
        return Lease(
            payments: newPayments,
            discountRate: discountRate,
            residualValue: residualValue,
            startDate: startDate,
            initialDirectCosts: initialDirectCosts,
            prepaidAmount: prepaidAmount
        )
    }

    /// Internal initializer that takes periods array
    private init(
        payments: [Double],
        discountRate: Double,
        residualValue: Double,
        startDate: Date?,
        initialDirectCosts: Double,
        prepaidAmount: Double,
        periods: [Period],
        depreciationMethod: DepreciationMethod = .straightLine,
        variablePayments: TimeSeries<Double>? = nil,
        leaseTerm: LeaseTerm? = nil,
        underlyingAssetValue: Double? = nil,
        discountRateType: DiscountRateType = .incrementalBorrowingRate,
        fairValueOfAsset: Double? = nil
    ) {
        self.payments = payments
        self.periods = periods
        self.discountRate = discountRate
        self.residualValue = residualValue
        self.startDate = startDate
        self.initialDirectCosts = initialDirectCosts
        self.prepaidAmount = prepaidAmount
        self.depreciationMethod = depreciationMethod
        self.variablePayments = variablePayments
        self.leaseTerm = leaseTerm
        self.underlyingAssetValue = underlyingAssetValue
        self.discountRateType = discountRateType
        self.fairValueOfAsset = fairValueOfAsset
    }
}

/// Analysis comparing leasing vs buying an asset
public struct LeaseVsBuyAnalysis {
    public let leasePV: Double
    public let buyPV: Double

    public init(leasePV: Double, buyPV: Double) {
        self.leasePV = leasePV
        self.buyPV = buyPV
    }

    /// Net advantage to leasing (NAL)
    public var netAdvantageToLeasing: Double {
        return buyPV - leasePV
    }

    /// Should the company lease?
    public var shouldLease: Bool {
        return netAdvantageToLeasing > 0
    }

    /// Percentage savings from leasing (if positive)
    public var savingsPercentage: Double {
        guard buyPV > 0 else { return 0.0 }
        return netAdvantageToLeasing / buyPV
    }

    /// Recommendation text based on the analysis
    public var recommendation: String {
        if shouldLease {
			return "Lease (NAL: \(netAdvantageToLeasing.currency()))"
        } else {
			return "Buy (NAL: \(netAdvantageToLeasing.currency()))"
        }
    }
}

/// Calculate present value of lease payments for lease vs buy analysis
public func leasePaymentsPV(
    periodicPayment: Double,
    periods: Int,
    discountRate: Double
) -> Double {
    // PV of annuity formula
    guard discountRate > 0 else {
        return periodicPayment * Double(periods)
    }

    let pv = periodicPayment * (1.0 - pow(1.0 + discountRate, -Double(periods))) / discountRate
    return pv
}

/// Calculate present value of buying an asset
public func buyAssetPV(
    purchasePrice: Double,
    salvageValue: Double,
    holdingPeriod: Int,
    discountRate: Double,
    maintenanceCost: Double = 0.0
) -> Double {
    // PV of purchase price (paid now)
    var pv = purchasePrice

    // PV of annual maintenance
    if maintenanceCost > 0 {
        pv += leasePaymentsPV(
            periodicPayment: maintenanceCost,
            periods: holdingPeriod,
            discountRate: discountRate
        )
    }

    // Subtract PV of salvage value
    let salvagePV = salvageValue / pow(1.0 + discountRate, Double(holdingPeriod))
    pv -= salvagePV

    return pv
}

/// Represents a sale-and-leaseback transaction
public struct SaleAndLeaseback {
    public let salePrice: Double
    public let bookValue: Double
    public let leaseTerm: Int
    public let annualLeasePayment: Double
    public let discountRate: Double

    public init(
        salePrice: Double,
        bookValue: Double,
        leaseTerm: Int,
        annualLeasePayment: Double,
        discountRate: Double
    ) {
        self.salePrice = salePrice
        self.bookValue = bookValue
        self.leaseTerm = leaseTerm
        self.annualLeasePayment = annualLeasePayment
        self.discountRate = discountRate
    }

    /// Convenience init with alternative parameter names
    public init(
        carryingValue: Double,
        salePrice: Double,
        leasebackPayments: TimeSeries<Double>,
        discountRate: Double,
        startDate: Date
    ) {
        self.salePrice = salePrice
        self.bookValue = carryingValue
        self.leaseTerm = leasebackPayments.periods.count
        self.annualLeasePayment = leasebackPayments.valuesArray.first ?? 0.0
        self.discountRate = discountRate
    }

    /// Gain on sale
    public var gainOnSale: Double {
        return salePrice - bookValue
    }

    /// Present value of lease obligations
    public var leaseObligationPV: Double {
        return leasePaymentsPV(
            periodicPayment: annualLeasePayment,
            periods: leaseTerm,
            discountRate: discountRate
        )
    }

    /// Net cash benefit
    public var netCashBenefit: Double {
        return salePrice - leaseObligationPV
    }

    /// Is the transaction economically beneficial?
    public var isEconomicallyBeneficial: Bool {
        return netCashBenefit > 0
    }

    /// Calculate immediate gain recognized on sale
    public func immediateGain() -> Double {
        // Under ASC 842, the recognized gain is reduced by the PV of leaseback
        // since the seller retains some benefit through continued use
        return gainOnSale - (gainOnSale * (leaseObligationPV / salePrice))
    }

    /// Alias for immediateGain() for compatibility
    public func recognizedGain() -> Double {
        return immediateGain()
    }

    /// Calculate deferred gain (if any) to be amortized over lease term
    public func deferredGain() -> Double {
        // If leaseback is a finance lease or sale is not at fair value,
        // part of gain may be deferred
        // Simplified: return 0 for now (full gain immediate)
        return 0.0
    }
}

/// Calculate incremental borrowing rate for a lessee
public func calculateIncrementalBorrowingRate(
    riskFreeRate: Double,
    creditSpread: Double,
    assetRiskPremium: Double = 0.0
) -> Double {
    return riskFreeRate + creditSpread + assetRiskPremium
}

/// Determine if a lease should be classified as finance or operating (ASC 842)
public func classifyLease(
    leaseTerm: Int,
    assetUsefulLife: Int,
    presentValue: Double,
    assetFairValue: Double,
    ownershipTransfer: Bool,
    purchaseOption: Bool
) -> LeaseClassification {
    // Test 1: Ownership transfers at end
    if ownershipTransfer {
        return .finance
    }

    // Test 2: Purchase option reasonably certain to be exercised
    if purchaseOption {
        return .finance
    }

    // Test 3: Lease term is major part of asset's useful life (≥75%)
    let termRatio = Double(leaseTerm) / Double(assetUsefulLife)
    if termRatio >= 0.75 {
        return .finance
    }

    // Test 4: PV of lease payments ≥ substantially all of asset's fair value (≥90%)
    let pvRatio = presentValue / assetFairValue
    if pvRatio >= 0.90 {
        return .finance
    }

    // Test 5: Asset is specialized with no alternative use
    // (Would need additional parameter; assuming not applicable)

    return .operating
}

public enum LeaseClassification {
    case finance
    case operating
}
