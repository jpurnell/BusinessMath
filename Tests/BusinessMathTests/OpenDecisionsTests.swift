//
//  OpenDecisionsTests.swift
//  BusinessMath
//
//  The four items the contaminated-input campaign left open because they needed a
//  judgement rather than a guard.
//

import Testing
import Foundation
@testable import BusinessMath

/// Pins the four decisions taken after the five-phase contaminated-input campaign closed.
///
/// Each of these was found by the campaign and deliberately *not* fixed by it, because the
/// question was not "is this a defect" but "what should this API say instead" — a severity, a
/// scope, a trap, a spelling. What they have in common is that the old behaviour was the most
/// reassuring answer the return type could give: `isValid == true`, `"✅ Model is valid"`,
/// an empty bottleneck list, a report and a data column that disagreed about the same value.
///
/// Every test here is paired with a control that held before the decision as well as after.
/// The controls are the evidence that each change is targeted: a pre-revenue model still
/// validates, an all-finite model is still clean, a finite threshold still selects, and the
/// CSV spelling is unchanged.
@Suite("Open decisions after the contaminated-input campaign")
struct OpenDecisionsTests {

    // MARK: - Fixtures

    private func quarters() -> [Period] {
        [
            Period.quarter(year: 2026, quarter: 1),
            Period.quarter(year: 2026, quarter: 2)
        ]
    }

    // MARK: - Decision 1 — negative revenue is an error

    /// The pair that proves the change is targeted rather than a blanket tightening.
    ///
    /// Before this, `FinancialModel.validate()` could not return `isValid == false` for any
    /// reason of its own: empty was `.info`, costs-without-revenue and negative revenue were
    /// both `.warning`, and `isValid` is `!hasErrors`. Revenue below zero is now an error —
    /// a sign error or a contaminated input, not something a caller meant — while a
    /// pre-revenue company, which is an ordinary thing to model, keeps validating.
    @Test("A pre-revenue model still validates; a negative-revenue model does not")
    func negativeRevenueIsAnErrorAndPreRevenueIsNot() {
        var preRevenue = FinancialModel()
        preRevenue.costComponents.append(CostComponent(name: "Salaries", type: .fixed(50_000)))
        let preRevenueResult = preRevenue.validate()

        #expect(preRevenueResult.isValid, "A company before its first sale must keep validating")
        #expect(preRevenueResult.errors.isEmpty)
        #expect(preRevenueResult.warningsOnly.count == 1, "Costs without revenue is still worth saying, at warning severity")

        var negative = FinancialModel()
        negative.revenueComponents.append(RevenueComponent(name: "Product", amount: -1.0))
        let negativeResult = negative.validate()

        #expect(!negativeResult.isValid, "Revenue below zero is a sign error, not a modelling choice")
        #expect(negativeResult.errors.count == 1)
        #expect(negativeResult.warningsOnly.isEmpty, "The negative case moved out of the warning tier, it was not duplicated into both")

        let message: String = negativeResult.errors[0].message
        #expect(message.contains("negative value"))
        let reportedValue: String = negativeResult.errors[0].context["value"] ?? ""
        #expect(reportedValue.contains("-1"), "The offending amount travels with the error: \(reportedValue)")
    }

    /// The controls: the two severities this decision did not touch.
    ///
    /// An entirely empty model is still `.info` and still valid — there is nothing wrong with
    /// it, it is merely unbuilt — and an ordinary positive model produces nothing at all.
    @Test("An empty model is still information, and a positive model is still silent")
    func validateControlsAreUnchanged() {
        let empty = FinancialModel()
        let emptyResult = empty.validate()

        #expect(emptyResult.isValid)
        #expect(emptyResult.info.count == 1)
        #expect(emptyResult.errors.isEmpty)

        var good = FinancialModel()
        good.revenueComponents.append(RevenueComponent(name: "Product", amount: 1_000.0))
        good.costComponents.append(CostComponent(name: "Salaries", type: .fixed(400.0)))
        let goodResult = good.validate()

        #expect(goodResult.isValid)
        #expect(goodResult.warnings.isEmpty, "A complete, finite, positive model has nothing to report")
    }

