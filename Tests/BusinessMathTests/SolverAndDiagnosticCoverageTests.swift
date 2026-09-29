//
//  SolverAndDiagnosticCoverageTests.swift
//  BusinessMath
//

import Testing
import Foundation
@testable import BusinessMath

/// What the solvers and the diagnostics do about a period nobody supplied a number for.
///
/// The contract is `project/plans/CONTAMINATED_INPUT_CONTRACT.md` §3.7: *narrow the domain; do
/// not fabricate the observation*. These four call sites were the closing batch of that sweep,
/// and two of them sit inside a solver, where the substituted zero is not merely misleading —
/// it is a different system, and Gaussian elimination will return a confident answer to the
/// system it was handed rather than the one the modeller wrote.
///
/// Every refusal here is paired with a control that still produces the right number, because
/// the failure mode of this kind of fix is a guard that refuses everything.
@Suite("Solver and diagnostic period coverage")
struct SolverAndDiagnosticCoverageTests {

	private let jan = Period.month(year: 2026, month: 1)
	private let feb = Period.month(year: 2026, month: 2)

	private var months: [Period] { [jan, feb] }

	private func series(_ values: [Double]) -> TimeSeries<Double> {
		TimeSeries(periods: months, values: values)
	}

	// MARK: - LinearCycleSolver: an absent term and an absent period are not the same thing

	/// A missing coefficient *key* is a genuinely absent term, and has to keep working.
	///
	/// Three accounts round a loop, each formula naming exactly one of the other two. Every row
	/// of `(I − A)` is therefore sparse: two of its three off-diagonal weights have no entry in
	/// `coefficients` at all. That is not a missing observation — the member does not appear in
	/// that equation, so its weight is zero in every period — and a guard that refused it would
	/// make the ordinary case unsolvable.
	///
	/// `a = b + base`, `b = c/2`, `c = a/10` collapses to `a = a/20 + base`, so `a = base/0.95`
	/// exactly. There is no tolerance in the method, only the rounding the same arithmetic
	/// written by hand would carry.
	@Test("A sparse row, where two of three members are absent terms, is still solved exactly")
	func sparseCoefficientsAreNotMissingObservations() throws {
		let solver = LinearCycleSolver<Double>(
			accounts: [
				"base": series([1_000, 1_000]),
				"half": series([0.5, 0.5]),
				"tenth": series([0.1, 0.1])
			],
			members: ["a", "b", "c"],
			formulas: [
				"a": "b + base",
				"b": "c * half",
				"c": "a * tenth"
			]
		)

		let solved = try solver.solve()

		let a: Double = try #require(solved["a"]?[jan])
		let b: Double = try #require(solved["b"]?[jan])
		let c: Double = try #require(solved["c"]?[jan])

		let expectedA: Double = 1_000 / 0.95
		let expectedC: Double = expectedA / 10
		let expectedB: Double = expectedC / 2

		#expect(abs(a - expectedA) <= 1e-9)
		#expect(abs(b - expectedB) <= 1e-9)
		#expect(abs(c - expectedC) <= 1e-9)
	}

	/// The control: every input covers every period, so every period is answered.
	///
	/// The gross-up — a fee charged on a total that includes the fee — is `base / (1 − rate)`.
	@Test("A fully specified cycle is solved in every period it covers")
	func fullyCoveredCycleSolvesEveryPeriod() throws {
		let solver = LinearCycleSolver<Double>(
			accounts: [
				"base": series([1_000, 1_000]),
				"rate": series([0.1, 0.1])
			],
			members: ["fee", "total"],
			formulas: [
				"fee": "total * rate",
				"total": "base + fee"
			]
		)

		let solved = try solver.solve()
		let total = try #require(solved["total"])

		#expect(total.periods == months)

		let january: Double = try #require(total[jan])
		let february: Double = try #require(total[feb])
		let expected: Double = 1_000 / 0.9

		#expect(abs(january - expected) <= 1e-12)
		#expect(abs(february - expected) <= 1e-12)
	}

	/// The same cycle with a rate that stops after January is answered for January only.
	///
	/// This is the contract's "narrow the domain" in its observable form. A February rate of
	/// zero would not be a missing number, it would be the claim that no fee is charged, and
	/// `(I − A)` built from it is a *solvable* system with a wrong answer — `total` would come
	/// back as exactly `base`, which looks entirely plausible on a report.
	///
	/// So the assertion is about which periods exist, not about their values: February must not
	/// be in the result at all.
	@Test("A period the inputs do not cover is left out rather than solved from a zero")
	func aPeriodTheInputsDoNotCoverIsNotSolved() throws {
		let solver = LinearCycleSolver<Double>(
			accounts: [
				"base": series([1_000, 1_000]),
				"rate": TimeSeries(periods: [jan], values: [0.1])
			],
			members: ["fee", "total"],
			formulas: [
				"fee": "total * rate",
				"total": "base + fee"
			]
		)

		let solved = try solver.solve()
		let total = try #require(solved["total"])

		#expect(total.periods == [jan])
		#expect(total[feb] == nil)

		// January is unaffected: narrowing the domain must not cost the periods that *are*
		// covered. Were February fabricated instead, this same call would also report a
		// February total of exactly 1,000 — the fee silently gone.
		let january: Double = try #require(total[jan])
		let expected: Double = 1_000 / 0.9
		#expect(abs(january - expected) <= 1e-12)
	}

