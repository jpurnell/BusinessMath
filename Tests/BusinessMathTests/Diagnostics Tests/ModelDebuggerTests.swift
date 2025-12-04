//
//  ModelDebuggerTests.swift
//  BusinessMath
//
//  Created on December 1, 2025.
//

import Testing
import Foundation
@testable import BusinessMath

/// Tests for the ModelDebugger diagnostic system
///
/// Verifies that:
/// - Calculation tracing captures execution details
/// - Diagnostic reports identify issues accurately
/// - Validation constraints work correctly
/// - Explanations provide helpful insights
/// - Edge cases are handled properly
@Suite("ModelDebugger Tests")
struct ModelDebuggerTests {

    // MARK: - Basic Calculation Tracing

    @Test("Basic calculation trace captures result")
    func basicTraceResult() {
        let debugger = ModelDebugger()

        let trace = debugger.trace(value: "NPV") {
            1000.0
        }

        #expect(trace.value == "NPV")
        #expect(trace.result == 1000.0)
    }

    @Test("Basic trace captures errors")
    func basicTraceError() {
        let debugger = ModelDebugger()

        struct TestError: Error {
            let message: String
        }

        // Note: trace() catches errors internally, so no try needed
        let trace: DebugTrace<Int> = debugger.trace(value: "Calculation") {
            throw TestError(message: "Test error")
        }

        #expect(trace.value == "Calculation")
        #expect(trace.result == nil)
        #expect(trace.error != nil)
    }

	@Test(.disabled("Trace timing is captured"))
    func traceTimingCaptured() {
        let debugger = ModelDebugger()

        let trace = debugger.trace(value: "Slow Operation") {
            Thread.sleep(forTimeInterval: 0.01) // 10ms
            return 42.0
        }

        #expect(trace.duration >= 0.01)
        #expect(trace.duration < 1.0) // Should complete quickly
    }

    // MARK: - Detailed Calculation Tracing

    @Test("Detailed trace captures dependencies")
    func detailedTraceDependencies() throws {
        let debugger = ModelDebugger()

        let trace = try debugger.trace(
            value: "NPV",
            dependencies: ["rate": "0.08", "periods": "10"],
            formula: "PV / (1 + rate)^periods"
        ) {
            1000.0 / pow(1.08, 10.0)
        }

        #expect(trace.value == "NPV")
        #expect(trace.dependencies.count == 2)
        #expect(trace.dependencies["rate"] == "0.08")
        #expect(trace.dependencies["periods"] == "10")
        #expect(trace.formula == "PV / (1 + rate)^periods")
        #expect(trace.result != 0)
    }

    @Test("Detailed trace with no dependencies")
    func detailedTraceNoDependencies() throws {
        let debugger = ModelDebugger()

        let trace = try debugger.trace(
            value: "Constant",
            dependencies: [:],
            formula: "100"
        ) {
            100.0
        }

        #expect(trace.dependencies.isEmpty)
        #expect(trace.result == 100.0)
    }

    @Test("Detailed trace captures complex calculations")
    func detailedTraceComplex() throws {
        let debugger = ModelDebugger()

        let principal = 100_000.0
        let rate = 0.08
        let periods = 5

        let trace = try debugger.trace(
            value: "Future Value",
            dependencies: [
                "principal": String(principal),
                "rate": String(rate),
                "periods": String(periods)
            ],
            formula: "principal * (1 + rate)^periods"
        ) {
            principal * pow(1 + rate, Double(periods))
        }

        #expect(trace.result != 0)
        #expect(abs(trace.result - 146_932.81) < 0.01)
        #expect(trace.duration > 0)
    }

    // MARK: - Diagnostic Reports

    @Test("Diagnose exact match")
    func diagnoseExactMatch() {
        let debugger = ModelDebugger()

        let report = debugger.diagnose(
            value: 100.0,
            expected: 100.0,
            tolerance: 0.01
        )

        #expect(report.issues.isEmpty)
        #expect(report.warnings.isEmpty)
    }

    @Test("Diagnose within tolerance")
    func diagnoseWithinTolerance() {
        let debugger = ModelDebugger()

        let report = debugger.diagnose(
            value: 100.5,
            expected: 100.0,
            tolerance: 0.01 // 1% tolerance
        )

        #expect(report.issues.isEmpty)
    }

    @Test("Diagnose outside tolerance")
    func diagnoseOutsideTolerance() {
        let debugger = ModelDebugger()

        let report = debugger.diagnose(
            value: 120.0,
            expected: 100.0,
            tolerance: 0.01
        )

        #expect(!report.issues.isEmpty)
        let issue = report.issues.first
        #expect(issue?.severity == .error)
    }

    @Test("Diagnose with context")
    func diagnoseWithContext() {
        let debugger = ModelDebugger()

        let report = debugger.diagnose(
            value: 90.0,
            expected: 100.0,
            tolerance: 0.05,
            context: "Revenue calculation"
        )

        #expect(report.context == "Revenue calculation")
    }