    /// Revenue that is zero is not negative, and must not be swept up by the new severity.
    ///
    /// `0 < 0` is false, so this is a statement about the boundary rather than a new
    /// mechanism — but a free trial, a pre-launch line item and a discontinued product all
    /// legitimately sit at exactly zero, and reporting them as errors would be the same
    /// mistake in the opposite direction.
    @Test("Revenue of exactly zero is not an error")
    func zeroRevenueIsNotAnError() {
        var zero = FinancialModel()
        zero.revenueComponents.append(RevenueComponent(name: "Free Tier", amount: 0.0))
        let result = zero.validate()

        #expect(result.isValid)
        #expect(result.errors.isEmpty)
    }

    // MARK: - Decision 2 — ModelDebugger.validate scans both sides

    /// `validate(_:)` checked only `revenueComponents`, so a model whose entire cost series
    /// was `NaN` came back `isValid` with the summary `"✅ Model is valid"` — the most
    /// reassuring sentence this method has, about a model half of which it never looked at.
    /// Its sibling `findMissingData(in:)` had the identical gap and was widened first.
    @Test("A cost series full of NaN is no longer reported as a valid model")
    func validateScansCostComponents() async {
        let periods = quarters()
        var model = FinancialModel()
        model.revenueComponents.append(RevenueComponent(name: "Product", periods: periods, values: [100.0, 110.0]))
        model.costComponents.append(CostComponent(name: "Hosting", periods: periods, values: [Double.nan, Double.nan]))

        let debugger = ModelDebugger()
        let report = await debugger.validate(model)

        #expect(!report.isValid)
        #expect(report.errors.count == 2, "One error per unusable period, not one per component")

        let messages: String = report.errors.map(\.message).joined(separator: " | ")
        #expect(messages.contains("cost 'Hosting'"), "The error names the side of the model it came from: \(messages)")
        #expect(!report.summary.contains("Model is valid"), "Summary was: \(report.summary)")
    }

    /// A revenue and a cost component may share a name. Both must be reported.
    ///
    /// This is the analogue of `findMissingData(in:)`'s merge-on-collision: there the two
    /// components' periods merge into one key instead of one overwriting the other; here the
    /// errors are a list, so nothing can be displaced — but each error still has to say which
    /// side it came from, or the caller sees two identical sentences about one name.
    @Test("Two components sharing a name both report, and say which side they are")
    func validateDistinguishesSidesSharingAName() async {
        let periods = quarters()
        var model = FinancialModel()
        model.revenueComponents.append(RevenueComponent(name: "Ops", periods: periods, values: [Double.nan, 110.0]))
        model.costComponents.append(CostComponent(name: "Ops", periods: periods, values: [50.0, Double.nan]))

        let debugger = ModelDebugger()
        let report = await debugger.validate(model)

        #expect(report.errors.count == 2)

        let fields: [String] = report.errors.map(\.field)
        #expect(fields == ["Ops", "Ops"], "The field stays the component name, which is what a caller filters on")

        let messages: String = report.errors.map(\.message).joined(separator: " | ")
        #expect(messages.contains("revenue 'Ops'"), "Messages were: \(messages)")
        #expect(messages.contains("cost 'Ops'"), "Messages were: \(messages)")
    }

    /// The controls: an all-finite model is still clean, and the revenue side still reports.
    ///
    /// The second half is what shows the widening added a scan rather than moving one.
    @Test("An all-finite model is still valid and a NaN revenue is still caught")
    func validateControlsBothSides() async {
        let periods = quarters()
        var clean = FinancialModel()
        clean.revenueComponents.append(RevenueComponent(name: "Product", periods: periods, values: [100.0, 110.0]))
        clean.costComponents.append(CostComponent(name: "Hosting", periods: periods, values: [40.0, 45.0]))

        let debugger = ModelDebugger()
        let cleanReport = await debugger.validate(clean)

        #expect(cleanReport.isValid)
        #expect(cleanReport.errors.isEmpty)
        #expect(cleanReport.summary.contains("Model is valid"))

        var contaminatedRevenue = FinancialModel()
        contaminatedRevenue.revenueComponents.append(
            RevenueComponent(name: "Product", periods: periods, values: [Double.nan, 110.0])
        )
        let revenueReport = await debugger.validate(contaminatedRevenue)

        #expect(!revenueReport.isValid)
        #expect(revenueReport.errors.count == 1)
        let rule: String = revenueReport.errors[0].rule
        #expect(rule == "no-nan-values")
    }

