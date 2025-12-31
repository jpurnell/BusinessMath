//
//  BuilderMacros.swift
//  BusinessMath
//
//  Created on December 30, 2025.
//

import SwiftSyntax
import SwiftSyntaxMacros

/// Macro that generates builder initialization methods for structs
public struct BuilderInitializableMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // 1. Extract struct name
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            return []
        }

        let structName = structDecl.name.text

        // 2. Generate builder method
        let builderMethod: DeclSyntax = """

        static func build(@\(raw: structName)Builder builder: () -> \(raw: structName)) -> \(raw: structName) {
            return builder()
        }
        """

        return [builderMethod]
    }
}
