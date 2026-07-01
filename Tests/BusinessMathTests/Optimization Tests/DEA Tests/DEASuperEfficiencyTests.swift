//
//  DEASuperEfficiencyTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-07-01.
//

import Testing
@testable import BusinessMath

// MARK: - Cooper et al. Reference Data (Super-Efficiency)

/// Same dataset as DEASolverTests — Cooper, Seiford & Tone (2007) Table 1.3.
private let cooperDMUs: [DMU] = [
    DMU(name: "A", inputs: [2, 5], outputs: [1, 4]),
    DMU(name: "B", inputs: [3, 3], outputs: [2, 2]),
    DMU(name: "C", inputs: [6, 2], outputs: [3, 1]),
    DMU(name: "D", inputs: [5, 5], outputs: [1, 3]),
    DMU(name: "E", inputs: [2, 4], outputs: [2, 1]),
    DMU(name: "F", inputs: [4, 6], outputs: [1, 5])
]

// MARK: - CCR Super-Efficiency Input-Oriented

@Suite("DEA Super-Efficiency CCR Input-Oriented")
struct DEASuperEfficiencyCCRInputTests {

    let solver = DEASolver()

    @Test("Efficient DMUs score >= 1.0 in CCR super-efficiency")
    func efficientDMUsScoreAboveOne() throws {
        let result = try solver.solve(
            dmus: cooperDMUs,
            model: .superEfficiency(base: .ccr),
            orientation: .inputOriented
        )

        let efficientNames: Set<String> = ["A", "B", "C", "E", "F"]
        for score in result.scores where efficientNames.contains(score.name) {
            #expect(
                score.efficiency >= 1.0 - 1e-6,
                "Efficient DMU \(score.name) should have super-efficiency >= 1.0, got \(score.efficiency)"
            )
        }
    }

    @Test("Inefficient DMU D scores identically to standard CCR (26/35)")
    func inefficientDMUMatchesStandard() throws {
        let result = try solver.solve(
            dmus: cooperDMUs,
            model: .superEfficiency(base: .ccr),
            orientation: .inputOriented
        )

        guard let dmuD = result.scores.first(where: { $0.name == "D" }) else {
            Issue.record("DMU D not found in results")
            return
        }

        let expectedScore = 26.0 / 35.0
        #expect(
            abs(dmuD.efficiency - expectedScore) < 0.01,
            "DMU D super-efficiency should match standard CCR score 26/35, got \(dmuD.efficiency)"
        )
    }

    @Test("Super-efficiency scores >= standard CCR scores for all DMUs")
    func superEfficiencyGreaterThanOrEqualStandard() throws {
        let standardResult = try solver.solve(
            dmus: cooperDMUs,
            model: .ccr,
            orientation: .inputOriented
        )
        let superResult = try solver.solve(
            dmus: cooperDMUs,
            model: .superEfficiency(base: .ccr),
            orientation: .inputOriented
        )

        let standardByName = Dictionary(
            uniqueKeysWithValues: standardResult.scores.map { ($0.name, $0.efficiency) }
        )

        for score in superResult.scores {
            guard let standardScore = standardByName[score.name] else {
                Issue.record("DMU \(score.name) not found in standard results")
                continue
            }
            #expect(
                score.efficiency >= standardScore - 1e-6,
                "Super-efficiency for \(score.name) (\(score.efficiency)) should be >= standard (\(standardScore))"
            )
        }
    }

    @Test("All super-efficiency scores are strictly positive")
    func allScoresPositive() throws {
        let result = try solver.solve(
            dmus: cooperDMUs,
            model: .superEfficiency(base: .ccr),
            orientation: .inputOriented
        )

        for score in result.scores {
            #expect(
                score.efficiency > 0,
                "Super-efficiency score must be > 0 for DMU \(score.name)"
            )
        }
    }

    @Test("Super-efficiency infeasible flag is false for standard CCR cases")
    func infeasibleFlagFalseForCCR() throws {
        let result = try solver.solve(
            dmus: cooperDMUs,
            model: .superEfficiency(base: .ccr),
            orientation: .inputOriented
        )

        for score in result.scores {
            #expect(
                !score.superEfficiencyInfeasible,
                "CCR super-efficiency should not be infeasible for DMU \(score.name)"
            )
        }
    }
}

// MARK: - CCR Super-Efficiency Output-Oriented

@Suite("DEA Super-Efficiency CCR Output-Oriented")
struct DEASuperEfficiencyCCROutputTests {

    let solver = DEASolver()

