//
//  CampaignLeftoverStatisticsTests.swift
//  BusinessMathTests
//
//  The four sites the five-phase contaminated-input campaign located, read, and left because
//  each needed more than a passing edit. Three fixes and one recorded non-defect.
//
//  | site                                    | before                                  |
//  | weightedBreakdownPoint, nan weight      | "Weights must be non-negative"          |
//  | PercentileLocation, unorderable values  | a finite value from the wrong rank      |
//  | summarisePosterior, nan draw            | median and interval from wrong quantiles|
//  | separatesByThreshold, all-nan column    | unreachable — screened by validatedDesign|
//
//  The first is the sharpest, and it is the one §4 of the contaminated-input contract names
//  outright: the refusal was *right* and the diagnosis was about a different condition. A
//  `nan` weight fails `>= 0` exactly as a negative weight does, so the caller was sent to
//  look for a minus sign that is nowhere in their data. What this file asserts is not that
//  contamination is refused — it always was — but that the two refusals are **distinguishable**.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Campaign leftovers — statistics")
struct CampaignLeftoverStatisticsTests {

	// MARK: - 1. weightedBreakdownPoint: right action, wrong diagnosis

	@Test("A nan weight and a genuinely zero total weight carry different diagnoses")
	func breakdownPointDistinguishesContaminationFromZeroTotal() throws {
		var contaminationError: BusinessMathError?
		do {
			let _ = try weightedBreakdownPoint([1.0, Double.nan, 2.0])
			Issue.record("a nan weight must not yield a breakdown point")
		} catch let error as BusinessMathError {
			contaminationError = error
		}

		var zeroTotalError: BusinessMathError?
		do {
			let _ = try weightedBreakdownPoint([0.0, 0.0, 0.0] as [Double])
			Issue.record("a zero total weight must not yield a breakdown point")
		} catch let error as BusinessMathError {
			zeroTotalError = error
		}

		let contamination = try #require(contaminationError)
		let zeroTotal = try #require(zeroTotalError)

		// The defect was that these two arrived as the same kind of complaint about a
		// condition only one of them has. Pinning each to its own case is the assertion.
		let expectedContamination = BusinessMathError.dataQuality(
			message: "Weighted breakdown point requires finite weights",
			context: ["invalid_count": "1"])
		let expectedZeroTotal = BusinessMathError.divisionByZero(
			context: "Total weight is zero in weighted breakdown point")
		#expect(contamination == expectedContamination, "contamination must be reported as contamination")
		#expect(zeroTotal == expectedZeroTotal, "a real zero total must still be reported as one")
	}

