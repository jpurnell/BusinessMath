//
//  Plugin.swift
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

/// Compiler plugin that provides BusinessMath macros.
@main
struct BusinessMathMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        // MCP and Tool Macros
        MCPToolMacro.self,

        // Validation Macros
        ValidatedMacro.self,
        PositiveMacro.self,
        NonNegativeMacro.self,
        RangeMacro.self,
        MinMacro.self,
        MaxMacro.self,
        NonEmptyMacro.self,

        // Optimization Macros
        VariableMacro.self,
        ConstraintMacro.self,
        ObjectiveMacro.self,

        // Utility Macros
        BuilderInitializableMacro.self,
        AsyncWrapperMacro.self
    ]
}
