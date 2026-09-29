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
/// let periods = Period.documentationQuarters
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
/// let schedule = try mortgage.schedule()
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
    /// - Throws: ``BusinessMathError/mismatchedDimensions(message:expected:actual:)`` when
    ///   ``AmortizationType/custom(schedule:)`` carries a payment array whose length is not the
    ///   number of periods between `startDate` and `maturityDate` at `paymentFrequency`. The
    ///   other three amortization types cannot throw.
    ///
    /// ## Why this throws, and why only for `.custom`
    ///
    /// The period count is **derived** from the two dates and the frequency; the payment array
    /// is **supplied**. When they disagree there is no rule that makes one of them right, and
    /// the two failures were not symmetric:
    ///
    /// - A **shorter** array indexed past its end. That is a trap in a public method reachable
    ///   from public input — the caller is told nothing at all, because the process stops.
    /// - A **longer** array had its tail silently discarded, so payments the caller specified
    ///   never appeared in `payment`, `totalPayments` was short by exactly those amounts, and
    ///   the ending balance was correspondingly overstated. Nothing in the returned schedule
    ///   said so.
    ///
    /// Neither could be answered by narrowing the schedule to the shorter of the two: that
    /// fixes the trap and keeps the tail-drop, which is contract §4's "silently dropping a
    /// value". Nor could the array be padded or truncated to fit — §4 again, since a fabricated
    /// zero payment is a real instruction to pay nothing that period, and interest accrues on
    /// it.
    ///
    /// The derived count is worth checking before you construct the instrument, because the
    /// term is measured in whole payment periods: five annual payments need a `maturityDate`
    /// five years after `startDate`, and a date a few days short of that yields four.
    ///
    /// This is a source-breaking change taken deliberately while the package is on a
    /// pre-release line, where SPM's `from:` ranges exclude pre-releases and only a caller
    /// naming an alpha exactly is affected. After `3.0.0` the trap would have been permanent.
    public func schedule() throws -> AmortizationSchedule {
        let periods = generatePeriods()
        let periodicRate = interestRate / Double(paymentFrequency.periodsPerYear) // fp-safety:disable — periodsPerYear is a closed enum returning 12, 4, 2 or 1
        let numPayments = periods.count

        // Screened here rather than at the `customPayments[index]` read, following the sweep's
        // rule that the check belongs at the entry point: by the time the loop is running the
        // running balance has already been advanced by payments from a schedule that was never
        // valid, and a half-built `AmortizationSchedule` is harder to reason about than none.
        if case .custom(let customPayments) = amortizationType,
           customPayments.count != numPayments {
            throw BusinessMathError.mismatchedDimensions(
                message: """
                A custom amortization schedule must carry exactly one payment per period. This \
                instrument covers \(numPayments) \(paymentFrequency) period(s) between its start \
                and maturity dates; the schedule supplied \(customPayments.count). A short \
                schedule used to trap on the missing period and a long one had its tail dropped \
                without notice.
                """,
                expected: "\(numPayments)",
                actual: "\(customPayments.count)"
            )
        }

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
            guard numPayments > 0 else { break }
            let principalPerPayment = principal / Double(numPayments) // fp-safety:disable — guarded above: numPayments > 0

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
                // Safe: the guard at the top of this function refused any `.custom` schedule
                // whose count differs from `periods.count`, and `index` runs over `periods`.
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
        return pow(1.0 + interestRate / n, n) - 1.0 // fp-safety:disable — n is periodsPerYear: 12, 4, 2 or 1
    }

    // MARK: - Private Helpers

    private func generatePeriods() -> [Period] {
        var periods: [Period] = []
        let calendar = gregorianUTC
        var currentDate = startDate

        // Calculate expected number of periods based on date range
        let timeInterval = maturityDate.timeIntervalSince(startDate)
        let periodsPerYear = Double(paymentFrequency.periodsPerYear)
        // Convention: 365.25, sizing a loop rather than pricing anything. The result is
        // rounded to a whole number of payment periods, so the choice between 365 and
        // 365.25 can only matter within half a period of the boundary — and the `while`
        // condition below tests `currentDate < maturityDate` independently, so a schedule
        // is never extended past maturity by this estimate being generous.
        let expectedPeriods = Int(round((timeInterval / (365.25 * 24 * 3600)) * periodsPerYear))

        while currentDate < maturityDate && periods.count < expectedPeriods {
            // Create a period based on payment frequency
            let period: Period?
            let nextDate: Date?
            switch paymentFrequency {
            case .monthly:
                let components = calendar.dateComponents([.year, .month], from: currentDate)
                if let year = components.year, let month = components.month {
                    period = Period.month(year: year, month: month)
                } else {
                    period = nil
                }
                nextDate = calendar.date(byAdding: .month, value: 1, to: currentDate)
            case .quarterly:
                let components = calendar.dateComponents([.year, .month], from: currentDate)
                if let year = components.year, let month = components.month {
                    let quarter = ((month - 1) / 3) + 1
                    period = Period.quarter(year: year, quarter: quarter)
                } else {
                    period = nil
                }
                nextDate = calendar.date(byAdding: .month, value: 3, to: currentDate)
            case .semiAnnual:
                // Use monthly periods for semi-annual, treated as 6-month intervals
                let components = calendar.dateComponents([.year, .month], from: currentDate)
                if let year = components.year, let month = components.month {
                    period = Period.month(year: year, month: month)
                } else {
                    period = nil
                }
                nextDate = calendar.date(byAdding: .month, value: 6, to: currentDate)
            case .annual:
                let components = calendar.dateComponents([.year], from: currentDate)
                if let year = components.year {
                    period = Period.year(year)
                } else {
                    period = nil
                }
                nextDate = calendar.date(byAdding: .year, value: 1, to: currentDate)
            }

            // Only add valid periods and continue if we can advance the date
            guard let validPeriod = period, let validNextDate = nextDate else { break }
            periods.append(validPeriod)
            currentDate = validNextDate
        }

        return periods
    }

    private func calculateLevelPayment(principal: Double, rate: Double, periods: Int) -> Double {
        if rate == 0 {
            // Zero interest - just divide principal evenly
            guard periods > 0 else { return 0.0 }
            return principal / Double(periods) // fp-safety:disable — guarded above: periods > 0
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
/// let start = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 1)) ?? Date()
/// let maturity = Calendar.current.date(from: DateComponents(year: 2030, month: 1, day: 1)) ?? Date()
///
/// let debtInstrument = DebtInstrument(
///     principal: 1_000_000.0,
///     interestRate: 0.06,
///     startDate: start,
///     maturityDate: maturity,
///     paymentFrequency: .quarterly,
///     amortizationType: .straightLine
/// )
///
/// let schedule = try debtInstrument.schedule()
///
/// for period in schedule.periods {
///     print("Period: \(period)")
///     print("  Payment: $\((schedule.payment[period] ?? 0))")
///     print("  Interest: $\((schedule.interest[period] ?? 0))")
///     print("  Principal: $\((schedule.principal[period] ?? 0))")
///     print("  Balance: $\((schedule.endingBalance[period] ?? 0))")
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

    // The `?? 0.0` in the three totals below is unreachable, and it is worth saying why
    // rather than leaving a reader to decide it is the usual "a missing period
    // contributes nothing to a total then reported as the whole" defect.
    //
    // `AmortizationSchedule` has no explicit initializer, so its memberwise one is
    // `internal` however public the stored properties are, and the only call to it in
    // the package is `DebtInstrument.schedule()`. That function writes every one of the
    // five dictionaries for every element of `periods`, in all four branches of
    // `AmortizationType`; `generatePeriods()` advances the cursor by a whole period each
    // iteration, so `periods` carries no duplicate key either. No caller can hand this
    // type a `periods` array its dictionaries do not cover.
    //
    // A `??` here therefore reports nothing and hides nothing. If the type ever gains a
    // public memberwise or decoded initializer, that stops being true and these three
    // become the defect they currently only resemble — validate the schedule there, not
    // here, so the caller is told which period is missing instead of being handed a
    // total that is quietly short.

    /// Total interest paid over the life of the loan.
    ///
    /// Sums `interest` over every period in the schedule. The schedule's dictionaries
    /// are populated over exactly `periods` by construction, so this is the whole figure.
    public var totalInterest: Double {
        periods.reduce(0.0) { sum, period in
            sum + (interest[period] ?? 0.0)
        }
    }

    /// Total principal paid over the life of the loan.
    ///
    /// Sums `principal` over every period in the schedule; see ``totalInterest``.
    public var totalPrincipal: Double {
        periods.reduce(0.0) { sum, period in
            sum + (principal[period] ?? 0.0)
        }
    }

    /// Total of all payments over the life of the loan.
    ///
    /// Sums `payment` over every period in the schedule; see ``totalInterest``.
    public var totalPayments: Double {
        periods.reduce(0.0) { sum, period in
            sum + (payment[period] ?? 0.0)
        }
    }
}
