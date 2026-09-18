import Testing
import Foundation
@testable import BusinessMath

/// The bytecode pipeline checked against an independent evaluator.
///
/// ## Why this suite exists
///
/// `Expression` has no direct evaluator: the only way to get a number out of one is to compile
/// it to bytecode and interpret that. So nothing in the package could say whether the compiler
/// and interpreter agree with the expression's *meaning* — there was no second opinion to
/// disagree with. `BytecodeInterpreter.evaluate` carries a cognitive complexity of 104 and had
/// no oracle behind it at all.
///
/// This supplies one: a plain recursive evaluator, written here, sharing no code with the
/// compiler, the optimizer or the interpreter. Agreement between the two is evidence; a
/// round-trip through the same code would not be.
///
/// Two differentials, because there are two transformations to doubt:
///
/// 1. **meaning vs machine** — the tree-walker against `interpret(compile(e))`
/// 2. **optimised vs not** — `interpret(compile(e))` against `interpret(optimize(compile(e)))`
///
/// The second is where algebraic rewriting lives, and rewriting is where floating point gets
/// betrayed: `a * 0 → 0` is false for `NaN` and infinity, `a + 0 → a` is false for `-0.0`. The
/// optimizer already declines the first and picks `a + (-0.0) → a` for the second, which is the
/// signed-zero-correct form — this suite is what keeps that true.
@Suite("Bytecode differential")
struct BytecodeDifferentialTests {

	// MARK: - The oracle

	/// Evaluate an expression directly, by walking it.
	///
	/// Mirrors the interpreter's *documented* semantics rather than its implementation: division
	/// refuses a zero divisor, `log` refuses a non-positive argument, `sqrt` refuses a negative
	/// one, comparisons yield 1 or 0, and equality is within 1e-10. A conditional evaluates all
	/// three of its operands, because the compiler emits all three before `select` — see
	/// ``conditionalsDoNotShortCircuit``.
	static func walk(_ expression: BusinessMath.Expression, _ inputs: [Double]) throws -> Double {
		switch expression {
		case .input(let index):
			guard index >= 0 && index < inputs.count else {
				throw EvaluationError.invalidInputIndex(index, available: inputs.count)
			}
			return inputs[index]

		case .constant(let value):
			return value

		case .unary(let op, let operand):
			let a = try walk(operand, inputs)
			switch op {
			case .negate: return -a
			case .abs: return Swift.abs(a)
			case .sqrt:
				guard a >= 0 else { throw EvaluationError.invalidOperation("sqrt of negative") }
				return Foundation.sqrt(a)
			case .log:
				guard a > 0 else { throw EvaluationError.invalidOperation("log of non-positive") }
				return Foundation.log(a)
			case .exp: return Foundation.exp(a)
			case .sin: return Foundation.sin(a)
			case .cos: return Foundation.cos(a)
			case .tan: return Foundation.tan(a)
			}

		case .binary(let op, let left, let right):
			let a = try walk(left, inputs)
			let b = try walk(right, inputs)
			switch op {
			case .add: return a + b
			case .subtract: return a - b
			case .multiply: return a * b
			case .divide:
				guard b != 0 else { throw EvaluationError.divisionByZero }
				return a / b
			case .power: return Foundation.pow(a, b)
			case .min: return Swift.min(a, b)
			case .max: return Swift.max(a, b)
			case .lessThan: return a < b ? 1 : 0
			case .greaterThan: return a > b ? 1 : 0
			case .lessOrEqual: return a <= b ? 1 : 0
			case .greaterOrEqual: return a >= b ? 1 : 0
			case .equal: return Swift.abs(a - b) < 1e-10 ? 1 : 0
			case .notEqual: return Swift.abs(a - b) >= 1e-10 ? 1 : 0
			}

		case .conditional(let condition, let whenTrue, let whenFalse):
			// Eager on purpose: the compiler emits all three operands and then `select`, so a
			// failing branch fails the whole expression even when it is not selected.
			let test = try walk(condition, inputs)
			let t = try walk(whenTrue, inputs)
			let f = try walk(whenFalse, inputs)
			return test != 0 ? t : f
		}
	}

	// MARK: - Generation

	private struct Generator {
		var state: UInt64
		mutating func next(_ bound: Int) -> Int {
			state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
			return Int((state >> 33) % UInt64(bound))
		}
	}

	/// Constants drawn from the values that break algebraic rewriting, not from a uniform range.
	///
	/// Zero and one are the identities a simplifier rewrites around; negative zero is the one a
	/// naive `a + 0 → a` gets wrong; the rest give the arithmetic somewhere to overflow.
	private static let constantPool: [Double] = [
		0.0, -0.0, 1.0, -1.0, 2.0, 0.5, -3.25, 10.0, 1e8, 1e-8
	]

	private static func generate(_ rng: inout Generator, depth: Int, inputCount: Int) -> BusinessMath.Expression {
		// At depth zero only leaves, so the tree terminates.
		if depth <= 0 || rng.next(4) == 0 {
			return rng.next(2) == 0
				? .input(rng.next(inputCount))
				: .constant(constantPool[rng.next(constantPool.count)])
		}

		switch rng.next(3) {
		case 0:
			let ops: [BusinessMath.Expression.UnaryOp] = [.negate, .abs, .exp, .sin, .cos, .tan]
			return .unary(ops[rng.next(ops.count)], generate(&rng, depth: depth - 1, inputCount: inputCount))
		case 1:
			let ops: [BusinessMath.Expression.BinaryOp] = [
				.add, .subtract, .multiply, .power, .min, .max,
				.lessThan, .greaterThan, .lessOrEqual, .greaterOrEqual, .equal, .notEqual
			]
			return .binary(
				ops[rng.next(ops.count)],
				generate(&rng, depth: depth - 1, inputCount: inputCount),
				generate(&rng, depth: depth - 1, inputCount: inputCount))
		default:
			return .conditional(
				generate(&rng, depth: depth - 1, inputCount: inputCount),
				generate(&rng, depth: depth - 1, inputCount: inputCount),
				generate(&rng, depth: depth - 1, inputCount: inputCount))
		}
	}

