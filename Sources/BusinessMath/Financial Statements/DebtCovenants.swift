import Foundation
import Numerics
#if canImport(OSLog)
import OSLog
#endif

/// Represents a financial covenant attached to debt agreements.
///
/// Covenants are restrictions placed on borrowers to protect lenders.
/// Violations can trigger default, higher interest rates, or mandatory repayment.
///
/// ## Covenant Types
/// - **Maintenance Covenants**: Must be satisfied continuously (e.g., maintain current ratio > 1.5)
/// - **Incurrence Covenants**: Triggered by specific actions (e.g., can't issue more debt if debt/equity > 2.0)
///
/// ## Common Financial Covenants
/// - **Current Ratio**: Current Assets / Current Liabilities (typical minimum: 1.2-1.5)
/// - **Debt-to-Equity**: Total Debt / Total Equity (typical maximum: 2.0-3.0)
/// - **Interest Coverage**: EBIT / Interest Expense (typical minimum: 2.5-3.0)
/// - **Debt Service Coverage (DSCR)**: EBITDA / (Interest + Principal) (typical minimum: 1.25-1.50)
/// - **Debt-to-EBITDA**: Total Debt / EBITDA (typical maximum: 3.0-4.0)
///
/// ## Example
/// ```swift
/// let balance = try BalanceSheet<Double>.documentationFixture
/// let income = try IncomeStatement<Double>.documentationFixture
/// let balanceSheet = try BalanceSheet<Double>.documentationFixture
/// let incomeStatement = try IncomeStatement<Double>.documentationFixture
/// let covenant = FinancialCovenant(
///     name: "Minimum Current Ratio",
///     requirement: .minimumRatio(metric: .currentRatio, threshold: 1.5),
///     curePeriodDays: 30
/// )
///
/// let results = covenant.isCompliant(
///     incomeStatement: income,
///     balanceSheet: balance,
///     period: Period.quarter(year: 2024, quarter: 1)
/// )
/// ```
///
/// ## See Also
/// - ``CovenantMonitor``
/// - ``headroom(incomeStatement:balanceSheet:period:)``
@available(macOS 11.0, *)
public struct FinancialCovenant {
//	let logger = Logger(subsystem: "\(#file)", category: "\(#function)")
    /// Types of financial covenant requirements.
    ///
    /// `principalPayment` is read only by ``FinancialMetric/debtServiceCoverage``, whose
    /// denominator is interest **plus** scheduled principal. It defaults to `nil`, and
    /// `nil` is taken as *no scheduled amortisation in this period* — true of a bullet
    /// or interest-only facility, and the reason the default exists. A `Double?` cannot
    /// distinguish that from an author who simply did not supply the figure, and the two
    /// are not symmetric: leaving principal out shrinks the denominator, so the reported
    /// coverage is higher than the real one and a `minimumRatio` DSCR covenant reads as
    /// **complied with** when it may be breached. Supply it whenever the facility
    /// amortises.
    ///
    /// `minimumValue` and `maximumValue` carry no `principalPayment` at all and pass
    /// `nil`, so a DSCR expressed as a value covenant is always interest-only coverage.
    public enum Requirement {
        case minimumRatio(metric: FinancialMetric, threshold: Double, principalPayment: Double? = nil)
        case maximumRatio(metric: FinancialMetric, threshold: Double, principalPayment: Double? = nil)
        case minimumValue(metric: FinancialMetric, threshold: Double)
        case maximumValue(metric: FinancialMetric, threshold: Double)
        case custom((IncomeStatement<Double>, BalanceSheet<Double>, Period) -> Bool)
    }

    /// Financial metrics that can be used in covenants
    public enum FinancialMetric: ExpressibleByStringLiteral {
        case currentRatio
        case debtToEquity
        case interestCoverage
        case debtToEBITDA
        case debtServiceCoverage
        case quickRatio
        case tangibleNetWorth
        case custom(String)

