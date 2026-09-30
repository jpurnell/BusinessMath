//
//  ModelDebugger.swift
//  BusinessMath
//
//  Created on December 1, 2025.
//

import Foundation

#if canImport(OSLog)
import OSLog
#endif

// MARK: - Global Debug Context

/// Thread-safe global debugging context for capturing calculation steps
// Justification: All mutable state (steps, isEnabled) is protected by an NSLock; no unguarded access.
final class DebugContext: @unchecked Sendable {
    private let lock = NSLock()
    private var steps: [CalculationStep] = []
    private var isEnabled = false

    /// Maximum steps to retain (prevents unbounded memory growth)
    private let maxSteps: Int = 10_000

    static let shared = DebugContext()

    private init() {}

    func enable() {
        lock.lock()
        defer { lock.unlock() }
        isEnabled = true
        steps.removeAll()
    }

    func disable() {
        lock.lock()
        defer { lock.unlock() }
        isEnabled = false
    }

    /// Records one traced step, stamped by `clock`.
    ///
    /// The clock is a parameter rather than stored state because this context is a
    /// process-wide singleton: a stored, settable clock would be global mutable state
    /// shared across every test in the suite, which is a worse problem than the one it
    /// solves. Callers in production omit it and get the system clock.
    ///
    /// - Parameters:
    ///   - operation: The operation being recorded.
    ///   - input: A rendering of the operation's inputs.
    ///   - output: A rendering of the operation's result.
    ///   - clock: Supplies the step's timestamp. Defaults to the system clock.
    func recordStep(
        operation: String,
        input: String,
        output: String,
        clock: any WallClock = SystemWallClock()
    ) {
        let now = clock.now

        lock.lock()
        defer { lock.unlock() }
        guard isEnabled else { return }

        // Enforce maximum steps to prevent unbounded memory growth
        if steps.count >= maxSteps {
            steps.removeFirst()
        }

        steps.append(CalculationStep(
            operation: operation,
            input: input,
            output: output,
            timestamp: now
        ))
    }

    func getSteps() -> [CalculationStep] {
        lock.lock()
        defer { lock.unlock() }
        return steps
    }

    func clearSteps() { // LIVE: public reset for debug tracing sessions
        lock.lock()
        defer { lock.unlock() }
        steps.removeAll()
    }
}

// MARK: - Model Debugger

