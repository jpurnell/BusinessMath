//
//  ModelDebuggerZeroExpectedTests.swift
//  BusinessMathTests
//
//  `ModelDebugger.diagnose` and `.explain` both scale their answer by `expected`, and both
//  used to substitute a relative difference of **0** when `expected` was zero — the one
//  value that passes every tolerance and trips no magnitude branch.
//
//  So `diagnose(value: 1_000_000_000, expected: 0)` returned a clean bill of health, and
//  `explain(actual: 50, expected: 0)` published `percentageDifference == 0` for a comparison
//  whose relative difference is unbounded. A diagnostic that under-reports is the worst kind:
//  it is consulted precisely when something is already suspected.
//
//  The mirrored case (`value == 0`, `expected != 0`) was flagged all along, which is what
//  makes this an oversight rather than a policy.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Debugger comparisons against an expected value of zero")
struct ModelDebuggerZeroExpectedTests {

    // MARK: - diagnose

    /// The defect in its plainest form.
    @Test("Diagnose_ZeroExpected_DoesNotWaveThroughAnyValue")
    func diagnoseZeroExpectedDoesNotWaveThroughAnyValue() async {
        let report = await ModelDebugger().diagnose(value: 1_000_000_000, expected: 0)
        #expect(report.hasErrors, "a billion where zero was expected is not a clean result")
        #expect(report.issues.count == 1)
    }

    /// `tolerance` is relative, so with `expected == 0` there is no scale to multiply it by.
    /// Reading it as an absolute bound keeps ordinary numerical residuals quiet — the
    /// `atol` half of the conventional `|a - b| <= atol + rtol * |b|` rule — without
    /// letting a large value through.
    @Test("Diagnose_ZeroExpected_StillToleratesAResidual")
    func diagnoseZeroExpectedStillToleratesAResidual() async {
        let residual = await ModelDebugger().diagnose(value: 1e-12, expected: 0, tolerance: 0.01)
        #expect(!residual.hasErrors, "a 1e-12 residual against zero is within an 0.01 bound")

        let overshoot = await ModelDebugger().diagnose(value: 0.5, expected: 0, tolerance: 0.01)
        #expect(overshoot.hasErrors, "0.5 is not")
    }

    /// Both directions of the zero comparison now report, which is the symmetry the
    /// mirrored warning always implied.
    @Test("Diagnose_ZeroComparison_IsSymmetric")
    func diagnoseZeroComparisonIsSymmetric() async {
        let debugger = ModelDebugger()
        let valueIsZero = await debugger.diagnose(value: 0, expected: 1_000_000_000)
        let expectedIsZero = await debugger.diagnose(value: 1_000_000_000, expected: 0)
        #expect(valueIsZero.hasErrors)
        #expect(expectedIsZero.hasErrors)
    }

    /// A non-finite `expected` gives the comparison nothing to happen against. Saying
    /// nothing reports success for a check that never ran.
    @Test("Diagnose_NonFiniteExpected_IsItselfAnIssue")
    func diagnoseNonFiniteExpectedIsItselfAnIssue() async {
        let debugger = ModelDebugger()
        let againstNaN = await debugger.diagnose(value: 100, expected: .nan)
        let againstInfinity = await debugger.diagnose(value: 100, expected: .infinity)
        #expect(againstNaN.hasErrors, "nothing can be verified against a NaN reference")
        #expect(againstInfinity.hasErrors)
    }

    /// The ordinary relative path is untouched.
    @Test("Diagnose_RelativePath_Unchanged")
    func diagnoseRelativePathUnchanged() async {
        let debugger = ModelDebugger()
        let outside = await debugger.diagnose(value: 110, expected: 100, tolerance: 0.01)
        let inside = await debugger.diagnose(value: 100.5, expected: 100, tolerance: 0.01)
        #expect(outside.hasErrors, "10% against a 1% tolerance")
        #expect(!inside.hasErrors, "0.5% against a 1% tolerance")
    }

    // MARK: - explain

    /// The relative difference between 50 and 0 is not 0%; it is unbounded. Infinity is the
    /// honest value, and `Double.number(_:)` renders it as `∞`, so `formatted()` stays
    /// readable.
    @Test("Explain_ZeroExpected_ReportsAnUnboundedDifference")
    func explainZeroExpectedReportsAnUnboundedDifference() async {
        let explanation = await ModelDebugger().explain(actual: 50.0, expected: 0.0, context: "Test")
        #expect(explanation.percentageDifference.isEqual(to: .infinity))
        #expect(explanation.difference.isEqual(to: 50.0), "the absolute difference is unaffected")
    }

    /// Signed, so the direction of the miss survives.
    @Test("Explain_ZeroExpected_KeepsTheSign")
    func explainZeroExpectedKeepsTheSign() async {
        let explanation = await ModelDebugger().explain(actual: -50.0, expected: 0.0)
        #expect(explanation.percentageDifference.isEqual(to: -.infinity))
    }

    /// The consequence that matters to a caller: with the percentage stuck at 0, the
    /// magnitude analysis below it never fired, so the report offered no guidance at all
    /// for the largest possible discrepancy.
    @Test("Explain_ZeroExpected_ReachesTheLargeDiscrepancyAnalysis")
    func explainZeroExpectedReachesTheLargeDiscrepancyAnalysis() async {
        let explanation = await ModelDebugger().explain(actual: 50.0, expected: 0.0)
        let mentionsMagnitude = explanation.possibleReasons.contains { $0.contains("Large discrepancy") }
        #expect(mentionsMagnitude, "reasons were: \(explanation.possibleReasons)")
    }

    /// Zero against zero is an exact match, not an unbounded difference — the guard has to
    /// separate "no scale" from "no difference".
    @Test("Explain_BothZero_IsAnExactMatch")
    func explainBothZeroIsAnExactMatch() async {
        let explanation = await ModelDebugger().explain(actual: 0.0, expected: 0.0)
        #expect(explanation.percentageDifference.isEqual(to: 0.0))
        let matches = explanation.possibleReasons.contains { $0.contains("match exactly") }
        #expect(matches, "reasons were: \(explanation.possibleReasons)")
    }

    /// The ordinary relative path is untouched.
    @Test("Explain_RelativePath_Unchanged")
    func explainRelativePathUnchanged() async {
        let explanation = await ModelDebugger().explain(actual: 80.0, expected: 100.0)
        #expect(explanation.percentageDifference.isEqual(to: -20.0))
    }
}
