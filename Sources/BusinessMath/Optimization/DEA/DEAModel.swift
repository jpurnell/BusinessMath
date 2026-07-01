//
//  DEAModel.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-07-01.
//

import Foundation

/// Specifies the DEA model type.
public enum DEAModelType: Sendable, Equatable {
    /// Charnes-Cooper-Rhodes model (constant returns to scale).
    case ccr
    /// Banker-Charnes-Cooper model (variable returns to scale).
    case bcc
}

/// Specifies the orientation of the DEA model.
public enum DEAOrientation: Sendable, Equatable {
    /// Input-oriented: minimize inputs while maintaining output levels.
    case inputOriented
    /// Output-oriented: maximize outputs while maintaining input levels.
    case outputOriented
}

/// A decision-making unit (DMU) with named inputs and outputs.
public struct DMU: Sendable {
    /// Identifier for this DMU.
    public let name: String
    /// Input values (resources consumed — lower is better).
    public let inputs: [Double]
    /// Output values (benefits produced — higher is better).
    public let outputs: [Double]

    /// Creates a decision-making unit.
    ///
    /// - Parameters:
    ///   - name: Identifier for this DMU (e.g., product name).
    ///   - inputs: Input values. All must be strictly positive.
    ///   - outputs: Output values. All must be strictly positive.
    public init(name: String, inputs: [Double], outputs: [Double]) {
        self.name = name
        self.inputs = inputs
        self.outputs = outputs
    }
}

/// Errors specific to DEA analysis.
public enum DEAError: Error, Sendable {
    /// Fewer than 2 DMUs provided.
    case insufficientDMUs(count: Int)
    /// A DMU has zero or negative input/output values.
    case nonPositiveValues(dmu: String, dimension: String)
    /// DMUs have inconsistent input or output dimensions.
    case dimensionMismatch(expected: Int, actual: Int, dmu: String)
    /// No inputs or no outputs specified.
    case emptyDimension(description: String)
    /// The underlying LP solver failed for a specific DMU.
    case solverFailed(dmu: String, status: SimplexStatus)
}
