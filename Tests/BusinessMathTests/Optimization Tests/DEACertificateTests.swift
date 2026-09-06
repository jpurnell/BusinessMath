//
//  DEACertificateTests.swift
//  BusinessMath
//
//  An external oracle for data envelopment analysis, mostly without a fixture.
//
//  DEA is unusually well suited to being checked against itself, because almost
//  everything it claims is a definition rather than a computation:
//
//  - An input-oriented efficiency is the smallest `θ` for which some non-negative
//    combination of the other units produces at least as much output using no more
//    than `θ` times this unit's inputs. The reported reference set *is* that
//    combination, so the claim can be evaluated directly. That proves the score is
//    **attainable** — it cannot be too low.
//  - Every unit in a reference set must itself be efficient; the frontier is made
//    of efficient units by construction.
//  - Efficiency is **units invariant**. Measuring an input in thousands rather than
//    units, or output in dollars rather than cents, cannot change who is efficient.
//    This is the property DEA is chosen for, and a scaling error inside the solver
//    breaks it while leaving every score plausible.
//  - Relaxing constant returns to scale to variable returns cannot lower a score,
//    so `BCC ≥ CCR` for every unit, and their ratio — scale efficiency — is at
//    most one.
//  - Super-efficiency re-evaluates a unit against the others with itself removed.
//    An efficient unit scores at least 1 there; an inefficient one is unaffected,
//    because it was never on the frontier to remove.
//
//  ## Where an exact answer exists, it is used
//
//  With one input and one output the whole problem collapses to a ratio:
//
//      θ_o = (y_o / x_o) / max_j (y_j / x_j)
//
//  No linear program is involved. `singleInputSingleOutputMatchesTheClosedForm`
//  computes that directly, which pins the scale of the answer and not merely its
//  internal consistency — the one thing the definitional checks above cannot do,
//  since a solver returning `θ = 1` for everything satisfies attainability.
//
//  ## And an optimality check in low dimension
//
//  Attainability bounds the score from one side only. For the constant-returns
//  frontier with a single output, the binding combination uses at most as many
//  units as there are inputs, so for two inputs a scan over pairs finds the true
//  optimum. `noCombinationBeatsTheReportedScore` runs that scan and fails if it
//  finds a better `θ` than the solver did.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Data envelopment analysis — certificates")
struct DEACertificateTests {

	// MARK: - Corpus

	private struct Dataset: Sendable {
		let name: String
		let note: String
		let dmus: [DMU]
	}

