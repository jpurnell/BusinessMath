//
//  DEASolverTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-07-01.
//

import Testing
@testable import BusinessMath

// MARK: - Cooper et al. Textbook Reference Data

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

/// Expected CCR input-oriented efficiency scores.
/// A, B, C, E, F are efficient; D is the only inefficient DMU.
/// F is efficient because its output 2 = 5 (highest) cannot be replicated
/// by other DMUs without exceeding input budgets.
/// D's score verified: θ = 26/35 via LP with reference to F and C.
private let cooperExpectedCCR: [String: Double] = [
    "A": 1.000,
    "B": 1.000,
    "C": 1.000,
    "D": 26.0 / 35.0,
    "E": 1.000,
    "F": 1.000
]

// MARK: - CCR Input-Oriented Golden Path

@Suite("DEA CCR Input-Oriented")
struct DEACCRInputOrientedTests {

    let solver = DEASolver()

    @Test("Cooper et al. Table 1.3 — CCR input-oriented efficiency scores")
    func cooperCCRInputOriented() throws {
        let result = try solver.solve(
            dmus: cooperDMUs,
            model: .ccr,
            orientation: .inputOriented
        )

        #expect(result.scores.count == 6)

        for score in result.scores {
            guard let expected = cooperExpectedCCR[score.name] else {
                Issue.record("Unexpected DMU name: \(score.name)")
                continue
            }
            #expect(
                abs(score.efficiency - expected) < 0.01,
                "DMU \(score.name): expected \(expected), got \(score.efficiency)"
            )
        }
    }

    @Test("Cooper et al. — efficient DMUs identified correctly")
    func cooperEfficientDMUs() throws {
        let result = try solver.solve(
            dmus: cooperDMUs,
            model: .ccr,
            orientation: .inputOriented
        )

        let efficient = Set(result.efficientDMUs)
        #expect(efficient == Set(["A", "B", "C", "E", "F"]))
    }

    @Test("Cooper et al. — inefficient DMUs identified correctly")
    func cooperInefficientDMUs() throws {
        let result = try solver.solve(
            dmus: cooperDMUs,
            model: .ccr,
            orientation: .inputOriented
        )

        let inefficient = Set(result.inefficientDMUs)
        #expect(inefficient == Set(["D"]))
    }

    @Test("Cooper et al. — inefficient DMU D has non-empty reference set")
    func cooperDMUDReferenceSet() throws {
        let result = try solver.solve(
            dmus: cooperDMUs,
            model: .ccr,
            orientation: .inputOriented
        )

        guard let dmuD = result.scores.first(where: { $0.name == "D" }) else {
            Issue.record("DMU D not found in results")
            return
        }

        #expect(!dmuD.referenceSet.isEmpty)
        for ref in dmuD.referenceSet {
            #expect(ref.weight > 0)
            let expectedScore = cooperExpectedCCR[ref.name] ?? 0.0
            #expect(abs(expectedScore - 1.0) < 1e-6,
                    "Reference DMU \(ref.name) should be efficient")
        }
    }

    @Test("Cooper et al. — target inputs are less than or equal to actual inputs")
    func cooperTargetInputs() throws {
        let result = try solver.solve(
            dmus: cooperDMUs,
            model: .ccr,
            orientation: .inputOriented
        )

        for score in result.scores where !score.isEfficient {
            guard let targets = score.targetInputs else {
                Issue.record("Inefficient DMU \(score.name) should have target inputs")
                continue
            }
            guard let dmu = cooperDMUs.first(where: { $0.name == score.name }) else {
                continue
            }
            for (target, actual) in zip(targets, dmu.inputs) {
                #expect(target <= actual + 1e-6,
                        "Target input should not exceed actual for DMU \(score.name)")
            }
        }
    }
}

// MARK: - Analytical Cross-Check (1-input / 1-output)

@Suite("DEA 1-Input 1-Output Cross-Check")
struct DEASingleDimensionTests {

    let solver = DEASolver()

