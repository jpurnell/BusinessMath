//
//  DEASolver.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-07-01.
//

import Foundation

/// Solves Data Envelopment Analysis problems using the simplex method.
///
/// Evaluates the relative efficiency of decision-making units (DMUs) across
/// multiple input and output dimensions. Constructs and solves one linear
/// program per DMU using the existing ``SimplexSolver``.
///
/// ## Example
/// ```swift
/// let solver = DEASolver()
/// let dmus = [
///     DMU(name: "A", inputs: [2, 5], outputs: [1, 4]),
///     DMU(name: "B", inputs: [3, 3], outputs: [2, 2]),
///     DMU(name: "C", inputs: [5, 5], outputs: [1, 3])
/// ]
/// let result = try solver.solve(dmus: dmus)
/// ```
public struct DEASolver: Sendable {

    /// Creates a DEA solver.
    public init() {}

    /// Evaluate the relative efficiency of DMUs.
    ///
    /// Solves one LP per DMU to determine its efficiency score.
    ///
    /// - Parameters:
    ///   - dmus: Array of decision-making units to evaluate. Minimum 2.
    ///   - model: CCR (constant returns to scale) or BCC (variable returns to scale).
    ///   - orientation: Input-oriented or output-oriented.
    ///   - inputNames: Optional labels for input dimensions.
    ///   - outputNames: Optional labels for output dimensions.
    /// - Returns: DEA results including efficiency scores and improvement targets.
    /// - Throws: ``DEAError`` if inputs are invalid or LP fails.
    public func solve(
        dmus: [DMU],
        model: DEAModelType = .ccr,
        orientation: DEAOrientation = .inputOriented,
        inputNames: [String]? = nil,
        outputNames: [String]? = nil
    ) throws -> DEAResult {
        try validate(dmus: dmus)

        let simplex = SimplexSolver()
        var scores: [DMUScore] = []
        var totalIterations = 0

        for k in 0..<dmus.count {
            let lpResult = try solveLP(
                forDMU: k,
                dmus: dmus,
                model: model,
                orientation: orientation,
                solver: simplex
            )
            totalIterations += lpResult.iterations

            let score = try extractScore(
                forDMU: k,
                dmus: dmus,
                orientation: orientation,
                lpResult: lpResult
            )
            scores.append(score)
        }

        return DEAResult(
            scores: scores,
            model: model,
            orientation: orientation,
            totalIterations: totalIterations
        )
    }

    // MARK: - Input Validation

    private func validate(dmus: [DMU]) throws {
        guard dmus.count >= 2 else {
            throw DEAError.insufficientDMUs(count: dmus.count)
        }

        guard let firstDMU = dmus.first else {
            throw DEAError.insufficientDMUs(count: 0)
        }

        guard !firstDMU.inputs.isEmpty else {
            throw DEAError.emptyDimension(description: "No input dimensions specified")
        }
        guard !firstDMU.outputs.isEmpty else {
            throw DEAError.emptyDimension(description: "No output dimensions specified")
        }

        let expectedInputCount = firstDMU.inputs.count
        let expectedOutputCount = firstDMU.outputs.count

        for dmu in dmus {
            guard dmu.inputs.count == expectedInputCount else {
                throw DEAError.dimensionMismatch(
                    expected: expectedInputCount,
                    actual: dmu.inputs.count,
                    dmu: dmu.name
                )
            }
            guard dmu.outputs.count == expectedOutputCount else {
                throw DEAError.dimensionMismatch(
                    expected: expectedOutputCount,
                    actual: dmu.outputs.count,
                    dmu: dmu.name
                )
            }

            for (i, value) in dmu.inputs.enumerated() {
                guard value > 0 else {
                    throw DEAError.nonPositiveValues(
                        dmu: dmu.name,
                        dimension: "input[\(i)]"
                    )
                }
            }
            for (r, value) in dmu.outputs.enumerated() {
                guard value > 0 else {
                    throw DEAError.nonPositiveValues(
                        dmu: dmu.name,
                        dimension: "output[\(r)]"
                    )
                }
            }
        }
    }

