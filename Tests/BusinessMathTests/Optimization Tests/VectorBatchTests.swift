//
//  VectorBatchTests.swift
//  BusinessMath
//
//  Rebuilding a batch of vectors from a flat buffer, and the truncation it must refuse.
//
//  The GPU paths in `DifferentialEvolution` and `ParticleSwarmOptimization` read a flat
//  row-major buffer back into `[V]` in a loop. Both did it like this:
//
//      if let vec = V.fromArray(components) { population.append(vec) }
//
//  A conversion that fails appends nothing, so the array comes back **shorter than the
//  population** — and the caller then writes `newPopulation[i] = trialPopulation[i]` across
//  `0..<popSize`. That is an out-of-range crash rather than a wrong answer, and it is silent
//  right up until it is fatal.
//
//  It is unreachable through the public API today, because both optimizers gate the GPU on
//  `VectorN<Double>` and `VectorN.fromArray` accepts any length. It is reachable the moment
//  either gate changes, and `Vector1D`, `Vector2D`, `Vector3D`, `Double` and `Float` all
//  return `nil` on a length mismatch — so the failure is one conformance away, not
//  hypothetical.
//
//  The rule: a batch conversion returns `nil` for the whole batch or every element of it.
//  Never a prefix.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Vector batch conversion")
struct VectorBatchTests {

	@Test("A full buffer becomes every vector in it")
	func fullBufferConverts() throws {
		let flat: [Double] = [1, 2, 3, 4, 5, 6]
		let vectors = try #require(Vector2D<Double>.vectors(fromFlat: flat, count: 3, dimension: 2))
		#expect(vectors.count == 3)
		#expect(vectors[0] == Vector2D<Double>(x: 1, y: 2))
		#expect(vectors[1] == Vector2D<Double>(x: 3, y: 4))
		#expect(vectors[2] == Vector2D<Double>(x: 5, y: 6))
	}

	@Test("A dimension the type cannot take is refused, not truncated")
	func wrongDimensionIsRefused() {
		// Vector2D.fromArray returns nil for anything but two scalars. Three per vector
		// means every element fails, and the answer is nil rather than an empty array —
		// an empty array reads as "nothing to do" and would be indexed anyway.
		let flat: [Double] = [1, 2, 3, 4, 5, 6]
		#expect(Vector2D<Double>.vectors(fromFlat: flat, count: 2, dimension: 3) == nil)
	}

	@Test("A buffer too short for the count it claims is refused")
	func shortBufferIsRefused() {
		let flat: [Double] = [1, 2, 3, 4, 5]
		#expect(Vector2D<Double>.vectors(fromFlat: flat, count: 3, dimension: 2) == nil)
		#expect(Vector2D<Double>.vectors(fromFlat: [], count: 1, dimension: 2) == nil)
	}

	@Test("Degenerate counts are refused rather than answered with an empty batch")
	func degenerateCountsAreRefused() {
		let flat: [Double] = [1, 2]
		#expect(Vector2D<Double>.vectors(fromFlat: flat, count: 0, dimension: 2) == nil)
		#expect(Vector2D<Double>.vectors(fromFlat: flat, count: 1, dimension: 0) == nil)
		#expect(Vector2D<Double>.vectors(fromFlat: flat, count: -1, dimension: 2) == nil)
	}

	@Test("The type the optimizers actually use round-trips at population scale")
	func vectorNConvertsAtScale() throws {
		// VectorN accepts any length, which is why the defect never fired in production.
		let dimension = 4
		let count = 250
		var flat: [Double] = []
		for index in 0..<(count * dimension) { flat.append(Double(index)) }
		let vectors = try #require(VectorN<Double>.vectors(fromFlat: flat,
														   count: count,
														   dimension: dimension))
		#expect(vectors.count == count, "no element may be dropped")
		let first = vectors[0].toArray()
		#expect(first == [0, 1, 2, 3])
		let last = vectors[count - 1].toArray()
		#expect(last == [996, 997, 998, 999])
	}

	@Test("Every element is present, which is the invariant the callers rely on")
	func batchIsAllOrNothing() throws {
		// The callers index the result by `0..<count`. A prefix would crash there, so the
		// only two acceptable answers are a full batch or nil.
		for count in 1...20 {
			let flat: [Double] = (0..<(count * 2)).map { Double($0) }
			let vectors = try #require(Vector2D<Double>.vectors(fromFlat: flat,
																count: count,
																dimension: 2))
			#expect(vectors.count == count, "count \(count) gave \(vectors.count)")
		}
	}
}