    @Test("Single input/output CCR reduces to ratio comparison")
    func singleDimensionCCR() throws {
        let dmus = [
            DMU(name: "P1", inputs: [2], outputs: [1]),
            DMU(name: "P2", inputs: [3], outputs: [2]),
            DMU(name: "P3", inputs: [5], outputs: [4]),
            DMU(name: "P4", inputs: [4], outputs: [3])
        ]

        let expected: [String: Double] = [
            "P1": 0.625,
            "P2": 0.833,
            "P3": 1.000,
            "P4": 0.938
        ]

        let result = try solver.solve(
            dmus: dmus,
            model: .ccr,
            orientation: .inputOriented
        )

        for score in result.scores {
            guard let exp = expected[score.name] else { continue }
            #expect(
                abs(score.efficiency - exp) < 0.01,
                "DMU \(score.name): expected \(exp), got \(score.efficiency)"
            )
        }
    }

    @Test("Single input/output — only best ratio DMU is efficient")
    func singleDimensionOnlyBestIsEfficient() throws {
        let dmus = [
            DMU(name: "P1", inputs: [2], outputs: [1]),
            DMU(name: "P2", inputs: [3], outputs: [2]),
            DMU(name: "P3", inputs: [5], outputs: [4]),
            DMU(name: "P4", inputs: [4], outputs: [3])
        ]

        let result = try solver.solve(dmus: dmus, model: .ccr)

        #expect(result.efficientDMUs == ["P3"])
    }
}

// MARK: - CCR Output-Oriented

@Suite("DEA CCR Output-Oriented")
struct DEACCROutputOrientedTests {

    let solver = DEASolver()

    @Test("Output-oriented efficiency is normalized to (0, 1]")
    func outputOrientedNormalization() throws {
        let result = try solver.solve(
            dmus: cooperDMUs,
            model: .ccr,
            orientation: .outputOriented
        )

        for score in result.scores {
            #expect(score.efficiency > 0, "Efficiency must be > 0 for DMU \(score.name)")
            #expect(score.efficiency <= 1.0 + 1e-6,
                    "Normalized efficiency must be <= 1.0 for DMU \(score.name)")
        }
    }

    @Test("Output-oriented rawScore >= 1.0")
    func outputOrientedRawScore() throws {
        let result = try solver.solve(
            dmus: cooperDMUs,
            model: .ccr,
            orientation: .outputOriented
        )

        for score in result.scores {
            #expect(score.rawScore >= 1.0 - 1e-6,
                    "Raw output-oriented score must be >= 1.0 for DMU \(score.name)")
        }
    }

    @Test("Output-oriented efficiency equals 1/rawScore")
    func outputOrientedEfficiencyIsInverseOfRaw() throws {
        let result = try solver.solve(
            dmus: cooperDMUs,
            model: .ccr,
            orientation: .outputOriented
        )

        for score in result.scores {
            let expectedEfficiency = 1.0 / score.rawScore
            #expect(
                abs(score.efficiency - expectedEfficiency) < 1e-6,
                "efficiency should equal 1/rawScore for DMU \(score.name)"
            )
        }
    }

    @Test("Output-oriented same efficient set as input-oriented")
    func outputOrientedSameEfficientSet() throws {
        let inputResult = try solver.solve(
            dmus: cooperDMUs, model: .ccr, orientation: .inputOriented
        )
        let outputResult = try solver.solve(
            dmus: cooperDMUs, model: .ccr, orientation: .outputOriented
        )

        #expect(
            Set(inputResult.efficientDMUs) == Set(outputResult.efficientDMUs),
            "CCR efficient set must be the same regardless of orientation"
        )
    }

    @Test("Output-oriented target outputs >= actual outputs")
    func outputOrientedTargetOutputs() throws {
        let result = try solver.solve(
            dmus: cooperDMUs,
            model: .ccr,
            orientation: .outputOriented
        )

        for score in result.scores where !score.isEfficient {
            guard let targets = score.targetOutputs else {
                Issue.record("Inefficient DMU \(score.name) should have target outputs")
                continue
            }
            guard let dmu = cooperDMUs.first(where: { $0.name == score.name }) else {
                continue
            }
            for (target, actual) in zip(targets, dmu.outputs) {
                #expect(target >= actual - 1e-6,
                        "Target output should not be less than actual for DMU \(score.name)")
            }
        }
    }
}

// MARK: - BCC Model

@Suite("DEA BCC Model")
struct DEABCCTests {

