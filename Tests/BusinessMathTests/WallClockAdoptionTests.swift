//
//  WallClockAdoptionTests.swift
//  BusinessMath
//

import Foundation
import Testing
import TestSupport  // identical(_:_:) — bit-for-bit comparison

@testable import BusinessMath

/// Timestamps recorded on returned values must come from an injected clock.
///
/// Every assertion here is an **exact** equality against a chosen instant. A tolerance
/// would defeat the purpose: the point of injecting a clock is that the moment is no
/// longer approximate, and a test written with a tolerance passes just as well against
/// `Date()` — which is the state these tests were written to replace.
@Suite("WallClock Adoption")
struct WallClockAdoptionTests {

	/// A fixed, arbitrary moment: 2026-01-01 00:00:00 UTC.
	///
	/// Deliberately not derived from the present — a fixture computed from "now" is not a
	/// fixture. This mirrors SwiftDeterminism's `Date.fixture`, restated locally because
	/// only the clock types themselves are re-exported.
	static let instant = Date(timeIntervalSince1970: 1_767_225_600)

	// MARK: - CapTable

	@Test("Granted options record the injected instant")
	func capTableGrantOptions() {
		let table = CapTable(
			shareholders: [],
			optionPool: 1_000_000,
			clock: FixedWallClock(at: Self.instant)
		)

		let granted = table.grantOptions(recipient: "Alice", shares: 1_000, strikePrice: 0.01)

		let alice = granted.shareholders.first { $0.name == "Alice" }
		#expect(alice?.investmentDate == Self.instant)
	}

	@Test("A financing round records the investor at the injected instant")
	func capTableModelRound() {
		let founder = CapTable.Shareholder(
			name: "Founder",
			shares: 1_000_000,
			investmentDate: .distantPast,
			pricePerShare: 0.001
		)
		let table = CapTable(
			shareholders: [founder],
			optionPool: 0,
			clock: FixedWallClock(at: Self.instant)
		)

		let after = table.modelRound(
			newInvestment: 1_000_000,
			preMoneyValuation: 4_000_000,
			optionPoolIncrease: 0,
			investorName: "Series A Investor"
		)

		let investor = after.shareholders.first { $0.name == "Series A Investor" }
		#expect(investor?.investmentDate == Self.instant)
	}

	@Test("A down round records the investor at the injected instant")
	func capTableModelDownRound() {
		let founder = CapTable.Shareholder(
			name: "Founder",
			shares: 1_000_000,
			investmentDate: .distantPast,
			pricePerShare: 0.001
		)
		let table = CapTable(
			shareholders: [founder],
			optionPool: 0,
			clock: FixedWallClock(at: Self.instant)
		)

		let after = table.modelDownRound(
			newInvestment: 500_000,
			preMoneyValuation: 1_000_000,
			payToPlayParticipants: []
		)

		let investor = after.shareholders.first { $0.name == "Down Round Investor" }
		#expect(investor?.investmentDate == Self.instant)
	}

	@Test("A round carries the clock into the table it returns")
	func capTableRoundPropagatesClock() {
		let founder = CapTable.Shareholder(
			name: "Founder",
			shares: 1_000_000,
			investmentDate: .distantPast,
			pricePerShare: 0.001
		)
		let table = CapTable(
			shareholders: [founder],
			optionPool: 100_000,
			clock: FixedWallClock(at: Self.instant)
		)

		// Two operations in sequence: the second must still see the injected clock, not
		// a system clock silently reinstated by the intermediate `CapTable(...)`.
		let after = table
			.modelRound(newInvestment: 1_000_000, preMoneyValuation: 4_000_000, optionPoolIncrease: 0)
			.grantOptions(recipient: "Employee", shares: 10_000, strikePrice: 0.5)

		let employee = after.shareholders.first { $0.name == "Employee" }
		#expect(employee?.investmentDate == Self.instant)
	}

	@Test("A cap table left to its default uses the system clock")
	func capTableDefaultsToSystemClock() throws {
		let table = CapTable(shareholders: [], optionPool: 1_000)

		// Bracketed rather than given a tolerance. The property is that the instant came
		// from the system clock, and an instant between two readings of that clock is
		// exactly that claim — true no matter how slow the machine is. A slack window
		// asserts a duration instead, which is a different thing and can be unlucky.
		let before = Date()
		let granted = table.grantOptions(recipient: "Alice", shares: 100, strikePrice: 0.01)
		let after = Date()

		let alice = try #require(granted.shareholders.first { $0.name == "Alice" })
		#expect(alice.investmentDate >= before && alice.investmentDate <= after)
	}