/// Debugging and diagnostic tools for financial models
///
/// The ModelDebugger provides comprehensive tools for understanding, diagnosing,
/// and validating financial models. It can trace calculations, identify issues,
/// and provide actionable suggestions for fixes.
///
/// ## Features
///
/// - **Calculation Tracing**: Understand how values are computed
/// - **Diagnostics**: Identify issues, warnings, and potential problems
/// - **Validation**: Check model consistency and constraints
/// - **Explanations**: Understand differences between expected and actual values
///
/// ## Example Usage
///
/// ```swift
/// let debugger = ModelDebugger()
///
/// // Trace a calculation
/// let flows = [-100_000.0, 30_000, 40_000, 50_000]
/// let trace = await debugger.trace(value: "NPV") {
///     npv(discountRate: 0.08, cashFlows: flows)
/// }
/// print(trace.result ?? 0)
///
/// // Diagnose issues
/// let computedNPV = npv(discountRate: 0.08, cashFlows: flows)
/// let report = await debugger.diagnose(value: computedNPV, expected: 50_000, tolerance: 0.01)
/// if report.hasIssues {
///     print(report.formatted())
/// }
/// ```
public actor ModelDebugger {

    /// Logger for debug operations
    #if canImport(OSLog)
    private let logger = Logger.validation
    #endif

    /// The clock that stamps the reports this debugger returns.
    ///
    /// Every report type here carries a `timestamp`, which made each returned value
    /// depend on when it was produced. Supplying a ``FixedWallClock`` pins it.
    ///
    /// Note that this clock is *not* used for the `duration` recorded by the `trace`
    /// methods. A duration is elapsed time, and differencing two wall-clock readings is
    /// the wrong way to obtain one whoever supplies them; those durations come from
    /// ``elapsedTime``.
    public let clock: any WallClock

    /// The monotonic counter every traced duration is read from.
    ///
    /// Separate from ``clock`` because a duration and a timestamp want different
    /// instruments: wall time can be corrected backwards mid-measurement, which is how a
    /// trace ends up reporting a negative interval. See ``ElapsedTimeSource``.
    ///
    /// Injecting a ``ManualElapsedTimeSource`` lets a test state the duration it is
    /// reasoning about instead of sleeping for it and hoping the machine agreed.
    public let elapsedTime: any ElapsedTimeSource

    /// Initialize a new model debugger.
    ///
    /// - Parameters:
    ///   - clock: Stamps the reports this debugger returns. Defaults to the system clock.
    ///   - elapsedTime: Supplies the readings every traced duration is the difference of.
    ///     Defaults to the system's monotonic counter, which is what a debugger should be
    ///     measuring against unless a test needs to name the duration itself.
    public init(
        clock: any WallClock = SystemWallClock(),
        elapsedTime: any ElapsedTimeSource = SystemElapsedTimeSource()
    ) {
        self.clock = clock
        self.elapsedTime = elapsedTime
    }

    // MARK: - Calculation Tracing

    /// Trace how a value is calculated
    ///
    /// Executes the calculation and captures information about the computation,
    /// including inputs, intermediate steps, and the final result.
    ///
    /// - Parameters:
    ///   - value: Name of the value being calculated
    ///   - calculation: Closure that performs the calculation
    ///
    /// - Returns: A calculation trace containing the result and computation details
    ///
    /// Example:
    /// ```swift
    /// let debugger = ModelDebugger()
    /// let price = 25.0
    /// let quantity = 400.0
    /// let trace = await debugger.trace(value: "Revenue") {
    ///     price * quantity
    /// }
    /// ```
	public func trace<T>(
        value: String,
        calculation: () throws -> T
    ) -> DebugTrace<T> where T: Sendable {
        // The moment recorded on the returned trace: read once, so both the success and
        // the failure path report the same instant.
        let startedAt = clock.now
        // A separate, monotonic anchor for `duration`: an interval must not come from
        // differencing wall-clock readings, which an NTP correction can move backwards.
        let start = elapsedTime.now

        do {
            #if canImport(OSLog)
            logger.calculationStarted(value)
            #endif

            let result = try calculation()
            let duration = (elapsedTime.now - start).inSeconds

            #if canImport(OSLog)
            logger.calculationCompleted(value, result: result, duration: duration)
            #endif

            return DebugTrace(
                value: value,
                result: result,
                error: nil,
                duration: duration,
                timestamp: startedAt
            )
        } catch {
            let duration = (elapsedTime.now - start).inSeconds

            #if canImport(OSLog)
            logger.calculationFailed(value, error: error)
            #endif

            return DebugTrace(
                value: value,
                result: nil,
                error: error,
                duration: duration,
                timestamp: startedAt
            )
        }
    }

    /// Trace a calculation with explicit dependencies
    ///
    /// Similar to `trace()` but captures additional details about inputs,
    /// formulas, and dependencies for more thorough debugging.
    ///
    /// - Parameters:
    ///   - value: Name of the value being calculated
    ///   - dependencies: Dictionary of input values
    ///   - formula: The formula or expression used
    ///   - calculation: Closure that performs the calculation
    ///
    /// - Returns: Detailed trace with formula and dependencies
    ///
    /// Example:
    /// ```swift
    /// let debugger = ModelDebugger()
    /// let periods = Period.documentationQuarters
    /// let trace = try await debugger.trace(
    ///     value: "NPV",
    ///     dependencies: ["rate": "0.08", "periods": "10"],
    ///     formula: "PV / (1 + rate)^periods"
    /// ) {
    ///     100_000.0 / Foundation.pow(1.08, 10.0)
    /// }
    /// ```
    public func trace<T>(
        value: String,
        dependencies: [String: String],
        formula: String,
        calculation: () throws -> T
    ) throws -> DetailedDebugTrace<T> where T: Sendable {
        // Recorded on the returned trace.
        let startedAt = clock.now
        // Monotonic anchor for `duration` — see the sibling `trace` above.
        let start = elapsedTime.now

        #if canImport(OSLog)
        logger.calculationStarted(value, context: dependencies)
        #endif

        let result = try calculation()
        let duration = (elapsedTime.now - start).inSeconds

        #if canImport(OSLog)
        logger.calculationCompleted(value, result: result, duration: duration)
        #endif

        return DetailedDebugTrace(
            value: value,
            result: result,
            formula: formula,
            dependencies: dependencies,
            duration: duration,
            timestamp: startedAt
        )
    }

    // MARK: - Diagnostics

    /// Diagnose a value against expected output
    ///
    /// Compares an actual value to an expected value and generates a diagnostic
    /// report with issues, warnings, and suggestions.
    ///
    /// - Parameters:
    ///   - value: The actual value
    ///   - expected: The expected value
    ///   - tolerance: Acceptable relative difference (0.01 = 1%)
    ///   - context: Optional context description
    ///
    /// - Returns: Diagnostic report with issues and suggestions
    ///
    /// Example:
    /// ```swift
    /// let debugger = ModelDebugger()
    /// let calculatedNPV = 48_500.0
    /// let report = await debugger.diagnose(
    ///     value: calculatedNPV,
    ///     expected: 50_000,
    ///     tolerance: 0.05,  // 5% tolerance
    ///     context: "NPV Calculation"
    /// )
    /// ```
    public func diagnose(
        value: Double,
        expected: Double,
        tolerance: Double = 0.01,
        context: String? = nil
    ) -> DiagnosticReport {
        var issues: [DiagnosticIssue] = []
        var warnings: [DiagnosticWarning] = []
        var suggestions: [DiagnosticSuggestion] = []

        let difference = value - expected

        // Check for NaN or infinity
        if value.isNaN {
            issues.append(DiagnosticIssue(
                severity: .error,
                message: "Value is NaN (Not a Number)",
                location: context,
                suggestion: "Check for division by zero or invalid operations"
            ))
        }

        if value.isInfinite {
            issues.append(DiagnosticIssue(
                severity: .error,
                message: "Value is infinite",
                location: context,
                suggestion: "Check for division by very small numbers or overflow"
            ))
        }

        // A non-finite `expected` leaves nothing to compare against. Staying silent here
        // reported a clean bill of health for a check that never actually ran.
        if !expected.isFinite {
            let kind = expected.isNaN ? "NaN" : "infinite"
            issues.append(DiagnosticIssue(
                severity: .error,
                message: "Expected value is \(kind), so there is nothing to compare against",
                location: context,
                suggestion: "Supply a finite expected value"
            ))
        }

        // Check tolerance.
        //
        // `tolerance` is *relative*, so it needs a non-zero `expected` to scale by. When
        // `expected` is exactly zero the relative difference is unbounded for every non-zero
        // value, so read `tolerance` as an absolute bound on the magnitude of `value`
        // instead — the `atol` half of the conventional `|a - b| <= atol + rtol * |b|` rule.
        // Substituting a relative difference of zero, as this did, passed a value of *any*
        // size: `diagnose(value: 1_000_000_000, expected: 0)` reported no issues at all.
        let relative = Self.relativeDifference(value: value, expected: expected)
        let discrepancy = relative ?? abs(value)
        let comparable = value.isFinite && expected.isFinite
        if comparable && discrepancy > tolerance {
            let detail: String
            if relative != nil {
                detail = "by \((discrepancy * 100).number(2))% (tolerance: \((tolerance * 100).number(2))%)"
            } else {
                detail = "by \(discrepancy.number(2)) against an expected value of exactly zero, where a relative tolerance has no scale to measure with (absolute tolerance: \(tolerance.number(2)))"
            }
            issues.append(DiagnosticIssue(
                severity: .error,
                message: "Value differs from expected \(detail)",
                location: context,
                suggestion: "Review calculation logic and input values"
            ))

            suggestions.append(DiagnosticSuggestion(
                message: "Actual: \(value), Expected: \(expected), Difference: \(difference)",
                action: "Verify formula implementation"
            ))
        }

        // Add warnings for edge cases
        if value == 0 && expected != 0 {
            warnings.append(DiagnosticWarning(
                message: "Value is zero but expected non-zero",
                location: context,
                suggestion: "Check if calculation is returning default/initial value"
            ))
        }

        return DiagnosticReport(
            timestamp: clock.now,
            modelName: context,
            issues: issues,
            warnings: warnings,
            suggestions: suggestions
        )
    }

    // MARK: - Relative difference

    /// Unsigned relative difference `|value - expected| / |expected|`.
    ///
    /// Returns `nil` when `expected` is zero — there is then no scale to divide by, and the
    /// relative difference of any non-zero `value` is unbounded rather than zero. Making
    /// that case unrepresentable as a number is the point: callers have to say what they
    /// mean by it at their own site instead of inheriting a sentinel that also reads as
    /// "perfect agreement".
    ///
    /// - Parameters:
    ///   - value: The observed value.
    ///   - expected: The reference value to scale by.
    /// - Returns: The unsigned relative difference, or `nil` when `expected` is zero.
    private static func relativeDifference(value: Double, expected: Double) -> Double? {
        guard expected != 0 else { return nil }
        return abs((value - expected) / expected)
    }

    /// Signed relative difference `(actual - expected) / expected`, keeping the direction
    /// of the miss.
    ///
    /// Returns `nil` when `expected` is zero, for the same reason as
    /// ``relativeDifference(value:expected:)``.
    ///
    /// - Parameters:
    ///   - actual: The observed value.
    ///   - expected: The reference value to scale by.
    /// - Returns: The signed relative difference, or `nil` when `expected` is zero.
    private static func signedRelativeDifference(actual: Double, expected: Double) -> Double? {
        guard expected != 0 else { return nil }
        return (actual - expected) / expected
    }

    // MARK: - Validation

    /// Validate a value against constraints
    ///
    /// Checks whether a value satisfies specified validation rules
    /// and returns a detailed report of any violations.
    ///
    /// - Parameters:
    ///   - value: The value to validate
    ///   - name: Name of the field being validated
    ///   - constraints: List of validation constraints
    ///
    /// - Returns: Validation report with violations
    ///
    /// Example:
    /// ```swift
    /// let debugger = ModelDebugger()
    /// let discountRate = 0.08
    /// let report = await debugger.validate(
    ///     value: discountRate,
    ///     name: "discountRate",
    ///     constraints: [.positive, .range(0.0, 1.0), .finite]
    /// )
    /// ```
    public func validate(
        value: Double,
        name: String,
        constraints: [ValidationConstraint]
    ) -> DebugValidationReport {
        var errors: [ValidationError] = []

        for constraint in constraints {
            let violation = constraint.validate(value: value, fieldName: name)
            if let violation = violation {
                errors.append(violation)
            }
        }

        return DebugValidationReport(
            timestamp: clock.now,
            fieldName: name,
            value: value,
            errors: errors
        )
    }

    // MARK: - Explanations

    /// Explain why two values differ
    ///
    /// Analyzes the difference between actual and expected values
    /// and provides possible reasons and suggestions.
    ///
    /// - Parameters:
    ///   - actual: The actual value
    ///   - expected: The expected value
    ///   - context: Optional context description
    ///
    /// - Returns: Explanation with possible reasons
    ///
    /// Example:
    /// ```swift
    /// let debugger = ModelDebugger()
    /// let explanation = await debugger.explain(
    ///     actual: 90_000,
    ///     expected: 100_000,
    ///     context: "Revenue"
    /// )
    /// print(explanation.possibleReasons)
    /// ```
    public func explain(
        actual: Double,
        expected: Double,
        context: String? = nil
    ) -> Explanation {
        let difference = actual - expected

        // The percentage difference from zero is unbounded, not zero. Reporting zero both
        // published a fabricated statistic on `Explanation` and — because every magnitude
        // branch below tests `abs(percentDifference)` — meant the largest possible
        // discrepancy produced the least guidance. `Double.number(_:)` renders an infinity
        // as `∞`, so `formatted()` stays readable.
        let percentDifference: Double
        if let relative = Self.signedRelativeDifference(actual: actual, expected: expected) {
            percentDifference = relative * 100
        } else if difference == 0 {
            percentDifference = 0
        } else {
            percentDifference = difference < 0 ? -.infinity : .infinity
        }

        var possibleReasons: [String] = []
        var suggestions: [String] = []

        // Analyze the difference
        if actual.isNaN || expected.isNaN {
            possibleReasons.append("NaN value indicates invalid calculation")
            suggestions.append("Check for division by zero or square root of negative numbers")
        } else if actual.isInfinite || expected.isInfinite {
            possibleReasons.append("Infinite value indicates overflow or division by zero")
            suggestions.append("Check denominators and ensure values are within reasonable ranges")
        } else if difference == 0 {
            possibleReasons.append("Values match exactly")
        } else {
            // Provide context-aware analysis
            if actual < expected {
                possibleReasons.append("Actual value is lower than expected")
                suggestions.append("Check if all revenue sources are included")
                suggestions.append("Verify growth rates and multipliers")
            } else {
                possibleReasons.append("Actual value is higher than expected")
                suggestions.append("Check for double-counting")
                suggestions.append("Verify cost reductions or efficiency gains")
            }

            // Additional analysis based on magnitude
            if abs(percentDifference) > 50 {
                possibleReasons.append("Large discrepancy suggests fundamental calculation error")
                suggestions.append("Double-check the formula implementation")
                suggestions.append("Verify units and scaling factors")
            } else if abs(percentDifference) > 10 {
                possibleReasons.append("Moderate discrepancy may indicate data or parameter issues")
                suggestions.append("Review input data accuracy")
                suggestions.append("Check for rounding or precision issues")
            }
        }

        return Explanation(
            actual: actual,
            expected: expected,
            difference: difference,
            percentageDifference: percentDifference,
            possibleReasons: possibleReasons,
            suggestions: suggestions,
            context: context
        )
    }

    // MARK: - Real-Time Tracing

    /// Enable calculation tracing.
    ///
    /// When enabled, the debugger will capture all calculation steps
    /// for later inspection.
    ///
    /// Example:
    /// ```swift
    /// let period = Period.documentationQuarters[0]
    /// let model = FinancialModel()
    /// let debugger = ModelDebugger()
    /// await debugger.enableTracing()
    /// let result = model.totalRevenue(for: period)
    /// let trace = await debugger.getTrace()
    /// ```
    public func enableTracing() {
        DebugContext.shared.enable()
    }

    /// Disable calculation tracing.
    public func disableTracing() {
        DebugContext.shared.disable()
    }

    /// Get the captured calculation trace.
    ///
    /// Returns all calculation steps captured since tracing was enabled.
    ///
    /// - Returns: Calculation trace with all captured steps
    ///
    /// Example:
    /// ```swift
    /// let debugger = ModelDebugger()
    /// await debugger.enableTracing()
    /// // ... perform calculations ...
    /// let trace = await debugger.getTrace()
    /// for step in trace.steps {
    ///     print("\(step.operation): \(step.input) → \(step.output)")
    /// }
    /// ```
    public func getTrace() -> DebuggerTrace {
        return DebuggerTrace(steps: DebugContext.shared.getSteps())
    }

    // MARK: - Model Validation

    /// Validate a financial model.
    ///
    /// Checks exactly three things, and no others:
    /// - the model has at least one revenue or cost component
    /// - a model with costs also has revenue
    /// - no time series carries a `NaN`, on either side of the model
    ///
    /// **Both sides are scanned.** This used to walk `revenueComponents` only, and its
    /// documentation described that narrowness rather than deciding it — so a model whose
    /// cost series was `NaN` from end to end came back `isValid` with the summary
    /// `"✅ Model is valid"`, which is the most reassuring thing this method can say. Its
    /// sibling ``ModelDebugger/findMissingData(in:)`` had the identical gap and was widened
    /// first; this follows it so the two agree about what "the model" means.
    ///
    /// A revenue and a cost component may carry the same name. Each produces its own error,
    /// labelled with the side it came from, so neither displaces the other — the same
    /// guarantee `findMissingData(in:)` buys by merging into one key instead of overwriting.
    ///
    /// Infinities are not reported here. They order and compare correctly and are a
    /// legitimate observation in a financial series, so the contaminated-input contract
    /// leaves them alone unless they break the specific computation; the rule this method
    /// reports under is `no-nan-values` and it means what it says.
    ///
    /// It does **not** detect dependency cycles between accounts. A ``FinancialModel``'s
    /// components hold time series rather than formulas, so no account can refer to another
    /// and there is nothing here for a cycle walk to traverse. Cycles arise a layer up, in
    /// whatever defines each account's formula; ``FormulaEvaluator/accountNames(in:)``
    /// reports a formula's dependencies without evaluating it, which is enough to walk those
    /// definitions yourself and throw ``BusinessMathError/circularDependency(path:)``.
    ///
    /// - Parameter model: The model to validate
    /// - Returns: Validation report with issues and suggestions
    ///
    /// Example:
    /// ```swift
    /// let model = FinancialModel()
    /// let debugger = ModelDebugger()
    /// let validation = await debugger.validate(model)
    /// if !validation.isValid {
    ///     for issue in validation.errors + validation.warnings {
    ///         print("[\(issue.rule)] \(issue.field)")
    ///     }
    /// }
    /// ```
    public func validate(_ model: FinancialModel) -> ValidationReport {
        var errors: [ValidationError] = []
        var warnings: [ValidationError] = []

        // Check for empty model
        if model.revenueComponents.isEmpty && model.costComponents.isEmpty {
            warnings.append(ValidationError(
                field: "model",
                value: 0,
                rule: "model-not-empty",
                message: "Model is empty - no revenue or cost components",
                suggestion: "Add at least one revenue component"
            ))
        }

        // Check for missing revenue
        if model.revenueComponents.isEmpty && !model.costComponents.isEmpty {
            warnings.append(ValidationError(
                field: "revenueComponents",
                value: 0,
                rule: "has-revenue",
                message: "Model has expenses but no revenue",
                suggestion: "Add revenue components to calculate net income"
            ))
        }

        // Check for NaN values in time series, on both sides of the model.
        //
        // `side` reaches the message rather than the field so that two components sharing a
        // name stay tellable apart in the report; `field` remains the component name, which
        // is what a caller filters on.
        for component in model.revenueComponents {
            errors.append(contentsOf: nanErrors(in: component.timeSeries, named: component.name, side: "revenue"))
        }

        for component in model.costComponents {
            errors.append(contentsOf: nanErrors(in: component.timeSeries, named: component.name, side: "cost"))
        }

        let isValid = errors.isEmpty
        let summary = isValid ? "✅ Model is valid" : "❌ Model has \(errors.count) error(s)"

        return ValidationReport(
            isValid: isValid,
            errors: errors,
            warnings: warnings,
            summary: summary,
            timestamp: clock.now
        )
    }

    /// The `NaN` errors one component's series contributes to a validation report.
    ///
    /// Shared by the revenue and cost passes of ``validate(_:)`` so the two cannot drift
    /// apart again: one scan, called twice, differing only in the word it uses for the side
    /// of the model a component sits on.
    ///
    /// - Parameters:
    ///   - series: The component's series, or `nil` for a component that carries a single
    ///     amount instead. A component with no series contributes no errors, because there
    ///     is no per-period value here to read.
    ///   - name: The component's name, reported as the error's `field`.
    ///   - side: `"revenue"` or `"cost"`, which is all that distinguishes two components
    ///     that share a name.
    /// - Returns: One error per `NaN` reading, in period order; empty when there are none.
    private func nanErrors(in series: TimeSeries<Double>?, named name: String, side: String) -> [ValidationError] {
        guard let series else { return [] }

        var errors: [ValidationError] = []
        for (period, value) in zip(series.periods, series.valuesArray) where value.isNaN {
            errors.append(ValidationError(
                field: name,
                value: value,
                rule: "no-nan-values",
                message: "NaN value in \(side) '\(name)' for period \(period)",
                suggestion: "Replace NaN with valid number or use fillMissing()"
            ))
        }
        return errors
    }

    /// Find missing data in a financial model.
    ///
    /// Identifies periods where accounts have missing or NaN values.
    ///
    /// Both sides of the model are scanned. This used to walk only `revenueComponents` while
    /// claiming "accounts", so a cost whose series carried a NaN came back as nothing missing
    /// at all — an empty dictionary from a method whose entire purpose is to say where the
    /// gaps are reads as "there are none", and the caller had no way to tell that half the
    /// model was never looked at.
    ///
    /// A revenue and a cost component may carry the same name. Their periods are merged under
    /// that one key rather than one silently replacing the other, so no gap is dropped.
    ///
    /// - Parameter model: The model to analyze
    /// - Returns: Dictionary mapping account names to arrays of missing periods
    ///
    /// Example:
    /// ```swift
    /// let model = FinancialModel()
    /// let debugger = ModelDebugger()
    /// let periods = Period.documentationQuarters
    /// let missing = await debugger.findMissingData(in: model)
    /// for (account, periods) in missing {
    ///     print("\(account): missing \(periods.count) periods")
    /// }
    /// ```
    public func findMissingData(in model: FinancialModel) -> [String: [Period]] {
        var missing: [String: [Period]] = [:]

        // Check revenue components
        for component in model.revenueComponents {
            if let timeSeries = component.timeSeries {
                var missingPeriods: [Period] = []
                for (period, value) in zip(timeSeries.periods, timeSeries.valuesArray) {
                    if value.isNaN || value.isInfinite {
                        missingPeriods.append(period)
                    }
                }
                if !missingPeriods.isEmpty {
                    missing[component.name, default: []].append(contentsOf: missingPeriods)
                }
            }
        }

        // Check cost components, by the same test
        for component in model.costComponents {
            if let timeSeries = component.timeSeries {
                var missingPeriods: [Period] = []
                for (period, value) in zip(timeSeries.periods, timeSeries.valuesArray) {
                    if value.isNaN || value.isInfinite {
                        missingPeriods.append(period)
                    }
                }
                if !missingPeriods.isEmpty {
                    missing[component.name, default: []].append(contentsOf: missingPeriods)
                }
            }
        }

        return missing
    }

    // MARK: - Model Snapshot

    /// Create a snapshot of a financial model for inspection.
    ///
    /// Captures the current state of a financial model including accounts,
    /// periods, and validation status for debugging and documentation.
    ///
    /// - Parameter model: The financial model to snapshot
    /// - Returns: A model snapshot with summary information
    ///
    /// Example:
    /// ```swift
    /// let model = FinancialModel()
    /// let debugger = ModelDebugger()
    /// let snapshot = await debugger.snapshot(of: model)
    /// print(snapshot.summary)
    /// ```
    public func snapshot(of model: FinancialModel) async -> ModelSnapshot {
        // Collect all periods from time series data
        var allPeriods: Set<Period> = []
        for component in model.revenueComponents {
            if let timeSeries = component.timeSeries {
                allPeriods.formUnion(timeSeries.periods)
            }
        }
        for component in model.costComponents {
            if let timeSeries = component.timeSeries {
                allPeriods.formUnion(timeSeries.periods)
            }
        }

        // Create revenue account snapshots
        let revenueSnapshots = model.revenueComponents.map { component in
            AccountSnapshot(revenue: component, periods: allPeriods)
        }

        // Calculate revenue by period, for the percent-of-revenue expenses below.
        //
        // Reachable, unlike most lookups of this shape. The usual reason a `?? 0` on a series
        // cannot fire is that the loop iterates that same series' own keys, and `TimeSeries`
        // derives `periods` from them. Not here: `allPeriods` is a *union* formed over every
        // revenue **and** cost component above, so each component is asked about periods only
        // its siblings covered. A component whose series stops early — or a period that only a
        // cost component contributed — leaves a revenue component with nothing to say.
        // Adding zero for it is not a missing observation, it is the assertion that the
        // component earned nothing, and this total is the denominator every percent-of-revenue
        // cost is calculated from: the fabricated shortfall comes back as a confidently
        // understated expense rather than as a gap anyone can see.
        //
        // So a period some component cannot answer for is left out of the dictionary entirely.
        // That is what `AccountSnapshot(revenue:periods:)` already does with the same gap in its
        // own series a few lines below, and what `TimeSeries.zip(with:)` does everywhere.
        var revenueByPeriod: [Period: Double] = [:]
        for period in allPeriods {
            var periodRevenue = 0.0
            var covered = true
            for component in model.revenueComponents {
                if let timeSeries = component.timeSeries {
                    guard let value = timeSeries[period] else {
                        covered = false
                        break
                    }
                    periodRevenue += value
                } else {
                    periodRevenue += component.amount
                }
            }
            if covered {
                revenueByPeriod[period] = periodRevenue
            }
        }

        // Create expense account snapshots
        let expenseSnapshots = model.costComponents.map { component in
            AccountSnapshot(cost: component, periods: allPeriods, revenueByPeriod: revenueByPeriod)
        }

        // Sort periods chronologically
        let sortedPeriods = allPeriods.sorted()

        // Determine status
        let status: String
        if revenueSnapshots.isEmpty && expenseSnapshots.isEmpty {
            status = "Empty"
        } else if revenueSnapshots.isEmpty {
            status = "Missing Revenue"
        } else {
            status = "Valid"
        }

        let entityName = model.entity?.name ?? "Financial Model"

        return ModelSnapshot(
            timestamp: clock.now,
            modelName: entityName,
            revenueAccounts: revenueSnapshots,
            expenseAccounts: expenseSnapshots,
            periods: sortedPeriods,
            status: status
        )
    }
}