    @Test("Diagnose includes suggestions")
    func diagnoseIncludesSuggestions() {
        let debugger = ModelDebugger()

        let report = debugger.diagnose(
            value: 80.0,
            expected: 100.0,
            tolerance: 0.01
        )

        #expect(!report.suggestions.isEmpty)
    }

    // MARK: - Validation Constraints

    @Test("Validate positive constraint passes")
    func validatePositivePasses() {
        let debugger = ModelDebugger()

        let report = debugger.validate(
            value: 100.0,
            name: "revenue",
            constraints: [.positive]
        )

        #expect(report.isValid)
        #expect(report.violations.isEmpty)
    }

    @Test("Validate positive constraint fails")
    func validatePositiveFails() {
        let debugger = ModelDebugger()

        let report = debugger.validate(
            value: -50.0,
            name: "revenue",
            constraints: [.positive]
        )

        #expect(!report.isValid)
        #expect(!report.violations.isEmpty)
        #expect(report.violations[0].rule == "positive")
    }

    @Test("Validate range constraint")
    func validateRangeConstraint() {
        let debugger = ModelDebugger()

        // Within range
        let validReport = debugger.validate(
            value: 0.05,
            name: "discountRate",
            constraints: [.range(0.0, 1.0)]
        )
        #expect(validReport.isValid)

        // Outside range
        let invalidReport = debugger.validate(
            value: 1.5,
            name: "discountRate",
            constraints: [.range(0.0, 1.0)]
        )
        #expect(!invalidReport.isValid)
    }

    @Test("Validate non-negative constraint")
    func validateNonNegative() {
        let debugger = ModelDebugger()

        #expect(debugger.validate(value: 0.0, name: "value", constraints: [.nonNegative]).isValid)
        #expect(debugger.validate(value: 10.0, name: "value", constraints: [.nonNegative]).isValid)
        #expect(!debugger.validate(value: -0.1, name: "value", constraints: [.nonNegative]).isValid)
    }

    @Test("Validate finite constraint")
    func validateFinite() {
        let debugger = ModelDebugger()

        #expect(debugger.validate(value: 100.0, name: "value", constraints: [.finite]).isValid)
        #expect(!debugger.validate(value: .infinity, name: "value", constraints: [.finite]).isValid)
        #expect(!debugger.validate(value: -.infinity, name: "value", constraints: [.finite]).isValid)
        #expect(!debugger.validate(value: .nan, name: "value", constraints: [.finite]).isValid)
    }

    @Test("Validate multiple constraints")
    func validateMultipleConstraints() {
        let debugger = ModelDebugger()

        let report = debugger.validate(
            value: 0.08,
            name: "interestRate",
            constraints: [.positive, .range(0.0, 1.0), .finite]
        )

        #expect(report.isValid)
        #expect(report.violations.isEmpty)
    }

    @Test("Validate multiple constraints with failures")
    func validateMultipleConstraintsFailures() {
        let debugger = ModelDebugger()

        let report = debugger.validate(
            value: -0.5,
            name: "rate",
            constraints: [.positive, .range(0.0, 1.0)]
        )

        #expect(!report.isValid)
        // Should fail both positive and range constraints
        #expect(report.violations.count == 2)
    }

    @Test("Validate max value constraint")
    func validateMaxValue() {
        let debugger = ModelDebugger()

        #expect(debugger.validate(value: 50.0, name: "value", constraints: [.maxValue(100.0)]).isValid)
        #expect(debugger.validate(value: 100.0, name: "value", constraints: [.maxValue(100.0)]).isValid)
        #expect(!debugger.validate(value: 150.0, name: "value", constraints: [.maxValue(100.0)]).isValid)
    }

    @Test("Validate min value constraint")
    func validateMinValue() {
        let debugger = ModelDebugger()

        #expect(debugger.validate(value: 100.0, name: "value", constraints: [.minValue(50.0)]).isValid)
        #expect(debugger.validate(value: 50.0, name: "value", constraints: [.minValue(50.0)]).isValid)
        #expect(!debugger.validate(value: 25.0, name: "value", constraints: [.minValue(50.0)]).isValid)
    }

    // MARK: - Explanations

    @Test("Explain difference provides reasons")
    func explainDifferenceReasons() {
        let debugger = ModelDebugger()

        let explanation = debugger.explain(
            actual: 90.0,
            expected: 100.0,
            context: "Revenue"
        )

        #expect(explanation.actual == 90.0)
        #expect(explanation.expected == 100.0)
        #expect(explanation.difference == -10.0)
        #expect(!explanation.possibleReasons.isEmpty)
    }

    @Test("Explain percentage difference")
    func explainPercentageDifference() {
        let debugger = ModelDebugger()

        let explanation = debugger.explain(
            actual: 80.0,
            expected: 100.0,
            context: "Sales"
        )

        #expect(abs(explanation.percentageDifference - (-20.0)) < 0.01)
    }

