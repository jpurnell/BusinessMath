//
//  Phase5SmallAreaTests.swift
//  BusinessMath
//
//  Phase 5 of the contaminated-input sweep: the small, never-probed areas.
//

import Testing
import Foundation
@testable import BusinessMath

/// What a detector says when it cannot evaluate the thing it was asked about.
///
/// Every defect pinned here is one mechanism wearing different clothes. A validator, an
/// auditor and a diagnostic all report a problem by letting a comparison become true —
/// `amount < 0`, `diff > tolerance`, `value < min || value > max`. Every comparison
/// involving a NaN is false, so each of those tests answered "no problem found" about a
/// value nobody could compute, and the caller had asked *specifically* whether there was a
/// problem. That is the worst possible place for a reassuring default: the whole point of
/// calling these is to be told when something is wrong.
///
/// The correctly-behaving sibling that settled the contract for all of them is
/// `TimeSeries.validate(detectOutliers:)` in `ValidationFramework.swift`, which has always
/// reported a non-finite observation as `.error`.
///
/// Every test is paired with a clean control that passed before the fix as well as after —
/// the controls are what show the suite discriminates rather than simply failing.
@Suite("Phase 5 — contaminated input in the small areas")
struct Phase5SmallAreaTests {

	// MARK: - Fixtures

	private func entity() -> Entity {
		Entity(id: "PHASE5", primaryType: .ticker, name: "Phase Five Co")
	}

	private func periods() -> [Period] {
		[
			Period.quarter(year: 2026, quarter: 1),
			Period.quarter(year: 2026, quarter: 2)
		]
	}

	private func balanceSheet(
		assets: [Double],
		liabilities: [Double],
		equity: [Double]
	) throws -> BalanceSheet<Double> {
		let quarters = periods()
		let cash = try Account(
			entity: entity(),
			name: "Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: TimeSeries(periods: quarters, values: assets)
		)
		let debt = try Account(
			entity: entity(),
			name: "Debt",
			balanceSheetRole: .longTermDebt,
			timeSeries: TimeSeries(periods: quarters, values: liabilities)
		)
		let stock = try Account(
			entity: entity(),
			name: "Equity",
			balanceSheetRole: .commonStock,
			timeSeries: TimeSeries(periods: quarters, values: equity)
		)
		return try BalanceSheet(entity: entity(), periods: quarters, accounts: [cash, debt, stock])
	}

	private func incomeStatement(
		revenue: [Double],
		costOfGoodsSold: [Double]
	) throws -> IncomeStatement<Double> {
		let quarters = periods()
		let sales = try Account(
			entity: entity(),
			name: "Sales",
			incomeStatementRole: .revenue,
			timeSeries: TimeSeries(periods: quarters, values: revenue)
		)
		let cogs = try Account(
			entity: entity(),
			name: "COGS",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: TimeSeries(periods: quarters, values: costOfGoodsSold)
		)
		return try IncomeStatement(entity: entity(), periods: quarters, accounts: [sales, cogs])
	}

	private func context() -> ValidationContext {
		ValidationContext(fieldName: "Phase 5")
	}

	// MARK: - BalanceSheetBalances

	/// The substitution that made an unanswerable sheet balance exactly.
	///
	/// `let lhs = assets.isNaN ? 0 : assets` stood in this rule. With liabilities and equity
	/// both zero the comparison became `|0 - 0| <= tolerance`, so a balance sheet whose total
	/// assets could not be computed was reported *valid* — the accounting equation confirmed
	/// against a number nobody measured.
	@Test("A balance sheet with non-finite assets is not reported as balancing")
	func balanceSheetWithNaNAssetsIsInvalid() throws {
		let sheet = try balanceSheet(
			assets: [Double.nan, Double.nan],
			liabilities: [0.0, 0.0],
			equity: [0.0, 0.0]
		)

		let rule = FinancialValidation.BalanceSheetBalances<Double>()
		let result = rule.validate(sheet, context: context())

		#expect(!result.isValid)
		#expect(result.errors.count == 2, "One error per period, neither of which is answerable")
		let message: String = result.errors[0].message
		#expect(message.contains("finite"))
	}