        /// Initialize a metric from a string literal.
        ///
        /// Automatically maps common string representations to standard metrics,
        /// allowing covenants to be specified with natural language strings.
        ///
        /// ## Supported Strings
        /// - "Current Ratio" → `currentRatio`
        /// - "Debt to Equity", "Debt/Equity" → `debtToEquity`
        /// - "Interest Coverage" → `interestCoverage`
        /// - "Debt to EBITDA", "Debt/EBITDA" → `debtToEBITDA`
        /// - "Debt Service Coverage", "DSCR" → `debtServiceCoverage`
        /// - "Quick Ratio" → `quickRatio`
        /// - "Tangible Net Worth", "Net Worth" → `tangibleNetWorth`
        /// - "EBITDA" → custom("EBITDA")
        /// - Other strings → custom(value)
        ///
        /// ## Example
        /// ```swift
        /// let metric: FinancialCovenant.FinancialMetric = "Current Ratio"  // Maps to .currentRatio
        /// let custom: FinancialCovenant.FinancialMetric = "Custom Metric"  // Maps to .custom("Custom Metric")
        /// ```
        ///
        /// - Parameter value: String representation of the metric
        public init(stringLiteral value: String) {
            // Map common string names to standard metrics
            switch value.lowercased() {
            case "currentratio", "current ratio":
                self = .currentRatio
            case "debttoequity", "debt to equity", "debt/equity":
                self = .debtToEquity
            case "interestcoverage", "interest coverage":
                self = .interestCoverage
            case "debttoebitda", "debt to ebitda", "debt/ebitda":
                self = .debtToEBITDA
            case "debtservicecoverage", "debt service coverage", "dscr":
                self = .debtServiceCoverage
            case "quickratio", "quick ratio":
                self = .quickRatio
            case "tangiblenetworth", "tangible net worth", "networth", "net worth":
                self = .tangibleNetWorth
            case "ebitda", "minimum ebitda":
                // EBITDA is measured as a value, map to custom that will use operating income
                self = .custom("EBITDA")
            default:
                self = .custom(value)
            }
        }
    }

    /// The name or description of this covenant (e.g., "Minimum Current Ratio").
    public let name: String

    /// The specific requirement this covenant enforces.
    ///
    /// ## See Also
    /// - ``Requirement``
    public let requirement: Requirement

    /// Number of days borrower has to cure (fix) a covenant violation.
    ///
    /// During the cure period, the violation doesn't trigger default.
    /// Common cure periods: 30, 60, or 90 days.
    public let curePeriodDays: Int

    /// Create a financial covenant with a name, requirement, and optional cure period.
    ///
    /// - Parameters:
    ///   - name: Descriptive name for the covenant
    ///   - requirement: The covenant requirement (minimum/maximum ratio or value)
    ///   - curePeriodDays: Days allowed to cure violations (default: 0 = immediate default)
    ///
    /// ## Example
    /// ```swift
    /// let covenant = FinancialCovenant(
    ///     name: "Minimum Current Ratio",
    ///     requirement: .minimumRatio(metric: .currentRatio, threshold: 1.5),
    ///     curePeriodDays: 30
    /// )
    /// ```
    public init(name: String, requirement: Requirement, curePeriodDays: Int = 0) {
        self.name = name
        self.requirement = requirement
        self.curePeriodDays = curePeriodDays
    }

    /// Check if this covenant is compliant for a given period
    public func isCompliant<T: Real & BinaryFloatingPoint & Sendable>(
        incomeStatement: IncomeStatement<T>,
        balanceSheet: BalanceSheet<T>,
        period: Period
    ) -> [CovenantComplianceResult] where T: Codable {
        let monitor = CovenantMonitor(covenants: [self])
        return monitor.checkCompliance(
            incomeStatement: incomeStatement,
            balanceSheet: balanceSheet,
            period: period
        )
    }

    /// Calculate headroom (cushion) before violating the covenant
    ///
    /// Returns a positive number indicating how much the metric can deteriorate before
    /// violating the covenant. Negative headroom indicates the covenant is already violated.
    public func headroom<T: Real & BinaryFloatingPoint & Sendable>(
        incomeStatement: IncomeStatement<T>,
        balanceSheet: BalanceSheet<T>,
        period: Period
    ) -> Double where T: Codable {
        let results = isCompliant(
            incomeStatement: incomeStatement,
            balanceSheet: balanceSheet,
            period: period
        )

        guard let result = results.first else { return 0.0 }

        switch requirement {
        case .minimumRatio, .minimumValue:
            // Headroom = actual - threshold (positive is good)
            return result.actualValue - result.requiredValue

        case .maximumRatio, .maximumValue:
            // Headroom = threshold - actual (positive is good)
            return result.requiredValue - result.actualValue

        case .custom:
            // For custom covenants, headroom is binary (1.0 if compliant, -1.0 if not)
            return result.isCompliant ? 1.0 : -1.0
        }
    }