	@Test("A genuinely negative weight is still reported as a negative weight")
	func breakdownPointStillReportsNegativeWeights() throws {
		let expected = BusinessMathError.invalidInput(
			message: "Weights must be non-negative", value: nil, expectedRange: nil)
		#expect(throws: expected) {
			let _ = try weightedBreakdownPoint([1.0, -1.0, 1.0])
		}
	}

	@Test("Infinite weights are refused rather than returning nan from a throwing function")
	func breakdownPointRefusesInfiniteWeights() throws {
		// `[inf, inf]` passed every guard and evaluated `minWeight / totalWeight` as `inf / inf`,
		// so a function whose contract is to refuse by throwing returned a `nan` instead.
		let expected = BusinessMathError.dataQuality(
			message: "Weighted breakdown point requires finite weights",
			context: ["invalid_count": "2"])
		#expect(throws: expected) {
			let _ = try weightedBreakdownPoint([Double.infinity, Double.infinity])
		}
	}

	@Test("Control — clean weights still give min(w) over sum(w)")
	func breakdownPointCleanControl() throws {
		let weights: [Double] = [1, 2, 3, 4]
		let total: Double = weights.reduce(0, +)
		let smallest: Double = try #require(weights.min())
		let expected: Double = smallest / total
		let actual: Double = try weightedBreakdownPoint(weights)
		#expect(actual.isEqual(to: expected), "breakdown point is min(w) / sum(w) = \(expected)")
	}

	@Test("Control — a trimmed estimator still reports its trimming proportion")
	func breakdownPointTrimmedControl() throws {
		let weights: [Double] = [1, 2, 3, 4]
		let alpha: Double = 0.25
		let actual: Double = try weightedBreakdownPoint(weights, trimming: alpha)
		#expect(actual.isEqual(to: alpha), "with trimming the breakdown point is the trimming level")
	}

	// MARK: - 2. PercentileLocation: sorted, then indexed, on a bare Comparable

	@Test("Control — nearest rank reads the right element of a shuffled clean array")
	func percentileLocationCleanOrdering() throws {
		// The input is shuffled and the expected order is written out, so an index that came
		// from an unsorted array would name a different element at almost every percentile.
		let values: [Double] = [3, 1, 2, 5, 4]
		let ascending: [Double] = [1, 2, 3, 4, 5]
		let n: Int = values.count
		for percentile in 1...99 {
			// Nearest-rank, 1-based: r = ceil(p/100 * n). Derived here rather than recalled.
			let position: Double = Double(percentile) / 100.0
			let rank: Int = Int(ceil(position * Double(n)))
			let expected: Double = ascending[rank - 1]
			let actual: Double = try PercentileLocation(percentile, values: values)
			#expect(actual.isEqual(to: expected), "percentile \(percentile) should take rank \(rank)")
		}
	}

	@Test("Control — the 0th and 100th percentiles are the extremes, not the array ends")
	func percentileLocationEndpointsAreExtremes() throws {
		let values: [Double] = [3, 1, 2, 5, 4]
		let smallest: Double = try #require(values.min())
		let largest: Double = try #require(values.max())
		let atZero: Double = try PercentileLocation(0, values: values)
		let atHundred: Double = try PercentileLocation(100, values: values)
		#expect(atZero.isEqual(to: smallest), "the 0th percentile is the minimum")
		#expect(atHundred.isEqual(to: largest), "the 100th percentile is the maximum")
	}

	@Test("Values that will not order are refused rather than indexed")
	func percentileLocationRefusesUnorderableValues() throws {
		// `[3, 1, nan, 2, 5, 4].sorted()` came back `[1, 3, nan, 2, 4, 5]` — the *valid*
		// elements out of place. At the 60th percentile nearest rank takes position 4 and
		// returned `2.0` as "the 60th percentile" of data whose 60th percentile is `4.0`:
		// finite, plausible, and from the wrong rank, with nothing to say so.
		let contaminated: [Double] = [3, 1, Double.nan, 2, 5, 4]
		let expected = BusinessMathError.dataQuality(
			message: "Percentile location requires values that sort into ascending order",
			context: ["count": "6"])
		#expect(throws: expected) {
			let _ = try PercentileLocation(60, values: contaminated)
		}
	}

	@Test("The detector fires whatever position the unorderable value takes")
	func percentileLocationRefusesAtEveryPosition() throws {
		// Position matters — a single placement can look fine, so every one is exercised.
		let clean: [Double] = [3, 1, 2, 5, 4]
		for position in 0...clean.count {
			var contaminated: [Double] = clean
			contaminated.insert(Double.nan, at: position)
			let expected = BusinessMathError.dataQuality(
				message: "Percentile location requires values that sort into ascending order",
				context: ["count": "6"])
			#expect(throws: expected, "a nan at index \(position) must be refused") {
				let _ = try PercentileLocation(50, values: contaminated)
			}
		}
	}

	@Test("The empty and out-of-range refusals are unchanged")
	func percentileLocationKeepsItsOtherRefusals() throws {
		// `ArrayError` is not `Equatable`, and it carries no payload — the case is the whole
		// content of the claim, so it is matched rather than compared.
		#expect {
			let _: Double = try PercentileLocation(50, values: [])
		} throws: { error in
			guard case ArrayError.emptyArray = error else { return false }
			return true
		}
		let expected = BusinessMathError.invalidInput(
			message: "Percentile must be between 0 and 100",
			value: "101",
			expectedRange: "0 to 100")
		#expect(throws: expected) {
			let _ = try PercentileLocation(101, values: [1.0, 2.0, 3.0])
		}
	}

	// MARK: - 3. summarisePosterior: an unspecified sort under the median and the interval

	@Test("Control — the posterior median and interval come from the right ranks")
	func posteriorSummaryReadsTheRightQuantiles() throws {
		// Two chains, deliberately interleaved so that the merged sample is in no order at
		// all. `ascending` is the order the summary must impose; if it did not, the median
		// and the interval bounds would be different elements of this same set.
		let chainA: [Double] = [0.5, 0.1, 0.9, 0.3]
		let chainB: [Double] = [0.7, 0.2, 0.8, 0.6]
		let ascending: [Double] = [0.1, 0.2, 0.3, 0.5, 0.6, 0.7, 0.8, 0.9]
		let sigma: [[Double]] = [[1.0, 1.0, 1.0, 1.0], [1.0, 1.0, 1.0, 1.0]]

		let result = try summarisePosterior(
			allChainSigmaS: sigma,
			allChainSigmaR: sigma,
			allChainSigmaE: sigma,
			allChainICC: [chainA, chainB])

		let count: Int = ascending.count
		let medianIndex: Int = count / 2
		let lowerIndex: Int = Int(0.025 * Double(count))
		let upperIndex: Int = Swift.min(count - 1, Int(0.975 * Double(count)))
		let expectedMedian: Double = ascending[medianIndex]
		let expectedLower: Double = ascending[lowerIndex]
		let expectedUpper: Double = ascending[upperIndex]

		#expect(result.iccMedian.isEqual(to: expectedMedian), "median is the draw at rank \(medianIndex)")
		#expect(result.iccCredibleInterval.lower.isEqual(to: expectedLower), "lower bound is rank \(lowerIndex)")
		#expect(result.iccCredibleInterval.upper.isEqual(to: expectedUpper), "upper bound is rank \(upperIndex)")
	}

	@Test("A draw that will not order is refused rather than sorted around")
	func posteriorSummaryRefusesUnorderableDraws() throws {
		// One unusable draw is enough: `sorted()` is unspecified when `<` is not a strict
		// weak ordering, so the *valid* draws move and the median and 2.5% / 97.5% indices
		// read whichever draws land there — a finite posterior with a tight interval built
		// from the wrong quantiles.
		let chainA: [Double] = [0.5, 0.1, Double.nan, 0.3]
		let chainB: [Double] = [0.7, 0.2, 0.8, 0.6]
		let sigma: [[Double]] = [[1.0, 1.0, 1.0, 1.0], [1.0, 1.0, 1.0, 1.0]]
		let expected = BusinessMathError.dataQuality(
			message: "Bayesian ICC posterior requires finite draws",
			context: ["invalid_count": "1"])
		#expect(throws: expected) {
			let _: BayesianICCResult<Double> = try summarisePosterior(
				allChainSigmaS: sigma,
				allChainSigmaR: sigma,
				allChainSigmaE: sigma,
				allChainICC: [chainA, chainB])
		}
	}

	@Test("The empty-posterior refusal is unchanged")
	func posteriorSummaryStillRefusesAnEmptySample() throws {
		let empty: [[Double]] = [[], []]
		let expected = BusinessMathError.calculationFailed(
			operation: "Bayesian ICC",
			reason: "No post-burn-in samples collected; increase iterations or reduce burn-in",
			suggestions: [])
		#expect(throws: expected) {
			let _: BayesianICCResult<Double> = try summarisePosterior(
				allChainSigmaS: empty,
				allChainSigmaR: empty,
				allChainSigmaE: empty,
				allChainICC: empty)
		}
	}

	@Test("Control — a seeded run on clean ratings still produces an ordered interval")
	func bayesianICCSeededControl() throws {
		let ratings: [[Double]] = [
			[9.0, 8.0, 9.0],
			[6.0, 5.0, 6.0],
			[8.0, 8.0, 7.0],
			[4.0, 5.0, 4.0],
			[7.0, 6.0, 7.0]
		]
		let config = GibbsConfig<Double>(iterations: 400, burnIn: 200, thinning: 1, chains: 2, seed: 20260929)
		let result = try bayesianICC(ratings, model: .twoWayRandom, config: config)

		let lower: Double = result.iccCredibleInterval.lower
		let upper: Double = result.iccCredibleInterval.upper
		let median: Double = result.iccMedian
		#expect(lower <= median, "the median cannot sit below the lower credible bound")
		#expect(median <= upper, "the median cannot sit above the upper credible bound")
		// Bound outside the macro: `allSatisfy` is `rethrows`, which `#expect` cannot prove.
		let unusableDraws: Int = result.iccSamples.filter { !$0.isFinite }.count
		#expect(unusableDraws == 0, "a clean seeded run produces only usable draws")
	}

	// MARK: - 4. LogisticRegression.separatesByThreshold — recorded unreachable

	@Test("An unreadable predictor column is refused before any separation test runs")
	func logisticRegressionScreensTheDesignBeforeDetectingSeparation() throws {
		// `separatesByThreshold` compares with `min()` / `max()`, and every comparison against
		// a `nan` is false, so an all-`nan` column would return `false` — "no separation
		// found", the answer that lets a divergent fit proceed. It never gets the chance:
		// `fit` calls `validatedDesign()` before `refuseSeparation()`, and that rejects a
		// non-finite predictor outright. This test is what keeps the ordering honest.
		let predictors: [[Double]] = [
			[Double.nan], [Double.nan], [Double.nan], [Double.nan],
			[Double.nan], [Double.nan], [Double.nan], [Double.nan]
		]
		let outcomes: [Bool] = [true, false, true, false, true, false, true, false]
		let model = LogisticRegression<Double>(predictors: predictors, outcomes: outcomes)
		#expect(throws: LogisticRegressionError.malformedInput(reason: "a predictor is not finite")) {
			let _ = try model.fit()
		}
	}

	@Test("Control — a clean separating column is still named as separation")
	func logisticRegressionStillDetectsSeparation() throws {
		let predictors: [[Double]] = [
			[1.0], [2.0], [3.0], [4.0], [5.0], [6.0], [7.0], [8.0]
		]
		let outcomes: [Bool] = [false, false, false, false, true, true, true, true]
		let model = LogisticRegression<Double>(predictors: predictors, outcomes: outcomes)
		#expect(throws: LogisticRegressionError.separation(variables: [0])) {
			let _ = try model.fit()
		}
	}
}