    @Test("Output-oriented super-efficiency works without throwing")
    func outputOrientedSuperEfficiency() throws {
        let result = try solver.solve(
            dmus: cooperDMUs,
            model: .superEfficiency(base: .ccr),
            orientation: .outputOriented
        )

        #expect(result.scores.count == cooperDMUs.count)

        for score in result.scores {
            #expect(
                score.efficiency > 0,
                "Output-oriented super-efficiency must be > 0 for DMU \(score.name)"
            )
        }
    }

    @Test("Output-oriented inefficient DMUs match standard scores")
    func outputOrientedInefficientMatchStandard() throws {
        let standardResult = try solver.solve(
            dmus: cooperDMUs,
            model: .ccr,
            orientation: .outputOriented
        )
        let superResult = try solver.solve(
            dmus: cooperDMUs,
            model: .superEfficiency(base: .ccr),
            orientation: .outputOriented
        )

        let standardByName = Dictionary(
            uniqueKeysWithValues: standardResult.scores.map { ($0.name, $0.efficiency) }
        )

        for score in superResult.scores {
            guard let standardScore = standardByName[score.name] else {
                Issue.record("DMU \(score.name) not found in standard results")
                continue
            }
            if standardScore < 1.0 - 1e-6 {
                #expect(
                    abs(score.efficiency - standardScore) < 0.01,
                    "Inefficient DMU \(score.name) should match standard score"
                )
            }
        }
    }
}

// MARK: - BCC Super-Efficiency

@Suite("DEA Super-Efficiency BCC")
struct DEASuperEfficiencyBCCTests {

    let solver = DEASolver()

    @Test("BCC super-efficiency handles potential infeasibility gracefully")
    func bccSuperEfficiencyDoesNotThrow() throws {
        let result = try solver.solve(
            dmus: cooperDMUs,
            model: .superEfficiency(base: .bcc),
            orientation: .inputOriented
        )

        #expect(result.scores.count == cooperDMUs.count)

        for score in result.scores {
            #expect(
                score.efficiency > 0,
                "BCC super-efficiency must be > 0 for DMU \(score.name)"
            )
        }
    }

    @Test("BCC infeasible DMUs are flagged correctly")
    func bccInfeasibleFlagging() throws {
        let result = try solver.solve(
            dmus: cooperDMUs,
            model: .superEfficiency(base: .bcc),
            orientation: .inputOriented
        )

        for score in result.scores {
            if score.superEfficiencyInfeasible {
                #expect(
                    score.efficiency.isInfinite,
                    "Infeasible DMU \(score.name) should have efficiency = infinity"
                )
            } else {
                #expect(
                    score.efficiency.isFinite,
                    "Non-infeasible DMU \(score.name) should have finite efficiency"
                )
            }
        }
    }
}

// MARK: - 1-Input / 1-Output Analytical Cross-Check

@Suite("DEA Super-Efficiency Analytical Cross-Check")
struct DEASuperEfficiencyAnalyticalTests {

    let solver = DEASolver()

    @Test("1-input/1-output: best ratio DMU gets super-efficiency > 1.0")
    func singleDimensionBestRatioSuperEfficient() throws {
        let dmus = [
            DMU(name: "P1", inputs: [2], outputs: [1]),
            DMU(name: "P2", inputs: [3], outputs: [2]),
            DMU(name: "P3", inputs: [5], outputs: [4]),
            DMU(name: "P4", inputs: [4], outputs: [3])
        ]

        let result = try solver.solve(
            dmus: dmus,
            model: .superEfficiency(base: .ccr),
            orientation: .inputOriented
        )

        guard let p3 = result.scores.first(where: { $0.name == "P3" }) else {
            Issue.record("P3 not found in results")
            return
        }

        #expect(
            p3.efficiency > 1.0 + 1e-6,
            "Best-ratio DMU P3 should have super-efficiency strictly > 1.0, got \(p3.efficiency)"
        )

        let expectedSuperEfficiency = 16.0 / 15.0
        #expect(
            abs(p3.efficiency - expectedSuperEfficiency) < 0.01,
            "P3 super-efficiency should be 16/15 ~ 1.067, got \(p3.efficiency)"
        )
    }

    @Test("1-input/1-output: inefficient DMUs retain standard scores")
    func singleDimensionInefficientRetainScores() throws {
        let dmus = [
            DMU(name: "P1", inputs: [2], outputs: [1]),
            DMU(name: "P2", inputs: [3], outputs: [2]),
            DMU(name: "P3", inputs: [5], outputs: [4]),
            DMU(name: "P4", inputs: [4], outputs: [3])
        ]

        let standardResult = try solver.solve(
            dmus: dmus, model: .ccr, orientation: .inputOriented
        )
        let superResult = try solver.solve(
            dmus: dmus, model: .superEfficiency(base: .ccr), orientation: .inputOriented
        )

        let standardByName = Dictionary(
            uniqueKeysWithValues: standardResult.scores.map { ($0.name, $0.efficiency) }
        )

        for score in superResult.scores {
            guard let standardScore = standardByName[score.name] else { continue }
            if standardScore < 1.0 - 1e-6 {
                #expect(
                    abs(score.efficiency - standardScore) < 1e-4,
                    "Inefficient DMU \(score.name) super-efficiency (\(score.efficiency)) should match standard (\(standardScore))"
                )
            }
        }
    }
}