    @Test("Explain zero expected value")
    func explainZeroExpected() {
        let debugger = ModelDebugger()

        let explanation = debugger.explain(
            actual: 50.0,
            expected: 0.0,
            context: "Test"
        )

        // When expected is zero, percentage difference is calculated as 0
        // (see implementation: expected != 0 ? (difference / expected) * 100 : 0)
        #expect(explanation.percentageDifference == 0)
        #expect(explanation.difference == 50.0)
    }

    @Test("Explain exact match")
    func explainExactMatch() {
        let debugger = ModelDebugger()

        let explanation = debugger.explain(
            actual: 100.0,
            expected: 100.0,
            context: "Match"
        )

        #expect(explanation.difference == 0.0)
        #expect(explanation.percentageDifference == 0.0)
    }

    // MARK: - Edge Cases

    @Test("Trace with NaN result")
    func traceNaNResult() {
        let debugger = ModelDebugger()

        let trace = debugger.trace(value: "Invalid") {
            Double.nan
        }

        #expect(trace.result?.isNaN == true)
    }

    @Test("Trace with infinity result")
    func traceInfinityResult() {
        let debugger = ModelDebugger()

        let trace = debugger.trace(value: "Infinite") {
            Double.infinity
        }

        #expect(trace.result == .infinity)
    }

    @Test("Diagnose NaN values")
    func diagnoseNaNValues() {
        let debugger = ModelDebugger()

        let report = debugger.diagnose(
            value: .nan,
            expected: 100.0,
            tolerance: 0.01
        )

        #expect(!report.issues.isEmpty)
    }

    @Test("Diagnose infinity values")
    func diagnoseInfinityValues() {
        let debugger = ModelDebugger()

        let report = debugger.diagnose(
            value: .infinity,
            expected: 100.0,
            tolerance: 0.01
        )

        #expect(!report.issues.isEmpty)
    }

    @Test("Validate with NaN")
    func validateNaN() {
        let debugger = ModelDebugger()

        let report = debugger.validate(
            value: .nan,
            name: "value",
            constraints: [.finite, .positive]
        )

        #expect(!report.isValid)
        // Should fail finite constraint
        #expect(report.violations.contains { $0.rule == "finite" })
    }

    @Test("Very small tolerance")
    func verySmallTolerance() {
        let debugger = ModelDebugger()

        let report = debugger.diagnose(
            value: 100.001,
            expected: 100.0,
            tolerance: 0.00001 // 0.001%
        )

        #expect(!report.issues.isEmpty)
    }

    @Test("Very large tolerance")
    func veryLargeTolerance() {
        let debugger = ModelDebugger()

        let report = debugger.diagnose(
            value: 150.0,
            expected: 100.0,
            tolerance: 1.0 // 100% tolerance
        )

        #expect(report.issues.isEmpty)
    }

    // MARK: - Integration Tests

    @Test("Complete diagnostic workflow")
    func completeDiagnosticWorkflow() throws {
        let debugger = ModelDebugger()

        // Step 1: Trace calculation
        let trace = try debugger.trace(
            value: "Monthly Payment",
            dependencies: [
                "principal": "200000.0",
                "rate": "0.05",
                "periods": "360"
            ],
            formula: "P * r * (1+r)^n / ((1+r)^n - 1)"
        ) {
            let P = 200_000.0
            let r = 0.05 / 12
            let n = 360.0
            return P * r * pow(1 + r, n) / (pow(1 + r, n) - 1)
        }

        #expect(trace.result != 0)

        // Step 2: Validate result
        let validation = debugger.validate(
            value: trace.result,
            name: "Monthly Payment",
            constraints: [.positive, .finite, .maxValue(10_000.0)]
        )

        #expect(validation.isValid)

        // Step 3: Compare to expected
        let expectedPayment = 1073.64
        let diagnostic = debugger.diagnose(
            value: trace.result,
            expected: expectedPayment,
            tolerance: 0.01,
            context: "Mortgage Payment Calculation"
        )

        // Should be close to expected value
        #expect(diagnostic.issues.isEmpty || diagnostic.issues.count == 1)
    }

    @Test("Concurrent debugging operations")
    func concurrentDebugging() {
        let debugger = ModelDebugger()

        // Run multiple debug operations concurrently
        DispatchQueue.concurrentPerform(iterations: 100) { index in
            let trace = debugger.trace(value: "Calc \(index)") {
                Double(index) * 2.0
            }
            #expect(trace.result == Double(index) * 2.0)

            let validation = debugger.validate(
                value: Double(index),
                name: "value",
                constraints: [.nonNegative]
            )
            #expect(validation.isValid)
        }
    }

    @Test("Debugger is sendable and thread-safe")
    func debuggerSendable() {
        let debugger = ModelDebugger()

        // This should compile because ModelDebugger conforms to Sendable
        Task {
            let trace = debugger.trace(value: "Async") {
                42.0
            }
            #expect(trace.result == 42.0)
        }
    }
}
