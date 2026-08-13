//
//  ExpressionArrayTests.swift
//  BusinessMath
//
//  `ExpressionArray` is public API with, until now, no tests at all. That is how it came to
//  ship a `stdDev()` dividing by `count` — the population form, under the name this library
//  gives the sample form — for long enough that nobody noticed the two disagreed by 11.8%.
//  The `unreachable` checker found it by asking a question no test was asking: does anything
//  call this?
//
//  These evaluate each operation through `MonteCarloExpressionModel`, so the assertion is on
//  the number the compiled bytecode produces rather than on the shape of the expression tree.
//  An expression that builds correctly and evaluates wrongly is the failure mode that matters.
//

import Testing
import TestSupport
import Foundation
@testable import BusinessMath

@Suite("Expression Array Tests")
struct ExpressionArrayTests {

	/// Evaluates a one-expression model over `inputs`.
	private static func evaluate(
		_ inputs: [Double],
		_ build: @escaping (ExpressionBuilder) -> ExpressionProxy
	) throws -> Double {
		let model = try MonteCarloExpressionModel(build)
		return try model.evaluate(inputs: inputs)
	}

	// MARK: - Reductions

	@Test("sum adds every element")
	func sum() throws {
		let result = try Self.evaluate([1, 2, 3]) { $0.array([0, 1, 2]).sum() }
		#expect(identical(result, 6.0))
	}

	@Test("product multiplies every element")
	func product() throws {
		let result = try Self.evaluate([2, 3, 4]) { $0.array([0, 1, 2]).product() }
		#expect(identical(result, 24.0))
	}

	@Test("min and max select the extremes")
	func minAndMax() throws {
		let smallest = try Self.evaluate([5, 2, 9]) { $0.array([0, 1, 2]).min() }
		let largest = try Self.evaluate([5, 2, 9]) { $0.array([0, 1, 2]).max() }

		#expect(identical(smallest, 2.0))
		#expect(identical(largest, 9.0))
	}

	/// Cross-checked against the canonical `mean(_:)` rather than a hand-written expectation,
	/// so the DSL cannot drift from the library's own definition the way `stdDev()` did.
	@Test("mean agrees with the canonical mean")
	func meanMatchesCanonical() throws {
		let values: [Double] = [4, 7, 10, 13]
		let fromDSL = try Self.evaluate(values) { $0.array([0, 1, 2, 3]).mean() }

		#expect(abs(fromDSL - mean(values)) < 1e-12, "DSL mean \(fromDSL) != canonical \(mean(values))")
	}

	// MARK: - Element-wise

	@Test("map transforms every element")
	func map() throws {
		let result = try Self.evaluate([1, 2, 3]) { builder in
			builder.array([0, 1, 2]).map { $0 * $0 }.sum()
		}
		#expect(identical(result, 14.0), "1 + 4 + 9")
	}

	@Test("zipWith combines two arrays position by position")
	func zipWith() throws {
		let result = try Self.evaluate([1, 2, 3]) { builder in
			let inputs = builder.array([0, 1, 2])
			let factors = builder.array([10.0, 100.0, 1000.0])
			return inputs.zipWith(factors) { $0 * $1 }.sum()
		}
		#expect(identical(result, 3210.0), "10 + 200 + 3000")
	}

	// MARK: - Linear algebra

	@Test("dot is the sum of pairwise products")
	func dot() throws {
		let result = try Self.evaluate([1, 2, 3]) { builder in
			builder.array([0, 1, 2]).dot(builder.array([2.0, 3.0, 4.0]))
		}
		#expect(identical(result, 20.0), "2 + 6 + 12")
	}

	@Test("norm is the Euclidean length")
	func norm() throws {
		let result = try Self.evaluate([3, 4]) { $0.array([0, 1]).norm() }
		#expect(abs(result - 5.0) < 1e-12, "3-4-5 triangle, got \(result)")
	}

	/// `normalize` divides by the sum, so the elements sum to one — which is what makes it
	/// useful for portfolio weights, and the property worth pinning.
	@Test("normalize produces elements summing to one")
	func normalize() throws {
		let result = try Self.evaluate([2, 3, 5]) { $0.array([0, 1, 2]).normalize().sum() }
		#expect(abs(result - 1.0) < 1e-12, "normalized weights should sum to 1, got \(result)")
	}

	// MARK: - Constants

	@Test("a constant array carries its values")
	func constantArray() throws {
		let result = try Self.evaluate([0]) { $0.array([1.5, 2.5, 3.0]).sum() }
		#expect(identical(result, 7.0))
	}

	// MARK: - Degenerate shapes

	/// `sum` and `product` return their identity elements for an empty array rather than
	/// trapping, so a reduction over a filtered-to-nothing array stays composable.
	@Test("empty reductions return identities")
	func emptyReductions() throws {
		let emptySum = try Self.evaluate([0]) { $0.array([Int]()).sum() }
		let emptyProduct = try Self.evaluate([0]) { $0.array([Int]()).product() }

		#expect(identical(emptySum, 0.0))
		#expect(identical(emptyProduct, 1.0))
	}
}