// MARK: - Calculation Trace Types

/// Result of a basic calculation trace
public struct DebugTrace<T: Sendable>: Sendable {
    /// Name of the value being calculated
    public let value: String

    /// The calculated result (nil if error occurred)
    public let result: T?

    /// Error that occurred during calculation (nil if successful)
    public let error: Error?

    /// Time taken for the calculation
    public let duration: TimeInterval

    /// When the calculation was performed
    public let timestamp: Date

    /// Format as a simple description
    public func formatted() -> String {
        if let result = result {
            return """
            Calculation: \(value)
            Result: \(result)
            Duration: \(duration.number(3))s
            Timestamp: \(timestamp)
            """
        } else if let error = error {
            return """
            Calculation: \(value)
            Error: \(error.localizedDescription)
            Duration: \(duration.number(3))s
            Timestamp: \(timestamp)
            """
        } else {
            return """
            Calculation: \(value)
            Result: Unknown
            Duration: \(duration.number(3))s
            """
        }
    }
}

/// Detailed calculation trace with dependencies and formula
public struct DetailedDebugTrace<T: Sendable>: Sendable {
    /// Name of the value being calculated
    public let value: String

    /// The calculated result
    public let result: T

    /// Formula used for calculation
    public let formula: String

    /// Input dependencies (as strings for Sendable conformance)
    public let dependencies: [String: String]

