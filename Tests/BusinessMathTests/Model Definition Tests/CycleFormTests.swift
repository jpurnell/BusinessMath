//
//  CycleFormTests.swift
//  BusinessMath
//

import Testing
import Foundation
@testable import BusinessMath

/// Whether a cycle is linear in its own members, decided from the parse tree.
///
/// The classification is decidable rather than heuristic, and that is the whole reason it is
/// worth having. The formula grammar is `+ − × ÷` and nothing else, so "does any member of this
/// cycle multiply or divide another member" is a question the parse tree answers exactly. A
/// linear cycle has an exact solution; a nonlinear one has to be iterated to a tolerance.
///
/// The asymmetry these tests are built around: classifying a nonlinear cycle as linear produces
/// a wrong answer with total confidence, and classifying a linear cycle as nonlinear costs an
/// iteration. Every case where the tree cannot be read — a formula that tokenises but does not
/// parse — therefore lands on ``DependencyCycle/Form/nonlinear``.
@Suite("Cycle Form")
struct CycleFormTests {

	private let months = [
		Period.month(year: 2026, month: 1),
		Period.month(year: 2026, month: 2)
	]

	private func series(_ values: [Double]) -> TimeSeries<Double> {
		TimeSeries(periods: months, values: values)
	}

	private func form(of model: ModelDefinition<Double>) throws -> DependencyCycle.Form? {
		try model.dependencyReport().cycles.first?.form
	}

	// MARK: - Linear

	@Test("A cycle whose members are only added is linear")
	func additionIsLinear() throws {
		let model = ModelDefinition<Double>()
			.defining("a", as: "b + 1")
			.defining("b", as: "a + 2")

		#expect(try form(of: model) == .linear)
	}

	@Test("A member scaled by a literal is linear")
	func literalCoefficientIsLinear() throws {
		let model = ModelDefinition<Double>()
			.defining("a", as: "b * 1.1")
			.defining("b", as: "a + 100")

		#expect(try form(of: model) == .linear)
	}

	/// The case the classification exists for. `rate` is an account, and it is multiplied by a
	/// cycle member — but it is not itself in the cycle, so it is a coefficient. Reading this
	/// as nonlinear would send circular interest, cash sweeps and gross-ups down the iterative
	/// path when every one of them has an exact answer.
	@Test("An account outside the cycle is a coefficient, however it is combined")
	func outsideAccountIsACoefficient() throws {
		let model = ModelDefinition<Double>(inputs: [
			"rate": series([0.06, 0.06]),
			"principal": series([1_000, 1_000])
		])
			.defining("interest", as: "debt * rate")
			.defining("debt", as: "principal + interest")

		#expect(try form(of: model) == .linear)
	}

	@Test("Dividing a member by something outside the cycle is linear")
	func divisionByACoefficientIsLinear() throws {
		let model = ModelDefinition<Double>(inputs: ["periods": series([12, 12])])
			.defining("a", as: "b / periods")
			.defining("b", as: "a + 5")

		#expect(try form(of: model) == .linear)
	}

	@Test("Negation does not change the degree")
	func negationIsLinear() throws {
		let model = ModelDefinition<Double>()
			.defining("a", as: "-b")
			.defining("b", as: "a - 3")

		#expect(try form(of: model) == .linear)
	}

	@Test("Nested constants folded around a member stay linear")
	func nestedConstantsAreLinear() throws {
		let model = ModelDefinition<Double>(inputs: ["scale": series([2, 2])])
			.defining("a", as: "(2 * scale) * (b / (3 * scale)) + scale")
			.defining("b", as: "a + 1")

		#expect(try form(of: model) == .linear)
	}

	/// `Revenue = Revenue * 1.1` is very likely a typo, and it is nonetheless a linear system
	/// with exactly one solution. The form says what can be solved, not what was meant — a
	/// caller who wants to flag a self-reference has ``DependencyCycle/accounts`` of size one.
	@Test("A self-reference scaled by a literal is linear")
	func selfReferenceIsLinear() throws {
		let model = ModelDefinition<Double>().defining("revenue", as: "revenue * 1.1")

		#expect(try form(of: model) == .linear)
	}

	// MARK: - Nonlinear

	@Test("Two members multiplied together is nonlinear")
	func memberTimesMemberIsNonlinear() throws {
		let model = ModelDefinition<Double>()
			.defining("a", as: "b * c")
			.defining("b", as: "a + 1")
			.defining("c", as: "a + 2")

		#expect(try form(of: model) == .nonlinear)
	}

