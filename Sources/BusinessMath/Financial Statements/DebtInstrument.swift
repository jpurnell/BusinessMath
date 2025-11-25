import Foundation

/// Represents a debt instrument (loan, bond, etc.) with payment schedule generation.
///
/// `DebtInstrument` models various types of debt with different amortization structures:
/// - Level payment (constant total payment, like mortgages)
/// - Straight line (equal principal payments, declining interest)
/// - Bullet payment (interest-only with principal at maturity)
/// - Custom payment schedules
///
/// ## Overview
///
/// Use this type to model loans, bonds, and other debt instruments with scheduled payments.
/// The instrument generates a complete amortization schedule showing how principal and interest
/// are allocated over time.
///
/// ## Usage Example
///
/// ```swift
/// // Create a 30-year mortgage
/// let mortgage = DebtInstrument(
///     principal: 250_000.0,
///     interestRate: 0.045,
///     startDate: Date(),
///     maturityDate: Calendar.current.date(byAdding: .year, value: 30, to: Date())!,
///     paymentFrequency: .monthly,
///     amortizationType: .levelPayment
/// )
///
/// let schedule = mortgage.schedule()
/// print("Monthly payment: $\(schedule.payment[schedule.periods.first!]!)")
/// print("Total interest: $\(schedule.totalInterest)")
/// ```
///
/// ## Related Topics
///
/// - ``AmortizationSchedule``
/// - ``AmortizationType``
/// - ``PaymentFrequency``
public struct DebtInstrument {
    /// The original loan amount or principal balance
    public let principal: Double

    /// Annual interest rate as a decimal (e.g., 0.06 for 6%)
    public let interestRate: Double

    /// The date the loan begins
    public let startDate: Date

    /// The date the loan must be fully paid off
    public let maturityDate: Date

    /// How often payments are made
    public let paymentFrequency: PaymentFrequency

    /// The method used to calculate payments and amortization
    public let amortizationType: AmortizationType

    /// Creates a new debt instrument.
    ///
    /// - Parameters:
    ///   - principal: The original loan amount
    ///   - interestRate: Annual interest rate as a decimal (e.g., 0.06 for 6%)
    ///   - startDate: The date the loan begins
    ///   - maturityDate: The date the loan must be fully paid off
    ///   - paymentFrequency: How often payments are made
    ///   - amortizationType: The method used to calculate payments
    public init(
        principal: Double,
        interestRate: Double,
        startDate: Date,
        maturityDate: Date,
        paymentFrequency: PaymentFrequency,
        amortizationType: AmortizationType
    ) {
        self.principal = principal
        self.interestRate = interestRate
        self.startDate = startDate
        self.maturityDate = maturityDate
        self.paymentFrequency = paymentFrequency
        self.amortizationType = amortizationType
    }