    /// Time taken for the calculation
    public let duration: TimeInterval

    /// When the calculation was performed
    public let timestamp: Date

    /// Format as a tree structure
    public func asTree() -> String {
        var output = """
        \(value) = \(result)
        Formula: \(formula)
        Duration: \(duration.number(3))s

        Dependencies:
        """

        for (name, value) in dependencies.sorted(by: { $0.key < $1.key }) {
            output += "\n  ├─ \(name) = \(value)"
        }

        return output
    }

    /// Format as JSON for export
    public func asJSON() throws -> String {
        let dict: [String: Any] = [
            "value": value,
            "result": String(describing: result),
            "formula": formula,
            "duration": duration,
            "timestamp": ISO8601DateFormatter().string(from: timestamp),
            "dependencies": dependencies
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
        return String(data: jsonData, encoding: .utf8) ?? "{}"
    }
}

// MARK: - Diagnostic Types

/// Comprehensive diagnostic report
public struct DiagnosticReport: Sendable {
    /// When the diagnostic was run
    public let timestamp: Date

    /// Name of the model being diagnosed
    public let modelName: String?

    /// Critical issues found
    public let issues: [DiagnosticIssue]

    /// Warnings found
    public let warnings: [DiagnosticWarning]

    /// Suggestions for improvement
    public let suggestions: [DiagnosticSuggestion]