    /// Check if we're still within the cure period for a violation
    ///
    /// - Parameters:
    ///   - violationDate: The date when the violation occurred
    ///   - currentDate: The current date
    /// - Returns: True if still within the cure period
    public func isInCurePeriod(violationDate: Date, currentDate: Date) -> Bool {
        let elapsed = currentDate.timeIntervalSince(violationDate)
        let cureSeconds = Double(curePeriodDays) * 86400.0 // days to seconds
        return elapsed <= cureSeconds
    }

    /// Grant a temporary waiver for this covenant
    ///
    /// Creates a new covenant with a waiver that makes it automatically compliant
    /// for the specified period until the expiration date.
    ///
    /// - Parameters:
    ///   - period: The period for which the waiver applies
    ///   - expirationDate: When the waiver expires
    /// - Returns: A new covenant with the waiver applied
    public func grantWaiver(period: Period, expirationDate: Date) -> FinancialCovenant {
        // For now, return a covenant that always passes via a custom requirement
        // A full implementation would track waivers per period
        return FinancialCovenant(
            name: self.name + " (Waived)",
            requirement: .custom { _, _, _ in true },  // Always compliant during waiver
            curePeriodDays: self.curePeriodDays
        )
    }
}

/// Result of checking covenant compliance.
///
/// Contains the covenant being evaluated, whether it's compliant, and the
/// actual vs. required metric values.
///
/// ## Example
/// ```swift
/// let covenant = FinancialCovenant(
///     name: "Minimum Current Ratio",
///     requirement: .minimumRatio(metric: "Current Ratio", threshold: 1.5)
/// )
///
/// let result = CovenantComplianceResult(
///     covenant: covenant,
///     isCompliant: true,
///     actualValue: 2.1,    // Current ratio of 2.1
///     requiredValue: 1.5   // Required minimum of 1.5
/// )
/// print("Headroom: \(result.actualValue - result.requiredValue)")  // 0.6
/// ```
@available(macOS 11.0, *)
public struct CovenantComplianceResult {
//	let logger = Logger(subsystem: "\(#file)", category: "\(#function)")

    /// The covenant that was evaluated.
    public let covenant: FinancialCovenant

    /// Whether the covenant requirement is **affirmatively satisfied**.
    ///
    /// `false` covers two situations that a lender treats very differently — a measured breach
    /// and a test that could not be run. Read ``status`` to tell them apart; this property is
    /// deliberately conservative, so nothing is certified from data that is not there.
    public let isCompliant: Bool

    /// Whether the covenant passed, failed, or could not be tested.
    ///
    /// ## Why a `Bool` was not enough
    ///
    /// `calculateMetric` answers `.nan` for a period the supplied statements do not cover
    /// (contract §3.7 — *narrow the domain, do not fabricate the observation*). `nan >= x` and
    /// `nan <= x` are both false, so ``isCompliant`` is `false` whichever way the covenant's
    /// threshold points, which is the right *default* — a missing quarter can no longer clear a
    /// ceiling the way `0.0` used to. But it says the wrong thing: it reads as **"we tested this
    /// and you failed"** when the truth is **"we could not test this"**.
    ///
    /// That distinction is the difference between a default notice and a data request, and it
    /// is not recoverable from the `Bool`. It is recoverable from ``actualValue``, which is
    /// `.nan` in exactly that case, so this property is derived rather than stored separately
    /// and cannot drift out of step with the number beside it.
    ///
    /// Added rather than replacing ``isCompliant``: every existing caller keeps compiling and
    /// keeps its conservative verdict, and `[CovenantComplianceResult].violations` still
    /// includes an untestable covenant, because a covenant nobody can test is something a
    /// credit officer must look at rather than something to filter away.
    public var status: CovenantStatus {
        if actualValue.isNaN { return .notAnswerable }
        return isCompliant ? .compliant : .breach
    }

    /// The actual value of the metric (e.g., current ratio = 2.1).
    ///
    /// `.nan` when the metric could not be computed for this period — see ``status``.
    public let actualValue: Double

    /// The required threshold value (e.g., minimum = 1.5).
    public let requiredValue: Double

    /// Create a covenant compliance result.
    /// - Parameters:
    ///   - covenant: The covenant being evaluated
    ///   - isCompliant: Whether the covenant is affirmatively satisfied
    ///   - actualValue: The calculated metric value, or `.nan` if it could not be computed
    ///   - requiredValue: The covenant's threshold value
    public init(covenant: FinancialCovenant, isCompliant: Bool, actualValue: Double, requiredValue: Double) {
        self.covenant = covenant
        self.isCompliant = isCompliant
        self.actualValue = actualValue
        self.requiredValue = requiredValue
    }
}