	// MARK: - IterativeCycleSolver: a period with no prior iterate has not converged

	/// `a = b²/2`, `b = 2a`, whose fixed point reachable from zero is `a = b = 0`.
	///
	/// Nonlinear — two members multiplied — so it is iterated rather than solved exactly, and
	/// it settles on the first sweep from a zero start. That makes the sweep budget a clean
	/// instrument: with `maxIterations: 1` the model converges, so anything that *stops* it
	/// converging is the thing under test rather than the model being hard.
	private func selfCancellingCycle() -> ModelDefinition<Double> {
		ModelDefinition<Double>(inputs: [
			"half": series([0.5, 0.5]),
			"two": series([2, 2])
		])
			.defining("a", as: "b * b * half")
			.defining("b", as: "a * two")
	}

	/// The control: from the enumerated zero start, one sweep settles it.
	@Test("The cycle settles in a single sweep from the default start")
	func nonlinearCycleSettlesInOneSweep() throws {
		let solved = try selfCancellingCycle()
			.solve(settings: IterationSettings(maxIterations: 1))

		let a: Double = try #require(solved["a"]?[feb])
		let b: Double = try #require(solved["b"]?[feb])

		#expect(abs(a) <= 1e-12)
		#expect(abs(b) <= 1e-12)
	}

	/// A warm start covering fewer periods than the model does not count as settled there.
	///
	/// `a` is supplied for January only, so on the first sweep its February value is computed
	/// against **no prior iterate at all**. Reading the absent prior as zero made `delta` the
	/// whole of the newly computed value — and this value is zero, so the delta was zero, so
	/// February reported itself settled without a single comparison having taken place. Every
	/// other member was settled too, `sweep.moving` came back empty, and `solve()` returned a
	/// first evaluation as a fixed point.
	///
	/// The other direction is harmless: a large new value inflates the reported change, which
	/// costs sweeps but never a wrong answer. Only the near-zero direction is silent.
	@Test("A warm start narrower than the model leaves the uncovered period unsettled")
	func warmStartCoveringFewerPeriodsIsNotReportedAsSettled() throws {
		let narrow = TimeSeries(periods: [jan], values: [0.0])
		let settings = IterationSettings<Double>(
			maxIterations: 1,
			initialValues: .supplied(["a": narrow])
		)

		do {
			_ = try selfCancellingCycle().solve(settings: settings)
			Issue.record("expected the uncovered period to keep the sweep unsettled")
		} catch let error as CycleSolverError {
			guard case .notConverged(_, _, let iterations, _, let stillMoving) = error else {
				Issue.record("expected a convergence failure, got \(error)")
				return
			}
			#expect(iterations == 1)
			#expect(stillMoving == ["a"])
		}
	}

	/// And the refusal is temporary, not permanent: the second sweep has a prior iterate for
	/// every period, so the same warm start settles on exactly the answer the full start gives.
	///
	/// This is what keeps the guard from being a way of failing rather than a way of measuring.
	@Test("The narrow warm start converges on the next sweep, to the same answer")
	func theUnsettledPeriodSettlesOnTheFollowingSweep() throws {
		let narrow = TimeSeries(periods: [jan], values: [0.0])
		let settings = IterationSettings<Double>(
			maxIterations: 2,
			initialValues: .supplied(["a": narrow])
		)

		let solved = try selfCancellingCycle().solve(settings: settings)

		let aJan: Double = try #require(solved["a"]?[jan])
		let aFeb: Double = try #require(solved["a"]?[feb])
		let bFeb: Double = try #require(solved["b"]?[feb])

		#expect(abs(aJan) <= 1e-12)
		#expect(abs(aFeb) <= 1e-12)
		#expect(abs(bFeb) <= 1e-12)
	}

	// MARK: - ModelDebugger: an unknown revenue is not a revenue of zero

	/// A model whose revenue stops in January while a cost series runs to February.
	///
	/// `allPeriods` is a union, so February exists because `Rent` covers it. No revenue
	/// component can answer for February, which is why the percent-of-revenue commission has
	/// nothing to be a percentage *of*.
	private func raggedModel() -> FinancialModel {
		var model = FinancialModel()
		model.revenueComponents = [
			RevenueComponent(name: "Subscriptions", periods: [jan], values: [1_000])
		]
		model.costComponents = [
			CostComponent(name: "Rent", periods: months, values: [100, 100]),
			CostComponent(name: "Commission", type: .variable(0.10)),
			CostComponent(name: "Overhead", type: .fixed(5_000))
		]
		return model
	}

