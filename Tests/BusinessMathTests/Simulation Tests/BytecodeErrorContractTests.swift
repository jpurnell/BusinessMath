//
//  BytecodeErrorContractTests.swift
//  BusinessMathTests
//
//  What the interpreter does when it cannot answer, and what the caller is told.
//

import Testing
import Foundation
@testable import BusinessMath

/// The contract for a bytecode program that cannot be evaluated.
///
/// ## Why this suite exists
///
/// `BytecodeInterpreter.evaluate` carries a cognitive complexity of 104 across twenty-two
/// instruction cases. Its *arithmetic* already has an oracle — `BytecodeDifferentialTests` walks
/// the expression tree independently and agrees with it over thousands of evaluations — but a
/// differential can only compare answers. It says nothing about what happens when there is no
/// answer to give, which is the half of the contract that decides whether a wrong number reaches
/// a simulation.
///
/// And that is where the defect was. The interpreter is careful: `sqrt` of a negative, `log` of
/// a non-positive, and division by zero each **throw**, naming what went wrong.
/// ``MonteCarloExpressionModel/toClosure()`` then caught every one of those and returned `0.0`.
///
/// `0.0` is a number the model never produced. Measured on `log(x)` over 300 draws spanning
/// `[-1, 3]`:
///
/// | | |
/// |---|---|
/// | draws that threw | **75** |
/// | zeros substituted | **75** |
/// | mean reported | 0.0707 |
/// | mean over the draws that were actually defined | 0.0943 |
/// | NaN or infinity anywhere in the samples | **none** |
///
/// A 25% error in the reported mean, with nothing in the output to suggest anything had gone
/// wrong. `MonteCarloSimulation` uses this closure as its CPU path, so that is a simulation
/// result, not an internal detail. It is the case the package's fail-silent rule exists for:
/// never return a plausible-but-wrong result.
@Suite("What the interpreter says when it cannot answer")
struct BytecodeErrorContractTests {

	/// The instructions that refuse a value rather than inventing one.
	///
	/// Pinned as a table because the interpreter and ``BytecodeOptimizer`` must agree on it: the
	/// optimizer declines to constant-fold exactly the operations that would throw, so that
	/// optimising a model never turns a raised error into a silent number. A new guard added to
	/// one and not the other breaks that, and this is what notices.
	@Test("Domain errors throw rather than returning a value", arguments: [
		("sqrt of a negative", [Bytecode.constant(-1), .sqrt]),
		("log of a negative", [Bytecode.constant(-1), .log]),
		("log of zero", [Bytecode.constant(0), .log]),
		("division by zero", [Bytecode.constant(1), .constant(0), .divide]),
		("division by negative zero", [Bytecode.constant(1), .constant(-0.0), .divide])
	])
	func domainErrorsThrow(named: String, bytecode: [Bytecode]) throws {
		#expect(throws: EvaluationError.self, "\(named) must refuse, not return") {
			_ = try BytecodeInterpreter.evaluate(bytecode: bytecode, inputs: [])
		}