	// MARK: - AsyncGradientDescentOptimizer

	@Test("Progress updates are stamped with the injected instant")
	func gradientDescentProgressTimestamps() async throws {
		let optimizer = AsyncGradientDescentOptimizer<Double>(
			learningRate: 0.1,
			tolerance: 0.001,
			maxIterations: 200,
			momentum: 0.9,
			stepSize: 0.0001,
			clock: FixedWallClock(at: Self.instant)
		)

		var timestamps: [Date] = []
		for try await progress in optimizer.optimizeWithProgress(
			objective: { x in (x - 5.0) * (x - 5.0) },
			constraints: [],
			initialGuess: 0.0,
			bounds: nil
		) {
			timestamps.append(progress.timestamp)
		}

		#expect(!timestamps.isEmpty)
		#expect(timestamps.allSatisfy { $0 == Self.instant })
	}

	@Test("An optimizer left to its default stamps progress from the system clock")
	func gradientDescentDefaultsToSystemClock() async throws {
		let optimizer = AsyncGradientDescentOptimizer<Double>(
			learningRate: 0.1,
			tolerance: 0.001,
			maxIterations: 50,
			momentum: 0.9,
			stepSize: 0.0001
		)
		let before = Date()

		var first: Date?
		for try await progress in optimizer.optimizeWithProgress(
			objective: { x in (x - 5.0) * (x - 5.0) },
			constraints: [],
			initialGuess: 0.0,
			bounds: nil
		) {
			if first == nil { first = progress.timestamp }
		}

		let after = Date()

		let recorded = try #require(first)
		#expect(recorded >= before && recorded <= after)
	}

	// MARK: - ModelDebugger

	@Test("Diagnostic reports carry the injected instant")
	func debuggerDiagnoseTimestamp() async {
		let debugger = ModelDebugger(clock: FixedWallClock(at: Self.instant))

		let report = await debugger.diagnose(value: 1.0, expected: 1.0)

		#expect(report.timestamp == Self.instant)
	}

	@Test("Value validation reports carry the injected instant")
	func debuggerValidateValueTimestamp() async {
		let debugger = ModelDebugger(clock: FixedWallClock(at: Self.instant))

		let report = await debugger.validate(value: 0.5, name: "rate", constraints: [.positive])

		#expect(report.timestamp == Self.instant)
	}

	/// The companion to the above, and the reason `ValidationReport` had to become
	/// `Sendable`.
	///
	/// `validate(_ model:)` is actor-isolated and returns a `ValidationReport`. Until that
	/// type conformed to `Sendable` the result could not leave the actor — not into a test,
	/// and not into any other caller either, which made the method unreachable rather than
	/// merely untested. Every stored property was already a value type, and
	/// `ValidationError.value` was already declared `any Sendable`; only the conformance
	/// itself was missing.
	@Test("A model validation report carries the injected instant")
	func debuggerModelValidationTimestamp() async {
		let debugger = ModelDebugger(clock: FixedWallClock(at: Self.instant))
		let model = FinancialModel {
			Revenue { Product("Widget Sales").price(50).quantity(1000) }
			Costs { Fixed("Overhead", 10_000) }
		}

		let report = await debugger.validate(model)

		#expect(report.timestamp == Self.instant)
	}

	@Test("Model snapshots carry the injected instant")
	func debuggerSnapshotTimestamp() async {
		let debugger = ModelDebugger(clock: FixedWallClock(at: Self.instant))
		let model = FinancialModel {
			Revenue { Product("Widget Sales").price(50).quantity(1000) }
			Costs { Fixed("Overhead", 10_000) }
		}

		let snapshot = await debugger.snapshot(of: model)

		#expect(snapshot.timestamp == Self.instant)
	}

	@Test("A debugger left to its default uses the system clock")
	func debuggerDefaultsToSystemClock() async {
		let debugger = ModelDebugger()
		let before = Date()

		let report = await debugger.diagnose(value: 1.0, expected: 1.0)
		let after = Date()

		#expect(report.timestamp >= before && report.timestamp <= after)
	}

	@Test("Recorded debug steps carry the injected instant")
	func debugContextStepTimestamp() {
		let context = DebugContext.shared
		context.enable()
		defer { context.disable() }

		context.recordStep(
			operation: "Sum",
			input: "[1, 2]",
			output: "3",
			clock: FixedWallClock(at: Self.instant)
		)

		let steps = context.getSteps()
		#expect(steps.last?.timestamp == Self.instant)
	}

	// MARK: - ModelProfiler