    /// Generates the complete amortization schedule for this debt instrument.
    ///
    /// Returns an ``AmortizationSchedule`` containing period-by-period details of:
    /// - Beginning and ending balance
    /// - Interest charged
    /// - Principal paid
    /// - Total payment
    ///
    /// - Returns: Complete amortization schedule
    public func schedule() -> AmortizationSchedule {
        let periods = generatePeriods()
        let periodicRate = interestRate / Double(paymentFrequency.periodsPerYear)
        let numPayments = periods.count

        // Pre-allocate dictionary capacity for better performance
        var beginningBalance: [Period: Double] = [:]
        beginningBalance.reserveCapacity(numPayments)
        var endingBalance: [Period: Double] = [:]
        endingBalance.reserveCapacity(numPayments)
        var interest: [Period: Double] = [:]
        interest.reserveCapacity(numPayments)
        var principalPayment: [Period: Double] = [:]
        principalPayment.reserveCapacity(numPayments)
        var payment: [Period: Double] = [:]
        payment.reserveCapacity(numPayments)

        var currentBalance = principal

        switch amortizationType {
        case .levelPayment:
            // Calculate constant payment using amortization formula
            let levelPaymentAmount = calculateLevelPayment(
                principal: principal,
                rate: periodicRate,
                periods: numPayments
            )

            for period in periods {
                beginningBalance[period] = currentBalance

                let interestCharge = currentBalance * periodicRate
                let principalPaid = levelPaymentAmount - interestCharge

                interest[period] = interestCharge
                principalPayment[period] = principalPaid
                payment[period] = levelPaymentAmount

                currentBalance -= principalPaid
                endingBalance[period] = currentBalance
            }

        case .straightLine:
            // Equal principal payments, declining interest
            let principalPerPayment = principal / Double(numPayments)

            for period in periods {
                beginningBalance[period] = currentBalance

                let interestCharge = currentBalance * periodicRate

                interest[period] = interestCharge
                principalPayment[period] = principalPerPayment
                payment[period] = principalPerPayment + interestCharge

                currentBalance -= principalPerPayment
                endingBalance[period] = currentBalance
            }

        case .bulletPayment:
            // Interest-only payments with principal at maturity
            let interestCharge = principal * periodicRate  // Constant for bullet payments
            let lastIndex = periods.count - 1

            for (index, period) in periods.enumerated() {
                beginningBalance[period] = principal  // Always full principal until last payment

                let isLastPayment = (index == lastIndex)

                interest[period] = interestCharge
                principalPayment[period] = isLastPayment ? principal : 0.0
                payment[period] = interestCharge + (isLastPayment ? principal : 0.0)

                endingBalance[period] = isLastPayment ? 0.0 : principal
            }

        case .custom(let customPayments):
            // Use custom payment schedule
            for (index, period) in periods.enumerated() {
                beginningBalance[period] = currentBalance

                let interestCharge = currentBalance * periodicRate
                let totalPayment = customPayments[index]
                let principalPaid = totalPayment - interestCharge

                interest[period] = interestCharge
                principalPayment[period] = principalPaid
                payment[period] = totalPayment

                currentBalance -= principalPaid
                endingBalance[period] = currentBalance
            }
        }

        return AmortizationSchedule(
            periods: periods,
            beginningBalance: beginningBalance,
            endingBalance: endingBalance,
            interest: interest,
            principal: principalPayment,
            payment: payment
        )
    }

    /// Calculates the effective annual rate (EAR) for this debt instrument.
    ///
    /// The effective annual rate accounts for compounding within the year.
    /// For example, 12% compounded monthly has an EAR of approximately 12.68%.
    ///
    /// Formula: EAR = (1 + r/n)^n - 1
    /// where r is the nominal annual rate and n is the compounding frequency
    ///
    /// - Returns: The effective annual interest rate
    public func effectiveAnnualRate() -> Double {
        let n = Double(paymentFrequency.periodsPerYear)
        return pow(1.0 + interestRate / n, n) - 1.0
    }

    // MARK: - Private Helpers

    private func generatePeriods() -> [Period] {
        var periods: [Period] = []
        let calendar = Calendar.current
        var currentDate = startDate

        // Calculate expected number of periods based on date range
        let timeInterval = maturityDate.timeIntervalSince(startDate)
        let periodsPerYear = Double(paymentFrequency.periodsPerYear)
        let expectedPeriods = Int(round((timeInterval / (365.25 * 24 * 3600)) * periodsPerYear))

        while currentDate < maturityDate && periods.count < expectedPeriods {
            // Create a period based on payment frequency
            let period: Period
            switch paymentFrequency {
            case .monthly:
                let components = calendar.dateComponents([.year, .month], from: currentDate)
                period = Period.month(year: components.year!, month: components.month!)
            case .quarterly:
                let components = calendar.dateComponents([.year, .month], from: currentDate)
                let quarter = ((components.month! - 1) / 3) + 1
                period = Period.quarter(year: components.year!, quarter: quarter)
            case .semiAnnual:
                // Use monthly periods for semi-annual, treated as 6-month intervals
                let components = calendar.dateComponents([.year, .month], from: currentDate)
                period = Period.month(year: components.year!, month: components.month!)
            case .annual:
                let components = calendar.dateComponents([.year], from: currentDate)
                period = Period.year(components.year!)
            }

            periods.append(period)

            // Advance to next payment date
            switch paymentFrequency {
            case .monthly:
                currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate)!
            case .quarterly:
                currentDate = calendar.date(byAdding: .month, value: 3, to: currentDate)!
            case .semiAnnual:
                currentDate = calendar.date(byAdding: .month, value: 6, to: currentDate)!
            case .annual:
                currentDate = calendar.date(byAdding: .year, value: 1, to: currentDate)!
            }
        }