		// And optimising must not convert the refusal into a value.
		let optimised = BytecodeOptimizer.optimize(bytecode)
		#expect(throws: EvaluationError.self,
				"\(named) returned a value once optimised, so optimisation changed the answer") {
			_ = try BytecodeInterpreter.evaluate(bytecode: optimised, inputs: [])
		}
	}

	/// `power` does not guard its domain, and that is recorded rather than changed.
	///
	/// `(-1) ^ 0.5` is the same mathematical domain error as `sqrt(-1)`, and `0 ^ -1` is the same
	/// one as `1 / 0`, but `power` forwards to `pow` and returns `NaN` and `+∞` respectively.
	///
	/// Left alone deliberately. A non-finite result is *loud*: it propagates through every mean,
	/// variance and quantile downstream and cannot be mistaken for an answer, which is the
	/// property the `0.0` substitution lacked and the reason that one was a defect and this is
	/// not. Adding guards here would also change what `x ^ y` means for every existing model, to
	/// fix an asymmetry that costs nobody a wrong number.
	///
	/// Pinned so that the asymmetry is a decision on the record rather than an oversight waiting
	/// to be discovered again.
	@Test("Power reaches non-finite values where the named spellings throw", arguments: [
		("(-1) ^ 0.5", [Bytecode.constant(-1), .constant(0.5), .power], true),
		("(-8) ^ (1/3)", [Bytecode.constant(-8), .constant(1.0 / 3.0), .power], true),
		("0 ^ -1", [Bytecode.constant(0), .constant(-1), .power], false)
	])
	func powerIsNotGuarded(named: String, bytecode: [Bytecode], expectNaN: Bool) throws {
		let value = try BytecodeInterpreter.evaluate(bytecode: bytecode, inputs: [])
		#expect(!value.isFinite, "\(named) is a domain error, so it cannot be finite; got \(value)")
		#expect(value.isNaN == expectNaN,
				"\(named): expected NaN \(expectNaN), got \(value)")
	}

	// MARK: - The closure handed to simulations

	/// A model that cannot be evaluated must not report a plausible number.
	///
	/// `toClosure()` cannot throw — its type is `([Double]) -> Double`, because that is what
	/// `MonteCarloSimulation` takes — so it has exactly one way to say "no answer", and that is a
	/// value no arithmetic produces. It used to say `0.0` instead, which is a value arithmetic
	/// produces constantly.
	///
	/// The distinction is not stylistic. `0.0` averages in. `NaN` does not: it propagates through
	/// the mean and every statistic taken from it, so a model with an unhandled domain error
	/// reports as broken rather than as slightly different.
	@Test("The simulation closure reports failure as non-finite, not as zero")
	func theClosureDoesNotSubstituteAPlausibleNumber() throws {
		let model = try MonteCarloExpressionModel { b in b[0].log() }
		let closure = model.toClosure()

		// Defined: the closure and the throwing path agree.
		let e = Foundation.exp(1.0)
		let defined = closure([e])
		let viaEvaluate = try model.evaluate(inputs: [e])
		#expect(abs(defined - 1.0) < 1e-12, "log(e) is 1, the closure returned \(defined)")
		#expect(abs(defined - viaEvaluate) < 1e-12,
				"the two paths disagree on a value both can compute")

		// Undefined: `evaluate` throws, so the closure must not produce a usable number.
		#expect(throws: EvaluationError.self) {
			_ = try model.evaluate(inputs: [-1.0])
		}
		let undefined = closure([-1.0])
		#expect(!undefined.isFinite,
				"""
				log(-1) has no value, but the closure returned \(undefined) — a number that \
				averages into a simulation result indistinguishably from a real sample
				""")
	}

	/// The measurement that made the severity legible, kept as a test.
	///
	/// A sweep over `[-1, 3]` puts a quarter of the draws outside `log`'s domain. With `0.0`
	/// substituted the reported mean was wrong by 25% and every sample was finite. The assertion
	/// is that the failures are *visible*, not that they are absent: a model with a domain error
	/// on a quarter of its draws is a modelling problem, and the library's job is to say so.
	@Test("A quarter-invalid sweep is visibly invalid, not quietly shifted")
	func aPartlyUndefinedSweepIsVisiblyUndefined() throws {
		let model = try MonteCarloExpressionModel { b in b[0].log() }
		let closure = model.toClosure()

		let count = 300
		var samples: [Double] = []
		var refusals = 0
		for i in 0..<count {
			let x = -1.0 + 4.0 * Double(i) / Double(count - 1)
			samples.append(closure([x]))
			if (try? model.evaluate(inputs: [x])) == nil { refusals += 1 }
		}

		// The sweep has to actually contain refusals, or it tests nothing.
		try #require(refusals > 0, "the sweep never left log's domain, so it proves nothing")
		#expect(refusals == 75, "expected 75 of 300 draws outside the domain, got \(refusals)")

		let nonFinite = samples.filter { !$0.isFinite }.count
		#expect(nonFinite == refusals,
				"""
				\(refusals) draws could not be evaluated but only \(nonFinite) samples say so; \
				the rest are finite numbers standing in for answers that do not exist
				""")

		// And the summary a caller would compute must inherit that, rather than quietly shifting.
		let mean = samples.reduce(0, +) / Double(count)
		#expect(!mean.isFinite,
				"a mean over undefined samples reported \(mean), which reads as an answer")
	}
}