    let solver = DEASolver()

    @Test("BCC scores >= CCR scores (variable returns less restrictive)")
    func bccGreaterThanOrEqualCCR() throws {
        let ccrResult = try solver.solve(
            dmus: cooperDMUs, model: .ccr, orientation: .inputOriented
        )
        let bccResult = try solver.solve(
            dmus: cooperDMUs, model: .bcc, orientation: .inputOriented
        )

        for (ccr, bcc) in zip(
            ccrResult.scores.sorted(by: { $0.name < $1.name }),
            bccResult.scores.sorted(by: { $0.name < $1.name })
        ) {
            #expect(ccr.name == bcc.name)
            #expect(
                bcc.efficiency >= ccr.efficiency - 1e-6,
                "BCC score should be >= CCR score for DMU \(ccr.name)"
            )
        }
    }

    @Test("BCC efficient set is superset of CCR efficient set")
    func bccEfficientSupersetOfCCR() throws {
        let ccrResult = try solver.solve(
            dmus: cooperDMUs, model: .ccr, orientation: .inputOriented
        )
        let bccResult = try solver.solve(
            dmus: cooperDMUs, model: .bcc, orientation: .inputOriented
        )

        let ccrEfficient = Set(ccrResult.efficientDMUs)
        let bccEfficient = Set(bccResult.efficientDMUs)

        #expect(ccrEfficient.isSubset(of: bccEfficient),
                "Every CCR-efficient DMU must also be BCC-efficient")
    }

    @Test("BCC all scores in (0, 1]")
    func bccScoresInRange() throws {
        let result = try solver.solve(
            dmus: cooperDMUs, model: .bcc, orientation: .inputOriented
        )

        for score in result.scores {
            #expect(score.efficiency > 0, "BCC score must be > 0 for DMU \(score.name)")
            #expect(score.efficiency <= 1.0 + 1e-6,
                    "BCC score must be <= 1.0 for DMU \(score.name)")
        }
    }
}

// MARK: - Edge Cases

@Suite("DEA Edge Cases")
struct DEAEdgeCaseTests {

    let solver = DEASolver()

    @Test("All identical DMUs are efficient")
    func allIdenticalDMUs() throws {
        let dmus = (1...5).map { i in
            DMU(name: "Unit\(i)", inputs: [10, 20], outputs: [5, 8])
        }

        let result = try solver.solve(dmus: dmus, model: .ccr)

        for score in result.scores {
            #expect(score.isEfficient,
                    "Identical DMU \(score.name) should be efficient")
        }
    }

    @Test("Two DMUs — dominant one is efficient, dominated is not")
    func twoDMUsDomination() throws {
        let dmus = [
            DMU(name: "Good", inputs: [1], outputs: [10]),
            DMU(name: "Bad", inputs: [10], outputs: [1])
        ]

        let result = try solver.solve(dmus: dmus, model: .ccr)

        let good = result.scores.first(where: { $0.name == "Good" })
        let bad = result.scores.first(where: { $0.name == "Bad" })

        #expect(good?.isEfficient == true)
        #expect(bad?.isEfficient == false)
    }

    @Test("Two DMUs — neither dominates, both efficient")
    func twoDMUsNonDominating() throws {
        let dmus = [
            DMU(name: "Cheap", inputs: [1, 5], outputs: [3]),
            DMU(name: "Quality", inputs: [5, 1], outputs: [3])
        ]

        let result = try solver.solve(dmus: dmus, model: .ccr)

        #expect(result.scores.allSatisfy { $0.isEfficient },
                "Non-dominating DMUs should both be efficient")
    }
}

// MARK: - Property-Based Tests

@Suite("DEA Properties")
struct DEAPropertyTests {

    let solver = DEASolver()

