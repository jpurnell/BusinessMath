//
//  DEAResult.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-07-01.
//

import Foundation

/// Complete DEA analysis results.
public struct DEAResult: Sendable {
    /// Per-DMU efficiency evaluation.
    public let scores: [DMUScore]

    /// The model type used.
    public let model: DEAModelType

    /// The orientation used.
    public let orientation: DEAOrientation

    /// Names of efficient DMUs (score == 1.0).
    public var efficientDMUs: [String] {
        scores.filter { $0.isEfficient }.map { $0.name }
    }

    /// Names of inefficient DMUs (score < 1.0).
    public var inefficientDMUs: [String] {
        scores.filter { !$0.isEfficient }.map { $0.name }
    }

    /// Total simplex iterations across all LPs.
    public let totalIterations: Int

    /// Creates a DEA result.
    public init(
        scores: [DMUScore],
        model: DEAModelType,
        orientation: DEAOrientation,
        totalIterations: Int
    ) {
        self.scores = scores
        self.model = model
        self.orientation = orientation
        self.totalIterations = totalIterations
    }
}

/// Efficiency score and improvement targets for a single DMU.
public struct DMUScore: Sendable {
    /// Name of the DMU.
    public let name: String

    /// Normalized efficiency score in (0, 1].
    /// 1.0 = efficient (on the frontier), < 1.0 = inefficient.
    ///
    /// Always normalized to (0, 1] regardless of orientation:
    /// - Input-oriented: theta directly from LP
    /// - Output-oriented: 1/eta where eta is the raw LP result
    public let efficiency: Double

    /// Raw LP objective value before normalization.
    /// - Input-oriented: same as ``efficiency``
    /// - Output-oriented: eta >= 1.0 (output expansion factor)
    public let rawScore: Double

    /// Whether this DMU is on the efficient frontier.
    public var isEfficient: Bool { abs(efficiency - 1.0) < 1e-6 }

    /// Reference set: efficient DMUs that define the comparison point.
    public let referenceSet: [ReferenceUnit]

    /// Target input values to become efficient (input-oriented).
    public let targetInputs: [Double]?

    /// Target output values to become efficient (output-oriented).
    public let targetOutputs: [Double]?

    /// Input slack values.
    public let inputSlacks: [Double]?

    /// Output slack values.
    public let outputSlacks: [Double]?

    /// Whether the super-efficiency LP was infeasible for this DMU.
    ///
    /// In BCC super-efficiency, extreme-vertex DMUs may have no feasible
    /// reference set when excluded from the frontier. When `true`,
    /// ``efficiency`` is set to `Double.infinity`.
    public let superEfficiencyInfeasible: Bool

    /// Creates a DMU score.
    public init(
        name: String,
        efficiency: Double,
        rawScore: Double,
        referenceSet: [ReferenceUnit],
        targetInputs: [Double]? = nil,
        targetOutputs: [Double]? = nil,
        inputSlacks: [Double]? = nil,
        outputSlacks: [Double]? = nil,
        superEfficiencyInfeasible: Bool = false
    ) {
        self.name = name
        self.efficiency = efficiency
        self.rawScore = rawScore
        self.referenceSet = referenceSet
        self.targetInputs = targetInputs
        self.targetOutputs = targetOutputs
        self.inputSlacks = inputSlacks
        self.outputSlacks = outputSlacks
        self.superEfficiencyInfeasible = superEfficiencyInfeasible
    }
}

/// A reference unit in the efficient frontier.
public struct ReferenceUnit: Sendable {
    /// Name of the efficient DMU.
    public let name: String
    /// Lambda weight.
    public let weight: Double

    /// Creates a reference unit.
    public init(name: String, weight: Double) {
        self.name = name
        self.weight = weight
    }
}
