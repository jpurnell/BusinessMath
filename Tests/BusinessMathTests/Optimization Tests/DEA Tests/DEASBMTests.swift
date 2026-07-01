//
//  DEASBMTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-07-01.
//

import Testing
@testable import BusinessMath

// MARK: - Cooper et al. Reference Data

/// Reference data from Cooper, Seiford & Tone (2007) Table 1.3.
/// 6 DMUs, 2 inputs, 2 outputs.
private let cooperDMUs: [DMU] = [
    DMU(name: "A", inputs: [2, 5], outputs: [1, 4]),
    DMU(name: "B", inputs: [3, 3], outputs: [2, 2]),
    DMU(name: "C", inputs: [6, 2], outputs: [3, 1]),
    DMU(name: "D", inputs: [5, 5], outputs: [1, 3]),
    DMU(name: "E", inputs: [2, 4], outputs: [2, 1]),
    DMU(name: "F", inputs: [4, 6], outputs: [1, 5])
]

// MARK: - SBM CRS Tests

@Suite("DEA SBM Constant Returns to Scale")
struct DEASBMCRSTests {

    let solver = DEASolver()
    let tolerance = 0.01

    @Test("SBM efficiency scores are in (0, 1]")
    func scoresInValidRange() throws {
        let result = try solver.solve(
            dmus: cooperDMUs,
            model: .sbm(returnsToScale: .constant),
            orientation: .inputOriented
        )

        #expect(result.scores.count == cooperDMUs.count)
        for score in result.scores {
            #expect(
                score.efficiency > 0 && score.efficiency <= 1.0 + tolerance,
                "DMU \(score.name): efficiency \(score.efficiency) outside (0, 1]"
            )
        }
    }

    @Test("SBM-efficient DMUs have all slacks zero")
    func efficientDMUsHaveZeroSlacks() throws {
        let result = try solver.solve(
            dmus: cooperDMUs,
            model: .sbm(returnsToScale: .constant),
            orientation: .inputOriented
        )

        for score in result.scores where score.isEfficient {
            guard let inSlacks = score.inputSlacks,
                  let outSlacks = score.outputSlacks else {
                Issue.record("DMU \(score.name): slacks not populated")
                continue
            }
            let allSlacksZero = inSlacks.allSatisfy { $0 < tolerance }
                && outSlacks.allSatisfy { $0 < tolerance }
            #expect(
                allSlacksZero,
                "Efficient DMU \(score.name) should have all slacks near zero"
            )
        }
    }

    @Test("SBM-efficient set matches CCR-efficient set for CRS")
    func sbmEfficientMatchesCCR() throws {
        let sbmResult = try solver.solve(
            dmus: cooperDMUs,
            model: .sbm(returnsToScale: .constant),
            orientation: .inputOriented
        )
        let ccrResult = try solver.solve(
            dmus: cooperDMUs,
            model: .ccr,
            orientation: .inputOriented
        )

        let sbmEfficient = Set(sbmResult.efficientDMUs)
        let ccrEfficient = Set(ccrResult.efficientDMUs)

        #expect(
            sbmEfficient == ccrEfficient,
            "SBM-CRS efficient set \(sbmEfficient) should match CCR \(ccrEfficient)"
        )
    }

    @Test("All input and output slacks are non-negative")
    func slacksNonNegative() throws {
        let result = try solver.solve(
            dmus: cooperDMUs,
            model: .sbm(returnsToScale: .constant),
            orientation: .inputOriented
        )

        for score in result.scores {
            guard let inSlacks = score.inputSlacks,
                  let outSlacks = score.outputSlacks else {
                Issue.record("DMU \(score.name): slacks not populated")
                continue
            }
            for (i, slack) in inSlacks.enumerated() {
                #expect(
                    slack >= -tolerance,
                    "DMU \(score.name) input slack[\(i)] = \(slack) should be >= 0"
                )
            }
            for (r, slack) in outSlacks.enumerated() {
                #expect(
                    slack >= -tolerance,
                    "DMU \(score.name) output slack[\(r)] = \(slack) should be >= 0"
                )
            }
        }
    }

    @Test("Inefficient DMUs have at least one positive slack")
    func inefficientDMUsHavePositiveSlack() throws {
        let result = try solver.solve(
            dmus: cooperDMUs,
            model: .sbm(returnsToScale: .constant),
            orientation: .inputOriented
        )

        for score in result.scores where !score.isEfficient {
            guard let inSlacks = score.inputSlacks,
                  let outSlacks = score.outputSlacks else {
                Issue.record("DMU \(score.name): slacks not populated")
                continue
            }
            let hasPositiveSlack = inSlacks.contains { $0 > tolerance }
                || outSlacks.contains { $0 > tolerance }
            #expect(
                hasPositiveSlack,
                "Inefficient DMU \(score.name) should have at least one positive slack"
            )
        }
    }

    @Test("SBM efficiency <= CCR efficiency for all DMUs")
    func sbmMoreDiscriminating() throws {
        let sbmResult = try solver.solve(
            dmus: cooperDMUs,
            model: .sbm(returnsToScale: .constant),
            orientation: .inputOriented
        )
        let ccrResult = try solver.solve(
            dmus: cooperDMUs,
            model: .ccr,
            orientation: .inputOriented
        )

        for sbmScore in sbmResult.scores {
            guard let ccrScore = ccrResult.scores.first(where: {
                $0.name == sbmScore.name
            }) else {
                Issue.record("DMU \(sbmScore.name) not found in CCR results")
                continue
            }
            #expect(
                sbmScore.efficiency <= ccrScore.efficiency + tolerance,
                "DMU \(sbmScore.name): SBM \(sbmScore.efficiency) should be <= CCR \(ccrScore.efficiency)"
            )
        }
    }

    @Test("Result has inputSlacks and outputSlacks populated for all DMUs")
    func slacksPopulated() throws {
        let result = try solver.solve(
            dmus: cooperDMUs,
            model: .sbm(returnsToScale: .constant),
            orientation: .inputOriented
        )

        let expectedInputCount = cooperDMUs[0].inputs.count
        let expectedOutputCount = cooperDMUs[0].outputs.count
        for score in result.scores {
            let inSlacks = try #require(
                score.inputSlacks,
                "DMU \(score.name): inputSlacks should be populated"
            )
            let outSlacks = try #require(
                score.outputSlacks,
                "DMU \(score.name): outputSlacks should be populated"
            )
            #expect(
                inSlacks.count == expectedInputCount,
                "DMU \(score.name): inputSlacks count mismatch"
            )
            #expect(
                outSlacks.count == expectedOutputCount,
                "DMU \(score.name): outputSlacks count mismatch"
            )
        }
    }
}