/// The three outcomes of testing one financial covenant.
///
/// A covenant test has always had three, but ``CovenantComplianceResult/isCompliant`` is a
/// `Bool` and could only carry two. See ``CovenantComplianceResult/status``.
public enum CovenantStatus: String, Sendable, Hashable, CaseIterable {
    /// The metric was computed and satisfies the requirement.
    case compliant

    /// The metric was computed and does not satisfy the requirement.
    case breach

    /// The metric could not be computed, so the covenant was not tested.
    ///
    /// The usual cause is a `period` the supplied income statement and balance sheet do not
    /// cover. This is **not** a breach: no figure was measured, and none is reported.
    case notAnswerable
}

/// Monitors and checks compliance with financial covenants.
///
/// The `CovenantMonitor` evaluates multiple covenants against financial statements
/// for a given period, returning compliance results for each.
///
/// ## Example
/// ```swift
/// let balance = try BalanceSheet<Double>.documentationFixture
/// let income = try IncomeStatement<Double>.documentationFixture
/// let q1 = Period.documentationQuarters[0]
/// let balanceSheet = try BalanceSheet<Double>.documentationFixture
/// let incomeStatement = try IncomeStatement<Double>.documentationFixture
/// let covenants = [
///     FinancialCovenant(name: "Min Current Ratio", requirement: .minimumRatio(metric: .currentRatio, threshold: 1.5)),
///     FinancialCovenant(name: "Max Debt/Equity", requirement: .maximumRatio(metric: .debtToEquity, threshold: 2.0))
/// ]
/// let monitor = CovenantMonitor(covenants: covenants)
/// let results = monitor.checkCompliance(incomeStatement: income, balanceSheet: balance, period: q1)
/// ```
@available(macOS 11.0, *)
public struct CovenantMonitor {
//	let logger = Logger(subsystem: "\(#file)", category: "\(#function)")

    /// The financial covenants to monitor for compliance.
    public let covenants: [FinancialCovenant]

    /// Create a covenant monitor with a list of covenants to check.
    /// - Parameter covenants: Array of financial covenants to monitor
    public init(covenants: [FinancialCovenant]) {
        self.covenants = covenants
    }

    /// Check compliance for all covenants
    public func checkCompliance<T: Real & BinaryFloatingPoint & Sendable>(
        incomeStatement: IncomeStatement<T>,
        balanceSheet: BalanceSheet<T>,
        period: Period
    ) -> [CovenantComplianceResult] where T: Codable {
        return covenants.map { covenant in
            checkCovenant(
                covenant,
                incomeStatement: incomeStatement,
                balanceSheet: balanceSheet,
                period: period
            )
        }
    }

    private func checkCovenant<T: Real & BinaryFloatingPoint & Sendable>(
        _ covenant: FinancialCovenant,
        incomeStatement: IncomeStatement<T>,
        balanceSheet: BalanceSheet<T>,
        period: Period
    ) -> CovenantComplianceResult where T: Codable {
        switch covenant.requirement {
        case .minimumRatio(let metric, let threshold, let principalPayment):
            let actualValue = calculateMetric(
                metric,
                incomeStatement: incomeStatement,
                balanceSheet: balanceSheet,
                period: period,
                principalPayment: principalPayment
            )
//			logger.debug("\(#function) got \(actualValue)")
            return CovenantComplianceResult(
                covenant: covenant,
                isCompliant: actualValue >= threshold,
                actualValue: actualValue,
                requiredValue: threshold
            )

        case .maximumRatio(let metric, let threshold, let principalPayment):
            let actualValue = calculateMetric(
                metric,
                incomeStatement: incomeStatement,
                balanceSheet: balanceSheet,
                period: period,
                principalPayment: principalPayment
            )
//			logger.debug("maximumRatio \(#function) got \(actualValue)")
            return CovenantComplianceResult(
                covenant: covenant,
                isCompliant: actualValue <= threshold,
                actualValue: actualValue,
                requiredValue: threshold
            )

        case .minimumValue(let metric, let threshold):
            let actualValue = calculateMetric(
                metric,
                incomeStatement: incomeStatement,
                balanceSheet: balanceSheet,
                period: period,
                principalPayment: nil
            )
//			logger.debug("\(#function) got \(actualValue)")
            return CovenantComplianceResult(
                covenant: covenant,
                isCompliant: actualValue >= threshold,
                actualValue: actualValue,
                requiredValue: threshold
            )

        case .maximumValue(let metric, let threshold):
            let actualValue = calculateMetric(
                metric,
                incomeStatement: incomeStatement,
                balanceSheet: balanceSheet,
                period: period,
                principalPayment: nil
            )

            return CovenantComplianceResult(
                covenant: covenant,
                isCompliant: actualValue <= threshold,
                actualValue: actualValue,
                requiredValue: threshold
            )

        case .custom(let customCheck):
            // Convert to Double-based financial statements for custom check
            let doubleIncomeStatement = convertToDoubleIncomeStatement(incomeStatement)
            let doubleBalanceSheet = convertToDoubleBalanceSheet(balanceSheet)
            let isCompliant = customCheck(doubleIncomeStatement, doubleBalanceSheet, period)
            return CovenantComplianceResult(
                covenant: covenant,
                isCompliant: isCompliant,
                actualValue: isCompliant ? 1.0 : 0.0,
                requiredValue: 1.0
            )
        }
    }

