//
//  OptimizationMacros.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-12-29.
//

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder
import SwiftCompilerPlugin
import SwiftDiagnostics
import Foundation

/// Macro for marking optimization variables with bounds checking
public struct VariableMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // 1. Verify this is a variable declaration
        guard let varDecl = declaration.as(VariableDeclSyntax.self) else {
            return []
        }

        // 2. Extract the variable name and type
        guard let binding = varDecl.bindings.first,
              let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
            return []
        }

        let varName = pattern.identifier.text

        // Extract type annotation
        let varType = binding.typeAnnotation?.type.description.trimmingCharacters(in: CharacterSet.whitespaces) ?? "Double"

        // 3. Extract bounds from macro arguments
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
            return []
        }

        var boundsLower: String?
        var boundsUpper: String?

        for argument in arguments {
            if argument.label?.text == "bounds",
               let rangeExpr = argument.expression.as(SequenceExprSyntax.self) {
                // Parse range expression like "0...1" or "-10.0...10.0"
                let elements = rangeExpr.elements
                if elements.count >= 3 {
                    // First element is lower bound
                    boundsLower = elements[elements.startIndex].description.trimmingCharacters(in: CharacterSet.whitespaces)
                    // Third element is upper bound (middle is the ... operator)
                    let upperIndex = elements.index(elements.startIndex, offsetBy: 2)
                    boundsUpper = elements[upperIndex].description.trimmingCharacters(in: CharacterSet.whitespaces)
                }
            }
        }

        guard let lower = boundsLower, let upper = boundsUpper else {
            return []
        }

        // 4. Generate enhanced properties and methods
        let generatedCode: DeclSyntax = """

        /// Bounds for \(raw: varName) variable
        var \(raw: varName)_bounds: ClosedRange<\(raw: varType)> {
            return \(raw: lower)...\(raw: upper)
        }

        /// Check if \(raw: varName) is within bounds
        var \(raw: varName)_isValid: Bool {
            return \(raw: varName)_bounds.contains(\(raw: varName))
        }

        /// Clamp \(raw: varName) to valid bounds
        mutating func clamp\(raw: varName.prefix(1).uppercased() + varName.dropFirst())() {
            if \(raw: varName) < \(raw: lower) {
                \(raw: varName) = \(raw: lower)
            } else if \(raw: varName) > \(raw: upper) {
                \(raw: varName) = \(raw: upper)
            }
        }

        /// Set \(raw: varName) with automatic bounds clamping
        mutating func set\(raw: varName.prefix(1).uppercased() + varName.dropFirst())Clamped(_ value: \(raw: varType)) {
            \(raw: varName) = min(max(value, \(raw: lower)), \(raw: upper))
        }
        """

        return [generatedCode]
    }
}

/// Macro for defining optimization constraints with validation
public struct ConstraintMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // 1. Verify this is a function declaration
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            return []
        }

        // 2. Extract function name
        let functionName = funcDecl.name.text

        // 3. Generate enhanced constraint properties and methods
        let generatedCode: DeclSyntax = """

        /// Constraint identifier for \(raw: functionName)
        var \(raw: functionName)_name: String {
            return "\(raw: functionName)"
        }

        /// Validate constraint \(raw: functionName)
        var \(raw: functionName)_isSatisfied: Bool {
            return \(raw: functionName)()
        }

        /// Get constraint violation amount (0 if satisfied)
        var \(raw: functionName)_violation: Double {
            return \(raw: functionName)() ? 0.0 : 1.0
        }
        """

        return [generatedCode]
    }
}

/// Macro for defining optimization objectives with evaluation tracking
public struct ObjectiveMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // 1. Verify this is a function declaration
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            return []
        }

        // 2. Extract function name
        let functionName = funcDecl.name.text

        // 3. Generate enhanced objective properties and methods
        let generatedCode: DeclSyntax = """

        /// Objective function reference for \(raw: functionName)
        var objectiveFunction: () -> Double {
            return \(raw: functionName)
        }

        /// Objective function name
        var objectiveFunctionName: String {
            return "\(raw: functionName)"
        }

        /// Evaluate objective at current state
        var currentObjectiveValue: Double {
            return \(raw: functionName)()
        }

        /// Check if objective is better than target
        func objectiveMeetsTarget(_ target: Double, isMaximization: Bool = false) -> Bool {
            let current = \(raw: functionName)()
            return isMaximization ? current >= target : current <= target
        }
        """

        return [generatedCode]
    }
}
