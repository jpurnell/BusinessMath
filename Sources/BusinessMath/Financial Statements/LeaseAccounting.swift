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
///
/// ## Accounting Standards
/// - **IFRS 16**: Requires lessees to recognize assets and liabilities for all leases
///   (with limited exemptions for short-term and low-value leases)
/// - **ASC 842** (US GAAP): Similar to IFRS 16 but retains operating vs. finance lease distinction
///
/// ## Usage Example
/// ```swift
/// // 5-year equipment lease with monthly payments
/// let monthlyPayment = 5_000.0
/// let months = 60
/// let payments = Array(repeating: monthlyPayment, count: months)
///
/// let lease = Lease(
///     payments: payments,
///     discountRate: 0.06,  // 6% annual rate
///     residualValue: 10_000.0,
///     initialDirectCosts: 2_000.0
/// )
///
/// let liability = lease.presentValue()
/// let rouAsset = lease.rightOfUseAsset()
/// ```
///
/// ## SeeAlso
/// - ``LeaseTerm``
/// - ``DepreciationMethod``
/// - ``DiscountRateType``
public struct Lease {
    /// Array of fixed lease payments.
    ///
    /// These are the contractually determined minimum payments.
    /// Does not include variable payments (which are tracked separately).
    public let payments: [Double]

    /// Optional time periods corresponding to each payment.
    ///
    /// When provided, enables period-specific calculations and proper
    /// discount rate adjustments based on payment frequency.
    public let periods: [Period]?

    /// Annual discount rate for present value calculations.
    ///
    /// Should be either:
    /// - The rate implicit in the lease (if readily determinable), OR
    /// - The lessee's incremental borrowing rate
    ///
    /// Express as decimal (e.g., 0.06 for 6%).
    public let discountRate: Double

    /// Estimated residual value at lease end.
    ///
    /// For lessee accounting, this is typically zero unless the lessee
    /// guarantees a residual value or has a purchase option it's reasonably
    /// certain to exercise.
    public let residualValue: Double

    /// Lease commencement date.
    ///
    /// The date the lessor makes the underlying asset available for use.
    /// If nil, uses the first period's start date when periods are provided.
    public let startDate: Date?

    /// Initial direct costs incurred by the lessee.
    ///
    /// Costs directly attributable to negotiating and arranging the lease
    /// (e.g., commissions, legal fees). Added to ROU asset value.
    public let initialDirectCosts: Double

    /// Lease payments made at or before commencement.
    ///
    /// Prepaid amounts are added to the ROU asset value.
    public let prepaidAmount: Double

    /// Method used to depreciate the right-of-use asset.
    ///
    /// Defaults to ``DepreciationMethod/straightLine``, which is most common.
    /// The ROU asset is typically depreciated over the shorter of:
    /// - The lease term, OR
    /// - The useful life of the asset (if ownership transfers)
    public let depreciationMethod: DepreciationMethod

    /// Variable lease payments not dependent on an index or rate.
    ///
    /// Variable payments based on usage, performance, or other variable factors
    /// are excluded from lease liability and recognized as expense when incurred.
    ///
    /// Example: Percentage rent in retail leases based on sales.
    public let variablePayments: TimeSeries<Double>?

    /// Specified lease term.
    ///
    /// Used to determine if short-term exemption applies (≤12 months).
    /// If nil, term is inferred from payment count.
    public let leaseTerm: LeaseTerm?

    /// Fair value of the underlying asset.
    ///
    /// Used to determine if low-value exemption applies (typically <$5,000).
    /// For finance lease classification under ASC 842, also compared to lease PV.
    public let underlyingAssetValue: Double?

    /// Type of discount rate used.
    ///
    /// Indicates whether the rate is:
    /// - ``DiscountRateType/implicitRate``: Rate implicit in the lease
    /// - ``DiscountRateType/incrementalBorrowingRate``: Lessee's IBR
    ///
    /// Documentation purposes; doesn't affect calculations.
    public let discountRateType: DiscountRateType

    /// Fair value of the leased asset.
    ///
    /// Used in finance lease tests under ASC 842. A lease is classified
    /// as a finance lease if PV of payments ≥ 90% of fair value.
    public let fairValueOfAsset: Double?

