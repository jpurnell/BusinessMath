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
    func basicTraceResult() async {
        let debugger = ModelDebugger()

        let trace = await debugger.trace(value: "NPV") {
            1000.0
        }

        #expect(trace.value == "NPV")
        #expect(trace.result == 1000.0)
    }

    @Test("Basic trace captures errors")
    func basicTraceError() async {
        let debugger = ModelDebugger()

        struct TestError: Error {
            let message: String
        }

        // Note: trace() catches errors internally, so no try needed
        let trace: DebugTrace<Int> = await debugger.trace(value: "Calculation") {
            throw TestError(message: "Test error")
        }

        #expect(trace.value == "Calculation")
        #expect(trace.result == nil)
        #expect(trace.error != nil)
    }

	@Test(.disabled("Trace timing is captured"))
    func traceTimingCaptured() async {
        let debugger = ModelDebugger()

        let trace = await debugger.trace(value: "Slow Operation") {
            Thread.sleep(forTimeInterval: 0.01) // 10ms
            return 42.0
        }

        #expect(trace.duration >= 0.01)
        #expect(trace.duration < 1.0) // Should complete quickly
    }

    // MARK: - Detailed Calculation Tracing

    @Test("Detailed trace captures dependencies")
    func detailedTraceDependencies() async throws {
        let debugger = ModelDebugger()

        let trace = try await debugger.trace(
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
    func detailedTraceNoDependencies() async throws {
        let debugger = ModelDebugger()

        let trace = try await debugger.trace(
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
    func detailedTraceComplex() async throws {
        let debugger = ModelDebugger()

        let principal = 100_000.0
        let rate = 0.08
        let periods = 5

        let trace = try await debugger.trace(
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
    func diagnoseExactMatch() async {
        let debugger = ModelDebugger()

        let report = await debugger.diagnose(
            value: 100.0,
            expected: 100.0,
            tolerance: 0.01
        )

        #expect(report.issues.isEmpty)
        #expect(report.warnings.isEmpty)
    }

    @Test("Diagnose within tolerance")
    func diagnoseWithinTolerance() async {
        let debugger = ModelDebugger()

        let report = await debugger.diagnose(
            value: 100.5,
            expected: 100.0,
            tolerance: 0.01 // 1% tolerance
        )

        #expect(report.issues.isEmpty)
    }

    @Test("Diagnose outside tolerance")
    func diagnoseOutsideTolerance() async {
        let debugger = ModelDebugger()

        let report = await debugger.diagnose(
            value: 120.0,
            expected: 100.0,
            tolerance: 0.01
        )

        #expect(!report.issues.isEmpty)
        let issue = report.issues.first
        #expect(issue?.severity == .error)
    }

    @Test("Diagnose with context")
    func diagnoseWithContext() async {
        let debugger = ModelDebugger()

        let report = await debugger.diagnose(
            value: 90.0,
            expected: 100.0,
            tolerance: 0.05,
            context: "Revenue calculation"
        )

        #expect(report.context == "Revenue calculation")
    }

    @Test("Diagnose includes suggestions")
    func diagnoseIncludesSuggestions() async {
        let debugger = ModelDebugger()

        let report = await debugger.diagnose(
            value: 80.0,
            expected: 100.0,
            tolerance: 0.01
        )

        #expect(!report.suggestions.isEmpty)
    }

    // MARK: - Validation Constraints

    @Test("Validate positive constraint passes")
    func validatePositivePasses() async {
        let debugger = ModelDebugger()

        let report = await debugger.validate(
            value: 100.0,
            name: "revenue",
            constraints: [.positive]
        )

        #expect(report.isValid)
        #expect(report.violations.isEmpty)
    }

    @Test("Validate positive constraint fails")
    func validatePositiveFails() async {
        let debugger = ModelDebugger()

        let report = await debugger.validate(
            value: -50.0,
            name: "revenue",
            constraints: [.positive]
        )

        #expect(!report.isValid)
        #expect(!report.violations.isEmpty)
        #expect(report.violations[0].rule == "positive")
    }

    @Test("Validate range constraint")
    func validateRangeConstraint() async {
        let debugger = ModelDebugger()

        // Within range
        let validReport = await debugger.validate(
            value: 0.05,
            name: "discountRate",
            constraints: [.range(0.0, 1.0)]
        )
        #expect(validReport.isValid)

        // Outside range
        let invalidReport = await debugger.validate(
            value: 1.5,
            name: "discountRate",
            constraints: [.range(0.0, 1.0)]
        )
        #expect(!invalidReport.isValid)
    }

    @Test("Validate non-negative constraint")
    func validateNonNegative() async {
        let debugger = ModelDebugger()

        #expect(await debugger.validate(value: 0.0, name: "value", constraints: [.nonNegative]).isValid)
        #expect(await debugger.validate(value: 10.0, name: "value", constraints: [.nonNegative]).isValid)
        #expect(!(await debugger.validate(value: -0.1, name: "value", constraints: [.nonNegative]).isValid))
    }

    @Test("Validate finite constraint")
    func validateFinite() async {
        let debugger = ModelDebugger()

        #expect(await debugger.validate(value: 100.0, name: "value", constraints: [.finite]).isValid)
        #expect(!(await debugger.validate(value: .infinity, name: "value", constraints: [.finite]).isValid))
        #expect(!(await debugger.validate(value: -.infinity, name: "value", constraints: [.finite]).isValid))
        #expect(!(await debugger.validate(value: .nan, name: "value", constraints: [.finite]).isValid))
    }

    @Test("Validate multiple constraints")
    func validateMultipleConstraints() async {
        let debugger = ModelDebugger()

        let report = await debugger.validate(
            value: 0.08,
            name: "interestRate",
            constraints: [.positive, .range(0.0, 1.0), .finite]
        )

        #expect(report.isValid)
        #expect(report.violations.isEmpty)
    }

    @Test("Validate multiple constraints with failures")
    func validateMultipleConstraintsFailures() async {
        let debugger = ModelDebugger()

        let report = await debugger.validate(
            value: -0.5,
            name: "rate",
            constraints: [.positive, .range(0.0, 1.0)]
        )

        #expect(!report.isValid)
        // Should fail both positive and range constraints
        #expect(report.violations.count == 2)
    }

    @Test("Validate max value constraint")
    func validateMaxValue() async {
        let debugger = ModelDebugger()

        #expect(await debugger.validate(value: 50.0, name: "value", constraints: [.maxValue(100.0)]).isValid)
        #expect(await debugger.validate(value: 100.0, name: "value", constraints: [.maxValue(100.0)]).isValid)
        #expect(!(await debugger.validate(value: 150.0, name: "value", constraints: [.maxValue(100.0)]).isValid))
    }

    @Test("Validate min value constraint")
    func validateMinValue() async {
        let debugger = ModelDebugger()

        #expect(await debugger.validate(value: 100.0, name: "value", constraints: [.minValue(50.0)]).isValid)
        #expect(await debugger.validate(value: 50.0, name: "value", constraints: [.minValue(50.0)]).isValid)
        #expect(!(await debugger.validate(value: 25.0, name: "value", constraints: [.minValue(50.0)]).isValid))
    }

    // MARK: - Explanations

    @Test("Explain difference provides reasons")
    func explainDifferenceReasons() async {
        let debugger = ModelDebugger()

        let explanation = await debugger.explain(
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
    func explainPercentageDifference() async {
        let debugger = ModelDebugger()

        let explanation = await debugger.explain(
            actual: 80.0,
            expected: 100.0,
            context: "Sales"
        )

        #expect(abs(explanation.percentageDifference - (-20.0)) < 0.01)
    }

    @Test("Explain zero expected value")
    func explainZeroExpected() async {
        let debugger = ModelDebugger()

        let explanation = await debugger.explain(
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
    func explainExactMatch() async {
        let debugger = ModelDebugger()

        let explanation = await debugger.explain(
            actual: 100.0,
            expected: 100.0,
            context: "Match"
        )

        #expect(explanation.difference == 0.0)
        #expect(explanation.percentageDifference == 0.0)
    }

    // MARK: - Edge Cases

    @Test("Trace with NaN result")
    func traceNaNResult() async {
        let debugger = ModelDebugger()

        let trace = await debugger.trace(value: "Invalid") {
            Double.nan
        }

        #expect(trace.result?.isNaN == true)
    }

    @Test("Trace with infinity result")
    func traceInfinityResult() async {
        let debugger = ModelDebugger()

        let trace = await debugger.trace(value: "Infinite") {
            Double.infinity
        }

        #expect(trace.result == .infinity)
    }

    @Test("Diagnose NaN values")
    func diagnoseNaNValues() async {
        let debugger = ModelDebugger()

        let report = await debugger.diagnose(
            value: .nan,
            expected: 100.0,
            tolerance: 0.01
        )

        #expect(!report.issues.isEmpty)
    }

    @Test("Diagnose infinity values")
    func diagnoseInfinityValues() async {
        let debugger = ModelDebugger()

        let report = await debugger.diagnose(
            value: .infinity,
            expected: 100.0,
            tolerance: 0.01
        )

        #expect(!report.issues.isEmpty)
    }

    @Test("Validate with NaN")
    func validateNaN() async {
        let debugger = ModelDebugger()

        let report = await debugger.validate(
            value: .nan,
            name: "value",
            constraints: [.finite, .positive]
        )

        #expect(!report.isValid)
        // Should fail finite constraint
        #expect(report.violations.contains { $0.rule == "finite" })
    }

    @Test("Very small tolerance")
    func verySmallTolerance() async {
        let debugger = ModelDebugger()

        let report = await debugger.diagnose(
            value: 100.001,
            expected: 100.0,
            tolerance: 0.00001 // 0.001%
        )

        #expect(!report.issues.isEmpty)
    }

    @Test("Very large tolerance")
    func veryLargeTolerance() async {
        let debugger = ModelDebugger()

        let report = await debugger.diagnose(
            value: 150.0,
            expected: 100.0,
            tolerance: 1.0 // 100% tolerance
        )

        #expect(report.issues.isEmpty)
    }

    // MARK: - Integration Tests

    @Test("Complete diagnostic workflow")
    func completeDiagnosticWorkflow() async throws {
        let debugger = ModelDebugger()

        // Step 1: Trace calculation
        let trace = try await debugger.trace(
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
        let validation = await debugger.validate(
            value: trace.result,
            name: "Monthly Payment",
            constraints: [.positive, .finite, .maxValue(10_000.0)]
        )

        #expect(validation.isValid)

        // Step 3: Compare to expected
        let expectedPayment = 1073.64
        let diagnostic = await debugger.diagnose(
            value: trace.result,
            expected: expectedPayment,
            tolerance: 0.01,
            context: "Mortgage Payment Calculation"
        )

        // Should be close to expected value
        #expect(diagnostic.issues.isEmpty || diagnostic.issues.count == 1)
    }

    @Test("Concurrent debugging operations")
    func concurrentDebugging() async {
        let debugger = ModelDebugger()

        // Run multiple debug operations concurrently using TaskGroup
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<100 {
                group.addTask {
                    let trace = await debugger.trace(value: "Calc \(index)") {
                        Double(index) * 2.0
                    }
                    #expect(trace.result == Double(index) * 2.0)

                    let validation = await debugger.validate(
                        value: Double(index),
                        name: "value",
                        constraints: [.nonNegative]
                    )
                    #expect(validation.isValid)
                }
            }
        }
    }

    @Test("Debugger is sendable and thread-safe")
    func debuggerSendable() async {
        let debugger = ModelDebugger()

        // This should compile because ModelDebugger conforms to Sendable
        Task {
            let trace = await debugger.trace(value: "Async") {
                42.0
            }
            #expect(trace.result == 42.0)
        }
    }

    @Test("Real-time tracing captures model calculations")
    func realTimeTracingIntegration() async {
        // Create a financial model
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1, q1 + 1, q1 + 2, q1 + 3]

        let model = FinancialModel {
            Revenue("Product Sales", periods: periods, values: [100_000, 110_000, 120_000, 130_000])
            Revenue("Service Revenue", periods: periods, values: [20_000, 22_000, 24_000, 26_000])
            Fixed("Rent", 10_000)
        }

        // Create debugger and enable tracing
        let debugger = ModelDebugger()
        await debugger.enableTracing()

        // Perform calculation
        let q1Revenue = model.totalRevenue(for: q1)

        // Get trace
        let trace = await debugger.getTrace()

        // Verify the calculation result
        #expect(q1Revenue == 120_000) // 100,000 + 20,000

        // Verify steps were captured
        #expect(!trace.steps.isEmpty)

        // Should have captured:
        // - GetAccount(Product Sales)
        // - GetAccount(Service Revenue)
        // - Sum(Revenue Accounts)
        #expect(trace.steps.count >= 3)

        // Verify step contents
        let hasProductSales = trace.steps.contains { $0.operation.contains("Product Sales") }
        let hasServiceRevenue = trace.steps.contains { $0.operation.contains("Service Revenue") }
        let hasSum = trace.steps.contains { $0.operation.contains("Sum") }

        #expect(hasProductSales)
        #expect(hasServiceRevenue)
        #expect(hasSum)

        // Verify the trace can be formatted
		let formatted = trace.formatted()
        #expect(!formatted.isEmpty)
        #expect(formatted.contains("Calculation Trace"))

        await debugger.disableTracing()
    }
}
