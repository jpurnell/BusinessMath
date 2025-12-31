//
//  AsyncWrapperMacro.swift
//  BusinessMath
//
//  Created on December 30, 2025.
//

import SwiftSyntax
import SwiftSyntaxMacros

/// Macro that generates async wrapper functions for synchronous functions
public struct AsyncWrapperMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // 1. Verify this is a function declaration
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            return []
        }

        // 2. Extract function information
        let functionName = funcDecl.name.text
        let parameters = funcDecl.signature.parameterClause.parameters
        let isThrows = funcDecl.signature.effectSpecifiers?.throwsSpecifier != nil
        let returnType = funcDecl.signature.returnClause?.type.description.trimmingCharacters(in: .whitespaces) ?? "Void"

        // 3. Generate parameter list for function call
        let paramList = parameters.map { parameter -> String in
            let name = parameter.secondName?.text ?? parameter.firstName.text
            let label = parameter.firstName.text
            return "\(label): \(name)"
        }.joined(separator: ", ")

        // 4. Generate parameter list for function signature
        let paramSigList = parameters.map { parameter -> String in
            parameter.description.trimmingCharacters(in: .whitespaces)
        }.joined(separator: ", ")

        // 5. Generate async wrapper function
        let throwsKeyword = isThrows ? "throws " : ""
        let tryKeyword = isThrows ? "try " : ""
        let asyncThrowsKeyword = isThrows ? " throws" : ""

        let asyncWrapper: DeclSyntax = """

        func \(raw: functionName)Async(\(raw: paramSigList)) async\(raw: asyncThrowsKeyword) -> \(raw: returnType) {
            return \(raw: tryKeyword)await Task {
                return \(raw: tryKeyword)\(raw: functionName)(\(raw: paramList))
            }.value
        }
        """

        return [asyncWrapper]
    }
}