// MARK: - SBM VRS Tests

@Suite("DEA SBM Variable Returns to Scale")
struct DEASBMVRSTests {

    let solver = DEASolver()
    let tolerance = 0.01

    @Test("VRS SBM scores >= CRS SBM scores")
    func vrsScoresGreaterOrEqual() throws {
        let crsResult = try solver.solve(
            dmus: cooperDMUs,
            model: .sbm(returnsToScale: .constant),
            orientation: .inputOriented
        )
        let vrsResult = try solver.solve(
            dmus: cooperDMUs,
            model: .sbm(returnsToScale: .variable),
            orientation: .inputOriented
        )

        for vrsScore in vrsResult.scores {
            guard let crsScore = crsResult.scores.first(where: {
                $0.name == vrsScore.name
            }) else {
                Issue.record("DMU \(vrsScore.name) not found in CRS results")
                continue
            }
            #expect(
                vrsScore.efficiency >= crsScore.efficiency - tolerance,
                "DMU \(vrsScore.name): VRS \(vrsScore.efficiency) should be >= CRS \(crsScore.efficiency)"
            )
        }
    }

    @Test("VRS SBM efficient set is superset of CRS SBM efficient set")
    func vrsEfficientIsSupersetOfCRS() throws {
        let crsResult = try solver.solve(
            dmus: cooperDMUs,
            model: .sbm(returnsToScale: .constant),
            orientation: .inputOriented
        )
        let vrsResult = try solver.solve(
            dmus: cooperDMUs,
            model: .sbm(returnsToScale: .variable),
            orientation: .inputOriented
        )

        let crsEfficient = Set(crsResult.efficientDMUs)
        let vrsEfficient = Set(vrsResult.efficientDMUs)

        #expect(
            crsEfficient.isSubset(of: vrsEfficient),
            "CRS efficient \(crsEfficient) should be subset of VRS efficient \(vrsEfficient)"
        )
    }

    @Test("VRS SBM scores are in (0, 1]")
    func vrsScoresInValidRange() throws {
        let result = try solver.solve(
            dmus: cooperDMUs,
            model: .sbm(returnsToScale: .variable),
            orientation: .inputOriented
        )

        #expect(result.scores.count == cooperDMUs.count)
        for score in result.scores {
            #expect(
                score.efficiency > 0 && score.efficiency <= 1.0 + tolerance,
                "DMU \(score.name): VRS efficiency \(score.efficiency) outside (0, 1]"
            )
        }
    }

    @Test("VRS SBM slacks are non-negative")
    func vrsSlacksNonNegative() throws {
        let result = try solver.solve(
            dmus: cooperDMUs,
            model: .sbm(returnsToScale: .variable),
            orientation: .inputOriented
        )

        for score in result.scores {
            guard let inSlacks = score.inputSlacks,
                  let outSlacks = score.outputSlacks else {
                Issue.record("DMU \(score.name): slacks not populated")
                continue
            }
            for slack in inSlacks {
                #expect(slack >= -tolerance, "Negative input slack")
            }
            for slack in outSlacks {
                #expect(slack >= -tolerance, "Negative output slack")
            }
        }
    }
}

// MARK: - SBM Cross-Validation

@Suite("DEA SBM Cross-Validation")
struct DEASBMCrossValidationTests {

    let solver = DEASolver()
    let tolerance = 0.01

    @Test("1-input/1-output: SBM-efficient matches CCR-efficient")
    func singleDimensionCrossCheck() throws {
        let simpleDMUs = [
            DMU(name: "P", inputs: [2], outputs: [4]),
            DMU(name: "Q", inputs: [3], outputs: [5]),
            DMU(name: "R", inputs: [4], outputs: [3]),
            DMU(name: "S", inputs: [1], outputs: [2])
        ]

        let sbmResult = try solver.solve(
            dmus: simpleDMUs,
            model: .sbm(returnsToScale: .constant),
            orientation: .inputOriented
        )
        let ccrResult = try solver.solve(
            dmus: simpleDMUs,
            model: .ccr,
            orientation: .inputOriented
        )

        let sbmEfficient = Set(sbmResult.efficientDMUs)
        let ccrEfficient = Set(ccrResult.efficientDMUs)

        #expect(
            sbmEfficient == ccrEfficient,
            "Single-dimension SBM efficient \(sbmEfficient) should match CCR \(ccrEfficient)"
        )
    }
}
