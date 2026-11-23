//
//  GroupedRankingPerformanceTests.swift
//  BusinessMath
//
//  A guard against the toolkit running unspecialised for `Double`.
//
//  In 3.0.0-alpha.18 the public entry points were generic with nothing telling the compiler to build a `Double` version, so a
//  caller in another module paid for a runtime type lookup on every arithmetic operation: a backtest through the toolkit ran
//  about thirty times slower than the same arithmetic written for `Double`. These tests time each heavy entry point against a
//  plain `Double` evaluation of the same likelihood on the same data, measured on the same machine in the same run, so a
//  loaded machine slows both and the ratio holds.
//
//  They run only in an optimised build (`swift test -c release`). A debug build has no specialisation to lose, and its timings
//  say nothing about the shipped code, so there the suite is disabled rather than loosened.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

/// What the performance guard needs: a build-kind switch, a synthetic class of realistic shape and a plain `Double` reference.
enum GroupedRankingPerformance {

	/// Whether this is an optimised build, the only kind in which the timings mean anything.
	static let isOptimisedBuild: Bool = {
		#if DEBUG
		return false
		#else
		return true
		#endif
	}()

	/// The reference weight for each of fifteen feature columns, and how often a candidate carries each.
	static let reference: [Double] = [2.5, 3.0, 2.5, 4.0, 1.5, 2.0, 8.0, 10.0, 0.3, 0.7, 1.0, 10.0, 0.2, 0.3, 2.0]
	static let density: [Double] = [0.04, 0.001, 0.001, 0.30, 0.20, 0.06, 0.05, 0.006, 0.03, 0.01, 0.03, 0.0001, 0.03, 0.03, 0.001]

	/// A class of `people` people, each with `people - 1` candidates (everyone else), sparse features of about the density of a
	/// real class, a few candidates chosen per person by a noisy draw from a known model, and a small fixed deduction.
	static func model(people: Int, seed: UInt64) -> GroupedChoiceModel<Double>? {
		let (groups, offsets) = sparseGroups(people: people, seed: seed)
		guard let data = GroupedChoiceData<Double>(sparseGroups: groups, featureCount: reference.count, offsets: offsets) else { return nil }
		return GroupedChoiceModel(data: data, reference: reference, likelihood: .subset)
	}

	/// The candidates `model(people:seed:)` is built from.
	static func sparseGroups(people: Int, seed: UInt64) -> ([[(features: [(feature: Int, value: Double)], chosen: Bool)]], [[Double]]) {
		var generator = SplitMix64(seed: seed)
		func uniform() -> Double { Double.random(in: 0..<1, using: &generator) }
		var groups: [[(features: [(feature: Int, value: Double)], chosen: Bool)]] = []
		var offsets: [[Double]] = []
		for person in 0..<people {
			var rows: [(features: [(feature: Int, value: Double)], chosen: Bool)] = []
			var scores: [Double] = []
			var deductions: [Double] = []
			for _ in 0..<(people - 1) {
				var entries: [(feature: Int, value: Double)] = []
				var score = 0.0
				for feature in 0..<reference.count where uniform() < density[feature] {
					let value: Double = feature == 3 ? Double(1 + Int(uniform() * 3)) : 1
					entries.append((feature: feature, value: value))
					score += reference[feature] * value * (feature == 5 ? 1.4 : 1)
				}
				let deduction: Double = uniform() < 0.05 ? -0.75 : 0
				scores.append(0.35 * (score + deduction))
				deductions.append(deduction)
				rows.append((features: entries, chosen: false))
			}
			let noisy: [Double] = scores.map { $0 - Double.log(-Double.log(Swift.max(uniform(), 1e-12))) }
			let order = noisy.indices.sorted { noisy[$0] > noisy[$1] }
			for index in order.prefix(2 + person % 3) { rows[index].chosen = true }
			groups.append(rows)
			offsets.append(deductions)
		}
		return (groups, offsets)
	}