        return periods
    }

    private func calculateLevelPayment(principal: Double, rate: Double, periods: Int) -> Double {
        if rate == 0 {
            // Zero interest - just divide principal evenly
            return principal / Double(periods)
        }

        // Standard amortization formula: PMT = P * [r(1+r)^n] / [(1+r)^n - 1]
        let numerator = rate * pow(1.0 + rate, Double(periods))
        let denominator = pow(1.0 + rate, Double(periods)) - 1.0
        return principal * (numerator / denominator)
    }
}

/// Defines how often payments are made on a debt instrument.
public enum PaymentFrequency: Sendable {
    /// Monthly payments (12 per year)
    case monthly

    /// Quarterly payments (4 per year)
    case quarterly

    /// Semi-annual payments (2 per year)
    case semiAnnual

    /// Annual payments (1 per year)
    case annual

    /// Number of payment periods in one year
    public var periodsPerYear: Int {
        switch self {
        case .monthly: return 12
        case .quarterly: return 4
        case .semiAnnual: return 2
        case .annual: return 1
        }
    }

    /// Number of years per payment period
    public var yearsPerPeriod: Double {
        switch self {
        case .monthly: return 1.0 / 12.0
        case .quarterly: return 0.25
        case .semiAnnual: return 0.5
        case .annual: return 1.0
        }
    }
}

/// Defines the method used to amortize (pay down) a debt instrument.
public enum AmortizationType {
    /// Level payment amortization - constant total payment each period.
    /// Principal portion increases over time while interest portion decreases.
    /// Common for mortgages and most consumer loans.
    case levelPayment

    /// Straight line amortization - constant principal payment each period.
    /// Interest decreases over time as balance declines, so total payment decreases.
    case straightLine

    /// Bullet payment - interest-only payments with full principal due at maturity.
    /// Common for bonds and some commercial loans.
    case bulletPayment

    /// Custom payment schedule - user-specified payment amounts for each period.
    /// - Parameter schedule: Array of payment amounts, one per period
    case custom(schedule: [Double])
}

/// Represents a complete amortization schedule for a debt instrument.
///
/// Contains period-by-period breakdowns of:
/// - Beginning and ending principal balance
/// - Interest charged
/// - Principal paid down
/// - Total payment amount
///
/// ## Usage Example
///
/// ```swift
/// let schedule = debtInstrument.schedule()
///
/// for period in schedule.periods {
///     print("Period: \(period)")
///     print("  Payment: $\(schedule.payment[period]!)")
///     print("  Interest: $\(schedule.interest[period]!)")
///     print("  Principal: $\(schedule.principal[period]!)")
///     print("  Balance: $\(schedule.endingBalance[period]!)")
/// }
///
/// print("\nTotal interest paid: $\(schedule.totalInterest)")
/// ```
public struct AmortizationSchedule {
    /// All payment periods in chronological order
    public let periods: [Period]

    /// Principal balance at the start of each period
    public let beginningBalance: [Period: Double]

    /// Principal balance at the end of each period (after payment)
    public let endingBalance: [Period: Double]

    /// Interest charged in each period
    public let interest: [Period: Double]

    /// Principal paid down in each period
    public let principal: [Period: Double]

    /// Total payment (principal + interest) in each period
    public let payment: [Period: Double]

    /// Total interest paid over the life of the loan
    public var totalInterest: Double {
        periods.reduce(0.0) { sum, period in
            sum + (interest[period] ?? 0.0)
        }
    }

    /// Total principal paid over the life of the loan
    public var totalPrincipal: Double {
        periods.reduce(0.0) { sum, period in
            sum + (principal[period] ?? 0.0)
        }
    }

    /// Total of all payments over the life of the loan
    public var totalPayments: Double {
        periods.reduce(0.0) { sum, period in
            sum + (payment[period] ?? 0.0)
        }
    }
}
