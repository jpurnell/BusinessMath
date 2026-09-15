//
//  BytecodeFaultInjectionTests.swift
//  BusinessMath
//
//  Fault injection tests verifying the bytecode interpreter and expression
//  model handle pathological inputs gracefully (division by zero, sqrt of
//  negative, log of non-positive, stack underflow, etc.)
//

import Foundation
import Testing
@testable import BusinessMath

@Suite("Bytecode Fault Injection Tests")
struct BytecodeFaultInjectionTests {

	@Test("Division by zero in expression throws divisionByZero")
	func divisionByZero() throws {
		let model = try MonteCarloExpressionModel { builder in
			builder[0] / builder[1]
		}

		// `EvaluationError` is not `Equatable`, so the case is matched by hand.
		#expect {
			_ = try model.evaluate(inputs: [1.0, 0.0])
		} throws: { error in
			guard case EvaluationError.divisionByZero = error else { return false }
			return true
		}
	}

	@Test("Square root of negative input throws invalidOperation")
	func sqrtOfNegative() throws {
		let bytecode: [Bytecode] = [.input(0), .sqrt]

		#expect {
			_ = try BytecodeInterpreter.evaluate(bytecode: bytecode, inputs: [-4.0])
		} throws: { error in
			guard case let EvaluationError.invalidOperation(what) = error else { return false }
			return what == "sqrt of negative"
		}
	}

	@Test("Log of zero throws invalidOperation")
	func logOfZero() throws {
		let bytecode: [Bytecode] = [.input(0), .log]

		#expect {
			_ = try BytecodeInterpreter.evaluate(bytecode: bytecode, inputs: [0.0])
		} throws: { error in
			guard case let EvaluationError.invalidOperation(what) = error else { return false }
			return what == "log of non-positive"
		}
	}

	@Test("Log of negative throws invalidOperation")
	func logOfNegative() throws {
		let bytecode: [Bytecode] = [.input(0), .log]

		// Zero and a negative argument meet the same guard, and report the same way.
		#expect {
			_ = try BytecodeInterpreter.evaluate(bytecode: bytecode, inputs: [-1.0])
		} throws: { error in
			guard case let EvaluationError.invalidOperation(what) = error else { return false }
			return what == "log of non-positive"
		}
	}

	@Test("Accessing out-of-bounds input index throws invalidInputIndex")
	func invalidInputIndex() throws {
		let model = try MonteCarloExpressionModel { builder in
			builder[2]
		}

		// The index asked for and the number available, which is what makes it actionable.
		#expect {
			_ = try model.evaluate(inputs: [1.0, 2.0])
		} throws: { error in
			guard case let EvaluationError.invalidInputIndex(index, available) = error else { return false }
			return index == 2 && available == 2
		}
	}

	@Test("Empty bytecode throws invalidStack")
	func emptyBytecode() throws {
		// Empty bytecode leaves nothing on the stack, and the count says so.
		#expect {
			_ = try BytecodeInterpreter.evaluate(bytecode: [], inputs: [])
		} throws: { error in
			guard case let EvaluationError.invalidStack(count) = error else { return false }
			return count == 0
		}
	}

	@Test("Binary operation with empty stack throws stackUnderflow")
	func stackUnderflowOnAdd() throws {
		#expect {
			_ = try BytecodeInterpreter.evaluate(bytecode: [.add], inputs: [])
		} throws: { error in
			guard case EvaluationError.stackUnderflow = error else { return false }
			return true
		}
	}

	@Test("Binary operation with one element throws stackUnderflow")
	func stackUnderflowOnDivide() throws {
		let bytecode: [Bytecode] = [.input(0), .divide]

		// One operand where two are needed is the same underflow as none at all.
		#expect {
			_ = try BytecodeInterpreter.evaluate(bytecode: bytecode, inputs: [5.0])
		} throws: { error in
			guard case EvaluationError.stackUnderflow = error else { return false }
			return true
		}
	}

	@Test("Valid expression model compiles and evaluates without throwing")
	func validExpressionModel() throws {
		let model = try MonteCarloExpressionModel { builder in
			builder[0] + builder[1]
		}

		let result = try model.evaluate(inputs: [10.0, 20.0])
		#expect(abs(result - 30.0) < 1e-6, "10.0 + 20.0 should equal 30.0")
	}
}