	private static let corpus: [Dataset] = [
		Dataset(name: "singleRatio",
				note: """
					One input, one output, so every score has a closed form and the
					frontier is a single unit.
					""",
				dmus: [
					DMU(name: "A", inputs: [2], outputs: [1]),
					DMU(name: "B", inputs: [4], outputs: [3]),
					DMU(name: "C", inputs: [6], outputs: [3]),
					DMU(name: "D", inputs: [3], outputs: [1]),
				]),

		Dataset(name: "singleRatioManyUnits",
				note: """
					The same shape with more units and a wider spread of ratios, so the
					closed form is exercised away from the frontier as well as on it.
					""",
				dmus: [
					DMU(name: "P1", inputs: [10], outputs: [4]),
					DMU(name: "P2", inputs: [12], outputs: [9]),
					DMU(name: "P3", inputs: [8], outputs: [2]),
					DMU(name: "P4", inputs: [20], outputs: [15]),
					DMU(name: "P5", inputs: [5], outputs: [3]),
					DMU(name: "P6", inputs: [15], outputs: [6]),
				]),

		Dataset(name: "twoInputsOneOutput",
				note: """
					The classic input-isoquant picture: units trade one input against
					another at equal output, so the frontier is a piecewise-linear
					boundary rather than a single point, and a unit can be inefficient
					without being dominated by any single other unit.
					""",
				dmus: [
					DMU(name: "A", inputs: [4, 3], outputs: [1]),
					DMU(name: "B", inputs: [7, 3], outputs: [1]),
					DMU(name: "C", inputs: [8, 1], outputs: [1]),
					DMU(name: "D", inputs: [4, 2], outputs: [1]),
					DMU(name: "E", inputs: [2, 4], outputs: [1]),
					DMU(name: "F", inputs: [10, 1], outputs: [1]),
				]),

		Dataset(name: "twoInputsTwoOutputs",
				note: """
					Both dimensions above one, where a score can no longer be read off a
					picture and the envelopment constraints are the only statement of
					what the number means.
					""",
				dmus: [
					DMU(name: "U1", inputs: [20, 151], outputs: [100, 90]),
					DMU(name: "U2", inputs: [19, 131], outputs: [150, 50]),
					DMU(name: "U3", inputs: [25, 160], outputs: [160, 55]),
					DMU(name: "U4", inputs: [27, 168], outputs: [180, 72]),
					DMU(name: "U5", inputs: [22, 158], outputs: [94, 66]),
					DMU(name: "U6", inputs: [55, 255], outputs: [230, 90]),
				]),

		Dataset(name: "duplicatesAndDominance",
				note: """
					Two units with identical data, and one strictly dominated by another.
					Duplicates make the optimal reference set non-unique, which is where a
					solver that assumes a unique frontier representation goes wrong.
					""",
				dmus: [
					DMU(name: "X", inputs: [3, 4], outputs: [2]),
					DMU(name: "XCopy", inputs: [3, 4], outputs: [2]),
					DMU(name: "Y", inputs: [6, 8], outputs: [2]),
					DMU(name: "Z", inputs: [2, 6], outputs: [2]),
				]),

		Dataset(name: "wideScaleSpread",
				note: """
					An input measured in units beside one measured in hundreds of
					thousands. DEA is units invariant in theory; a solver whose tolerances
					are absolute rather than relative stops being so in practice, and this
					is the shape that shows it.
					""",
				dmus: [
					DMU(name: "S1", inputs: [3, 250_000], outputs: [40]),
					DMU(name: "S2", inputs: [5, 180_000], outputs: [45]),
					DMU(name: "S3", inputs: [4, 300_000], outputs: [38]),
					DMU(name: "S4", inputs: [8, 120_000], outputs: [50]),
				]),
	]

	// MARK: - Helpers

	private static func solve(_ dataset: Dataset,
							  model: DEAModelType,
							  orientation: DEAOrientation = .inputOriented) throws -> DEAResult {
		try DEASolver().solve(dmus: dataset.dmus, model: model, orientation: orientation)
	}

	private static func unit(named name: String, in dataset: Dataset) -> DMU? {
		dataset.dmus.first { $0.name == name }
	}

	// MARK: - The exact case