	/// The control: the same rule, the same tolerance, a sheet that really does balance.
	@Test("A balancing sheet is still reported as valid")
	func balanceSheetControlStillValid() throws {
		let sheet = try balanceSheet(
			assets: [100.0, 110.0],
			liabilities: [40.0, 45.0],
			equity: [60.0, 65.0]
		)

		let rule = FinancialValidation.BalanceSheetBalances<Double>()
		let result = rule.validate(sheet, context: context())

		#expect(result.isValid)
		#expect(result.errors.isEmpty)
	}

	/// The control on the other side: a real imbalance is still a real imbalance.
	@Test("A genuinely unbalanced sheet is still reported as invalid")
	func balanceSheetControlStillInvalid() throws {
		let sheet = try balanceSheet(
			assets: [100.0, 110.0],
			liabilities: [40.0, 45.0],
			equity: [50.0, 55.0]
		)

		let rule = FinancialValidation.BalanceSheetBalances<Double>()
		let result = rule.validate(sheet, context: context())

		#expect(!result.isValid)
		let message: String = result.errors[0].message
		#expect(message.contains("do not equal"))
	}

	// MARK: - PositiveRevenue

	/// `nan < 0` is false, so the rule found nothing to say and returned `.valid`.
	@Test("Revenue that is not a number is reported, not passed")
	func positiveRevenueRejectsNaN() throws {
		let statement = try incomeStatement(
			revenue: [Double.nan, 100.0],
			costOfGoodsSold: [40.0, 40.0]
		)

		let rule = FinancialValidation.PositiveRevenue<Double>()
		let result = rule.validate(statement, context: context())

		#expect(!result.isValid)
		#expect(result.errors.count == 1, "Only the contaminated period is unanswerable")
		let message: String = result.errors[0].message
		#expect(message.contains("finite"))
	}

	/// The control: positive revenue still passes, negative revenue still fails.
	@Test("Positive revenue passes and negative revenue fails, unchanged")
	func positiveRevenueControls() throws {
		let good = try incomeStatement(revenue: [100.0, 120.0], costOfGoodsSold: [40.0, 50.0])
		let bad = try incomeStatement(revenue: [-100.0, 120.0], costOfGoodsSold: [40.0, 50.0])

		let rule = FinancialValidation.PositiveRevenue<Double>()

		#expect(rule.validate(good, context: context()).isValid)

		let badResult = rule.validate(bad, context: context())
		#expect(!badResult.isValid)
		let message: String = badResult.errors[0].message
		#expect(message.contains("negative"))
	}

	// MARK: - ReasonableGrossMargin

	/// `nan <= minMargin` and `nan >= maxMargin` are both false, so an unusable margin fell
	/// through both arms and the rule reported the margin reasonable.
	@Test("A gross margin that is not a number produces a warning")
	func grossMarginReportsNaN() throws {
		// Gross profit = revenue - COGS, so a NaN cost makes the margin NaN while leaving
		// revenue itself perfectly usable: the contamination has to reach the margin rather
		// than being caught by the revenue guard ahead of it.
		let statement = try incomeStatement(
			revenue: [100.0, 100.0],
			costOfGoodsSold: [Double.nan, 40.0]
		)

		let rule = FinancialValidation.ReasonableGrossMargin<Double>(minMargin: -0.20, maxMargin: 0.90)
		let result = rule.validate(statement, context: context())

		#expect(!result.warnings.isEmpty, "An unevaluable margin is not a reasonable one")
		let message: String = result.warnings[0].message
		#expect(message.contains("not a finite number"))
	}

	/// The control: an ordinary 60% margin sits inside the band and warns about nothing.
	@Test("An ordinary gross margin still warns about nothing")
	func grossMarginControl() throws {
		let statement = try incomeStatement(
			revenue: [100.0, 100.0],
			costOfGoodsSold: [40.0, 40.0]
		)

		let rule = FinancialValidation.ReasonableGrossMargin<Double>(minMargin: -0.20, maxMargin: 0.90)
		let result = rule.validate(statement, context: context())

		#expect(result.isValid)
		#expect(result.warnings.isEmpty)
	}

	// MARK: - ValidationConstraint