    /// Creates a lease with an array of fixed payments.
    ///
    /// Use this initializer when payments are not tied to specific time periods
    /// or when using a simple array is more convenient.
    ///
    /// - Parameters:
    ///   - payments: Array of fixed lease payments
    ///   - discountRate: Annual discount rate (as decimal, e.g., 0.06 for 6%)
    ///   - residualValue: Residual value at lease end (default: 0.0)
    ///   - startDate: Lease commencement date (optional)
    ///   - initialDirectCosts: Initial direct costs (default: 0.0)
    ///   - prepaidAmount: Prepaid lease payments (default: 0.0)
    ///   - depreciationMethod: How to depreciate ROU asset (default: straight-line)
    ///   - variablePayments: Variable payments time series (optional)
    ///   - leaseTerm: Specified lease term (optional)
    ///   - underlyingAssetValue: Fair value of asset (optional)
    ///   - discountRateType: Type of discount rate (default: IBR)
    ///   - fairValueOfAsset: Fair value for finance lease tests (optional)
    ///
    /// ## Usage Example
    /// ```swift
    /// let monthlyPayments = Array(repeating: 5_000.0, count: 36)
    /// let lease = Lease(
    ///     payments: monthlyPayments,
    ///     discountRate: 0.05,
    ///     residualValue: 5_000.0,
    ///     leaseTerm: .years(3)
    /// )
    /// ```
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

    /// Creates a lease with a time series of payments.
    ///
    /// Use this initializer when payments are tied to specific time periods.
    /// The periods enable more accurate discount rate adjustments based on
    /// payment frequency (monthly, quarterly, etc.).
    ///
    /// - Parameters:
    ///   - payments: Time series of fixed lease payments with associated periods
    ///   - discountRate: Annual discount rate (as decimal)
    ///   - residualValue: Residual value at lease end (default: 0.0)
    ///   - startDate: Lease commencement date (default: uses first period's start date)
    ///   - initialDirectCosts: Initial direct costs (default: 0.0)
    ///   - prepaidAmount: Prepaid lease payments (default: 0.0)
    ///   - depreciationMethod: How to depreciate ROU asset (default: straight-line)
    ///   - variablePayments: Variable payments time series (optional)
    ///   - leaseTerm: Specified lease term (optional)
    ///   - underlyingAssetValue: Fair value of asset (optional)
    ///   - discountRateType: Type of discount rate (default: IBR)
    ///   - fairValueOfAsset: Fair value for finance lease tests (optional)
    ///
    /// ## Usage Example
    /// ```swift
    /// let months = (1...60).map { Period.month(year: 2025, month: $0) }
    /// let paymentSeries = TimeSeries(periods: months, values: Array(repeating: 3_500.0, count: 60))
    ///
    /// let lease = Lease(
    ///     payments: paymentSeries,
    ///     discountRate: 0.07,
    ///     residualValue: 8_000.0,
    ///     initialDirectCosts: 1_500.0
    /// )
    ///
    /// // Get liability schedule with period-specific balances
    /// let schedule = lease.liabilitySchedule()
    /// ```
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
            case .millisecond:
                periodicRate = discountRate / (365.25 * 24 * 60 * 60 * 1000)
            case .second:
                periodicRate = discountRate / (365.25 * 24 * 60 * 60)
            case .minute:
                periodicRate = discountRate / (365.25 * 24 * 60)
            case .hourly:
                periodicRate = discountRate / (365.25 * 24)
            case .daily:
                periodicRate = discountRate / 365.25
            case .monthly:
                periodicRate = discountRate / 12.0
            case .quarterly:
                periodicRate = discountRate / 4.0
            case .annual:
                periodicRate = discountRate
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

