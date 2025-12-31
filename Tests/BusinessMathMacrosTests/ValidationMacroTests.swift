//
//  ValidationMacroTests.swift
//  BusinessMath
//
//  Created on December 30, 2025.
//

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing
@testable import BusinessMathMacrosImpl

/// Tests for validation macros (@Validated)
@Suite("Validation Macro Tests")
struct ValidationMacroTests {

    // MARK: - Test Helpers

    let testMacros: [String: Macro.Type] = [
        "Validated": ValidatedMacro.self
    ]

    // MARK: - @Validated Macro Tests

    @Test("@Validated macro generates validation method")
    func validatedGeneratesValidationMethod() {
        assertMacroExpansion(
            """
            @Validated
            struct LoanCalculation {
                var principal: Double
                var interestRate: Double
                var years: Int
            }
            """,
            expandedSource: """
            struct LoanCalculation {
                var principal: Double
                var interestRate: Double
                var years: Int

                func validate() throws {
                    // Validation logic placeholder
                }

                var isValid: Bool {
                    do {
                        try validate()
                        return true
                    } catch {
                        return false
                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("@Validated macro on empty struct")
    func validatedEmptyStruct() {
        assertMacroExpansion(
            """
            @Validated
            struct EmptyModel {
            }
            """,
            expandedSource: """
            struct EmptyModel {

                func validate() throws {
                    // Validation logic placeholder
                }

                var isValid: Bool {
                    do {
                        try validate()
                        return true
                    } catch {
                        return false
                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("@Validated macro with multiple properties")
    func validatedMultipleProperties() {
        assertMacroExpansion(
            """
            @Validated
            struct PortfolioModel {
                var stocks: Double
                var bonds: Double
                var cash: Double
                var totalValue: Double
            }
            """,
            expandedSource: """
            struct PortfolioModel {
                var stocks: Double
                var bonds: Double
                var cash: Double
                var totalValue: Double

                func validate() throws {
                    // Validation logic placeholder
                }

                var isValid: Bool {
                    do {
                        try validate()
                        return true
                    } catch {
                        return false
                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("@Validated macro with computed properties")
    func validatedWithComputedProperties() {
        assertMacroExpansion(
            """
            @Validated
            struct Investment {
                var amount: Double
                var returns: Double {
                    return amount * 0.05
                }
            }
            """,
            expandedSource: """
            struct Investment {
                var amount: Double
                var returns: Double {
                    return amount * 0.05
                }

                func validate() throws {
                    // Validation logic placeholder
                }

                var isValid: Bool {
                    do {
                        try validate()
                        return true
                    } catch {
                        return false
                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("@Validated macro with methods")
    func validatedWithMethods() {
        assertMacroExpansion(
            """
            @Validated
            struct Calculator {
                var value: Double

                func calculate() -> Double {
                    return value * 2
                }
            }
            """,
            expandedSource: """
            struct Calculator {
                var value: Double

                func calculate() -> Double {
                    return value * 2
                }

                func validate() throws {
                    // Validation logic placeholder
                }

                var isValid: Bool {
                    do {
                        try validate()
                        return true
                    } catch {
                        return false
                    }
                }
            }
            """,
            macros: testMacros
        )
    }
}
