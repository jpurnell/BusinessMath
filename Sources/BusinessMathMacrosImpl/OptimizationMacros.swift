//
//  OptimizationMacros.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-12-29.
//

import SwiftSyntax
import SwiftSyntaxMacros

/// Macro for marking optimization variables
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

        // 2. Extract the variable name
        guard let binding = varDecl.bindings.first,
              let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
            return []
        }

        let varName = pattern.identifier.text

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
                    boundsLower = elements[elements.startIndex].description.trimmingCharacters(in: .whitespaces)
                    // Third element is upper bound (middle is the ... operator)
                    let upperIndex = elements.index(elements.startIndex, offsetBy: 2)
                    boundsUpper = elements[upperIndex].description.trimmingCharacters(in: .whitespaces)
                }
            }
        }

        guard let lower = boundsLower, let upper = boundsUpper else {
            return []
        }

        // 4. Generate bounds computed property
        let boundsProperty: DeclSyntax = """

        var \(raw: varName)_bounds: ClosedRange<Double> {
            return \(raw: lower)...\(raw: upper)
        }
        """

        return [boundsProperty]
    }
}

/// Macro for defining optimization constraints
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

        // 3. Generate constraint identifier property
        let constraintProperty: DeclSyntax = """

        var \(raw: functionName)_constraint: String {
            return "\(raw: functionName)"
        }
        """

        return [constraintProperty]
    }
}

/// Macro for defining optimization objectives
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

        // 3. Generate objective function property
        let objectiveProperty: DeclSyntax = """

        var objectiveFunction: () -> Double {
            return \(raw: functionName)
        }
        """

        return [objectiveProperty]
    }
}