    // MARK: - LP Construction and Solving

    /// Solve the LP for a single DMU.
    ///
    /// LP variables are ordered: [θ/η, λ₁, λ₂, ..., λₙ]
    private func solveLP(
        forDMU k: Int,
        dmus: [DMU],
        model: DEAModelType,
        orientation: DEAOrientation,
        solver: SimplexSolver
    ) throws -> SimplexResult {
        let n = dmus.count
        let m = dmus[0].inputs.count
        let s = dmus[0].outputs.count
        let numVars = n + 1

        var objective = [Double](repeating: 0, count: numVars)
        objective[0] = 1.0

        var constraints: [SimplexConstraint] = []

        switch orientation {
        case .inputOriented:
            constraints = buildInputOrientedConstraints(
                forDMU: k, dmus: dmus, n: n, m: m, s: s, numVars: numVars
            )
        case .outputOriented:
            constraints = buildOutputOrientedConstraints(
                forDMU: k, dmus: dmus, n: n, m: m, s: s, numVars: numVars
            )
        }

        if model == .bcc {
            var convexityCoeffs = [Double](repeating: 0, count: numVars)
            for j in 0..<n {
                convexityCoeffs[j + 1] = 1.0
            }
            constraints.append(SimplexConstraint(
                coefficients: convexityCoeffs,
                relation: .equal,
                rhs: 1.0
            ))
        }

        let result: SimplexResult
        switch orientation {
        case .inputOriented:
            result = try solver.minimize(objective: objective, subjectTo: constraints)
        case .outputOriented:
            result = try solver.maximize(objective: objective, subjectTo: constraints)
        }

        guard result.status == .optimal else {
            throw DEAError.solverFailed(dmu: dmus[k].name, status: result.status)
        }

        return result
    }

    /// Build constraints for input-oriented DEA.
    ///
    /// ```
    /// minimize θ
    /// s.t.  Σⱼ λⱼ·xᵢⱼ - θ·xᵢₖ ≤ 0   for each input i
    ///       Σⱼ λⱼ·yᵣⱼ           ≥ yᵣₖ  for each output r
    /// ```
    private func buildInputOrientedConstraints(
        forDMU k: Int,
        dmus: [DMU],
        n: Int, m: Int, s: Int, numVars: Int
    ) -> [SimplexConstraint] {
        var constraints: [SimplexConstraint] = []

        for i in 0..<m {
            var coeffs = [Double](repeating: 0, count: numVars)
            coeffs[0] = -dmus[k].inputs[i]
            for j in 0..<n {
                coeffs[j + 1] = dmus[j].inputs[i]
            }
            constraints.append(SimplexConstraint(
                coefficients: coeffs,
                relation: .lessOrEqual,
                rhs: 0
            ))
        }

        for r in 0..<s {
            var coeffs = [Double](repeating: 0, count: numVars)
            for j in 0..<n {
                coeffs[j + 1] = dmus[j].outputs[r]
            }
            constraints.append(SimplexConstraint(
                coefficients: coeffs,
                relation: .greaterOrEqual,
                rhs: dmus[k].outputs[r]
            ))
        }

        return constraints
    }

    /// Build constraints for output-oriented DEA.
    ///
    /// ```
    /// maximize η
    /// s.t.  Σⱼ λⱼ·xᵢⱼ           ≤ xᵢₖ  for each input i
    ///       Σⱼ λⱼ·yᵣⱼ - η·yᵣₖ   ≥ 0    for each output r
    /// ```
    private func buildOutputOrientedConstraints(
        forDMU k: Int,
        dmus: [DMU],
        n: Int, m: Int, s: Int, numVars: Int
    ) -> [SimplexConstraint] {
        var constraints: [SimplexConstraint] = []

        for i in 0..<m {
            var coeffs = [Double](repeating: 0, count: numVars)
            for j in 0..<n {
                coeffs[j + 1] = dmus[j].inputs[i]
            }
            constraints.append(SimplexConstraint(
                coefficients: coeffs,
                relation: .lessOrEqual,
                rhs: dmus[k].inputs[i]
            ))
        }

        for r in 0..<s {
            var coeffs = [Double](repeating: 0, count: numVars)
            coeffs[0] = -dmus[k].outputs[r]
            for j in 0..<n {
                coeffs[j + 1] = dmus[j].outputs[r]
            }
            constraints.append(SimplexConstraint(
                coefficients: coeffs,
                relation: .greaterOrEqual,
                rhs: 0
            ))
        }

        return constraints
    }

