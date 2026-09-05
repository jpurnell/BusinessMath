//
//  QuasiRandomSamplingTests.swift
//  BusinessMathTests
//
//  Latin hypercube, Sobol, Halton, the alias table, and the MonteCarloSimulation
//  branch that consumes them.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Quasi-random sampling")
struct QuasiRandomSamplingTests {

	/// Our Sobol coordinates sit half a cell above SciPy's, deliberately: a coordinate
	/// of exactly zero inverse-transforms to −infinity. A `UInt32` fraction has cells
	/// of 2⁻³², so half a cell is 2⁻³³.
	static let sobolHalfCellOffset = 0x1p-33

	// MARK: - Every point set's shared contract

	@Test("Coordinates are strictly inside the unit interval")
	func coordinatesAreOpen() throws {
		let sets: [(String, any QuasiRandomPointSet)] = [
			("LatinHypercube", LatinHypercubeSampler(dimension: 5, seed: 11)),
			("Sobol", try SobolSequence(dimension: 5)),
			("Sobol/scrambled", try SobolSequence(dimension: 5, scrambleSeed: 11)),
			("Halton", try HaltonSequence(dimension: 5)),
			("Halton/scrambled", try HaltonSequence(dimension: 5, scrambleSeed: 11))
		]
		for (name, set) in sets {
			let points = set.points(count: 512)
			#expect(points.count == 512, "\(name) returned \(points.count) points")
			for point in points {
				#expect(point.count == 5, "\(name) point has \(point.count) coordinates")
				for value in point {
					#expect(value > 0 && value < 1,
						"\(name) produced \(value), which a quantile turns into an infinity")
				}
			}
		}
	}

	// MARK: - Latin hypercube

	@Test("Every stratum of every dimension is used exactly once")
	func latinHypercubeStratifies() {
		let count = 200
		let sampler = LatinHypercubeSampler(dimension: 4, seed: 20_260_904)
		let points = sampler.points(count: count)

		for axis in 0..<4 {
			var occupied = [Int](repeating: 0, count: count)
			for point in points {
				let stratum = Swift.min(count - 1, Int(point[axis] * Double(count)))
				occupied[stratum] += 1
			}
			#expect(occupied.allSatisfy { $0 == 1 },
				"dimension \(axis) does not use each stratum once: \(occupied.filter { $0 != 1 }.count) wrong")
		}
	}

	@Test("A Latin hypercube design is reproducible from its seed, and varies with it")
	func latinHypercubeIsSeeded() {
		let first = LatinHypercubeSampler(dimension: 3, seed: 7).points(count: 64)
		let same = LatinHypercubeSampler(dimension: 3, seed: 7).points(count: 64)
		let other = LatinHypercubeSampler(dimension: 3, seed: 8).points(count: 64)
		#expect(first == same)
		#expect(first != other, "two seeds produced the identical design")
	}

	// MARK: - Sobol

	@Test("Sobol matches scipy.stats.qmc.Sobol, up to the documented half-cell offset")
	func sobolMatchesReference() throws {
		let fixture = try ReferenceFixture.load("sobolPoints")
		#expect(!fixture.cases.isEmpty)

		var cache: [Int: [[Double]]] = [:]
		for testCase in fixture.cases {
			let dimension = Int(try testCase.required("dimension", in: fixture.name))
			let index = Int(try testCase.required("index", in: fixture.name))
			let axis = Int(try testCase.required("axis", in: fixture.name))
			let expected = try testCase.required("value", in: fixture.name)

			let points: [[Double]]
			if let cached = cache[dimension] {
				points = cached
			} else {
				points = try SobolSequence(dimension: dimension).points(count: 64)
				cache[dimension] = points
			}

			// Asserted as an exact offset rather than a loose tolerance: the two
			// implementations share a direction-number table, so they agree bit for bit
			// apart from the half cell we add on purpose. A tolerance would hide a real
			// divergence of the same size.
			let difference = points[index][axis] - expected
			#expect(abs(difference - Self.sobolHalfCellOffset) < 0x1p-40,
				"d=\(dimension) point \(index) axis \(axis): ours \(points[index][axis]), scipy \(expected), difference \(difference)")
		}
	}

	@Test("Sobol is balanced: every dyadic interval holds exactly one point")
	func sobolIsBalanced() throws {
		// The defining property of a (t, m, s)-net in base 2. Any sequence can look
		// well-spread on a plot; this is the statement that distinguishes one.
		let count = 1_024
		let points = try SobolSequence(dimension: 3).points(count: count)
		for axis in 0..<3 {
			var occupied = [Int](repeating: 0, count: count)
			for point in points {
				occupied[Swift.min(count - 1, Int(point[axis] * Double(count)))] += 1
			}
			#expect(occupied.allSatisfy { $0 == 1 },
				"dimension \(axis) is not balanced over 1024 dyadic intervals")
		}
	}

	@Test("Sobol refuses a dimension its table does not cover")
	func sobolRefusesUnvendoredDimensions() {
		#expect(throws: (any Error).self) {
			_ = try SobolSequence(dimension: SobolSequence.maximumDimension + 1)
		}
		#expect(throws: (any Error).self) {
			_ = try SobolSequence(dimension: 0)
		}
		#expect(SobolSequence.maximumDimension == 256)
	}

	@Test("Owen scrambling preserves uniformity while changing the sequence")
	func owenScramblingIsUniformAndDifferent() throws {
		let plain = try SobolSequence(dimension: 2).points(count: 4_096)
		let scrambled = try SobolSequence(dimension: 2, scrambleSeed: 99).points(count: 4_096)

		#expect(plain != scrambled, "scrambling left the sequence unchanged")

		// A scrambled Sobol sequence is still a Sobol sequence: the balance property
		// survives, which is precisely what distinguishes Owen's scramble from simply
		// shuffling the points.
		for axis in 0..<2 {
			var occupied = [Int](repeating: 0, count: 4_096)
			for point in scrambled {
				occupied[Swift.min(4_095, Int(point[axis] * 4_096))] += 1
			}
			#expect(occupied.allSatisfy { $0 == 1 },
				"scrambled dimension \(axis) lost its balance")
		}
	}

	@Test("Bit reversal is its own inverse")
	func bitReversalRoundTrips() {
		for value in [UInt32.zero, 1, 2, 0xdead_beef, 0x8000_0000, UInt32.max] {
			#expect(value.reversedBitOrder.reversedBitOrder == value)
		}
		#expect(UInt32(1).reversedBitOrder == 0x8000_0000)
	}

	// MARK: - Halton

	@Test("Halton matches scipy.stats.qmc.Halton")
	func haltonMatchesReference() throws {
		let fixture = try ReferenceFixture.load("haltonPoints")
		#expect(!fixture.cases.isEmpty)

		var cache: [Int: [[Double]]] = [:]
		for testCase in fixture.cases {
			let dimension = Int(try testCase.required("dimension", in: fixture.name))
			let index = Int(try testCase.required("index", in: fixture.name))
			let axis = Int(try testCase.required("axis", in: fixture.name))
			let expected = try testCase.required("value", in: fixture.name)

			let points: [[Double]]
			if let cached = cache[dimension] {
				points = cached
			} else {
				points = try HaltonSequence(dimension: dimension).points(count: 32)
				cache[dimension] = points
			}
			#expect(abs(points[index][axis] - expected) < 1e-12,
				"d=\(dimension) point \(index) axis \(axis): ours \(points[index][axis]), scipy \(expected)")
		}
	}

	@Test("Halton's first dimension is the van der Corput sequence")
	func haltonFirstDimensionIsVanDerCorput() throws {
		// Derived by hand from the definition, so this checks the fixture too.
		let expected = [0.5, 0.25, 0.75, 0.125, 0.625, 0.375, 0.875, 0.0625]
		let points = try HaltonSequence(dimension: 1).points(count: expected.count)
		for (index, value) in expected.enumerated() {
			#expect(abs(points[index][0] - value) < 1e-15,
				"point \(index) is \(points[index][0]), should be \(value)")
		}
	}

	@Test("Unscrambled Halton correlates in high dimensions; scrambling fixes it")
	func haltonHighDimensionCorrelation() throws {
		// Recorded, not asserted away. This is the sequence's known weakness and the
		// reason Sobol is preferred beyond a few dimensions; a suite that quietly
		// avoided it would leave the limitation as folklore.
		let count = 256
		let plain = try HaltonSequence(dimension: 32).points(count: count)
		let scrambled = try HaltonSequence(dimension: 32, scrambleSeed: 5).points(count: count)

		func correlation(_ points: [[Double]], _ a: Int, _ b: Int) -> Double {
			let xs = points.map { $0[a] }, ys = points.map { $0[b] }
			let mx = xs.reduce(0, +) / Double(count), my = ys.reduce(0, +) / Double(count)
			var sxy = 0.0, sxx = 0.0, syy = 0.0
			for (x, y) in zip(xs, ys) {
				sxy += (x - mx) * (y - my); sxx += (x - mx) * (x - mx); syy += (y - my) * (y - my)
			}
			let denominator = (sxx * syy).squareRoot()
			return denominator > 0 ? sxy / denominator : 0
		}

		let plainCorrelation = abs(correlation(plain, 30, 31))
		let scrambledCorrelation = abs(correlation(scrambled, 30, 31))

		#expect(plainCorrelation > 0.5,
			"dimensions 30 and 31 of plain Halton correlate at \(plainCorrelation); if this has fallen, the documented weakness has changed and the docs should say so")
		#expect(scrambledCorrelation < plainCorrelation,
			"scrambling did not reduce the correlation: \(scrambledCorrelation) against \(plainCorrelation)")
	}

	// MARK: - Alias table

	@Test("The alias table reproduces its weights")
	func aliasTableFollowsItsWeights() throws {
		let weights = [0.1, 0.45, 0.05, 0.3, 0.1]
		let table = try #require(AliasTable(weights: weights))
		#expect(table.outcomeCount == weights.count)

		var generator = Xoshiro256StarStar(seed: 31)
		let draws = 200_000
		var counts = [Int](repeating: 0, count: weights.count)
		for _ in 0..<draws { counts[table.next(using: &generator)] += 1 }

		for (index, weight) in weights.enumerated() {
			let observed = Double(counts[index]) / Double(draws)
			// Four standard errors on a binomial cell.
			let standardError = (weight * (1 - weight) / Double(draws)).squareRoot()
			#expect(abs(observed - weight) < 4 * standardError,
				"outcome \(index): observed \(observed), weight \(weight)")
		}
	}

	@Test("The alias table normalises, and rejects what it cannot represent")
	func aliasTableValidates() throws {
		// Weights need not sum to one; the table normalises them. Asserted by what the
		// table then does, not by its mere existence.
		let unnormalised = try #require(AliasTable(weights: [2, 2, 4]))
		#expect(unnormalised.outcomeCount == 3)
		var generator = Xoshiro256StarStar(seed: 3)
		var counts = [0, 0, 0]
		for _ in 0..<40_000 { counts[unnormalised.next(using: &generator)] += 1 }
		let lastShare = Double(counts[2]) / 40_000
		#expect(abs(lastShare - 0.5) < 0.01,
			"weight 4 of 8 should be drawn half the time, was \(lastShare)")
		#expect(AliasTable(weights: []) == nil)
		#expect(AliasTable(weights: [0, 0]) == nil)
		#expect(AliasTable(weights: [1, -1]) == nil)
		#expect(AliasTable(weights: [1, Double.nan]) == nil)
	}

	// MARK: - The simulation branch

	@Test("A quasi-random run is reproducible and stays on the CPU")
	func simulationHonoursTheSamplingMethod() throws {
		var simulation = MonteCarloSimulation(iterations: 1_024, enableGPU: true, seed: 4) { $0[0] + $0[1] }
		simulation.addInput(SimulationInput(name: "a", distribution: DistributionNormal(10, 2)))
		simulation.addInput(SimulationInput(name: "b", distribution: DistributionUniform(0, 5)))
		simulation.samplingMethod = .sobol(scrambled: false)

		let first = try simulation.run()
		let second = try simulation.run()
		#expect(first.values == second.values)
		#expect(first.usedGPU == false)
		#expect(first.executionNotes.contains { $0.contains("quasi-random") },
			"the run should say why it did not use the GPU: \(first.executionNotes)")
	}

	@Test("A quasi-random run refuses an input with no quantile, naming it")
	func simulationRefusesInputsWithoutAQuantile() {
		var simulation = MonteCarloSimulation(iterations: 64, enableGPU: false, seed: 4) { $0[0] }
		// A bare closure has no quantile to evaluate at a chosen point.
		simulation.addInput(SimulationInput(name: "opaque", sampler: { 1.0 }))
		simulation.samplingMethod = .latinHypercube

		#expect(throws: (any Error).self) { _ = try simulation.run() }
		do {
			_ = try simulation.run()
			Issue.record("the run should have refused")
		} catch let error as SimulationError {
			guard case .quasiRandomUnsupported(let name, _) = error else {
				Issue.record("wrong error: \(error)")
				return
			}
			#expect(name == "opaque", "the error should name the offending input")
		} catch {
			Issue.record("wrong error type: \(error)")
		}
	}

	@Test("Latin hypercube refuses to run without a seed")
	func latinHypercubeRequiresASeed() {
		// Justification: the missing seed is the subject of this test, not an oversight.
		var simulation = MonteCarloSimulation(iterations: 64, enableGPU: false) { $0[0] }
		simulation.addInput(SimulationInput(name: "a", distribution: DistributionNormal(0, 1)))
		simulation.samplingMethod = .latinHypercube
		#expect(throws: (any Error).self) { _ = try simulation.run() }
		#expect(SamplingMethod.latinHypercube.requiresSeed)
		#expect(SamplingMethod.pseudoRandom.requiresSeed == false)
		#expect(SamplingMethod.sobol(scrambled: false).requiresSeed == false)
		#expect(SamplingMethod.sobol(scrambled: true).requiresSeed)
	}

	@Test("Stratified sampling beats pseudo-random on the same iteration count")
	func quasiRandomConvergesFaster() throws {
		// The point of the whole feature, measured rather than asserted in prose.
		// Estimating E[X] for a standard normal: the true answer is 0, so the error is
		// just the estimate. Averaged over several seeds so one lucky draw cannot
		// decide it.
		func meanAbsoluteError(_ method: SamplingMethod, seeds: ClosedRange<UInt64>) throws -> Double {
			var total = 0.0
			for seed in seeds {
				var simulation = MonteCarloSimulation(iterations: 512, enableGPU: false, seed: seed) { $0[0] }
				simulation.addInput(SimulationInput(name: "z", distribution: DistributionNormal(0, 1)))
				simulation.samplingMethod = method
				total += abs(try simulation.run().statistics.mean)
			}
			return total / Double(seeds.count)
		}

		let pseudoRandom = try meanAbsoluteError(.pseudoRandom, seeds: 1...12)
		let latinHypercube = try meanAbsoluteError(.latinHypercube, seeds: 1...12)

		#expect(latinHypercube < pseudoRandom,
			"Latin hypercube averaged \(latinHypercube) against pseudo-random's \(pseudoRandom); stratification should reduce the error, not merely change it")
	}
}