    /// Whether any errors were found
    public var hasErrors: Bool { !issues.isEmpty }

    /// Whether any warnings were found
    public var hasWarnings: Bool { !warnings.isEmpty }

    /// Whether any issues were found (errors or warnings)
    public var hasIssues: Bool { hasErrors || hasWarnings }

    /// Context for the diagnostic (alias for modelName)
    public var context: String? { modelName }

    /// Pretty-print the report
    public func formatted() -> String {
        var output = "=== Diagnostic Report ===\n"
        if let name = modelName {
            output += "Model: \(name)\n"
        }
        output += "Timestamp: \(timestamp)\n\n"

        if hasErrors {
            output += "❌ ERRORS (\(issues.count)):\n"
            for (index, issue) in issues.enumerated() {
                output += "\(index + 1). \(issue.message)\n"
                if let location = issue.location {
                    output += "   Location: \(location)\n"
                }
                if let suggestion = issue.suggestion {
                    output += "   💡 \(suggestion)\n"
                }
                output += "\n"
            }
        }

        if hasWarnings {
            output += "⚠️  WARNINGS (\(warnings.count)):\n"
            for (index, warning) in warnings.enumerated() {
                output += "\(index + 1). \(warning.message)\n"
                if let location = warning.location {
                    output += "   Location: \(location)\n"
                }
                if let suggestion = warning.suggestion {
                    output += "   💡 \(suggestion)\n"
                }
                output += "\n"
            }
        }

        if !suggestions.isEmpty {
            output += "💭 SUGGESTIONS (\(suggestions.count)):\n"
            for (index, suggestion) in suggestions.enumerated() {
                output += "\(index + 1). \(suggestion.message)\n"
                if let action = suggestion.action {
                    output += "   → \(action)\n"
                }
                output += "\n"
            }
        }

        if !hasIssues {
            output += "✅ No issues found!\n"
        }

        return output
    }
}

/// A diagnostic issue (error or warning)
public struct DiagnosticIssue: Sendable {
    /// Severity level
    public enum Severity: Sendable {
        case error      // Prevents correct calculation
        case warning    // LIVE: diagnostic severity level for suspicious-but-valid findings
        case info       // LIVE: diagnostic severity level for informational notes
    }