	@Test("Performance reports carry the injected instant")
	func profilerReportTimestamp() async {
		let profiler = ModelProfiler(clock: FixedWallClock(at: Self.instant))

		let report = await profiler.report()

		#expect(report.timestamp == Self.instant)
	}

	@Test("A profiler left to its default uses the system clock")
	func profilerDefaultsToSystemClock() async {
		let profiler = ModelProfiler()
		let before = Date()

		let report = await profiler.report()
		let after = Date()

		#expect(report.timestamp >= before && report.timestamp <= after)
	}

	// MARK: - ModelValidator

	@Test("Validation reports carry the injected instant")
	func modelValidatorTimestamp() throws {
		let validator = ModelValidator<Double>(clock: FixedWallClock(at: Self.instant))

		let report = validator.validate(projection: try Self.makeProjection())

		#expect(report.timestamp == Self.instant)
	}

	@Test("A validator left to its default uses the system clock")
	func modelValidatorDefaultsToSystemClock() throws {
		let validator = ModelValidator<Double>()
		let before = Date()

		let report = validator.validate(projection: try Self.makeProjection())
		let after = Date()

		#expect(report.timestamp >= before && report.timestamp <= after)
	}

	// MARK: - CalculationTrace

	@Test("Trace steps carry the injected instant")
	func calculationTraceStepTimestamps() {
		let model = FinancialModel {
			Revenue { Product("Widget Sales").price(50).quantity(1000) }
			Costs { Fixed("Overhead", 10_000) }
		}
		let trace = CalculationTrace(model: model, clock: FixedWallClock(at: Self.instant))

		_ = trace.calculateProfit()

		#expect(!trace.steps.isEmpty)
		#expect(trace.steps.allSatisfy { $0.timestamp == Self.instant })
	}

	@Test("A trace left to its default uses the system clock")
	func calculationTraceDefaultsToSystemClock() throws {
		let model = FinancialModel {
			Revenue { Product("Widget Sales").price(50).quantity(1000) }
			Costs { Fixed("Overhead", 10_000) }
		}
		let trace = CalculationTrace(model: model)
		let before = Date()

		_ = trace.calculateProfit()

		let first = try #require(trace.steps.first)
		let after = Date()
		#expect(first.timestamp >= before && first.timestamp <= after)
	}

	// MARK: - TemplateRegistry

	@Test("Registration records the injected instant")
	func registryRegisteredAt() async throws {
		let registry = TemplateRegistry(clock: FixedWallClock(at: Self.instant))

		try await registry.register(StubTemplate(), metadata: Self.stubMetadata)

		let all = await registry.allTemplates()
		#expect(all.count == 1)
		#expect(all.first?.registeredAt == Self.instant)
	}

	@Test("Exported packages carry the injected instant")
	func registryExportCreatedAt() async throws {
		let registry = TemplateRegistry(clock: FixedWallClock(at: Self.instant))
		try await registry.register(StubTemplate(), metadata: Self.stubMetadata)

		let package = try await registry.export(Self.stubMetadata.name)

		#expect(package.createdAt == Self.instant)
	}

	@Test("Validation reports carry the injected instant")
	func registryValidatedAt() async throws {
		let registry = TemplateRegistry(clock: FixedWallClock(at: Self.instant))
		try await registry.register(StubTemplate(), metadata: Self.stubMetadata)

		let report = try await registry.validate(Self.stubMetadata.name)

		#expect(report.validatedAt == Self.instant)
	}

	@Test("Imported templates carry the injected instant")
	func registryImportRegisteredAt() async throws {
		let source = TemplateRegistry(clock: FixedWallClock(at: Date(timeIntervalSince1970: 0)))
		try await source.register(StubTemplate(), metadata: Self.stubMetadata)
		let package = try await source.export(Self.stubMetadata.name)

		let destination = TemplateRegistry(clock: FixedWallClock(at: Self.instant))
		let imported = try await destination.import(package)

		#expect(imported.registeredAt == Self.instant)
	}

	@Test("A registry left to its default uses the system clock")
	func registryDefaultsToSystemClock() async throws {
		let registry = TemplateRegistry()
		let before = Date()

		try await registry.register(StubTemplate(), metadata: Self.stubMetadata)

		let all = await registry.allTemplates()
		let registered = try #require(all.first?.registeredAt)
		let after = Date()
		#expect(registered >= before && registered <= after)
	}

	// MARK: - CalculationCache (time *passing*, not a single instant)