    @Test("All CCR input-oriented scores in (0, 1]")
    func ccrScoresInRange() throws {
        let result = try solver.solve(
            dmus: cooperDMUs, model: .ccr, orientation: .inputOriented
        )

        for score in result.scores {
            #expect(score.efficiency > 0,
                    "CCR score must be > 0 for DMU \(score.name)")
            #expect(score.efficiency <= 1.0 + 1e-6,
                    "CCR score must be <= 1.0 for DMU \(score.name)")
        }
    }

    @Test("Input-oriented rawScore equals efficiency")
    func inputOrientedRawEqualsEfficiency() throws {
        let result = try solver.solve(
            dmus: cooperDMUs, model: .ccr, orientation: .inputOriented
        )

        for score in result.scores {
            #expect(
                abs(score.rawScore - score.efficiency) < 1e-10,
                "Input-oriented rawScore should equal efficiency for DMU \(score.name)"
            )
        }
    }

    @Test("Efficient DMUs reference set contains only efficient DMUs")
    func referenceSetOnlyEfficient() throws {
        let result = try solver.solve(
            dmus: cooperDMUs, model: .ccr, orientation: .inputOriented
        )
        let efficientSet = Set(result.efficientDMUs)

        for score in result.scores {
            for ref in score.referenceSet {
                #expect(efficientSet.contains(ref.name),
                        "Reference DMU \(ref.name) should be efficient")
            }
        }
    }

    @Test("Reference set lambda weights are non-negative")
    func referenceSetWeightsNonNegative() throws {
        let result = try solver.solve(
            dmus: cooperDMUs, model: .ccr, orientation: .inputOriented
        )

        for score in result.scores {
            for ref in score.referenceSet {
                #expect(ref.weight >= -1e-6,
                        "Lambda weight should be non-negative for \(ref.name)")
            }
        }
    }

    @Test("Total iterations is positive")
    func totalIterationsPositive() throws {
        let result = try solver.solve(
            dmus: cooperDMUs, model: .ccr, orientation: .inputOriented
        )
        #expect(result.totalIterations > 0)
    }
}

// MARK: - Numerical Stability

@Suite("DEA Numerical Stability")
struct DEANumericalStabilityTests {

    let solver = DEASolver()

    @Test("Very small positive values still solve correctly")
    func verySmallValues() throws {
        let dmus = [
            DMU(name: "A", inputs: [1e-8, 2e-8], outputs: [3e-8]),
            DMU(name: "B", inputs: [2e-8, 1e-8], outputs: [2e-8]),
            DMU(name: "C", inputs: [3e-8, 3e-8], outputs: [1e-8])
        ]

        let result = try solver.solve(dmus: dmus, model: .ccr)

        for score in result.scores {
            #expect(score.efficiency.isFinite,
                    "Score should be finite for DMU \(score.name)")
            #expect(score.efficiency > 0,
                    "Score should be positive for DMU \(score.name)")
        }
    }

    @Test("Large spread between input and output scales")
    func largeScaleSpread() throws {
        let dmus = [
            DMU(name: "A", inputs: [1000, 2000], outputs: [0.5, 0.8]),
            DMU(name: "B", inputs: [1500, 1000], outputs: [0.7, 0.4]),
            DMU(name: "C", inputs: [2000, 3000], outputs: [0.3, 0.9])
        ]

        let result = try solver.solve(dmus: dmus, model: .ccr)

        for score in result.scores {
            #expect(score.efficiency.isFinite,
                    "Score should be finite for DMU \(score.name)")
            #expect(score.efficiency > 0 && score.efficiency <= 1.0 + 1e-6,
                    "Score should be in (0, 1] for DMU \(score.name)")
        }
    }
}

// MARK: - Stress Tests

@Suite("DEA Stress Tests")
struct DEAStressTests {

    let solver = DEASolver()

    @Test("100 DMUs with 5 inputs and 5 outputs completes",
          .timeLimit(.minutes(1)))
    func hundredDMUs() throws {
        var dmus: [DMU] = []
        for i in 0..<100 {
            let seed = Double(i + 1)
            let inputs = (0..<5).map { j in seed + Double(j) * 0.3 + 1.0 }
            let outputs = (0..<5).map { j in seed * 0.1 + Double(j) * 0.2 + 0.5 }
            dmus.append(DMU(name: "DMU_\(i)", inputs: inputs, outputs: outputs))
        }

        let result = try solver.solve(dmus: dmus, model: .ccr)

        #expect(result.scores.count == 100)
        for score in result.scores {
            #expect(score.efficiency > 0 && score.efficiency <= 1.0 + 1e-6)
        }
    }
}
