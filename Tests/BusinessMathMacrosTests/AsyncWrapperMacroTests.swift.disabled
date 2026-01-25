//
//  AsyncWrapperMacroTests.swift
//  BusinessMath
//
//  Created on December 30, 2025.
//

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing
@testable import BusinessMathMacrosImpl

/// Tests for async wrapper generation macros
@Suite("Async Wrapper Macro Tests")
struct AsyncWrapperMacroTests {

    // MARK: - Test Helpers

    let testMacros: [String: Macro.Type] = [
        "AsyncWrapper": AsyncWrapperMacro.self
    ]

    // MARK: - @AsyncWrapper Macro Tests

    @Test("@AsyncWrapper generates async version of function")
    func asyncWrapperBasic() {
        assertMacroExpansion(
            """
            @AsyncWrapper
            func calculate(x: Double) -> Double {
                return x * 2
            }
            """,
            expandedSource: """
            func calculate(x: Double) -> Double {
                return x * 2
            }

            func calculateAsync(x: Double) async -> Double {
                return await Task {
                    return calculate(x: x)
                }.value
            }
            """,
            macros: testMacros
        )
    }

    @Test("@AsyncWrapper with throwing function")
    func asyncWrapperThrowing() {
        assertMacroExpansion(
            """
            @AsyncWrapper
            func validate(value: Double) throws -> Bool {
                guard value > 0 else {
                    throw ValidationError.invalid
                }
                return true
            }
            """,
            expandedSource: """
            func validate(value: Double) throws -> Bool {
                guard value > 0 else {
                    throw ValidationError.invalid
                }
                return true
            }

            func validateAsync(value: Double) async throws -> Bool {
                return try await Task {
                    return try validate(value: value)
                }.value
            }
            """,
            macros: testMacros
        )
    }

    @Test("@AsyncWrapper with multiple parameters")
    func asyncWrapperMultipleParams() {
        assertMacroExpansion(
            """
            @AsyncWrapper
            func add(a: Double, b: Double, c: Double) -> Double {
                return a + b + c
            }
            """,
            expandedSource: """
            func add(a: Double, b: Double, c: Double) -> Double {
                return a + b + c
            }

            func addAsync(a: Double, b: Double, c: Double) async -> Double {
                return await Task {
                    return add(a: a, b: b, c: c)
                }.value
            }
            """,
            macros: testMacros
        )
    }

    @Test("@AsyncWrapper with no parameters")
    func asyncWrapperNoParams() {
        assertMacroExpansion(
            """
            @AsyncWrapper
            func generate() -> Double {
                return 42.0
            }
            """,
            expandedSource: """
            func generate() -> Double {
                return 42.0
            }

            func generateAsync() async -> Double {
                return await Task {
                    return generate()
                }.value
            }
            """,
            macros: testMacros
        )
    }
}