	@Test("A cached entry survives until the clock passes its TTL")
	func cacheHonoursInjectedClockForTTL() {
		let clock = ManualWallClock(at: Self.instant)
		let cache = CalculationCache(maxSize: 16, ttl: 60, clock: clock)
		let calls = Counter()

		#expect(cache.getOrCalculate(key: "k") { calls.increment() } == 1)
		#expect(cache.getOrCalculate(key: "k") { calls.increment() } == 1)
		#expect(calls.value == 1)

		clock.advance(by: 59)
		#expect(cache.getOrCalculate(key: "k") { calls.increment() } == 1)
		#expect(calls.value == 1)
	}

	@Test("A cached entry expires once the clock passes its TTL")
	func cacheExpiresWhenClockAdvances() {
		let clock = ManualWallClock(at: Self.instant)
		let cache = CalculationCache(maxSize: 16, ttl: 60, clock: clock)
		let calls = Counter()

		_ = cache.getOrCalculate(key: "k") { calls.increment() }
		clock.advance(by: 61)
		_ = cache.getOrCalculate(key: "k") { calls.increment() }

		#expect(calls.value == 2)
	}

	@Test("An async cached entry expires once the clock passes its TTL")
	func asyncCacheExpiresWhenClockAdvances() async {
		let clock = ManualWallClock(at: Self.instant)
		let cache = CalculationCacheAsync(maxSize: 16, ttl: 60, clock: clock)
		let calls = Counter()

		_ = await cache.getOrCalculate(key: "k") { calls.increment() }
		_ = await cache.getOrCalculate(key: "k") { calls.increment() }
		#expect(calls.value == 1)

		clock.advance(by: 61)
		_ = await cache.getOrCalculate(key: "k") { calls.increment() }
		#expect(calls.value == 2)
	}

	// MARK: - Elapsed time (ContinuousClock, not WallClock)

	// These assertions are deliberately weaker than the ones above, and that asymmetry is
	// the point. A recorded timestamp can be pinned exactly because the clock is injected;
	// a measured duration cannot, because the real elapsed time *is* the thing being
	// measured — a fake clock there would make the number meaningless rather than
	// testable. So what is asserted is what a monotonic source guarantees and a
	// wall-clock difference does not: never negative, always finite, and ordered.
	//
	// No assertion here pins a specific duration. That would be a flake by construction.

	@Test("A measured duration is never negative and always finite")
	func profilerDurationIsWellFormed() async throws {
		let profiler = ModelProfiler()

		_ = await profiler.measure(operation: "trivial") { 1 + 1 }

		let report = await profiler.report()
		let stats = try #require(report.operations.first { $0.operation == "trivial" })
		#expect(stats.totalTime >= 0)
		#expect(stats.totalTime.isFinite)
		#expect(stats.averageTime >= 0)
		#expect(stats.averageTime.isFinite)
	}

	@Test("A slower operation measures longer than a faster one")
	func profilerOrdersDurations() async throws {
		let profiler = ModelProfiler()

		_ = await profiler.measure(operation: "fast") { 1 + 1 }
		_ = await profiler.measure(operation: "slow") {
			var total = 0.0
			for i in 1...2_000_000 { total += Double(i).squareRoot() }
			return total
		}

		let report = await profiler.report()
		let fast = try #require(report.operations.first { $0.operation == "fast" })
		let slow = try #require(report.operations.first { $0.operation == "slow" })
		#expect(slow.totalTime > fast.totalTime)
	}

	@Test("A traced calculation reports a well-formed duration")
	func debuggerTraceDurationIsWellFormed() async {
		let debugger = ModelDebugger()

		let trace = await debugger.trace(value: "sum") { 1 + 1 }

		#expect(trace.duration >= 0)
		#expect(trace.duration.isFinite)
	}

	@Test("A traced calculation that throws still reports a well-formed duration")
	func debuggerFailedTraceDurationIsWellFormed() async throws {
		struct Boom: Error {}
		let debugger = ModelDebugger()

		let trace: DebugTrace<Int> = await debugger.trace(value: "boom") { throw Boom() }

		#expect(trace.duration >= 0)
		#expect(trace.duration.isFinite)
		// The error the closure threw, not merely *an* error: a debugger that swallowed
		// `Boom` and reported one of its own would still be non-nil here.
		let recorded = try #require(trace.error)
		#expect(recorded is Boom, "trace reported \(recorded), not the Boom the closure threw")
		#expect(trace.result == nil, "a throwing calculation has no result")
	}