	@Test("A member squared is nonlinear")
	func memberSquaredIsNonlinear() throws {
		let model = ModelDefinition<Double>().defining("a", as: "a * a + 1")

		#expect(try form(of: model) == .nonlinear)
	}

	@Test("A member in a divisor is nonlinear")
	func memberInADivisorIsNonlinear() throws {
		let model = ModelDefinition<Double>()
			.defining("a", as: "1 / b")
			.defining("b", as: "a + 1")

		#expect(try form(of: model) == .nonlinear)
	}

	/// The divisor is a whole subexpression, not just a name, and a member buried inside one
	/// is still a member. A ratio taken against a total the ratio contributes to is exactly
	/// this shape.
	@Test("A member inside a compound divisor is nonlinear")
	func memberInsideACompoundDivisorIsNonlinear() throws {
		let model = ModelDefinition<Double>(inputs: ["base": series([10, 10])])
			.defining("share", as: "base / (base + share)")

		#expect(try form(of: model) == .nonlinear)
	}

	/// Only one member's formula has to be nonlinear for the system to be. A cycle is solved
	/// as a whole or not at all.
	@Test("One nonlinear member makes the whole cycle nonlinear")
	func oneNonlinearMemberIsEnough() throws {
		let model = ModelDefinition<Double>()
			.defining("a", as: "b + 1")
			.defining("b", as: "c + 1")
			.defining("c", as: "a * b")

		#expect(try form(of: model) == .nonlinear)
	}

	/// A formula that tokenises but does not parse has no tree to read, and so no degree.
	/// Refused rather than called nonlinear: nonlinear is an assertion about the shape of an
	/// expression, and nobody has been able to read this one. It is the same answer the report
	/// already gives to a formula that will not tokenise.
	@Test("A formula that cannot be parsed is refused rather than classified")
	func unparseableIsRefused() throws {
		let model = ModelDefinition<Double>()
			.defining("a", as: "b +")
			.defining("b", as: "a")

		#expect(throws: FormulaError.self) { try model.dependencyReport() }
	}

	// MARK: - Through the report

	@Test("Each cycle in a model is classified on its own formulas")
	func cyclesAreClassifiedIndependently() throws {
		let report = try ModelDefinition<Double>()
			.defining("a", as: "b * 2")
			.defining("b", as: "a + 1")
			.defining("x", as: "y * z")
			.defining("y", as: "x + 1")
			.defining("z", as: "x + 2")
			.dependencyReport()

		#expect(report.cycles.map(\.accounts) == [["a", "b"], ["x", "y", "z"]])
		#expect(report.cycles.map(\.form) == [.linear, .nonlinear])
	}

	@Test("An acyclic model has nothing to classify and can be solved exactly")
	func acyclicIsExactlySolvable() throws {
		let report = try ModelDefinition<Double>()
			.defining("grossProfit", as: "revenue - cogs")
			.dependencyReport()

		#expect(report.cycles.isEmpty)
		#expect(report.isExactlySolvable)
	}

	/// The question a caller asks before deciding anything: is there an exact answer here, or
	/// will something have to be iterated to a tolerance?
	@Test("A model is exactly solvable when every cycle in it is linear")
	func exactlySolvableWhenEveryCycleIsLinear() throws {
		let linear = try ModelDefinition<Double>()
			.defining("a", as: "b * 2")
			.defining("b", as: "a + 1")
			.dependencyReport()

		let mixed = try ModelDefinition<Double>()
			.defining("a", as: "b * 2")
			.defining("b", as: "a + 1")
			.defining("x", as: "y * y")
			.defining("y", as: "x + 1")
			.dependencyReport()

		#expect(linear.isExactlySolvable)
		#expect(mixed.isExactlySolvable == false)
	}

	/// Form is a property of the formulas, and identity is the membership. A rename inside a
	/// cycle changes neither, so nothing keyed on a cycle stops matching because a formula was
	/// rewritten in a way that did not change its degree.
	@Test("Form does not take part in a cycle's identity")
	func formIsNotPartOfIdentity() throws {
		let linear = DependencyCycle(accounts: ["a", "b"], path: ["a", "b", "a"], form: .linear)
		let nonlinear = DependencyCycle(accounts: ["a", "b"], path: ["a", "b", "a"], form: .nonlinear)

		#expect(linear == nonlinear)
		#expect(linear.hashValue == nonlinear.hashValue)
	}
}