    /// Severity of the issue
    public let severity: Severity

    /// Description of the issue
    public let message: String

    /// Where the issue occurred
    public let location: String?

    /// Suggested fix
    public let suggestion: String?
}

/// A diagnostic warning
public struct DiagnosticWarning: Sendable { // legibility:reserved exposed via ModelDebugger's public `warnings` result; part of the downstream API contract
    /// Description of the warning
    public let message: String

    /// Where the warning occurred
    public let location: String?

    /// Suggested action
    public let suggestion: String?
}

/// A diagnostic suggestion
public struct DiagnosticSuggestion: Sendable {
    /// The suggestion message
    public let message: String

    /// Recommended action
    public let action: String?
}

// MARK: - Validation Types

/// Result of a debug validation check
public struct DebugValidationReport: Sendable {
    /// When the validation was performed
    public let timestamp: Date

    /// Name of the field validated
    public let fieldName: String

    /// The value that was validated
    public let value: Double

    /// Validation errors found
    public let errors: [ValidationError]

    /// Whether validation passed
    public var isValid: Bool { errors.isEmpty }

    /// List of constraint violations
    public var violations: [ValidationError] { errors }

    /// Format as human-readable text
    public func formatted() -> String {
        var output = "=== Validation Report ===\n"
        output += "Field: \(fieldName)\n"
        output += "Value: \(value)\n"
        output += "Timestamp: \(timestamp)\n\n"

        if isValid {
            output += "✅ Validation passed\n"
        } else {
            output += "❌ Validation failed with \(errors.count) error(s):\n\n"
            for (index, error) in errors.enumerated() {
                output += "\(index + 1). \(error.description)\n"
            }
        }

        return output
    }
}

/// Validation constraints for debugging
public enum ValidationConstraint: Sendable {
    case positive
    case nonNegative
    case range(Double, Double)
    case nonZero
    case finite
    case maxValue(Double)
    case minValue(Double)