	/// The negative log-likelihood of the observed choices, written for `Double` with no generics: the reference the timings are
	/// measured against, and a check that it computes the same number as the toolkit.
	static func plainNegativeLogLikelihood(_ data: GroupedChoiceData<Double>, reference: [Double], multipliers: [Double], scale: Double) -> Double {
		var total = 0.0
		var terms: [Double] = []
		var rolled: [Double] = []
		for group in 0..<data.groupCount {
			let rows = data.rows(ofGroup: group)
			var scores: [Double] = []
			scores.reserveCapacity(rows.count)
			var friends = 0
			var friendTotal = 0.0
			var maximum = -Double.infinity
			for row in rows {
				var sum = data.rowOffset[row]
				for entry in data.rowEntryStart[row]..<data.rowEntryStart[row + 1] {
					let feature = data.entryFeature[entry]
					sum += multipliers[feature] * reference[feature] * data.entryValue[entry]
				}
				let score = scale * sum
				scores.append(score)
				maximum = Swift.max(maximum, score)
				if data.rowChosen[row] { friends += 1; friendTotal += score }
			}
			guard friends > 0, friends < rows.count else { continue }
			terms = scores.map { Double.exp($0 - maximum) }
			rolled = [Double](repeating: 0, count: friends + 1)
			rolled[0] = 1
			for index in 0..<terms.count {
				var j = Swift.min(index + 1, friends)
				while j >= 1 { rolled[j] += terms[index] * rolled[j - 1]; j -= 1 }
			}
			total -= friendTotal - Double(friends) * maximum - Double.log(rolled[friends])
		}
		return total
	}

	/// The median wall-clock seconds of `runs` calls.
	static func seconds(runs: Int = 5, _ body: () -> Void) -> Double {
		var samples: [Double] = []
		for _ in 0..<runs {
			let start = ContinuousClock.now
			body()
			let elapsed = ContinuousClock.now - start
			samples.append(Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18)
		}
		return samples.sorted()[samples.count / 2]
	}
}

@Suite("Grouped ranking: performance", .enabled(if: GroupedRankingPerformance.isOptimisedBuild))
struct GroupedRankingPerformanceTests {

	private static let people = 70

	/// One plain evaluation, in seconds: the unit every ratio below is measured in.
	private static func unit(_ model: GroupedChoiceModel<Double>) -> Double {
		let ones = [Double](repeating: 1, count: model.data.featureCount)
		var sink = 0.0
		let seconds = GroupedRankingPerformance.seconds(runs: 9) {
			for _ in 0..<20 {
				sink += GroupedRankingPerformance.plainNegativeLogLikelihood(model.data, reference: model.reference, multipliers: ones, scale: 0.35)
			}
		} / 20
		#expect(sink.isFinite)
		return seconds
	}

	@Test("the plain reference computes the same likelihood as the toolkit")
	func referenceAgrees() throws {
		let model = try #require(GroupedRankingPerformance.model(people: 30, seed: 11))
		let ones = [Double](repeating: 1, count: model.data.featureCount)
		let weights = [Double](repeating: 1, count: model.data.groupCount)
		let toolkit = try #require(model.negativeLogLikelihood(multipliers: ones, scale: 0.35, groupWeights: weights))
		let plain = GroupedRankingPerformance.plainNegativeLogLikelihood(model.data, reference: model.reference, multipliers: ones, scale: 0.35)
		#expect(abs(toolkit.total - plain) < 1e-9 * Swift.max(1, abs(plain)))
	}

	/// The most each public entry point may take on a class of seventy, in units of one plain evaluation.
	///
	/// A bound sits about halfway, on a log scale, between what the entry point costs specialised and what it costs without the
	/// attribute (measured on an Apple-silicon Mac, optimised build, specialised against unspecialised): the evaluation 1.0 and 26,
	/// `fit` 103 and 3,428, `fitScale` and `referenceFit` 14 and 512, `choosePenalty` 1,907 and 62,972, `bootstrapIntervals` 670 and
	/// 22,460, `heldOutComparison` 4,023 and 134,325, `GroupedChoiceData` construction 4.1 and 25, `scores(for:)` 0.11 and 5.6,
	/// `perGroup` 3.8 and 48, `pooledEvaluation` 0.26 and 5.2. Noise has to move a ratio about two-fold (construction) to five-fold
	/// (the rest) to cross a bound in either direction. The model initialiser, `featureCounts` and `summary` are not specialised: the
	/// attribute made no measurable difference to them.
	private static let bounds: [(name: String, bound: Double)] = [
		("negativeLogLikelihood", 8), ("fit", 600), ("fitScale", 85), ("referenceFit", 85), ("choosePenalty", 11_000),
		("bootstrapIntervals", 4_000), ("heldOutComparison", 24_000), ("dataInit", 12), ("scores", 0.8), ("perGroup", 14),
		("pooledEvaluation", 1.2),
	]