    /// Detailed amortization schedule for the lease
    /// Returns balance field as beginning balance (before payment)
    public func detailedSchedule() -> [(period: Period?, payment: Double, interest: Double, principal: Double, balance: Double)] {
        // Determine periodic discount rate
        let periodicRate: Double
        if let periods = periods, let firstPeriod = periods.first {
            switch firstPeriod.type {
            case .millisecond:
                periodicRate = discountRate / (365.25 * 24 * 60 * 60 * 1000)
            case .second:
                periodicRate = discountRate / (365.25 * 24 * 60 * 60)
            case .minute:
                periodicRate = discountRate / (365.25 * 24 * 60)
            case .hourly:
                periodicRate = discountRate / (365.25 * 24)
            case .daily:
                periodicRate = discountRate / 365.25
            case .monthly:
                periodicRate = discountRate / 12.0
            case .quarterly:
                periodicRate = discountRate / 4.0
            case .annual:
                periodicRate = discountRate
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

    /// Calculate total interest expense over the entire lease term.
    ///
    /// Sums interest expense across all periods. Returns 0 if periods are not specified.
    ///
    /// - Returns: Total interest expense for the entire lease.
    ///
    /// ## Usage Example
    /// ```swift
    /// let lease = Lease(payments: paymentSeries, discountRate: 0.06)
    /// let totalInterest = lease.totalInterest()
    /// let totalPayments = lease.totalFuturePayments()
    /// let principalPaid = totalPayments - totalInterest
    /// print("Principal: $\(principalPaid), Interest: $\(totalInterest)")
    /// ```
    ///
    /// ## Note
    /// This represents the financing cost—the difference between total payments
    /// and the present value of the lease liability.
	public func totalInterest() -> Double {
		var interestExpenses: [Double] = []
		guard let periods else { return interestExpenses.reduce(0.0, +) }
		for period in periods {
			interestExpenses.append(self.interestExpense(period: period))
		}
		return interestExpenses.reduce(0.0, +)
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

/// Analysis comparing leasing vs buying an asset.
///
/// Calculates the Net Advantage to Leasing (NAL) by comparing present values
/// of lease payments vs. asset purchase (including maintenance and salvage value).
///
/// ## Decision Rule
/// - **NAL > 0**: Leasing is financially advantageous—lease the asset
/// - **NAL < 0**: Buying is financially advantageous—purchase the asset
/// - **NAL = 0**: Indifferent between leasing and buying
///
/// ## Usage Example
/// ```swift
/// // Calculate lease PV
/// let leasePV = leasePaymentsPV(
///     periodicPayment: 5_000,
///     periods: 60,
///     discountRate: 0.06 / 12
/// )
///
/// // Calculate buy PV
/// let buyPV = buyAssetPV(
///     purchasePrice: 250_000,
///     salvageValue: 50_000,
///     holdingPeriod: 5,
///     discountRate: 0.06,
///     maintenanceCost: 3_000
/// )
///
/// let analysis = LeaseVsBuyAnalysis(leasePV: leasePV, buyPV: buyPV)
/// print(analysis.recommendation)  // "Lease (NAL: $15,000)" or "Buy (NAL: -$10,000)"
/// ```
///
/// ## SeeAlso
/// - ``leasePaymentsPV(periodicPayment:periods:discountRate:)``
/// - ``buyAssetPV(purchasePrice:salvageValue:holdingPeriod:discountRate:maintenanceCost:)``
public struct LeaseVsBuyAnalysis {
    /// Present value of leasing the asset.
    ///
    /// Sum of discounted lease payments over the lease term.
    public let leasePV: Double

    /// Present value of buying the asset.
    ///
    /// Purchase price plus PV of maintenance costs minus PV of salvage value.
    public let buyPV: Double

    /// Creates a lease vs. buy analysis.
    ///
    /// - Parameters:
    ///   - leasePV: Present value of lease payments
    ///   - buyPV: Present value of buying (net of salvage and maintenance)
    ///
    /// ## Usage Example
    /// ```swift
    /// let analysis = LeaseVsBuyAnalysis(leasePV: 275_000, buyPV: 300_000)
    /// print("NAL: $\(analysis.netAdvantageToLeasing)")  // $25,000
    /// print("Should lease: \(analysis.shouldLease)")     // true
    /// ```
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

/// Represents a sale-and-leaseback transaction.
///
/// A sale-leaseback occurs when a company sells an asset and immediately leases
/// it back from the buyer. This provides cash while retaining use of the asset.
///
/// ## Accounting Treatment (ASC 842)
/// - If transfer qualifies as a sale: Recognize gain/loss, record new lease
/// - If not a sale: Treat as financing (no derecognition)
/// - Gain recognition may be limited if leaseback represents significant continuing use
///
/// ## Common Uses
/// - Raise capital while retaining asset use
/// - Improve balance sheet ratios
/// - Take advantage of depreciation/tax benefits
///
/// ## Usage Example
/// ```swift
/// let slb = SaleAndLeaseback(
///     salePrice: 5_000_000,
///     bookValue: 3_500_000,
///     leaseTerm: 10,
///     annualLeasePayment: 500_000,
///     discountRate: 0.06
/// )
///
/// print("Gain on sale: $\(slb.gainOnSale)")
/// print("Lease obligation PV: $\(slb.leaseObligationPV)")
/// print("Net cash benefit: $\(slb.netCashBenefit)")
/// print("Immediate gain: $\(slb.immediateGain())")
/// print("Economically beneficial: \(slb.isEconomicallyBeneficial)")
/// ```
///
/// ## SeeAlso
/// - ``Lease``
/// - ``leasePaymentsPV(periodicPayment:periods:discountRate:)``
public struct SaleAndLeaseback {
    /// Sale price of the asset.
    ///
    /// Amount received from selling the asset to the buyer/lessor.
    public let salePrice: Double

    /// Book value (carrying value) of the asset at sale date.
    ///
    /// Used to calculate gain or loss on sale.
    public let bookValue: Double

    /// Leaseback term in years.
    ///
    /// Number of years the seller will lease back the asset.
    public let leaseTerm: Int

    /// Annual lease payment to be made to the buyer.
    ///
    /// Fixed annual payment for leasing back the asset.
    public let annualLeasePayment: Double

    /// Discount rate for present value calculations.
    ///
    /// Typically the lessee's incremental borrowing rate.
    public let discountRate: Double

    /// Creates a sale-and-leaseback transaction.
    ///
    /// - Parameters:
    ///   - salePrice: Amount received from sale
    ///   - bookValue: Carrying value of asset before sale
    ///   - leaseTerm: Leaseback term in years
    ///   - annualLeasePayment: Annual payment to lease back the asset
    ///   - discountRate: Discount rate for PV calculations
    ///
    /// ## Usage Example
    /// ```swift
    /// // Company sells building for $10M, leases it back for 15 years at $800K/year
    /// let transaction = SaleAndLeaseback(
    ///     salePrice: 10_000_000,
    ///     bookValue: 7_000_000,
    ///     leaseTerm: 15,
    ///     annualLeasePayment: 800_000,
    ///     discountRate: 0.05
    /// )
    ///
    /// if transaction.isEconomicallyBeneficial {
    ///     print("Net benefit: $\(transaction.netCashBenefit)")
    /// }
    /// ```
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

/// Lease classification under ASC 842 (US GAAP).
///
/// ASC 842 requires lessees to classify leases as either finance or operating.
/// This affects how lease expense is recognized:
///
/// ## Finance Lease
/// - Similar to a capital lease under old standards
/// - Treated like an asset purchase with financing
/// - **Expense pattern**: Front-loaded (interest + depreciation)
/// - **Balance sheet**: ROU asset and lease liability
///
/// ## Operating Lease
/// - Similar to old operating leases but now on balance sheet
/// - **Expense pattern**: Straight-line (combined single expense)
/// - **Balance sheet**: ROU asset and lease liability (now required under ASC 842)
///
/// ## Classification Criteria (Any ONE triggers finance lease)
/// 1. Ownership transfers at lease end
/// 2. Purchase option reasonably certain to be exercised
/// 3. Lease term ≥ 75% of asset's economic life
/// 4. PV of payments ≥ 90% of asset's fair value
/// 5. Asset is specialized with no alternative use
///
/// ## Usage Example
/// ```swift
/// let classification = classifyLease(
///     leaseTerm: 8,
///     assetUsefulLife: 10,
///     presentValue: 450_000,
///     assetFairValue: 500_000,
///     ownershipTransfer: false,
///     purchaseOption: false
/// )
///
/// switch classification {
/// case .finance:
///     print("Finance lease: Record interest + depreciation")
/// case .operating:
///     print("Operating lease: Record straight-line expense")
/// }
/// ```
///
/// ## IFRS 16 Note
/// IFRS 16 doesn't use this classification—all leases are treated similarly
/// to finance leases under US GAAP (except short-term and low-value exemptions).
///
/// ## SeeAlso
/// - ``Lease``
/// - ``classifyLease(leaseTerm:assetUsefulLife:presentValue:assetFairValue:ownershipTransfer:purchaseOption:)``
public enum LeaseClassification {
    /// Finance lease classification.
    ///
    /// Lease meets at least one of the five finance lease criteria.
    /// Expense is front-loaded (interest expense + depreciation).
    case finance

    /// Operating lease classification.
    ///
    /// Lease doesn't meet any finance lease criteria.
    /// Expense is recognized on a straight-line basis.
    case operating
}