    /// Validate a value against this constraint.
    ///
    /// Every comparison involving NaN is false, so each of the comparison-based constraints
    /// below used to return "no violation" for a value that is not a number:
    /// `validate(value: .nan, name: "rate", constraints: [.range(0, 1)])` reported the value
    /// as inside the range, and `isValid` came back `true`. The caller asked specifically
    /// whether the value satisfied the constraint, so silence is the one answer that cannot
    /// be right. Each test therefore names NaN explicitly, and reports the violation it
    /// already had a message for — a NaN is not positive, is not non-negative, is not inside
    /// any range, and is neither at most a maximum nor at least a minimum.
    ///
    /// Infinities are deliberately left to the ordinary comparisons: they order correctly, so
    /// `+∞` legitimately passes `.positive` and legitimately fails `.maxValue`. `.nonZero` is
    /// also left alone — a NaN genuinely is not zero, which is the whole of what that
    /// constraint asks, and `.finite` is the constraint that asks the other question.
    ///
    /// - Parameters:
    ///   - value: The value to check.
    ///   - fieldName: The field name to report a violation against.
    /// - Returns: The violation, or `nil` when the constraint is satisfied.
    func validate(value: Double, fieldName: String) -> ValidationError? {
        switch self {
        case .positive:
            if value.isNaN || value <= 0 {
                return ValidationError(
                    field: fieldName,
                    value: value,
                    rule: "positive",
                    message: "Value must be positive",
                    suggestion: "Ensure \(fieldName) is greater than zero"
                )
            }

        case .nonNegative:
            if value.isNaN || value < 0 {
                return ValidationError(
                    field: fieldName,
                    value: value,
                    rule: "non-negative",
                    message: "Value must be non-negative",
                    suggestion: "Ensure \(fieldName) is greater than or equal to zero"
                )
            }

        case .range(let min, let max):
            if value.isNaN || value < min || value > max {
                return ValidationError(
                    field: fieldName,
                    value: value,
                    rule: "range",
                    message: "Value must be between \(min) and \(max)",
                    suggestion: "Adjust \(fieldName) to fall within the valid range"
                )
            }

        case .nonZero:
            if value == 0 {
                return ValidationError(
                    field: fieldName,
                    value: value,
                    rule: "non-zero",
                    message: "Value must not be zero",
                    suggestion: "Provide a non-zero value for \(fieldName)"
                )
            }

        case .finite:
            if !value.isFinite {
                return ValidationError(
                    field: fieldName,
                    value: value,
                    rule: "finite",
                    message: "Value must be finite (not NaN or infinite)",
                    suggestion: "Check calculation for division by zero or overflow"
                )
            }

        case .maxValue(let max):
            if value.isNaN || value > max {
                return ValidationError(
                    field: fieldName,
                    value: value,
                    rule: "max-value",
                    message: "Value exceeds maximum of \(max)",
                    suggestion: "Reduce \(fieldName) to be at most \(max)"
                )
            }

        case .minValue(let min):
            if value.isNaN || value < min {
                return ValidationError(
                    field: fieldName,
                    value: value,
                    rule: "min-value",
                    message: "Value is below minimum of \(min)",
                    suggestion: "Increase \(fieldName) to be at least \(min)"
                )
            }
        }

        return nil
    }
}

// MARK: - Explanation Types

/// Explanation of value differences
public struct Explanation: Sendable {
    /// The actual value
    public let actual: Double

    /// The expected value
    public let expected: Double

    /// Absolute difference (actual - expected)
    public let difference: Double

    /// Percentage difference
    public let percentageDifference: Double

    /// Possible reasons for the difference
    public let possibleReasons: [String]

    /// Suggestions for investigation
    public let suggestions: [String]

    /// Context for the explanation
    public let context: String?

