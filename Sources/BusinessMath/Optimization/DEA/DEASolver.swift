//
//  DEASolver.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-07-01.
//

import Foundation
import os

private let logger = Logger(subsystem: "com.businessmath", category: "DEASolver")

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

        switch model {
        case .superEfficiency(let base):
            return try solveSuperEfficiency(
                dmus: dmus,
                base: base,
                orientation: orientation
            )
        case .sbm(let rts):
            return try solveSBM(
                dmus: dmus,
                returnsToScale: rts,
                orientation: orientation
            )
        case .ccr, .bcc:
            return try solveStandard(
                dmus: dmus,
                model: model,
                orientation: orientation
            )
        }
    }

    /// Standard DEA solve loop for CCR and BCC models.
    private func solveStandard(
        dmus: [DMU],
        model: DEAModelType,
        orientation: DEAOrientation
    ) throws -> DEAResult {
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

    // MARK: - Single-DMU Solve (Internal)

    /// Solve the LP for a single DMU within a validated set.
    ///
    /// Callers must validate `dmus` before invoking. This method constructs and
    /// solves one LP, then extracts the score. Used by ``AsyncDEASolver`` to
    /// dispatch independent solves concurrently.
    ///
    /// - Parameters:
    ///   - index: Index of the DMU to evaluate.
    ///   - dmus: All DMUs (already validated).
    ///   - model: DEA model type.
    ///   - orientation: Input or output oriented.
    /// - Returns: Tuple of the DMU score and simplex iteration count.
    /// - Throws: ``DEAError`` if the LP fails.
    internal func solveSingleDMU(
        index k: Int,
        dmus: [DMU],
        model: DEAModelType,
        orientation: DEAOrientation
    ) throws -> (score: DMUScore, iterations: Int) {
        if case .sbm(let rts) = model {
            let simplex = SimplexSolver()
            let lpResult = try solveSBMLP(
                forDMU: k,
                dmus: dmus,
                returnsToScale: rts,
                solver: simplex
            )
            let score = try extractSBMScore(
                forDMU: k,
                dmus: dmus,
                lpResult: lpResult
            )
            return (score, lpResult.iterations)
        }

        let simplex = SimplexSolver()
        let lpResult = try solveLP(
            forDMU: k,
            dmus: dmus,
            model: model,
            orientation: orientation,
            solver: simplex
        )
        let score = try extractScore(
            forDMU: k,
            dmus: dmus,
            orientation: orientation,
            lpResult: lpResult
        )
        return (score, lpResult.iterations)
    }

    // MARK: - Input Validation

    /// Validate DMU inputs for consistency and correctness.
    ///
    /// Checks minimum count, dimension consistency, and positivity.
    /// Exposed as `internal` so ``AsyncDEASolver`` can validate once
    /// before dispatching concurrent solves.
    internal func validate(dmus: [DMU]) throws {
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

    // MARK: - SBM (Slacks-Based Measure, Tone 2001)

    /// Solve using the Slacks-Based Measure (SBM) model.
    ///
    /// SBM is non-oriented: it simultaneously optimizes input reductions
    /// and output expansions. Uses the Charnes-Cooper transformation to
    /// convert the fractional program into a standard LP.
    ///
    /// - Parameters:
    ///   - dmus: All DMUs (already validated).
    ///   - returnsToScale: Constant (CRS) or variable (VRS) returns to scale.
    ///   - orientation: Ignored for SBM (non-oriented by definition).
    /// - Returns: DEA results with SBM efficiency scores and slack decomposition.
    private func solveSBM(
        dmus: [DMU],
        returnsToScale: DEAReturnsToScale,
        orientation: DEAOrientation
    ) throws -> DEAResult {
        let simplex = SimplexSolver()
        var scores: [DMUScore] = []
        var totalIterations = 0

        for k in 0..<dmus.count {
            let lpResult = try solveSBMLP(
                forDMU: k,
                dmus: dmus,
                returnsToScale: returnsToScale,
                solver: simplex
            )
            totalIterations += lpResult.iterations

            let score = try extractSBMScore(
                forDMU: k,
                dmus: dmus,
                lpResult: lpResult
            )
            scores.append(score)
        }

        return DEAResult(
            scores: scores,
            model: .sbm(returnsToScale: returnsToScale),
            orientation: orientation,
            totalIterations: totalIterations
        )
    }

    /// Build and solve the Charnes-Cooper linearized SBM LP for DMU k.
    ///
    /// LP variables: `[t, Λ₁, ..., Λₙ, S₁⁻, ..., Sₘ⁻, S₁⁺, ..., Sₛ⁺]`
    ///
    /// After Charnes-Cooper transformation (t = 1 / denominator):
    /// ```
    /// minimize  t - (1/m) Σᵢ Sᵢ⁻/xᵢₖ
    /// s.t.      t + (1/s) Σᵣ Sᵣ⁺/yᵣₖ = 1
    ///           Σⱼ Λⱼ·xᵢⱼ + Sᵢ⁻ - t·xᵢₖ = 0   ∀i
    ///           Σⱼ Λⱼ·yᵣⱼ - Sᵣ⁺ - t·yᵣₖ = 0   ∀r
    ///           Σⱼ Λⱼ = t  (VRS only)
    /// ```
    private func solveSBMLP(
        forDMU k: Int,
        dmus: [DMU],
        returnsToScale: DEAReturnsToScale,
        solver: SimplexSolver
    ) throws -> SimplexResult {
        let n = dmus.count
        let m = dmus[0].inputs.count
        let s = dmus[0].outputs.count
        guard m > 0 else {
            throw DEAError.emptyDimension(description: "inputs")
        }
        guard s > 0 else {
            throw DEAError.emptyDimension(description: "outputs")
        }
        let numVars = 1 + n + m + s

        // Objective: minimize t - (1/m) Σᵢ Sᵢ⁻/xᵢₖ
        var objective = [Double](repeating: 0, count: numVars)
        objective[0] = 1.0
        let invM = 1.0 / Double(m)
        for i in 0..<m {
            let coeff = invM / dmus[k].inputs[i]
            objective[n + 1 + i] = -coeff
        }

        var constraints: [SimplexConstraint] = []

        // Normalization: t + (1/s) Σᵣ Sᵣ⁺/yᵣₖ = 1
        var normCoeffs = [Double](repeating: 0, count: numVars)
        normCoeffs[0] = 1.0
        let invS = 1.0 / Double(s)
        for r in 0..<s {
            let coeff = invS / dmus[k].outputs[r]
            normCoeffs[n + 1 + m + r] = coeff
        }
        constraints.append(SimplexConstraint(
            coefficients: normCoeffs,
            relation: .equal,
            rhs: 1.0
        ))

        // Input constraints: Σⱼ Λⱼ·xᵢⱼ + Sᵢ⁻ - t·xᵢₖ = 0
        for i in 0..<m {
            var coeffs = [Double](repeating: 0, count: numVars)
            coeffs[0] = -dmus[k].inputs[i]
            for j in 0..<n {
                coeffs[j + 1] = dmus[j].inputs[i]
            }
            coeffs[n + 1 + i] = 1.0
            constraints.append(SimplexConstraint(
                coefficients: coeffs,
                relation: .equal,
                rhs: 0
            ))
        }

        // Output constraints: Σⱼ Λⱼ·yᵣⱼ - Sᵣ⁺ - t·yᵣₖ = 0
        for r in 0..<s {
            var coeffs = [Double](repeating: 0, count: numVars)
            coeffs[0] = -dmus[k].outputs[r]
            for j in 0..<n {
                coeffs[j + 1] = dmus[j].outputs[r]
            }
            coeffs[n + 1 + m + r] = -1.0
            constraints.append(SimplexConstraint(
                coefficients: coeffs,
                relation: .equal,
                rhs: 0
            ))
        }

        // VRS convexity constraint: Σⱼ Λⱼ - t = 0
        if returnsToScale == .variable {
            var convCoeffs = [Double](repeating: 0, count: numVars)
            convCoeffs[0] = -1.0
            for j in 0..<n {
                convCoeffs[j + 1] = 1.0
            }
            constraints.append(SimplexConstraint(
                coefficients: convCoeffs,
                relation: .equal,
                rhs: 0
            ))
        }

        let result = try solver.minimize(
            objective: objective,
            subjectTo: constraints
        )

        guard result.status == .optimal else {
            throw DEAError.solverFailed(dmu: dmus[k].name, status: result.status)
        }

        return result
    }

    /// Extract SBM efficiency score and slacks from the Charnes-Cooper LP result.
    ///
    /// Recovers original-space slacks by dividing transformed variables by t.
    private func extractSBMScore(
        forDMU k: Int,
        dmus: [DMU],
        lpResult: SimplexResult
    ) throws -> DMUScore {
        let n = dmus.count
        let m = dmus[0].inputs.count
        let s = dmus[0].outputs.count
        let expectedVars = 1 + n + m + s

        guard lpResult.solution.count >= expectedVars else {
            throw DEAError.solverFailed(dmu: dmus[k].name, status: .unknown)
        }

        let t = lpResult.solution[0]

        // Division safety: t must be strictly positive
        guard t > Double.ulpOfOne else {
            throw DEAError.solverFailed(dmu: dmus[k].name, status: .unknown)
        }

        let efficiency = lpResult.objectiveValue

        // Recover original-space lambdas: λⱼ = Λⱼ / t
        var lambdas = [Double](repeating: 0, count: n)
        for j in 0..<n {
            lambdas[j] = lpResult.solution[j + 1] / t
        }

        // Recover original-space input slacks: sᵢ⁻ = Sᵢ⁻ / t
        var inputSlacks = [Double](repeating: 0, count: m)
        for i in 0..<m {
            let rawSlack = lpResult.solution[n + 1 + i]
            inputSlacks[i] = max(rawSlack / t, 0)
        }

        // Recover original-space output slacks: sᵣ⁺ = Sᵣ⁺ / t
        var outputSlacks = [Double](repeating: 0, count: s)
        for r in 0..<s {
            let rawSlack = lpResult.solution[n + 1 + m + r]
            outputSlacks[r] = max(rawSlack / t, 0)
        }

        // Build reference set from significant lambdas
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

        // Compute target values from the reference set projection
        var targetInputs = [Double](repeating: 0, count: m)
        for i in 0..<m {
            targetInputs[i] = dmus[k].inputs[i] - inputSlacks[i]
        }

        var targetOutputs = [Double](repeating: 0, count: s)
        for r in 0..<s {
            targetOutputs[r] = dmus[k].outputs[r] + outputSlacks[r]
        }

        return DMUScore(
            name: dmus[k].name,
            efficiency: efficiency,
            rawScore: efficiency,
            referenceSet: referenceSet,
            targetInputs: targetInputs,
            targetOutputs: targetOutputs,
            inputSlacks: inputSlacks,
            outputSlacks: outputSlacks
        )
    }

    // MARK: - Super-Efficiency (Andersen-Petersen)

    /// Solve using the Andersen-Petersen super-efficiency model.
    ///
    /// For each DMU k, the LP excludes k from the reference set (n-1 lambda
    /// variables). Efficient DMUs can score above 1.0; inefficient DMUs
    /// retain their standard scores.
    ///
    /// BCC super-efficiency may be infeasible for extreme-vertex DMUs.
    /// In that case the score is set to `Double.infinity` and
    /// ``DMUScore/superEfficiencyInfeasible`` is `true`.
    private func solveSuperEfficiency(
        dmus: [DMU],
        base: DEABaseModel,
        orientation: DEAOrientation
    ) throws -> DEAResult {
        let simplex = SimplexSolver()
        var scores: [DMUScore] = []
        var totalIterations = 0
        let model: DEAModelType = .superEfficiency(base: base)

        for k in 0..<dmus.count {
            let result = solveSuperLP(
                forDMU: k,
                dmus: dmus,
                base: base,
                orientation: orientation,
                solver: simplex
            )

            switch result {
            case .success(let lpResult):
                totalIterations += lpResult.iterations
                let score = try extractSuperScore(
                    forDMU: k,
                    dmus: dmus,
                    orientation: orientation,
                    lpResult: lpResult
                )
                scores.append(score)

            case .failure:
                scores.append(DMUScore(
                    name: dmus[k].name,
                    efficiency: .infinity,
                    rawScore: .infinity,
                    referenceSet: [],
                    superEfficiencyInfeasible: true
                ))
            }
        }

        return DEAResult(
            scores: scores,
            model: model,
            orientation: orientation,
            totalIterations: totalIterations
        )
    }

    /// Build and solve the super-efficiency LP for DMU k.
    ///
    /// Returns `.failure` if the LP is infeasible (possible with BCC).
    private func solveSuperLP(
        forDMU k: Int,
        dmus: [DMU],
        base: DEABaseModel,
        orientation: DEAOrientation,
        solver: SimplexSolver
    ) -> Result<SimplexResult, DEAError> {
        let n = dmus.count
        let m = dmus[0].inputs.count
        let s = dmus[0].outputs.count
        let numVars = n

        var objective = [Double](repeating: 0, count: numVars)
        objective[0] = 1.0

        var refIndices: [Int] = []
        for j in 0..<n where j != k {
            refIndices.append(j)
        }

        var constraints: [SimplexConstraint] = []

        switch orientation {
        case .inputOriented:
            constraints = buildSuperInputConstraints(
                forDMU: k, dmus: dmus,
                refIndices: refIndices,
                m: m, s: s, numVars: numVars
            )
        case .outputOriented:
            constraints = buildSuperOutputConstraints(
                forDMU: k, dmus: dmus,
                refIndices: refIndices,
                m: m, s: s, numVars: numVars
            )
        }

        if base == .bcc {
            var convexityCoeffs = [Double](repeating: 0, count: numVars)
            for p in 0..<refIndices.count {
                convexityCoeffs[p + 1] = 1.0
            }
            constraints.append(SimplexConstraint(
                coefficients: convexityCoeffs,
                relation: .equal,
                rhs: 1.0
            ))
        }

        let result: SimplexResult
        do {
            switch orientation {
            case .inputOriented:
                result = try solver.minimize(
                    objective: objective, subjectTo: constraints
                )
            case .outputOriented:
                result = try solver.maximize(
                    objective: objective, subjectTo: constraints
                )
            }
        } catch {
            logger.debug("Super-efficiency LP infeasible for DMU \(dmus[k].name, privacy: .public)")
            return .failure(
                DEAError.solverFailed(dmu: dmus[k].name, status: .infeasible)
            )
        }

        guard result.status == .optimal else {
            return .failure(
                DEAError.solverFailed(dmu: dmus[k].name, status: result.status)
            )
        }

        return .success(result)
    }

    /// Build input-oriented constraints for the super-efficiency LP.
    private func buildSuperInputConstraints(
        forDMU k: Int,
        dmus: [DMU],
        refIndices: [Int],
        m: Int, s: Int, numVars: Int
    ) -> [SimplexConstraint] {
        var constraints: [SimplexConstraint] = []

        for i in 0..<m {
            var coeffs = [Double](repeating: 0, count: numVars)
            coeffs[0] = -dmus[k].inputs[i]
            for (p, j) in refIndices.enumerated() {
                coeffs[p + 1] = dmus[j].inputs[i]
            }
            constraints.append(SimplexConstraint(
                coefficients: coeffs,
                relation: .lessOrEqual,
                rhs: 0
            ))
        }

        for r in 0..<s {
            var coeffs = [Double](repeating: 0, count: numVars)
            for (p, j) in refIndices.enumerated() {
                coeffs[p + 1] = dmus[j].outputs[r]
            }
            constraints.append(SimplexConstraint(
                coefficients: coeffs,
                relation: .greaterOrEqual,
                rhs: dmus[k].outputs[r]
            ))
        }

        return constraints
    }

    /// Build output-oriented constraints for the super-efficiency LP.
    private func buildSuperOutputConstraints(
        forDMU k: Int,
        dmus: [DMU],
        refIndices: [Int],
        m: Int, s: Int, numVars: Int
    ) -> [SimplexConstraint] {
        var constraints: [SimplexConstraint] = []

        for i in 0..<m {
            var coeffs = [Double](repeating: 0, count: numVars)
            for (p, j) in refIndices.enumerated() {
                coeffs[p + 1] = dmus[j].inputs[i]
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
            for (p, j) in refIndices.enumerated() {
                coeffs[p + 1] = dmus[j].outputs[r]
            }
            constraints.append(SimplexConstraint(
                coefficients: coeffs,
                relation: .greaterOrEqual,
                rhs: 0
            ))
        }

        return constraints
    }

    /// Extract a DMUScore from a super-efficiency LP result.
    private func extractSuperScore(
        forDMU k: Int,
        dmus: [DMU],
        orientation: DEAOrientation,
        lpResult: SimplexResult
    ) throws -> DMUScore {
        let n = dmus.count
        let refCount = n - 1

        guard lpResult.solution.count >= refCount + 1 else {
            throw DEAError.solverFailed(dmu: dmus[k].name, status: .unknown)
        }

        let rawScore = lpResult.solution[0]
        let lambdas = Array(lpResult.solution[1...refCount])

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

        var refIndices: [Int] = []
        for j in 0..<n where j != k {
            refIndices.append(j)
        }

        let lambdaTolerance = 1e-6
        var referenceSet: [ReferenceUnit] = []
        for (p, j) in refIndices.enumerated() {
            if lambdas[p] > lambdaTolerance {
                referenceSet.append(ReferenceUnit(
                    name: dmus[j].name,
                    weight: lambdas[p]
                ))
            }
        }

        return DMUScore(
            name: dmus[k].name,
            efficiency: efficiency,
            rawScore: rawScore,
            referenceSet: referenceSet,
            superEfficiencyInfeasible: false
        )
    }
}

// MARK: - Matrix-Form Convenience API

extension DEASolver {

    /// Evaluate efficiency from raw input/output matrices.
    ///
    /// Convenience method that constructs ``DMU`` objects from row-major matrices.
    /// Row `i` of `inputs` and `outputs` corresponds to DMU `i`.
    ///
    /// - Parameters:
    ///   - inputs: Matrix of input values, shape [n x m]. Each row is one DMU.
    ///   - outputs: Matrix of output values, shape [n x s]. Each row is one DMU.
    ///   - names: Optional DMU names. If nil, defaults to "DMU_1", "DMU_2", etc.
    ///   - model: DEA model type. Default: `.ccr`.
    ///   - orientation: Input or output oriented. Default: `.inputOriented`.
    ///   - inputNames: Optional labels for input dimensions.
    ///   - outputNames: Optional labels for output dimensions.
    /// - Returns: DEA results.
    /// - Throws: ``DEAError`` if dimensions are inconsistent or values non-positive.
    public func solve(
        inputs: [[Double]],
        outputs: [[Double]],
        names: [String]? = nil,
        model: DEAModelType = .ccr,
        orientation: DEAOrientation = .inputOriented,
        inputNames: [String]? = nil,
        outputNames: [String]? = nil
    ) throws -> DEAResult {
        guard inputs.count == outputs.count else {
            throw DEAError.dimensionMismatch(
                expected: inputs.count,
                actual: outputs.count,
                dmu: "matrix rows"
            )
        }

        if let names = names {
            guard names.count == inputs.count else {
                throw DEAError.dimensionMismatch(
                    expected: inputs.count,
                    actual: names.count,
                    dmu: "names array"
                )
            }
        }

        let dmuNames = names ?? (1...inputs.count).map { "DMU_\($0)" }

        let dmus = try zip(dmuNames, zip(inputs, outputs)).map { name, data in
            let (inp, out) = data
            guard let expectedInputCount = inputs.first?.count,
                  inp.count == expectedInputCount else {
                throw DEAError.dimensionMismatch(
                    expected: inputs.first?.count ?? 0,
                    actual: inp.count,
                    dmu: name
                )
            }
            return DMU(name: name, inputs: inp, outputs: out)
        }

        return try solve(
            dmus: dmus,
            model: model,
            orientation: orientation,
            inputNames: inputNames,
            outputNames: outputNames
        )
    }
}