    // MARK: - Result Extraction

    private func extractScore(
        forDMU k: Int,
        dmus: [DMU],
        orientation: DEAOrientation,
        lpResult: SimplexResult
    ) throws -> DMUScore {
        let n = dmus.count
        let m = dmus[0].inputs.count
        let s = dmus[0].outputs.count

        guard lpResult.solution.count >= n + 1 else {
            throw DEAError.solverFailed(dmu: dmus[k].name, status: .unknown)
        }

        let rawScore = lpResult.solution[0]

        let lambdas = Array(lpResult.solution[1...n])

        let efficiency: Double
        switch orientation {
        case .inputOriented:
            efficiency = rawScore
        case .outputOriented:
            guard abs(rawScore) > Double.ulpOfOne else {
                throw DEAError.solverFailed(dmu: dmus[k].name, status: .unknown)
            }
            efficiency = 1.0 / rawScore
        }

        let lambdaTolerance = 1e-6
        var referenceSet: [ReferenceUnit] = []
        for j in 0..<n {
            if lambdas[j] > lambdaTolerance {
                referenceSet.append(ReferenceUnit(
                    name: dmus[j].name,
                    weight: lambdas[j]
                ))
            }
        }

        var targetInputs: [Double]?
        var targetOutputs: [Double]?
        var inputSlacks: [Double]?
        var outputSlacks: [Double]?

        switch orientation {
        case .inputOriented:
            var targets = [Double](repeating: 0, count: m)
            var slacks = [Double](repeating: 0, count: m)
            for i in 0..<m {
                var projected = 0.0
                for j in 0..<n {
                    projected += lambdas[j] * dmus[j].inputs[i]
                }
                targets[i] = projected
                let radialTarget = rawScore * dmus[k].inputs[i]
                slacks[i] = radialTarget - projected
            }
            targetInputs = targets
            inputSlacks = slacks

            var oTargets = [Double](repeating: 0, count: s)
            var oSlacks = [Double](repeating: 0, count: s)
            for r in 0..<s {
                var projected = 0.0
                for j in 0..<n {
                    projected += lambdas[j] * dmus[j].outputs[r]
                }
                oTargets[r] = projected
                oSlacks[r] = projected - dmus[k].outputs[r]
            }
            targetOutputs = oTargets
            outputSlacks = oSlacks

        case .outputOriented:
            var targets = [Double](repeating: 0, count: m)
            var slacks = [Double](repeating: 0, count: m)
            for i in 0..<m {
                var projected = 0.0
                for j in 0..<n {
                    projected += lambdas[j] * dmus[j].inputs[i]
                }
                targets[i] = projected
                slacks[i] = dmus[k].inputs[i] - projected
            }
            targetInputs = targets
            inputSlacks = slacks

            var oTargets = [Double](repeating: 0, count: s)
            var oSlacks = [Double](repeating: 0, count: s)
            for r in 0..<s {
                var projected = 0.0
                for j in 0..<n {
                    projected += lambdas[j] * dmus[j].outputs[r]
                }
                oTargets[r] = projected
                let radialTarget = rawScore * dmus[k].outputs[r]
                oSlacks[r] = projected - radialTarget
            }
            targetOutputs = oTargets
            outputSlacks = oSlacks
        }

        return DMUScore(
            name: dmus[k].name,
            efficiency: efficiency,
            rawScore: rawScore,
            referenceSet: referenceSet,
            targetInputs: targetInputs,
            targetOutputs: targetOutputs,
            inputSlacks: inputSlacks,
            outputSlacks: outputSlacks
        )
    }
}