    /// Format as human-readable text
    public func formatted() -> String {
        var output = "=== Value Difference Explanation ===\n"
        if let ctx = context {
            output += "Context: \(ctx)\n"
        }
        output += "Actual: \(actual.number(2))\n"
        output += "Expected: \(expected.number(2))\n"
        output += "Difference: \(difference.number(2)) (\(percentageDifference.number(2))%)\n\n"

        if !possibleReasons.isEmpty {
            output += "Possible Reasons:\n"
            for reason in possibleReasons {
                output += "  • \(reason)\n"
            }
            output += "\n"
        }

        if !suggestions.isEmpty {
            output += "Suggestions:\n"
            for suggestion in suggestions {
                output += "  → \(suggestion)\n"
            }
        }

        return output
    }
}

// MARK: - Model Snapshot Types

/// Snapshot of a single account's data.
///
/// Represents a revenue or expense account with all its values across periods.
public struct AccountSnapshot: Sendable {
    /// Account name
    public let name: String

    /// Total value across all periods
    public let total: Double

    /// Values by period
    public let values: [Period: Double]

    /// Expense type (for expense accounts)
    public let expenseType: ExpenseType?

    /// Create a revenue account snapshot
    init(revenue: RevenueComponent, periods: Set<Period>) {
        self.name = revenue.name
        self.expenseType = nil

        var valueDict: [Period: Double] = [:]
        var totalValue = 0.0

        if let timeSeries = revenue.timeSeries {
            for period in periods {
                if let value = timeSeries[period] {
                    valueDict[period] = value
                    totalValue += value
                }
            }
        } else {
            // Single-value revenue - apply to all periods
            for period in periods {
                valueDict[period] = revenue.amount
                totalValue += revenue.amount
            }
        }

        self.values = valueDict
        self.total = totalValue
    }

    /// Create an expense account snapshot
    init(cost: CostComponent, periods: Set<Period>, revenueByPeriod: [Period: Double]) {
        self.name = cost.name
        self.expenseType = cost.expenseType

        var valueDict: [Period: Double] = [:]
        var totalValue = 0.0

        if let timeSeries = cost.timeSeries {
            for period in periods {
                if let value = timeSeries[period] {
                    valueDict[period] = value
                    totalValue += value
                }
            }
        } else {
            // Single-value cost - calculate for each period
            for period in periods {
                // This lookup could not miss until the caller above changed: `revenueByPeriod`
                // was written for every key of the same `allPeriods` this loop walks, so the
                // fallback was dead code sitting behind a total dictionary. Now that the
                // caller leaves out the periods it cannot answer for, the miss is the whole
                // signal, and it means revenue is *unknown* — not that it was zero.
                //
                // A `.fixed` cost never consults revenue, so it is reported either way — that
                // is why this asks about the cost type rather than simply skipping. A
                // `.variable` cost computed against a fabricated zero reports an expense of
                // exactly zero, which is indistinguishable from an expense that did not occur,
                // and it flows into `total` as well. The period is left out instead, exactly as
                // the revenue initialiser above leaves out a period its own series lacks.
                let revenue = revenueByPeriod[period]
                if case .variable = cost.type, revenue == nil { continue }
                let value = cost.calculate(revenue: revenue, for: period)
                valueDict[period] = value
                totalValue += value
            }
        }

        self.values = valueDict
        self.total = totalValue
    }
}

/// A snapshot of a financial model's state.
///
/// Captures key metrics and metadata about a financial model
/// for debugging, documentation, and validation purposes.
public struct ModelSnapshot: Sendable {
    /// When the snapshot was taken
    public let timestamp: Date

    /// Name of the model or entity
    public let modelName: String

    /// Revenue account snapshots
    public let revenueAccounts: [AccountSnapshot]

    /// Expense account snapshots
    public let expenseAccounts: [AccountSnapshot]

    /// All accounts (revenue + expenses)
    public var accounts: [AccountSnapshot] {
        revenueAccounts + expenseAccounts
    }

    /// Total number of accounts
    public var totalAccounts: Int {
        revenueAccounts.count + expenseAccounts.count
    }

    /// Periods covered by the model
    public let periods: [Period]

    /// Model validation status
    public let status: String

    /// Summary description of the model
    public var summary: String {
        let periodType = periods.first?.description.contains("Q") == true ? "quarters" : "periods"
        return """
        Model: \(modelName)
        Accounts: \(totalAccounts) (\(revenueAccounts.count) revenue, \(expenseAccounts.count) expenses)
        Periods: \(periods.count) \(periodType)
        Status: \(status)
        """
    }

    /// Formatted snapshot for display
    public func formatted() -> String {
        let periodType = periods.first?.description.contains("Q") == true ? "quarters" : "periods"
        var output = "=== Model Snapshot ===\n"
        output += "Timestamp: \(timestamp)\n"
        output += "Model: \(modelName)\n\n"
        output += "Accounts:\n"
        output += "  Revenue: \(revenueAccounts.count)\n"
        output += "  Expenses: \(expenseAccounts.count)\n"
        output += "  Total: \(totalAccounts)\n\n"
        output += "Time Coverage:\n"
        output += "  Periods: \(periods.count) \(periodType)\n\n"
        output += "Status: \(status)\n"
        return output
    }
}

// MARK: - Tracing Types

/// A single step in a calculation trace for ModelDebugger.
public struct CalculationStep: Sendable {
    /// The operation performed
    public let operation: String

    /// Input to the operation
    public let input: String

    /// Output from the operation
    public let output: String

    /// When the step was recorded
    public let timestamp: Date
}

/// Simplified trace for ModelDebugger real-time tracing.
public struct DebuggerTrace: Sendable {
    /// All captured calculation steps
    public let steps: [CalculationStep]

    /// Formatted trace output
    public func formatted() -> String {
        var output = "=== Calculation Trace ===\n"
        output += "Steps: \(steps.count)\n\n"
        for (index, step) in steps.enumerated() {
            output += "\(index + 1). \(step.operation): \(step.input) → \(step.output)\n"
        }
        return output
    }
}
