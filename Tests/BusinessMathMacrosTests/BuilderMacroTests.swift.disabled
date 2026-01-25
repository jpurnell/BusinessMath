//
//  BuilderMacroTests.swift
//  BusinessMath
//
//  Created on December 30, 2025.
//

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing
@testable import BusinessMathMacrosImpl

/// Tests for builder generation macros
@Suite("Builder Macro Tests")
struct BuilderMacroTests {

    // MARK: - Test Helpers

    let testMacros: [String: Macro.Type] = [
        "BuilderInitializable": BuilderInitializableMacro.self
    ]

    // MARK: - @BuilderInitializable Macro Tests

    @Test("@BuilderInitializable generates builder method")
    func builderGeneratesInitMethod() {
        assertMacroExpansion(
            """
            @BuilderInitializable
            struct Portfolio {
                var stocks: Double
                var bonds: Double
            }
            """,
            expandedSource: """
            struct Portfolio {
                var stocks: Double
                var bonds: Double

                static func build(@PortfolioBuilder builder: () -> Portfolio) -> Portfolio {
                    return builder()
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("@BuilderInitializable with single property")
    func builderSingleProperty() {
        assertMacroExpansion(
            """
            @BuilderInitializable
            struct SimpleModel {
                var value: Double
            }
            """,
            expandedSource: """
            struct SimpleModel {
                var value: Double

                static func build(@SimpleModelBuilder builder: () -> SimpleModel) -> SimpleModel {
                    return builder()
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("@BuilderInitializable with multiple properties")
    func builderMultipleProperties() {
        assertMacroExpansion(
            """
            @BuilderInitializable
            struct CashFlow {
                var revenue: Double
                var expenses: Double
                var taxes: Double
                var depreciation: Double
            }
            """,
            expandedSource: """
            struct CashFlow {
                var revenue: Double
                var expenses: Double
                var taxes: Double
                var depreciation: Double

                static func build(@CashFlowBuilder builder: () -> CashFlow) -> CashFlow {
                    return builder()
                }
            }
            """,
            macros: testMacros
        )
    }
}