	private func expense(_ snapshot: ModelSnapshot, _ name: String) throws -> AccountSnapshot {
		try #require(snapshot.expenseAccounts.first { $0.name == name })
	}

	/// A percent-of-revenue cost is omitted where revenue is unknown, not reported as zero.
	///
	/// Substituting zero here produced an expense of *exactly zero* for February —
	/// indistinguishable on a report from an expense that did not occur — and it flowed into
	/// the account's `total` as well. The total cannot tell the two apart, because adding zero
	/// and adding nothing give the same sum; the set of periods can, and is what is asserted.
	@Test("A percent-of-revenue cost is left out of a period whose revenue is unknown")
	func variableCostIsNotFabricatedFromAnUnknownRevenue() async throws {
		let snapshot = await ModelDebugger().snapshot(of: raggedModel())
		let commission = try expense(snapshot, "Commission")

		#expect(Set(commission.values.keys) == [jan])

		let january: Double = try #require(commission.values[jan])
		#expect(abs(january - 100) <= 1e-12)
	}

	/// A fixed cost never consults revenue, so an unknown revenue must not remove it.
	///
	/// This is the legitimate half the guard has to preserve. `CostComponent.calculate` reads
	/// `revenue` only in the `.variable` arm, so refusing the whole period would have deleted
	/// rent and overhead from February over a number neither of them uses.
	@Test("Fixed costs are still reported in a period whose revenue is unknown")
	func fixedCostsSurviveAnUnknownRevenue() async throws {
		let snapshot = await ModelDebugger().snapshot(of: raggedModel())

		let overhead = try expense(snapshot, "Overhead")
		let rent = try expense(snapshot, "Rent")

		#expect(Set(overhead.values.keys) == Set(months))
		#expect(Set(rent.values.keys) == Set(months))

		let overheadFeb: Double = try #require(overhead.values[feb])
		let rentFeb: Double = try #require(rent.values[feb])

		#expect(abs(overheadFeb - 5_000) <= 1e-12)
		#expect(abs(rentFeb - 100) <= 1e-12)
	}

	/// The control: when revenue covers every period, every cost is reported in every period.
	@Test("A fully covered model reports every cost in every period")
	func fullyCoveredModelSnapshotsEveryPeriod() async throws {
		var model = FinancialModel()
		model.revenueComponents = [
			RevenueComponent(name: "Subscriptions", periods: months, values: [1_000, 2_000])
		]
		model.costComponents = [CostComponent(name: "Commission", type: .variable(0.10))]

		let snapshot = await ModelDebugger().snapshot(of: model)
		let commission = try expense(snapshot, "Commission")

		#expect(Set(commission.values.keys) == Set(months))

		let january: Double = try #require(commission.values[jan])
		let february: Double = try #require(commission.values[feb])

		#expect(abs(january - 100) <= 1e-12)
		#expect(abs(february - 200) <= 1e-12)
	}

	// MARK: - ModelProfiler: a duration of zero is the fastest measurement, not a missing one

	/// The extremes and the percentiles come from the measured sample.
	///
	/// `report()` used to fall back to the literal `0` for the minimum, the maximum and both
	/// percentiles. For a *duration* that is not a neutral sentinel at all — it is the fastest
	/// execution representable, reported as a measurement — and it is the same defect
	/// `Percentiles.undefined(values:)` was written for, in its own words: rebuilding from a
	/// literal gave "a complete, confident summary of a sample nobody could summarise".
	///
	/// This is the control for that change: the five statistics must still be the five the
	/// sample actually has. 1, 2, 3, 4 and 5 milliseconds, named by a manual time source rather
	/// than slept for, so nothing here is a claim about how long the machine took.
	@Test("Report extremes and percentiles are the measured sample's own")
	func reportStatisticsComeFromTheSample() async throws {
		let time = ManualElapsedTimeSource()
		let profiler = ModelProfiler(elapsedTime: time)

		for milliseconds in [1, 2, 3, 4, 5] {
			await profiler.measure(operation: "Ramp") {
				time.advance(by: .milliseconds(milliseconds))
			}
		}

		let report = await profiler.report()
		let stats = try #require(report.operations.first { $0.operation == "Ramp" })

		#expect(abs(stats.minTime - 0.001) <= 1e-12)
		#expect(abs(stats.maxTime - 0.005) <= 1e-12)
		#expect(abs(stats.medianTime - 0.003) <= 1e-12)

		// A fabricated percentile would sit below the median, which no 95th percentile can.
		#expect(stats.percentile95 >= stats.medianTime)
		#expect(stats.percentile99 >= stats.percentile95)
		#expect(stats.percentile99 <= stats.maxTime)
	}
}