	@Test("With one input and one output the score is a ratio, and matches it")
	func singleInputSingleOutputMatchesTheClosedForm() throws {
		var compared = 0
		for dataset in Self.corpus where dataset.dmus.allSatisfy({ $0.inputs.count == 1 && $0.outputs.count == 1 }) {
			let best = dataset.dmus.reduce(0.0) { running, dmu in
				Swift.max(running, dmu.outputs[0] / dmu.inputs[0])
			}
			guard best > 0 else { continue }
			let result = try Self.solve(dataset, model: .ccr)

			for score in result.scores {
				guard let dmu = Self.unit(named: score.name, in: dataset) else {
					Issue.record("\(dataset.name): no unit named \(score.name)"); continue
				}
				// No linear program in sight: the constant-returns frontier through
				// the origin is the single best ratio, and everything else is measured
				// against it.
				let ratio: Double = dmu.outputs[0] / dmu.inputs[0]
				let expected: Double = ratio / best
				#expect(abs(score.efficiency - expected) < 1e-9,
						"\(dataset.name)/\(score.name): \(score.efficiency), closed form \(expected)")
				compared += 1
			}
		}
		#expect(compared >= 10, "only \(compared) scores compared against the closed form")
	}

	// MARK: - Attainability

	@Test("The reference set attains the reported score")
	func referenceSetAttainsTheScore() throws {
		for dataset in Self.corpus {
			for model in [DEAModelType.ccr, DEAModelType.bcc] {
				let result = try Self.solve(dataset, model: model)
				for score in result.scores {
					guard let dmu = Self.unit(named: score.name, in: dataset) else { continue }
					guard !score.referenceSet.isEmpty else {
						Issue.record("\(dataset.name)/\(score.name) [\(model)]: empty reference set")
						continue
					}

					var compositeInputs = [Double](repeating: 0, count: dmu.inputs.count)
					var compositeOutputs = [Double](repeating: 0, count: dmu.outputs.count)
					for peer in score.referenceSet {
						guard let source = Self.unit(named: peer.name, in: dataset) else {
							Issue.record("\(dataset.name)/\(score.name): peer \(peer.name) is not in the data")
							continue
						}
						for i in 0..<compositeInputs.count {
							compositeInputs[i] += peer.weight * source.inputs[i]
						}
						for r in 0..<compositeOutputs.count {
							compositeOutputs[r] += peer.weight * source.outputs[r]
						}
					}

					// Σλx ≤ θx_o and Σλy ≥ y_o. This is the definition of the score, so
					// it proves the number is attainable — it cannot be too low.
					for i in 0..<compositeInputs.count {
						let allowed: Double = score.efficiency * dmu.inputs[i]
						let bound = 1e-6 * Swift.max(1.0, abs(allowed))
						#expect(compositeInputs[i] <= allowed + bound,
								"""
								\(dataset.name)/\(score.name) [\(model)] input \(i): \
								composite \(compositeInputs[i]) exceeds θx = \(allowed)
								""")
					}
					for r in 0..<compositeOutputs.count {
						let required = dmu.outputs[r]
						let bound = 1e-6 * Swift.max(1.0, abs(required))
						#expect(compositeOutputs[r] >= required - bound,
								"""
								\(dataset.name)/\(score.name) [\(model)] output \(r): \
								composite \(compositeOutputs[r]) below y = \(required)
								""")
					}
				}
			}
		}
	}

	@Test("Every unit on a reference set is itself efficient")
	func peersAreEfficient() throws {
		for dataset in Self.corpus {
			for model in [DEAModelType.ccr, DEAModelType.bcc] {
				let result = try Self.solve(dataset, model: model)
				let efficiency = Dictionary(uniqueKeysWithValues: result.scores.map { ($0.name, $0.efficiency) })
				for score in result.scores {
					for peer in score.referenceSet where peer.weight > 1e-9 {
						guard let peerScore = efficiency[peer.name] else {
							Issue.record("\(dataset.name): peer \(peer.name) has no score"); continue
						}
						// The frontier is built out of efficient units. A peer that is
						// not efficient means the frontier was drawn through the
						// interior of the production set.
						#expect(abs(peerScore - 1.0) < 1e-6,
								"""
								\(dataset.name)/\(score.name) [\(model)]: peer \(peer.name) \
								carries weight \(peer.weight) but scores \(peerScore)
								""")
					}
				}
			}
		}
	}

	// MARK: - Optimality in low dimension

	@Test("No combination of units beats the reported score")
	func noCombinationBeatsTheReportedScore() throws {
		// For constant returns with one output, the binding combination needs at
		// most as many units as there are inputs. With two inputs, scanning pairs is
		// therefore a complete search — and it is a different algorithm from the
		// simplex underneath, so it can disagree.
		for dataset in Self.corpus where dataset.dmus.allSatisfy({ $0.outputs.count == 1 && $0.inputs.count <= 2 }) {
			let result = try Self.solve(dataset, model: .ccr)
			let units = dataset.dmus

			for score in result.scores {
				guard let target = Self.unit(named: score.name, in: dataset) else { continue }
				var best = Double.infinity

				/// The smallest θ for which `weights` scaled to meet the output
				/// requirement fits inside `θ · target.inputs`.
				func theta(_ combination: [(dmu: DMU, share: Double)]) -> Double? {
					var producedOutput = 0.0
					var usedInputs = [Double](repeating: 0, count: target.inputs.count)
					for part in combination {
						producedOutput += part.share * part.dmu.outputs[0]
						for i in 0..<usedInputs.count {
							usedInputs[i] += part.share * part.dmu.inputs[i]
						}
					}
					guard producedOutput > 1e-12 else { return nil }
					// Constant returns: scale the whole combination until it just
					// meets this unit's output.
					let scale: Double = target.outputs[0] / producedOutput
					var worst = 0.0
					for i in 0..<usedInputs.count {
						guard target.inputs[i] > 0 else { continue }
						let needed: Double = scale * usedInputs[i]
						worst = Swift.max(worst, needed / target.inputs[i])
					}
					return worst
				}

				for a in 0..<units.count {
					if let single = theta([(units[a], 1.0)]) { best = Swift.min(best, single) }
					guard target.inputs.count >= 2 else { continue }
					for b in (a + 1)..<units.count {
						// A scan over the mixing weight. 401 steps resolves the optimum
						// to about 2.5e-3 in the weight, and the objective is piecewise
						// linear in it, so the slack below is generous rather than tight.
						for step in 0...400 {
							let share = Double(step) / 400
							let pair = [(units[a], share), (units[b], 1 - share)]
							if let mixed = theta(pair) { best = Swift.min(best, mixed) }
						}
					}
				}

				guard best.isFinite else { continue }
				// The solver may not do worse than the scan. It is allowed to do
				// slightly better, since the scan only samples the mixing weight.
				#expect(score.efficiency <= best + 5e-3,
						"""
						\(dataset.name)/\(score.name): solver reports \(score.efficiency), \
						a scan over combinations reaches \(best)
						""")
			}
		}
	}

	// MARK: - Invariance

	@Test("Efficiency does not depend on the units inputs and outputs are measured in")
	func efficiencyIsUnitsInvariant() throws {
		let factors: [Double] = [0.001, 0.5, 7.0, 1000.0]
		for dataset in Self.corpus {
			let baseline = try Self.solve(dataset, model: .ccr)
			let baselineScores = Dictionary(uniqueKeysWithValues: baseline.scores.map { ($0.name, $0.efficiency) })

			let inputCount = dataset.dmus[0].inputs.count
			let outputCount = dataset.dmus[0].outputs.count

			for (index, factor) in factors.enumerated() {
				// Rescale one dimension at a time, alternating between an input and an
				// output so both paths through the solver are covered.
				let scaleInput = index % 2 == 0
				let dimension = scaleInput ? index % inputCount : index % outputCount

				let rescaled = dataset.dmus.map { dmu -> DMU in
					var inputs = dmu.inputs
					var outputs = dmu.outputs
					if scaleInput {
						inputs[dimension] *= factor
					} else {
						outputs[dimension] *= factor
					}
					return DMU(name: dmu.name, inputs: inputs, outputs: outputs)
				}

				let moved = try DEASolver().solve(dmus: rescaled, model: .ccr, orientation: .inputOriented)
				for score in moved.scores {
					guard let before = baselineScores[score.name] else { continue }
					// Units invariance is the property DEA is chosen for. Breaking it
					// leaves every score inside [0, 1] and every ranking plausible.
					#expect(abs(score.efficiency - before) < 1e-6,
							"""
							\(dataset.name)/\(score.name): \(before) became \(score.efficiency) \
							after scaling \(scaleInput ? "input" : "output") \(dimension) by \(factor)
							""")
				}
			}
		}
	}

	// MARK: - Relationships between the models

	@Test("Variable returns cannot score below constant returns")
	func bccIsAtLeastCCR() throws {
		var compared = 0
		for dataset in Self.corpus {
			let ccr = try Self.solve(dataset, model: .ccr)
			let bcc = try Self.solve(dataset, model: .bcc)
			let constantReturns = Dictionary(uniqueKeysWithValues: ccr.scores.map { ($0.name, $0.efficiency) })

			for score in bcc.scores {
				guard let underCRS = constantReturns[score.name] else { continue }
				// BCC drops the requirement that the frontier pass through the origin,
				// which is a relaxation, and a relaxation cannot hurt.
				#expect(score.efficiency >= underCRS - 1e-6,
						"\(dataset.name)/\(score.name): BCC \(score.efficiency) below CCR \(underCRS)")
				// Scale efficiency is their ratio and is itself an efficiency.
				guard score.efficiency > 1e-9 else { continue }
				let scaleEfficiency: Double = underCRS / score.efficiency
				#expect(scaleEfficiency <= 1 + 1e-6,
						"\(dataset.name)/\(score.name): scale efficiency \(scaleEfficiency)")
				compared += 1
			}
		}
		#expect(compared >= 20, "only \(compared) units compared across the two models")
	}

	@Test("The variable-returns reference set is a convex combination")
	func bccWeightsSumToOne() throws {
		for dataset in Self.corpus {
			let result = try Self.solve(dataset, model: .bcc)
			for score in result.scores {
				let total = score.referenceSet.reduce(0.0) { $0 + $1.weight }
				// Σλ = 1 is exactly what distinguishes BCC from CCR; without it the
				// two models are the same computation under two names.
				#expect(abs(total - 1.0) < 1e-6,
						"\(dataset.name)/\(score.name): BCC weights sum to \(total)")
			}
		}
	}

	@Test("Super-efficiency separates the frontier and leaves the interior alone")
	func superEfficiencyBehavesAtTheFrontier() throws {
		for dataset in Self.corpus {
			let ccr = try Self.solve(dataset, model: .ccr)
			let sup = try Self.solve(dataset, model: .superEfficiency(base: .ccr))
			let base = Dictionary(uniqueKeysWithValues: ccr.scores.map { ($0.name, $0.efficiency) })

			for score in sup.scores where !score.superEfficiencyInfeasible {
				guard let plain = base[score.name] else { continue }
				if abs(plain - 1.0) < 1e-6 {
					// Efficient under CCR: removing it from its own comparison set can
					// only leave it at or beyond the frontier the others form.
					#expect(score.efficiency >= 1 - 1e-6,
							"\(dataset.name)/\(score.name): efficient, but super-efficiency \(score.efficiency)")
				} else {
					// Inefficient: it was never part of the frontier, so removing it
					// changes nothing at all.
					#expect(abs(score.efficiency - plain) < 1e-6,
							"""
							\(dataset.name)/\(score.name): CCR \(plain) but super-efficiency \
							\(score.efficiency) — it was not on the frontier to remove
							""")
				}
			}
		}
	}

	// MARK: - Shape of the answer

	@Test("Scores sit in (0, 1], slacks are non-negative, and a frontier exists")
	func scoresAndSlacksAreWellFormed() throws {
		for dataset in Self.corpus {
			for model in [DEAModelType.ccr, DEAModelType.bcc] {
				let result = try Self.solve(dataset, model: model)
				#expect(result.scores.count == dataset.dmus.count,
						"\(dataset.name) [\(model)]: \(result.scores.count) scores for \(dataset.dmus.count) units")

				for score in result.scores {
					#expect(score.efficiency > 0,
							"\(dataset.name)/\(score.name) [\(model)]: efficiency \(score.efficiency)")
					#expect(score.efficiency <= 1 + 1e-6,
							"\(dataset.name)/\(score.name) [\(model)]: efficiency \(score.efficiency) above 1")
					for weight in score.referenceSet {
						#expect(weight.weight >= -1e-9,
								"\(dataset.name)/\(score.name) [\(model)]: negative weight \(weight.weight) on \(weight.name)")
					}
					// A slack is an amount of input still wasted after the radial
					// contraction, so it cannot be negative beyond rounding.
					for slack in (score.inputSlacks ?? []) {
						#expect(slack >= -1e-6,
								"\(dataset.name)/\(score.name) [\(model)]: input slack \(slack)")
					}
					for slack in (score.outputSlacks ?? []) {
						#expect(slack >= -1e-6,
								"\(dataset.name)/\(score.name) [\(model)]: output slack \(slack)")
					}
				}

				// Some unit defines the frontier — otherwise every score is measured
				// against nothing.
				#expect(!result.efficientDMUs.isEmpty,
						"\(dataset.name) [\(model)]: no unit is efficient")
			}
		}
	}

	@Test("A dominated unit scores below one and a dominating unit scores one")
	func dominanceIsReflectedInTheScores() throws {
		// Y uses exactly twice X's inputs for the same output, so it can be at most
		// half as efficient — a claim needing no solver at all. And X, using the
		// least of both inputs among the units producing 2, must be efficient.
		guard let dataset = Self.corpus.first(where: { $0.name == "duplicatesAndDominance" }) else {
			Issue.record("dataset missing"); return
		}
		let result = try Self.solve(dataset, model: .ccr)
		let byName = Dictionary(uniqueKeysWithValues: result.scores.map { ($0.name, $0.efficiency) })

		let x = try #require(byName["X"])
		let copy = try #require(byName["XCopy"])
		let y = try #require(byName["Y"])

		#expect(abs(x - 1.0) < 1e-6, "X scores \(x)")
		// Identical data must score identically, whatever tie-break the solver uses
		// to pick a reference set.
		#expect(abs(x - copy) < 1e-9, "X scores \(x) but its duplicate scores \(copy)")
		#expect(abs(y - 0.5) < 1e-6, "Y uses double X's inputs for the same output, yet scores \(y)")
	}
}