    private func calculateMetric<T: Real & BinaryFloatingPoint & Sendable>(
        _ metric: FinancialCovenant.FinancialMetric,
        incomeStatement: IncomeStatement<T>,
        balanceSheet: BalanceSheet<T>,
        period: Period,
        principalPayment: Double?
    ) -> Double where T: Codable {
        // A balance sheet ratio series omits any period whose denominator is zero,
        // because the ratio has no value there, and it omits any period its operands do
        // not both cover. Absence therefore means three different things, and `?? 0.0`
        // used to collapse all three: for a zero denominator `0.0` is the wrong answer
        // in the direction that matters — a minimum current-ratio covenant would be
        // breached by a company that owes nothing short-term, and a maximum
        // debt-to-equity covenant would be passed by a company with no equity at all.
        // Unbounded coverage is already written as `Double.infinity` in this file (see
        // `.debtToEBITDA` and `.debtServiceCoverage`), and it gives both covenants the
        // right verdict; an uncovered period is `.nan`, for the reasons set out on the
        // guard below.
        //
        // Every non-ratio metric below reaches its series through `covenantReading`,
        // which answers an uncovered period with `.nan` for the reasons documented on
        // that function. The one reading still fabricated here is an **unrecognised**
        // `.custom` metric name, which returns `0.0` at the bottom of this switch and so
        // breaches a minimum covenant and passes a maximum one. That is a misspelled
        // metric rather than missing data, and it wants a diagnostic rather than a
        // quieter number; it is recorded here rather than changed in passing.
        func ratioMetric(
            _ ratio: TimeSeries<T>,
            _ numerator: TimeSeries<T>,
            over denominator: TimeSeries<T>
        ) -> Double {
            if let value = ratio[period] { return Double(value) }
            // The ratio series omits a period for two unrelated reasons, and the guard
            // below separates them.
            //
            // The only way `BalanceSheet.ratio(_:over:)` drops a period both operands
            // cover is a zero denominator, so a *failed* guard here means at least one
            // operand does not cover this period at all — the statements the caller
            // supplied stop short of it, or start after it. That is not answerable, and
            // `0.0` does not decline to answer it: for a minimum-ratio covenant `0.0`
            // is the breach end of the threshold and for a maximum-ratio covenant it is
            // the compliant end, so the same missing data certifies a default on one
            // covenant and clean compliance on another. `.nan` fails both `>=` and
            // `<=`, so an uncovered period certifies nothing in either direction and
            // `actualValue` shows the caller that no figure was computed.
            //
            // Note the two operands need not share a period domain: an aggregated
            // accessor is `accounts[0].timeSeries + …`, and `+` on a `TimeSeries` is
            // `zip`, so the aggregate spans the *intersection* of its accounts. A
            // balance sheet whose current-asset account is one quarter shorter than its
            // current-liability accounts reaches exactly this branch.
            guard let bottom = denominator[period], let top = numerator[period], bottom == T(0) else {
                return .nan
            }
            // Zero underneath. With nothing on top either, the entity is empty and
            // there is nothing to report; with something on top the figure is unbounded.
            return top == T(0) ? 0.0 : .infinity
        }

        switch metric {
        case .currentRatio:
				let ratio = ratioMetric(
					balanceSheet.currentRatio,
					balanceSheet.currentAssets,
					over: balanceSheet.currentLiabilities
				)
//				logger.debug("got current ratio of \(ratio)")
            return ratio

        case .debtToEquity:
            return ratioMetric(
                balanceSheet.debtToEquity,
                balanceSheet.interestBearingDebt,
                over: balanceSheet.totalEquity
            )

        case .interestCoverage:
            return calculateInterestCoverage(
                incomeStatement: incomeStatement,
                balanceSheet: balanceSheet,
                period: period
            )

        case .debtToEBITDA:
            let totalDebt = covenantReading(balanceSheet.totalLiabilities[period])
            let ebitda = covenantReading(incomeStatement.operatingIncome[period])
//				logger.debug("\(#function) got (\(totalDebt)/\(ebitda))=\(totalDebt/ebitda)")
            // Screen the unanswerable reading before the zero-EBITDA exit, because
            // `abs(nan) > 0.001` is false and would have taken it: a period the
            // statements do not cover would have been reported as `.infinity`, which a
            // maximum debt/EBITDA covenant reads as a breach and a minimum one as
            // boundless coverage. Zero EBITDA is a measurement and keeps its `.infinity`.
            guard !totalDebt.isNaN, !ebitda.isNaN else { return .nan }
            guard abs(ebitda) > 0.001 else { return Double.infinity }
            return totalDebt / ebitda

        case .debtServiceCoverage:
            // DSCR = EBITDA / (Interest + Principal Payment)
            let ebitda = covenantReading(incomeStatement.operatingIncome[period])

            // Find interest expense from income statement
            let interestAccounts = incomeStatement.expenseAccounts.filter { account in
                let hasInterestCategory = account.metadata?.category?.lowercased().contains("interest") == true
                let hasInterestName = account.name.lowercased().contains("interest")
                return hasInterestCategory || hasInterestName
            }

            let interestExpense: Double = interestAccounts.reduce(0.0) { sum, account in
                let value = covenantReading(account.timeSeries[period])
                return sum + value
            }

            // Omitted means no scheduled amortisation, which is a real term sheet
            // (bullet, interest-only) and not a gap to refuse. See `Requirement` for
            // why the conflation with "not supplied" is documented rather than closed:
            // `Double?` cannot carry the difference and widening it is source-breaking.
            let principal = principalPayment ?? 0.0
            let debtService = interestExpense + principal

            // As above: an unanswerable EBITDA or interest expense must not fall
            // through the zero-debt-service exit and be reported as infinite coverage,
            // which is the passing end of a minimum DSCR covenant.
            guard !ebitda.isNaN, !debtService.isNaN else { return .nan }
            guard abs(debtService) > 0.001 else { return Double.infinity }
            return ebitda / debtService

        case .quickRatio:
            // Simplified: Quick Ratio ≈ Current Ratio for now
            // (Would need inventory account identification for accurate calculation)
            return ratioMetric(
                balanceSheet.currentRatio,
                balanceSheet.currentAssets,
                over: balanceSheet.currentLiabilities
            )

        case .tangibleNetWorth:
            // Simplified: Tangible Net Worth ≈ Total Equity for now
            // (Would need intangible asset identification for accurate calculation)
            return covenantReading(balanceSheet.totalEquity[period])

        case .custom(let metricName):
            // Handle custom string-based metrics
            switch metricName.lowercased() {
            case "ebitda", "minimum ebitda":
                return covenantReading(incomeStatement.operatingIncome[period])
            case "networth", "net worth":
                return covenantReading(balanceSheet.totalEquity[period])
            default:
                // Unknown custom metric, return 0
                return 0.0
            }
        }
    }