    /// An infinite reading is *not* an error here, and that is deliberate.
    ///
    /// The contaminated-input contract (§3.6) leaves infinities alone unless they break the
    /// specific computation: they order and compare correctly and are a legitimate
    /// observation. The rule this method reports under is `no-nan-values`, and it means what
    /// it says. `findMissingData(in:)` answers a different question — *where are the gaps* —
    /// and does count an infinity, which is why the two are pinned together here.
    @Test("An infinite reading is not a validation error, but is still missing data")
    func infinityIsNotAValidationError() async throws {
        let periods = quarters()
        var model = FinancialModel()
        model.costComponents.append(
            CostComponent(name: "Hosting", periods: periods, values: [Double.infinity, 45.0])
        )

        let debugger = ModelDebugger()
        let report = await debugger.validate(model)

        #expect(report.isValid, "Infinity is an observation, not an unreadable value")
        #expect(report.errors.isEmpty)

        let missing = await debugger.findMissingData(in: model)
        let hosting = try #require(missing["Hosting"])
        #expect(hosting.count == 1, "The gap finder does count it, and that asymmetry is the decision")
    }

    // MARK: - Decision 3 — a non-finite threshold is refused

    /// The guarded path: a finite threshold still selects exactly the operations above it.
    ///
    /// The durations are stated by the test through `ManualElapsedTimeSource` rather than
    /// measured, so nothing here depends on how fast the machine is.
    @Test("A finite threshold still selects the operations above it")
    func finiteThresholdStillSelects() async {
        let time = ManualElapsedTimeSource()
        let profiler = ModelProfiler(elapsedTime: time)

        await profiler.measure(operation: "Fast") {
            time.advance(by: .milliseconds(10))
        }
        await profiler.measure(operation: "Slow") {
            time.advance(by: .milliseconds(400))
        }

        // 10ms and 400ms straddle 50ms, so exactly one operation is above the threshold.
        let selected = await profiler.bottlenecks(threshold: 0.050)

        #expect(selected.count == 1)
        #expect(selected[0].operation == "Slow")

        // And a threshold above both selects neither — the empty list is a real answer, which
        // is precisely why a NaN threshold must not be able to produce it.
        let none = await profiler.bottlenecks(threshold: 1.0)
        #expect(none.isEmpty)
    }

    /// An infinite threshold is accepted, because it still compares.
    ///
    /// `+∞` selects nothing and `-∞` selects everything; both are answers a caller can act on,
    /// so neither is refused. Only `NaN` — against which every comparison is false — has no
    /// answer at all, and that is the line the trap is drawn on.
    @Test("An infinite threshold is answerable and is not refused")
    func infiniteThresholdIsAnswerable() async {
        let time = ManualElapsedTimeSource()
        let profiler = ModelProfiler(elapsedTime: time)

        await profiler.measure(operation: "Only") {
            time.advance(by: .milliseconds(100))
        }

        let aboveEverything = await profiler.bottlenecks(threshold: Double.infinity)
        #expect(aboveEverything.isEmpty, "Nothing is slower than infinity")

        let belowEverything = await profiler.bottlenecks(threshold: -Double.infinity)
        #expect(belowEverything.count == 1, "Everything is slower than negative infinity")
    }

    /// A `NaN` threshold traps rather than answering "no bottlenecks".
    ///
    /// Both entry points are refused. `bottlenecks(threshold: .nan)` returned `[]` — every
    /// comparison against `NaN` being false — from a run in which nothing had been examined,
    /// and `[OperationStatistics]` has no room to say "not answerable" because the empty list
    /// is already spoken for. `setWarningThreshold(.nan)` was worse: it silenced every
    /// subsequent warning for the life of the profiler, with no result to inspect at all.
    ///
    /// Neither was made `throws`. Both are public and both would become source-breaking at
    /// every call site, including the ones in the debugging guide; and a threshold is a
    /// parameter a programmer wrote rather than data an analyst was handed, which is the case
    /// `preconditionFailure` exists for.
    @Test("A NaN threshold traps rather than silently reporting nothing",
          .requiresUnsanitizedRuntime)
    func nanThresholdTraps() async {
        await #expect(processExitsWith: .failure) {
            let profiler = ModelProfiler()
            _ = await profiler.bottlenecks(threshold: Double.nan)
        }

