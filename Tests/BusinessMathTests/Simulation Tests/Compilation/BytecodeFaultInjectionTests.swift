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

		#expect(throws: EvaluationError.self) {
			_ = try model.evaluate(inputs: [1.0, 0.0])
		}
	}

	@Test("Square root of negative input throws invalidOperation")
	func sqrtOfNegative() throws {
		let bytecode: [Bytecode] = [.input(0), .sqrt]

		#expect(throws: EvaluationError.self) {
			_ = try BytecodeInterpreter.evaluate(bytecode: bytecode, inputs: [-4.0])
		}
	}

	@Test("Log of zero throws invalidOperation")
	func logOfZero() throws {
		let bytecode: [Bytecode] = [.input(0), .log]

		#expect(throws: EvaluationError.self) {
			_ = try BytecodeInterpreter.evaluate(bytecode: bytecode, inputs: [0.0])
		}
	}

	@Test("Log of negative throws invalidOperation")
	func logOfNegative() throws {
		let bytecode: [Bytecode] = [.input(0), .log]

		#expect(throws: EvaluationError.self) {
			_ = try BytecodeInterpreter.evaluate(bytecode: bytecode, inputs: [-1.0])
		}
	}

	@Test("Accessing out-of-bounds input index throws invalidInputIndex")
	func invalidInputIndex() throws {
		let model = try MonteCarloExpressionModel { builder in
			builder[2]
		}

		#expect(throws: EvaluationError.self) {
			_ = try model.evaluate(inputs: [1.0, 2.0])
		}
	}

	@Test("Empty bytecode throws invalidStack")
	func emptyBytecode() throws {
		#expect(throws: EvaluationError.self) {
			_ = try BytecodeInterpreter.evaluate(bytecode: [], inputs: [])
		}
	}

	@Test("Binary operation with empty stack throws stackUnderflow")
	func stackUnderflowOnAdd() throws {
		#expect(throws: EvaluationError.self) {
			_ = try BytecodeInterpreter.evaluate(bytecode: [.add], inputs: [])
		}
	}

	@Test("Binary operation with one element throws stackUnderflow")
	func stackUnderflowOnDivide() throws {
		let bytecode: [Bytecode] = [.input(0), .divide]

		#expect(throws: EvaluationError.self) {
			_ = try BytecodeInterpreter.evaluate(bytecode: bytecode, inputs: [5.0])
		}
	}

	@Test("Valid expression model compiles and evaluates without throwing")
	func validExpressionModel() throws {
		let model = try MonteCarloExpressionModel { builder in
			builder[0] + builder[1]
		}

		let result = try model.evaluate(inputs: [10.0, 20.0])
		#expect(result == 30.0, "10.0 + 20.0 should equal 30.0")
	}
}