    // Helper methods to convert generic financial statements to Double-based ones
    private func convertToDoubleIncomeStatement<T: Real & BinaryFloatingPoint & Sendable>(_ incomeStatement: IncomeStatement<T>) -> IncomeStatement<Double> where T: Codable {
        // Safe cast: if T is already Double, return directly; otherwise this custom check requires Double
        if let doubleStatement = incomeStatement as? IncomeStatement<Double> {
            return doubleStatement
        }
        // For non-Double types, custom covenants may not work correctly
        preconditionFailure("Custom covenants require IncomeStatement<Double>. Use Double-typed financial statements for custom covenant checks.")
    }

    private func convertToDoubleBalanceSheet<T: Real & BinaryFloatingPoint & Sendable>(_ balanceSheet: BalanceSheet<T>) -> BalanceSheet<Double> where T: Codable {
        // Safe cast: if T is already Double, return directly
        if let doubleSheet = balanceSheet as? BalanceSheet<Double> {
            return doubleSheet
        }
        // For non-Double types, custom covenants may not work correctly
        preconditionFailure("Custom covenants require BalanceSheet<Double>. Use Double-typed financial statements for custom covenant checks.")
    }
}

/// Reads one period out of a statement series for a covenant test.
///
/// Returns `.nan` when the series does not cover `period`. It used to return `0.0`,
/// which is not a reading of an absent period but an assertion about it, and the
/// assertion is wrong in **both** directions at once — the same missing quarter cleared
/// one covenant and tripped another in the same report:
///
/// | fabricated as `0` | covenant | verdict |
/// |---|---|---|
/// | `totalLiabilities`, `operatingIncome` | maximum debt/EBITDA | leverage of `0` → **passes** |
/// | `totalEquity` | minimum tangible net worth | net worth of `0` → **breaches** |
/// | one interest account of several | minimum interest coverage | expense understated → **passes** |
///
/// So neither "it fails safe" nor "it fails loud" was available as a defence. This is
/// the contaminated-input contract's §3.7 — *narrow the domain; do not fabricate the
/// observation* — wearing a helper: the `??` sat one level below every call site, which
/// is why a grep for `?? 0` across this file found nothing.
///
/// The `period` a covenant is tested at is **caller-supplied** and need not be one the
/// statement declares, so these reads are live rather than dead. Inside the statement's
/// own declared periods they cannot return `nil` at all:
/// `FinancialStatementHelpers.validatePeriodConsistency` rejects any account that does
/// not cover every declared period, supersets are permitted, and the `zip` behind
/// `TimeSeries.+` intersects sets that all contain those periods — so every aggregated
/// accessor spans at least `statement.periods`.
///
/// `.nan` rather than a throw: `calculateMetric` returns `Double` into a
/// ``CovenantComplianceResult`` whose `isCompliant` is a `Bool`, and neither has room
/// for "not answerable". Widening them is a deliberate API decision, not a guard to add
/// in passing. What `.nan` buys is that no *plausible* figure is reported —
/// `actualValue` shows the caller that nothing was computed — and that the verdict stops
/// depending on which way the covenant's threshold points: `nan >= x` and `nan <= x` are
/// both false, so a missing period can no longer clear a ceiling. It still reads as
/// non-compliance rather than as silence, which is the conflation left to that API
/// decision.
///
/// - Parameter value: The result of a `series[period]` lookup.
/// - Returns: The value as a `Double`, or `.nan` if the period is not covered.
private func covenantReading<T: BinaryFloatingPoint>(_ value: T?) -> Double {
    guard let val = value else { return .nan }
    return Double(val)
}