	@Test("Branch and bound reports a well-formed solve time")
	func branchAndBoundSolveTimeIsWellFormed() throws {
		let solver = BranchAndBoundSolver<VectorN<Double>>()
		let objective: @Sendable (VectorN<Double>) -> Double = { v in
			let arr = v.toArray()
			return arr[0] + arr[1]
		}

		let result = try solver.solve(
			objective: objective,
			from: VectorN([2.0, 2.0]),
			subjectTo: [.linearInequality(coefficients: [1.0, 1.0], rhs: 5.7, sense: .lessOrEqual)],
			integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
			minimize: true
		)

		#expect(result.solveTime >= 0)
		#expect(result.solveTime.isFinite)
	}

	@Test("A Duration converts to seconds without losing its scale")
	func durationConvertsToSeconds() {
		// The instrument changed; the reported unit did not. These pin the conversion at
		// the reporting boundary, which is the only place precision could silently shift.
		// The first three are exact: 3 and 0.25 are both representable, and the
		// attosecond term contributes nothing to them, so a tolerance would hide exactly
		// the drift being watched for. The sub-microsecond cases below are not exact —
		// 1e-18 is not representable — so they get a tolerance.
		#expect(Duration.seconds(0).inSeconds == 0)
		#expect(identical(Duration.seconds(3).inSeconds, 3.0))
		#expect(identical(Duration.milliseconds(250).inSeconds, 0.25))
		#expect(abs(Duration.microseconds(1).inSeconds - 1e-6) < 1e-15)
		#expect(abs(Duration.nanoseconds(1).inSeconds - 1e-9) < 1e-18)
	}

	// MARK: - Fixtures

	/// A minimal counter that a `@Sendable` calculation closure may capture.
	// Justification: `count` is guarded by `lock`; no other state exists.
	final class Counter: @unchecked Sendable {
		private let lock = NSLock()
		private var count = 0

		var value: Int {
			lock.lock()
			defer { lock.unlock() }
			return count
		}

		@discardableResult
		func increment() -> Int {
			lock.lock()
			defer { lock.unlock() }
			count += 1
			return 1
		}
	}

	struct StubTemplate: TemplateProtocol {
		var identifier: String { "com.test.wallclock-template" }

		func create(parameters: [String: Any]) throws -> Any {
			guard let value = parameters["value"] as? Double else {
				throw BusinessMathError.missingData(account: "value", period: "parameters")
			}
			return value
		}

		func schema() -> TemplateSchema {
			TemplateSchema(
				identifier: identifier,
				parameters: [
					TemplateSchema.Parameter(
						name: "value",
						type: .number,
						description: "A value",
						required: true
					)
				],
				examples: ["basic": ["value": "1.0"]]
			)
		}

		func validate(parameters: [String: Any]) throws {
			guard parameters["value"] != nil else {
				throw BusinessMathError.missingData(account: "value", period: "parameters")
			}
		}
	}

	static let stubMetadata = TemplateMetadata(
		name: "WallClock Stub",
		description: "A template that exists only so the registry has something to stamp",
		author: "Tests",
		version: "1.0.0",
		category: .custom,
		requiredParameters: ["value"],
		tags: ["test"]
	)

	static func makeProjection() throws -> FinancialProjection {
		let entity = Entity(id: "TEST", primaryType: .ticker, name: "Test Co")
		let periods = [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2)
		]

		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: TimeSeries(periods: periods, values: [100_000.0, 110_000.0])
		)
		let cogs = try Account(
			entity: entity,
			name: "COGS",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: TimeSeries(periods: periods, values: [60_000.0, 65_000.0])
		)
		let incomeStatement = try IncomeStatement(
			entity: entity,
			periods: periods,
			accounts: [revenue, cogs]
		)

		let cash = try Account(
			entity: entity,
			name: "Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: TimeSeries(periods: periods, values: [100_000.0, 110_000.0])
		)
		let equity = try Account(
			entity: entity,
			name: "Equity",
			balanceSheetRole: .commonStock,
			timeSeries: TimeSeries(periods: periods, values: [100_000.0, 110_000.0])
		)
		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			accounts: [cash, equity]
		)

		let operatingCF = try Account(
			entity: entity,
			name: "Operating Cash Flow",
			cashFlowRole: .otherOperatingActivities,
			timeSeries: TimeSeries(periods: periods, values: [40_000.0, 45_000.0])
		)
		let cashFlowStatement = try CashFlowStatement<Double>(
			entity: entity,
			periods: periods,
			accounts: [operatingCF]
		)

		let scenario = FinancialScenario(
			name: "Test Scenario",
			description: "Scenario for wall-clock adoption tests"
		)

		return FinancialProjection(
			scenario: scenario,
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			cashFlowStatement: cashFlowStatement
		)
	}
}
