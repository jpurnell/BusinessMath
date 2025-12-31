//
//  Plugin.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-12-29.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

/// Compiler plugin that provides BusinessMath macros.
@main
struct BusinessMathMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        MCPToolMacro.self,
        ValidatedMacro.self,
        VariableMacro.self,
        ConstraintMacro.self,
        ObjectiveMacro.self,
        BuilderInitializableMacro.self,
        AsyncWrapperMacro.self
    ]
}