	/// A constraint checker that passed a NaN against every range it was given.
	///
	/// `validate(value: .nan, name: "rate", constraints: [.range(0, 1)])` reported the value
	/// as satisfying the constraint. The caller asked precisely whether it did.
	@Test("Every comparison constraint reports a NaN as a violation")
	func constraintsRejectNaN() async {
		let debugger = ModelDebugger()

		let positive = await debugger.validate(value: .nan, name: "rate", constraints: [.positive])
		#expect(!positive.isValid, "A NaN is not positive")

		let nonNegative = await debugger.validate(value: .nan, name: "rate", constraints: [.nonNegative])
		#expect(!nonNegative.isValid, "A NaN is not non-negative")

		let range = await debugger.validate(value: .nan, name: "rate", constraints: [.range(0.0, 1.0)])
		#expect(!range.isValid, "A NaN is not inside any range")

		let maximum = await debugger.validate(value: .nan, name: "rate", constraints: [.maxValue(100.0)])
		#expect(!maximum.isValid, "A NaN is not at most a maximum")

		let minimum = await debugger.validate(value: .nan, name: "rate", constraints: [.minValue(0.0)])
		#expect(!minimum.isValid, "A NaN is not at least a minimum")
	}

	/// The control, and the boundary of the fix.
	///
	/// Infinities are deliberately left to the ordinary comparisons, because they order
	/// correctly: `+∞` really is positive and really does exceed a maximum. `.nonZero` is also
	/// left alone — a NaN genuinely is not zero, which is the whole of what that constraint
	/// asks, and `.finite` is the constraint that asks the other question.
	@Test("Finite values, infinities and .nonZero are unchanged")
	func constraintControls() async {
		let debugger = ModelDebugger()

		let ordinary = await debugger.validate(
			value: 0.5,
			name: "rate",
			constraints: [.positive, .nonNegative, .range(0.0, 1.0), .nonZero, .finite]
		)
		#expect(ordinary.isValid)

		let infinitePositive = await debugger.validate(
			value: .infinity,
			name: "rate",
			constraints: [.positive]
		)
		#expect(infinitePositive.isValid, "An infinity orders correctly and really is positive")

		let infiniteCapped = await debugger.validate(
			value: .infinity,
			name: "rate",
			constraints: [.maxValue(100.0)]
		)
		#expect(!infiniteCapped.isValid, "An infinity orders correctly and really exceeds the cap")

		let nanNonZero = await debugger.validate(value: .nan, name: "rate", constraints: [.nonZero])
		#expect(nanNonZero.isValid, "A NaN is genuinely not zero; .finite is the constraint that objects")

		let nanFinite = await debugger.validate(value: .nan, name: "rate", constraints: [.finite])
		#expect(!nanFinite.isValid)
	}

	// MARK: - ModelInspector.validateStructure

	/// `nan < 0` is false and `nan > 1` is false, so neither the negative-amount check nor
	/// the percentage range check had anything to say, and the structure was reported valid.
	@Test("A structural validator reports amounts and percentages that are not numbers")
	func structureValidationReportsNaN() {
		var model = FinancialModel()
		model.revenueComponents.append(RevenueComponent(name: "Product", amount: .nan))
		model.costComponents.append(CostComponent(name: "Commission", type: .variable(.nan)))

		let inspector = ModelInspector(model: model)
		let validation = inspector.validateStructure()

		#expect(!validation.isValid)
		#expect(validation.issues.count == 2, "One for the amount, one for the percentage")
		let joined: String = validation.issues.joined(separator: " | ")
		#expect(joined.contains("not a number"))
	}

	/// The control: a well-formed model is still valid, and a genuinely negative amount or
	/// out-of-range percentage is still reported with its own message.
	@Test("Structural validation of finite models is unchanged")
	func structureValidationControls() {
		var good = FinancialModel()
		good.revenueComponents.append(RevenueComponent(name: "Product", amount: 1_000.0))
		good.costComponents.append(CostComponent(name: "Commission", type: .variable(0.1)))
		#expect(ModelInspector(model: good).validateStructure().isValid)

		var bad = FinancialModel()
		bad.revenueComponents.append(RevenueComponent(name: "Product", amount: -1.0))
		bad.costComponents.append(CostComponent(name: "Commission", type: .variable(2.0)))
		let badValidation = ModelInspector(model: bad).validateStructure()
		#expect(!badValidation.isValid)
		let joined: String = badValidation.issues.joined(separator: " | ")
		#expect(joined.contains("negative amount"))
		#expect(joined.contains("invalid percentage"))
	}

