//
//  DEAModel.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-07-01.
//

import Foundation

/// Specifies constant or variable returns to scale.
public enum DEAReturnsToScale: Sendable, Equatable {
    /// Constant returns to scale (CRS).
    case constant
    /// Variable returns to scale (VRS).
    case variable
}

/// Specifies the base DEA model for super-efficiency analysis.
public enum DEABaseModel: Sendable, Equatable {
    /// Charnes-Cooper-Rhodes model (constant returns to scale).
    case ccr
    /// Banker-Charnes-Cooper model (variable returns to scale).
    case bcc
}

/// Specifies the DEA model type.
public enum DEAModelType: Sendable, Equatable {
    /// Charnes-Cooper-Rhodes model (constant returns to scale).
    case ccr
    /// Banker-Charnes-Cooper model (variable returns to scale).
    case bcc
    /// Andersen-Petersen super-efficiency model.
    ///
    /// Removes the evaluated DMU from its own reference set,
    /// allowing efficient DMUs to score above 1.0 for ranking.
    case superEfficiency(base: DEABaseModel)
    /// Slacks-Based Measure (Tone 2001). Non-oriented.
    ///
    /// Simultaneously optimizes all input reductions and output expansions.
    /// The orientation parameter is ignored for SBM models.
    case sbm(returnsToScale: DEAReturnsToScale)
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
