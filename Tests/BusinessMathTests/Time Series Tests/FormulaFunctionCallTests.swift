//
//  FormulaFunctionCallTests.swift
//  BusinessMath
//

import Testing
import Foundation
@testable import BusinessMath

/// Calling a function from a formula.
///
/// The evaluator had no notion of a call at all: its tokens were a number, a name,
/// four operators and two parentheses. These cover the machinery — recognising a
/// call, parsing its arguments, and refusing one it does not know — separately
/// from what any particular function computes.
@Suite("Formula Function Calls")
struct FormulaFunctionCallTests {

    private let months = [
        Period.month(year: 2026, month: 1),
        Period.month(year: 2026, month: 2)
    ]

    private func evaluator(
        _ accounts: [String: [Double]] = ["revenue": [100, 200], "cogs": [40, 80]]
    ) -> FormulaEvaluator<Double> {
        FormulaEvaluator(accounts: accounts.mapValues {
            TimeSeries(periods: Array(months.prefix($0.count)), values: $0)
        })
    }

    // MARK: - Tokenising

    @Test("A comma is a token")
    func commaTokenises() throws {
        let tokens = try FormulaEvaluator<Double>.tokenise("MAX(1, 2)")
        #expect(tokens.contains(.comma))
    }

    @Test("A comma outside a call is still a token, and fails in the parser")
    func strayCommaIsASyntaxError() {
        #expect(throws: FormulaError.self) {
            _ = try FormulaEvaluator<Double>(accounts: [:]).evaluate("1, 2")
        }
    }

    // MARK: - Parsing

    @Test("A name followed by a parenthesis parses as a call")
    func callParses() throws {
        let tokens = try FormulaEvaluator<Double>.tokenise("MAX(1, 2)")
        var parser = FormulaEvaluator<Double>.Parser(tokens: tokens)
        let node = try parser.parseExpression()

        guard case .function(let name, let arguments) = node else {
            Issue.record("Expected a function node, got \(node)")
            return
        }
        #expect(name == "MAX")
        #expect(arguments.count == 2)
    }

    @Test("A name not followed by a parenthesis is still an account")
    func bareNameIsNotACall() throws {
        let tokens = try FormulaEvaluator<Double>.tokenise("revenue")
        var parser = FormulaEvaluator<Double>.Parser(tokens: tokens)
        let node = try parser.parseExpression()

        guard case .name(let name) = node else {
            Issue.record("Expected a name node, got \(node)")
            return
        }
        #expect(name == "revenue")
    }

    @Test("A call takes no arguments at all")
    func zeroArgumentCallParses() throws {
        let tokens = try FormulaEvaluator<Double>.tokenise("NOW()")
        var parser = FormulaEvaluator<Double>.Parser(tokens: tokens)
        let node = try parser.parseExpression()

        guard case .function(let name, let arguments) = node else {
            Issue.record("Expected a function node, got \(node)")
            return
        }
        #expect(name == "NOW")
        #expect(arguments.isEmpty)
    }

    @Test("Calls nest")
    func callsNest() throws {
        let tokens = try FormulaEvaluator<Double>.tokenise("MAX(1, MIN(2, 3))")
        var parser = FormulaEvaluator<Double>.Parser(tokens: tokens)
        let node = try parser.parseExpression()

        guard case .function("MAX", let outer) = node, outer.count == 2,
              case .function("MIN", let inner) = outer[1] else {
            Issue.record("Expected MAX(_, MIN(_, _)), got \(node)")
            return
        }
        #expect(inner.count == 2)
    }

    @Test("A call is an operand like any other")
    func callIsAnOperand() throws {
        let tokens = try FormulaEvaluator<Double>.tokenise("1 + MAX(revenue, cogs) * 2")
        var parser = FormulaEvaluator<Double>.Parser(tokens: tokens)
        let node = try parser.parseExpression()

        guard case .binary(.add, _, let right) = node,
              case .binary(.multiply, let left, let scale) = right,
              case .function(let name, let arguments) = left,
              case .number(let factor) = scale else {
            Issue.record("Expected 1 + (MAX(...) * 2), got \(node)")
            return
        }
        #expect(name == "MAX")
        #expect(arguments.count == 2)
        #expect(factor == 2)
    }

    @Test("An argument is a full expression")
    func argumentsAreExpressions() throws {
        let tokens = try FormulaEvaluator<Double>.tokenise("MAX(revenue - cogs, 0)")
        var parser = FormulaEvaluator<Double>.Parser(tokens: tokens)
        let node = try parser.parseExpression()

        guard case .function(let name, let arguments) = node, arguments.count == 2,
              case .binary(.subtract, let minuend, _) = arguments[0],
              case .number(let floor) = arguments[1] else {
            Issue.record("Expected MAX(<subtraction>, <number>), got \(node)")
            return
        }
        #expect(name == "MAX")
        #expect(floor == 0)
        if case .name(let account) = minuend {
            #expect(account == "revenue")
        } else {
            Issue.record("Expected the subtraction's left side to be an account")
        }
    }

    @Test("A bracketed account name works as an argument")
    func bracketedNameAsArgument() throws {
        let tokens = try FormulaEvaluator<Double>.tokenise("MAX([Sales & Marketing], 0)")
        var parser = FormulaEvaluator<Double>.Parser(tokens: tokens)
        let node = try parser.parseExpression()

        guard case .function("MAX", let arguments) = node,
              case .name(let account) = arguments[0] else {
            Issue.record("Expected a bracketed name argument, got \(node)")
            return
        }
        #expect(account == "Sales & Marketing")
    }

    // MARK: - Malformed Calls

    @Test("An unclosed call is unbalanced parentheses")
    func unclosedCallThrows() throws {
        let tokens = try FormulaEvaluator<Double>.tokenise("MAX(1, 2")
        var parser = FormulaEvaluator<Double>.Parser(tokens: tokens)
        #expect(throws: FormulaError.unbalancedParentheses) {
            _ = try parser.parseExpression()
        }
    }

    @Test("A trailing comma is a syntax error, not an empty argument")
    func trailingCommaThrows() throws {
        let tokens = try FormulaEvaluator<Double>.tokenise("MAX(1,)")
        var parser = FormulaEvaluator<Double>.Parser(tokens: tokens)
        #expect(throws: FormulaError.self) {
            _ = try parser.parseExpression()
        }
    }

    // MARK: - Unknown Functions

    @Test("An unknown function throws rather than evaluating to zero")
    func unknownFunctionThrows() {
        // The whole point. A formula naming a function we do not have must fail
        // loudly: the recognizer upstream reports it as `.unregisteredFunction`,
        // and a silent zero would be a plausible wrong answer in a financial model.
        #expect(throws: FormulaError.unknownFunction("NOPE")) {
            _ = try evaluator().evaluate("NOPE(revenue)")
        }
    }

    @Test("An unknown function names itself in the error")
    func unknownFunctionNamesItself() {
        do {
            _ = try evaluator().evaluate("VLOOKUP(revenue, cogs)")
            Issue.record("Expected a throw")
        } catch let error as FormulaError {
            #expect(error == .unknownFunction("VLOOKUP"))
            #expect(error.errorDescription?.contains("VLOOKUP") == true)
        } catch {
            Issue.record("Expected a FormulaError, got \(error)")
        }
    }

    @Test("Function names are matched case-insensitively")
    func functionNamesAreCaseInsensitive() {
        // Excel does not care, and a formula copied out of a sheet should not
        // fail on capitalisation.
        do {
            _ = try evaluator().evaluate("nope(revenue)")
            Issue.record("Expected a throw")
        } catch let error as FormulaError {
            #expect(error == .unknownFunction("NOPE"))
        } catch {
            Issue.record("Expected a FormulaError, got \(error)")
        }
    }

    @Test("An account may share a name with no function and still resolve")
    func accountNamesAreUnaffected() throws {
        let result = try evaluator(["max": [5, 6]]).evaluate("max")
        #expect(result.valuesArray == [5, 6])
    }
}