	// MARK: - FinancialModel.validate()

	/// The `Validatable` conformance had no non-finite check at all, while the `TimeSeries`
	/// conformance beside it in the same file has always reported one as an error.
	@Test("A revenue amount that is not finite is an error, matching the TimeSeries sibling")
	func financialModelValidateReportsNonFinite() {
		var model = FinancialModel()
		model.revenueComponents.append(RevenueComponent(name: "Product", amount: .nan))

		let result = model.validate()

		#expect(!result.isValid)
		#expect(result.errors.count == 1)
		let message: String = result.errors[0].message
		#expect(message.contains("not finite"))
	}

	/// The control: a finite model still validates.
	///
	/// This test used to assert the other half too — that a negative amount stays a
	/// `.warning`, "that severity is a judgement about sign and this fix did not change it".
	/// That was true of the non-finite fix recorded above and is no longer true of the API:
	/// the judgement was taken afterwards, deliberately, and it went the other way. Revenue
	/// below zero is a sign error or a contaminated input, and leaving it at `.warning` left
	/// `FinancialModel.validate()` unable to return `isValid == false` for any reason of its
	/// own. The pair that proves the new severity is targeted — a pre-revenue model still
	/// validates while a negative-revenue one does not — lives in `OpenDecisionsTests`; what
	/// is kept here is the assertion this test was actually for.
	@Test("A finite model still validates, and negative revenue is now an error")
	func financialModelValidateControls() {
		var good = FinancialModel()
		good.revenueComponents.append(RevenueComponent(name: "Product", amount: 1_000.0))
		let goodResult = good.validate()
		#expect(goodResult.isValid)
		#expect(goodResult.errors.isEmpty)

		var negative = FinancialModel()
		negative.revenueComponents.append(RevenueComponent(name: "Product", amount: -1.0))
		let negativeResult = negative.validate()
		#expect(!negativeResult.isValid, "Negative revenue became an error after this phase closed")
		#expect(negativeResult.errors.count == 1)
		#expect(negativeResult.warningsOnly.isEmpty)
	}

	// MARK: - ModelDebugger.findMissingData

	/// The method documents "accounts" and walked only the revenue side, so a cost series
	/// full of NaNs came back as an empty dictionary — which reads as "nothing is missing".
	@Test("Missing data is found on the cost side as well as the revenue side")
	func findMissingDataCoversCosts() async throws {
		let quarters = periods()
		var model = FinancialModel()
		model.costComponents.append(
			CostComponent(name: "Hosting", periods: quarters, values: [Double.nan, 500.0])
		)

		let debugger = ModelDebugger()
		let missing = await debugger.findMissingData(in: model)

		let hosting = try #require(missing["Hosting"])
		#expect(hosting.count == 1, "The first quarter is the only unusable one")
	}

	/// The control: a model whose series are all finite reports nothing missing, on both
	/// sides — so the new scan cannot be passing by reporting everything.
	@Test("A clean model still reports nothing missing")
	func findMissingDataControl() async {
		let quarters = periods()
		var model = FinancialModel()
		model.revenueComponents.append(
			RevenueComponent(name: "Product", periods: quarters, values: [1_000.0, 1_100.0])
		)
		model.costComponents.append(
			CostComponent(name: "Hosting", periods: quarters, values: [400.0, 500.0])
		)

		let debugger = ModelDebugger()
		let missing = await debugger.findMissingData(in: model)

		#expect(missing.isEmpty)
	}

	// MARK: - IterativeCycleSolver