/// Calculate interest coverage ratio
public func calculateInterestCoverage<T: Real & BinaryFloatingPoint & Sendable>(
    incomeStatement: IncomeStatement<T>,
    balanceSheet: BalanceSheet<T>,
    period: Period
) -> Double where T: Codable {
    let operatingIncome = covenantReading(incomeStatement.operatingIncome[period])

    // Find interest expense from income statement
    let interestAccounts = incomeStatement.expenseAccounts.filter { account in
        let hasInterestCategory = account.metadata?.category?.lowercased().contains("interest") == true
        let hasInterestName = account.name.lowercased().contains("interest")
        return hasInterestCategory || hasInterestName
    }

    let interestExpense: Double = interestAccounts.reduce(0.0) { sum, account in
        let value = covenantReading(account.timeSeries[period])
        return sum + value
    }

    // An interest account that does not cover `period` poisons the sum, and the sum
    // must not then take the no-interest-expense exit: `abs(nan) > 0.001` is false, so
    // a missing period would have reported `.infinity` — boundless coverage, the
    // passing end of a minimum interest-coverage covenant. A genuinely zero interest
    // expense is a measurement and keeps its `.infinity`.
    guard !operatingIncome.isNaN, !interestExpense.isNaN else { return .nan }
    guard abs(interestExpense) > 0.001 else { return Double.infinity }
    let ratio: Double = operatingIncome / interestExpense // fp-safety:disable — guarded above: abs(interestExpense) > 0.001
    return ratio
}

/// Calculate the Modigliani-Miller value adjustment for leverage
public func modiglianiMillerValue(
    unleveredValue: Double,
    taxRate: Double,
    debt: Double
) -> Double {
    // MM Proposition I with taxes: VL = VU + T × D
    return unleveredValue + taxRate * debt
}

