//
//  OptimizationMacroTests.swift
//  BusinessMath
//
//  Created on December 30, 2025.
//

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing
@testable import BusinessMathMacrosImpl

/// Tests for optimization DSL macros (@Variable, @Constraint, @Objective)
@Suite("Optimization Macro Tests")
struct OptimizationMacroTests {

    // MARK: - Test Helpers

    let testMacros: [String: Macro.Type] = [
        "Variable": VariableMacro.self,
        "Constraint": ConstraintMacro.self,
        "Objective": ObjectiveMacro.self
    ]

    // MARK: - @Variable Macro Tests

    @Test("@Variable macro adds bounds information")
    func variableWithBounds() {
        assertMacroExpansion(
            """
            struct Portfolio {
                @Variable(bounds: 0...1)
                var stocks: Double
            }
            """,
            expandedSource: """
            struct Portfolio {
                var stocks: Double

                var stocks_bounds: ClosedRange<Double> {
                    return 0.0...1.0
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("@Variable macro with negative bounds")
    func variableWithNegativeBounds() {
        assertMacroExpansion(
            """
            struct Problem {
                @Variable(bounds: -10.0...10.0)
                var x: Double
            }
            """,
            expandedSource: """
            struct Problem {
                var x: Double

                var x_bounds: ClosedRange<Double> {
                    return -10.0...10.0
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("@Variable macro with unbounded (large range)")
    func variableUnbounded() {
        assertMacroExpansion(
            """
            struct Problem {
                @Variable(bounds: -1000.0...1000.0)
                var y: Double
            }
            """,
            expandedSource: """
            struct Problem {
                var y: Double

                var y_bounds: ClosedRange<Double> {
                    return -1000.0...1000.0
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - @Constraint Macro Tests

    @Test("@Constraint macro marks constraint function")
    func constraintFunction() {
        assertMacroExpansion(
            """
            struct Portfolio {
                @Constraint
                func sumToOne() -> Bool {
                    return stocks + bonds == 1.0
                }
            }
            """,
            expandedSource: """
            struct Portfolio {
                func sumToOne() -> Bool {
                    return stocks + bonds == 1.0
                }

                var sumToOne_constraint: String {
                    return "sumToOne"
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("@Constraint macro with inequality")
    func constraintInequality() {
        assertMacroExpansion(
            """
            struct Problem {
                @Constraint
                func nonNegative() -> Bool {
                    return x >= 0
                }
            }
            """,
            expandedSource: """
            struct Problem {
                func nonNegative() -> Bool {
                    return x >= 0
                }

                var nonNegative_constraint: String {
                    return "nonNegative"
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - @Objective Macro Tests

    @Test("@Objective macro marks objective function")
    func objectiveFunction() {
        assertMacroExpansion(
            """
            struct Portfolio {
                @Objective
                func sharpeRatio() -> Double {
                    return (expectedReturn - riskFreeRate) / volatility
                }
            }
            """,
            expandedSource: """
            struct Portfolio {
                func sharpeRatio() -> Double {
                    return (expectedReturn - riskFreeRate) / volatility
                }

                var objectiveFunction: () -> Double {
                    return sharpeRatio
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("@Objective macro with complex calculation")
    func objectiveComplexCalculation() {
        assertMacroExpansion(
            """
            struct Problem {
                @Objective
                func cost() -> Double {
                    return x * x + y * y
                }
            }
            """,
            expandedSource: """
            struct Problem {
                func cost() -> Double {
                    return x * x + y * y
                }

                var objectiveFunction: () -> Double {
                    return cost
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Integration Tests

    @Test("Multiple variables with different bounds")
    func multipleVariables() {
        assertMacroExpansion(
            """
            struct Portfolio {
                @Variable(bounds: 0...1)
                var stocks: Double

                @Variable(bounds: 0...1)
                var bonds: Double

                @Variable(bounds: 0...0.3)
                var cash: Double
            }
            """,
            expandedSource: """
            struct Portfolio {
                var stocks: Double

                var stocks_bounds: ClosedRange<Double> {
                    return 0.0...1.0
                }
                var bonds: Double

                var bonds_bounds: ClosedRange<Double> {
                    return 0.0...1.0
                }
                var cash: Double

                var cash_bounds: ClosedRange<Double> {
                    return 0.0...0.3
                }
            }
            """,
            macros: testMacros
        )
    }
}