	/// `a = 0.5·a² + 0.25`, whose fixed point reachable from zero is `1 − √½`. The same
	/// definition the cycle-solver suite uses, so the control below is comparable to it.
	private func contractingCycle() -> ModelDefinition<Double> {
		let months = [Period.month(year: 2026, month: 1), Period.month(year: 2026, month: 2)]
		return ModelDefinition<Double>(inputs: [
			"half": TimeSeries(periods: months, values: [0.5, 0.5]),
			"quarter": TimeSeries(periods: months, values: [0.25, 0.25])
		])
			.defining("a", as: "a * a * half + quarter")
	}

	/// A tolerance that is not a number cannot be met, and reading it as met returned the
	/// first sweep as a settled fixed point.
	///
	/// The old test was `size > absoluteTolerance && size > relativeTolerance * |new|` — both
	/// false against a NaN threshold, so nothing was ever "still moving" and `solve()` took
	/// its convergence exit on sweep one. `IterationSettings` takes both tolerances from the
	/// caller and validates neither.
	@Test("A tolerance that is not a number does not read as convergence")
	func nonFiniteToleranceDoesNotConverge() throws {
		let settings = IterationSettings<Double>(
			absoluteTolerance: .nan,
			relativeTolerance: .nan
		)

		#expect(throws: CycleSolverError.self) {
			_ = try self.contractingCycle().solve(settings: settings)
		}
	}

	/// The control: the same cycle at the default tolerances still reaches its fixed point,
	/// so the rewritten test is behaviourally identical everywhere it can be evaluated.
	@Test("The same cycle at ordinary tolerances still converges to its fixed point")
	func contractingCycleStillConverges() throws {
		let solved = try contractingCycle().solve()
		let month = Period.month(year: 2026, month: 1)
		let series = try #require(solved["a"])
		let a = try #require(series[month])
		let target: Double = 1 - (0.5 as Double).squareRoot()
		let gap: Double = abs(a - target)
		#expect(gap <= 1e-7)
	}

	// MARK: - PortfolioOptimizer.efficientFrontier

	/// `numberOfPoints >= 2` was asserted in a suppression comment and enforced nowhere.
	///
	/// At one point the divisor `Double(numberOfPoints - 1)` is zero, `step` is an infinity,
	/// and `minReturn + Double(0) * .infinity` is NaN — so the single target return handed to
	/// `portfolioForTargetReturn` was not a number. A claim in a comment is not a guard.
	@Test("A frontier of fewer than two points is refused rather than computed from a NaN")
	func efficientFrontierRefusesOnePoint() {
		let optimizer = PortfolioOptimizer()
		let returns = VectorN([0.08, 0.12, 0.15])
		let covariance = [
			[0.04, 0.01, 0.02],
			[0.01, 0.09, 0.03],
			[0.02, 0.03, 0.16]
		]

		#expect(throws: BusinessMathError.self) {
			_ = try optimizer.efficientFrontier(
				expectedReturns: returns,
				covariance: covariance,
				numberOfPoints: 1
			)
		}
	}

	/// The guard every sibling in this file already had. Without it the endpoints came from
	/// `?? 0.0` and `?? 0.1`: a frontier spanning 0% to 10%, invented for a portfolio holding
	/// no assets at all.
	@Test("A frontier over no assets is refused, as every sibling already refuses one")
	func efficientFrontierRefusesEmptyReturns() {
		let optimizer = PortfolioOptimizer()

		#expect(throws: PortfolioOptimizerError.self) {
			_ = try optimizer.efficientFrontier(
				expectedReturns: VectorN([Double]()),
				covariance: [],
				numberOfPoints: 5
			)
		}
	}

	/// The control: an ordinary frontier request still produces its portfolios.
	@Test("An ordinary frontier request is unchanged")
	func efficientFrontierControl() throws {
		let optimizer = PortfolioOptimizer()
		let returns = VectorN([0.08, 0.12, 0.15])
		let covariance = [
			[0.04, 0.01, 0.02],
			[0.01, 0.09, 0.03],
			[0.02, 0.03, 0.16]
		]

		let frontier = try optimizer.efficientFrontier(
			expectedReturns: returns,
			covariance: covariance,
			numberOfPoints: 5
		)

		#expect(frontier.portfolios.count == 5)
		let allFinite: Bool = frontier.targetReturns.allSatisfy { $0.isFinite }
		#expect(allFinite, "Every target return is a number the optimiser can aim at")
	}
}