	private static func ratios(_ model: GroupedChoiceModel<Double>) throws -> [String: Double] {
		let ones = [Double](repeating: 1, count: model.data.featureCount)
		let weights = [Double](repeating: 1, count: model.data.groupCount)
		let unit = Self.unit(model)
		let penalties: [PenaltyChoice<Double>] = [.penalty(0.05), .penalty(0.2), .penalty(1), .penalty(5), .penalty(25), .reference]
		let fitted = try model.fit(groupWeights: weights, penalty: 0.2)
		var result: [String: Double] = [:]
		result["negativeLogLikelihood"] = GroupedRankingPerformance.seconds(runs: 9) {
			for _ in 0..<20 { _ = model.negativeLogLikelihood(multipliers: ones, scale: 0.35, groupWeights: weights) }
		} / 20 / unit
		result["fit"] = GroupedRankingPerformance.seconds(runs: 3) { _ = try? model.fit(groupWeights: weights, penalty: 0.2) } / unit
		result["choosePenalty"] = GroupedRankingPerformance.seconds(runs: 3) {
			_ = GroupedCrossValidation.choosePenalty(model: model, groupWeights: weights, penalties: penalties, folds: 5, seed: 1)
		} / unit
		result["bootstrapIntervals"] = GroupedRankingPerformance.seconds(runs: 3) {
			_ = GroupedCrossValidation.bootstrapIntervals(
				model: model, full: fitted, penalty: 0.2, groupWeights: weights, resamples: 10, level: 0.9, seed: 2)
		} / unit
		result["heldOutComparison"] = GroupedRankingPerformance.seconds(runs: 3) {
			_ = GroupedCrossValidation.heldOutComparison(
				model: model, penalties: penalties, minimumChosen: 20, folds: 5, innerFolds: 3, resamples: 10, level: 0.9, seed: 3)
		} / unit
		let sparse = GroupedRankingPerformance.sparseGroups(people: Self.people, seed: 20_261_120)
		result["dataInit"] = GroupedRankingPerformance.seconds(runs: 5) {
			_ = GroupedChoiceData<Double>(sparseGroups: sparse.0, featureCount: GroupedRankingPerformance.reference.count, offsets: sparse.1)
		} / unit
		result["referenceFit"] = GroupedRankingPerformance.seconds(runs: 5) { _ = try? model.referenceFit(groupWeights: weights) } / unit
		result["fitScale"] = GroupedRankingPerformance.seconds(runs: 5) { _ = try? model.fitScale(groupWeights: weights) } / unit
		result["scores"] = GroupedRankingPerformance.seconds(runs: 9) { _ = model.scores(for: fitted) } / unit
		let scores = try #require(model.scores(for: fitted))
		result["perGroup"] = GroupedRankingPerformance.seconds(runs: 9) { _ = GroupRankingMetrics.perGroup(scores: scores, data: model.data, k: 25) } / unit
		result["pooledEvaluation"] = GroupedRankingPerformance.seconds(runs: 9) { _ = GroupRankingMetrics.pooledEvaluation(scores: scores, data: model.data) } / unit
		return result
	}

	@Test("each heavy entry point runs within its bound of a plain Double evaluation")
	func entryPointsAreSpecialised() throws {
		let model = try #require(GroupedRankingPerformance.model(people: Self.people, seed: 20_261_120))
		let measured = try Self.ratios(model)
		if ProcessInfo.processInfo.environment["GROUPED_RANKING_PERF_PRINT"] != nil {
			let line = measured.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
			FileHandle.standardError.write(Data("PERF \(line)\n".utf8))
		}
		for (name, bound) in Self.bounds {
			let ratio = try #require(measured[name], "no measurement for \(name)")
			#expect(ratio <= bound, "\(name) took \(ratio) plain evaluations, over its bound of \(bound): the toolkit may be running unspecialised for Double")
		}
	}
}