	/// Inputs chosen to exercise the edges, not the middle.
	private static let inputSets: [[Double]] = [
		[0.0, 1.0, -1.0],
		[-0.0, 2.5, 1e6],
		[1e-9, -4.0, 0.5],
		[3.0, 0.0, -0.0],
		[1e10, -1e10, 7.0]
	]

	/// Two results agree when they are the same number, or both are NaN.
	///
	/// `NaN != NaN`, so an equality test alone would report every NaN pair as a disagreement —
	/// and NaN is a legitimate shared answer here, since `pow` and `tan` produce it.
	static func agree(_ a: Double, _ b: Double) -> Bool {
		if a.isNaN && b.isNaN { return true }
		if a == b { return true }
		// Both infinite with the same sign compares equal above; anything else needs a
		// tolerance, because the optimizer may fold constants in a different association order.
		guard a.isFinite && b.isFinite else { return false }
		let scale = Swift.max(1.0, Swift.max(Swift.abs(a), Swift.abs(b)))
		return Swift.abs(a - b) <= 1e-9 * scale
	}

	/// What an evaluation produced: a number, or the fact that it refused.
	enum Outcome: Equatable {
		case value(Double)
		case refused

		static func of(_ body: () throws -> Double) -> Outcome {
			do { return .value(try body()) } catch { return .refused }
		}

		func matches(_ other: Outcome) -> Bool {
			switch (self, other) {
			case (.refused, .refused): return true
			case (.value(let a), .value(let b)): return agree(a, b)
			default: return false
			}
		}
	}

	// MARK: - The claims

	@Test("Compiled bytecode computes what the expression means")
	func compiledMatchesTheTreeWalk() throws {
		var rng = Generator(state: 20_260_918)
		var checked = 0
		var failures: [String] = []

		for _ in 0..<400 {
			let expression = Self.generate(&rng, depth: 4, inputCount: 3)
			guard let bytecode = try? BytecodeCompiler.compile(expression) else { continue }

			for inputs in Self.inputSets {
				checked += 1
				let expected = Outcome.of { try Self.walk(expression, inputs) }
				let actual = Outcome.of { try BytecodeInterpreter.evaluate(bytecode: bytecode, inputs: inputs) }
				if !expected.matches(actual) {
					failures.append("walk \(expected) vs bytecode \(actual) on \(inputs) for \(expression)")
				}
			}
		}

		#expect(checked > 1_500, "only \(checked) evaluations ran")
		let report = failures.prefix(4).joined(separator: "\n")
		#expect(failures.isEmpty, "\(failures.count) of \(checked) disagreed:\n\(report)")
	}

	@Test("Optimising bytecode does not change what it computes")
	func optimisedMatchesUnoptimised() throws {
		var rng = Generator(state: 777_001)
		var checked = 0
		var failures: [String] = []

		for _ in 0..<400 {
			let expression = Self.generate(&rng, depth: 4, inputCount: 3)
			guard let bytecode = try? BytecodeCompiler.compile(expression) else { continue }
			let optimised = BytecodeOptimizer.optimize(bytecode)

			for inputs in Self.inputSets {
				checked += 1
				let plain = Outcome.of { try BytecodeInterpreter.evaluate(bytecode: bytecode, inputs: inputs) }
				let fast = Outcome.of { try BytecodeInterpreter.evaluate(bytecode: optimised, inputs: inputs) }
				if !plain.matches(fast) {
					failures.append("plain \(plain) vs optimised \(fast) on \(inputs) for \(expression)")
				}
			}
		}

		#expect(checked > 1_500, "only \(checked) evaluations ran")
		let report = failures.prefix(4).joined(separator: "\n")
		#expect(failures.isEmpty, "\(failures.count) of \(checked) disagreed:\n\(report)")
	}

	/// A conditional evaluates every branch, so a guard cannot protect the branch it guards.
	///
	/// The compiler emits the condition, the true operand and the false operand, and only then
	/// `select`. `if x >= 0 then sqrt(x) else 0` therefore **throws** for negative `x`, which is
	/// the opposite of what the shape of the expression suggests to a reader.
	///
	/// Pinned rather than changed: making it lazy would change what every existing model
	/// computes, and the GPU kernels the bytecode also targets have no branch to be lazy with.
	/// It is recorded here so the behaviour is a decision rather than a surprise.
	@Test("Conditionals do not short-circuit")
	func conditionalsDoNotShortCircuit() throws {
		// if x >= 0 then sqrt(x) else 0
		let guarded = BusinessMath.Expression.conditional(
			.binary(.greaterOrEqual, .input(0), .constant(0)),
			.unary(.sqrt, .input(0)),
			.constant(0)
		)
		let bytecode = try BytecodeCompiler.compile(guarded)

		let positive = try BytecodeInterpreter.evaluate(bytecode: bytecode, inputs: [9.0])
		#expect(positive == 3.0, "sqrt(9) is 3, got \(positive)")

		// The guard says this branch is not taken, and it is evaluated anyway.
		#expect(throws: EvaluationError.self,
				"a conditional evaluates every operand, so the unselected sqrt(-4) still refuses") {
			_ = try BytecodeInterpreter.evaluate(bytecode: bytecode, inputs: [-4.0])
		}
	}
}