/// Black-Scholes option pricing model (simplified for equity options)
///
/// - Returns: The call price, or `.nan` when `strikePrice` is not positive. The model
///   prices on `log(stockPrice / strikePrice)`, which has no value at a strike of zero
///   and none below it.
public func bs(
    stockPrice: Double,
    strikePrice: Double,
    timeToExpiration: Double,
    riskFreeRate: Double,
    volatility: Double
) -> Double {
    // Simplified Black-Scholes for call option
    // For full implementation, would need normal distribution functions
    //
    // A strike of zero made the log-moneyness `+inf`, and the function answered with the
    // stock price: a finite, plausible figure for an option the model cannot price. A
    // negative strike already came back `nan` by way of `log` of a negative; this says
    // so for both, in one place, before the division rather than as a side effect of it.
    guard strikePrice > 0 else { return .nan }
    let d1 = (log(stockPrice / strikePrice) + (riskFreeRate + 0.5 * volatility * volatility) * timeToExpiration) / (volatility * sqrt(timeToExpiration))
    let d2 = d1 - volatility * sqrt(timeToExpiration)

	return stockPrice * normalCDF(x: d1) - strikePrice * exp(-riskFreeRate * timeToExpiration) * normalCDF(x: d2)
}

// MARK: - Array Extensions for Covenant Compliance

@available(macOS 11.0, *)
extension Array where Element == CovenantComplianceResult {
    /// Returns true if every covenant was tested **and** passed.
    ///
    /// A covenant that could not be tested makes this `false`, deliberately: the alternative is
    /// to certify a clean report from statements that did not cover the period.
    public var allCompliant: Bool {
        return allSatisfy { $0.isCompliant }
    }

    /// Returns every covenant that is not affirmatively compliant — measured breaches **and**
    /// covenants that could not be tested.
    ///
    /// Both belong on the same exception report, which is why this is not narrowed to
    /// ``breaches``: a covenant nobody could test is a thing a credit officer must chase, not a
    /// thing to filter away. Use ``breaches`` and ``untestable`` to separate them.
    public var violations: [CovenantComplianceResult] {
        return filter { !$0.isCompliant }
    }

    /// Returns only the covenants whose metric was computed and **failed** the requirement.
    public var breaches: [CovenantComplianceResult] {
        return filter { $0.status == .breach }
    }

    /// Returns only the covenants whose metric could not be computed, so no test was performed.
    ///
    /// These are a data problem rather than a credit event — most often a `period` the supplied
    /// statements do not cover. Reporting them as breaches was the conflation this exists to
    /// end.
    public var untestable: [CovenantComplianceResult] {
        return filter { $0.status == .notAnswerable }
    }

    /// Returns only the compliant covenants
    public var compliant: [CovenantComplianceResult] {
        return filter { $0.isCompliant }
    }

    /// Generate a text report of covenant compliance status
    public func generateReport() -> String {
        var report = "Covenant Compliance Report\n"
        report += "===========================\n\n"

        // The headline distinguishes the three outcomes because the reader's next action
        // differs: a breach starts a cure period, an untestable covenant starts a request for
        // the missing statements. Reporting the second as "VIOLATIONS DETECTED" sent a lender
        // after a default that had not happened.
        if allCompliant {
            report += "Status: ALL COVENANTS COMPLIANT ✓\n\n"
        } else if breaches.isEmpty {
            report += "Status: NOT TESTED — INSUFFICIENT DATA ⚠️\n\n"
        } else {
            report += "Status: COVENANT VIOLATIONS DETECTED ⚠️\n\n"
        }

        report += "Summary:\n"
        report += "  Total Covenants: \(count)\n"
        report += "  Compliant: \(compliant.count)\n"
        report += "  Breaches: \(breaches.count)\n"
        report += "  Not Testable: \(untestable.count)\n\n"

        if !breaches.isEmpty {
            report += "VIOLATIONS:\n"
            for (index, violation) in breaches.enumerated() {
                report += "  \(index + 1). \(violation.covenant.name)\n"
                report += "     Actual: \(violation.actualValue.number(2))\n"
                report += "     Required: \(violation.requiredValue.number(2))\n"
            }
            report += "\n"
        }

        if !untestable.isEmpty {
            report += "NOT TESTABLE (metric could not be computed for this period):\n"
            for (index, result) in untestable.enumerated() {
                report += "  \(index + 1). \(result.covenant.name)\n"
                report += "     Required: \(result.requiredValue.number(2))\n"
            }
            report += "\n"
        }

        if !compliant.isEmpty {
            report += "COMPLIANT:\n"
            for (index, result) in compliant.enumerated() {
                report += "  \(index + 1). \(result.covenant.name)\n"
                report += "     Actual: \(result.actualValue.number(2))\n"
                report += "     Required: \(result.requiredValue.number(2))\n"
            }
        }

        return report
    }
}