        await #expect(processExitsWith: .failure) {
            let profiler = ModelProfiler()
            await profiler.setWarningThreshold(Double.nan)
        }
    }

    // MARK: - Decision 4 — one spelling per audience

    /// The display formatters now spell a non-finite value for a person.
    ///
    /// They used to fall through to `String(describing:)`, which writes `nan` and `inf` — the
    /// spelling a *parser* wants — from a type whose documented job is "clean, readable
    /// output". So one library emitted two different renderings of the same value with
    /// nothing to say which was which.
    @Test("Every display strategy renders a non-finite value the same, readable way")
    func displayStrategiesAgree() {
        let smart = FloatingPointFormatter(strategy: .smartRounding())
        #expect(smart.format(Double.nan).formatted == "NaN")
        #expect(smart.format(Double.infinity).formatted == "∞")
        #expect(smart.format(-Double.infinity).formatted == "-∞")

        let sigFigs = FloatingPointFormatter(strategy: .significantFigures(count: 3))
        #expect(sigFigs.format(Double.nan).formatted == "NaN")
        #expect(sigFigs.format(Double.infinity).formatted == "∞")
        #expect(sigFigs.format(-Double.infinity).formatted == "-∞")

        let contextAware = FloatingPointFormatter(strategy: .contextAware())
        #expect(contextAware.format(Double.nan).formatted == "NaN")
        #expect(contextAware.format(Double.infinity).formatted == "∞")
        #expect(contextAware.format(-Double.infinity).formatted == "-∞")

        // The sign survives. `-∞` and `∞` are different answers, and a reader who is handed
        // the wrong one has no way to recover which was meant. (`percent()`, in
        // `Extensions/extensionFormatted.swift`, still drops it — that file is outside this
        // change and the discrepancy is reported rather than fixed here.)
        #expect(smart.format(-Double.infinity).formatted != smart.format(Double.infinity).formatted)
    }

    /// The display family agrees with the presentation formatters it sits beside.
    ///
    /// `percent()` hard-codes `"NaN"` and `"∞"` ahead of its locale-aware path; the formatter
    /// now produces the same two strings, which is what "consistent with each other" means
    /// here.
    @Test("The formatter and percent() spell the same value the same way")
    func displayFamilyAgreesWithPercent() {
        let smart = FloatingPointFormatter(strategy: .smartRounding())

        let formatterNaN: String = smart.format(Double.nan).formatted
        let percentNaN: String = Double.nan.percent()
        #expect(formatterNaN == percentNaN)

        let formatterInfinity: String = smart.format(Double.infinity).formatted
        let percentInfinity: String = Double.infinity.percent()
        #expect(formatterInfinity == percentInfinity)
    }

    /// The CSV spelling is unchanged, and that is the point of the pair.
    ///
    /// Lowercase ASCII is what round-trips through `Double(_: String)`, `strtod` and pandas,
    /// and it is locale-invariant. After this decision the lowercase spelling means exactly
    /// one thing — *this field is going to be parsed* — because it no longer appears anywhere
    /// a person is meant to read.
    @Test("The CSV tokens are unchanged and still differ from the display ones")
    func csvTokensAreUnchanged() {
        #expect(csvNumber(Double.nan) == "nan")
        #expect(csvNumber(Double.infinity) == "inf")
        #expect(csvNumber(-Double.infinity) == "-inf")

        let display = FloatingPointFormatter(strategy: .smartRounding())
        let displayNaN: String = display.format(Double.nan).formatted
        let machineNaN: String = csvNumber(Double.nan)
        #expect(displayNaN != machineNaN, "The two spellings are a decision, not an accident")

        // A finite value is spelled the same by both — the split is only about the three
        // values a CSV parser needs a token for.
        #expect(csvNumber(2.5) == "2.5")
    }

    /// `.raw` is the documented exception and keeps `String(describing:)`.
    ///
    /// Its contract is Swift's own rendering rather than a presented one, so a caller who
    /// reached for it asked for the unformatted value and must keep getting it.
    @Test("The raw formatter still gives Swift's own rendering")
    func rawFormatterIsUnchanged() {
        #expect(FloatingPointFormatter.raw.format(Double.nan).formatted == "nan")
        #expect(FloatingPointFormatter.raw.format(Double.infinity).formatted == "inf")
    }
}
