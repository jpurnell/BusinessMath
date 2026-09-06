//
//  LinearAlgebraReferenceTests.swift
//  BusinessMath
//
//  An external oracle for the Cholesky factorisation and the solves built on it.
//
//  `DenseMatrixCholeskyTests` has 15 tests and checked none of them against anything
//  outside the package. That matters more here than almost anywhere else: the mixed
//  models solve through this factorisation, and so do the regression and optimisation
//  paths. A defect would show up as small wrongness in several unrelated places and be
//  attributed to whichever of them was being looked at — which is close to what happened
//  with the REML projection bug, where the fault sat two layers below the symptom.
//
//  It is also the easiest thing in the package to check properly. LAPACK's `potrf` is
//  about as settled a reference as numerical software has, and unlike a distribution or
//  an estimator there is no parameterisation to get wrong: for a positive definite matrix
//  the factorisation is unique once the triangle is fixed.
//
//  Values from Tests/BusinessMathTests/Fixtures/linearAlgebra.json, generated once by
//  Scripts/reference-fixtures/generate_linear_algebra.py against scipy 1.18.1.
//
//  ## Tolerances scale with the condition number
//
//  A solve loses roughly as many digits as the condition number has, so one bound across
//  matrices spanning 1 to 1e11 would be either meaningless at one end or unachievable at
//  the other. Each assertion below scales its tolerance by the recorded condition number,
//  which is the honest way to say "as accurate as the problem allows".
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Dense linear algebra against LAPACK")
struct LinearAlgebraReferenceTests {

	// MARK: - Fixture

	private struct Fixture: Decodable {
		let name: String
		let reference: String
		let note: String
		let cases: [Case]
	}

	private struct Case: Decodable {
		let name: String
		let note: String
		let A: [[Double]]
		let L: [[Double]]
		let inverse: [[Double]]
		let b: [Double]
		let x: [Double]
		let B: [[Double]]
		let X: [[Double]]
		let conditionNumber: Double
		let determinant: Double
		let logDeterminant: Double

		/// Machine epsilon amplified by the conditioning of this particular matrix, with
		/// a generous constant. This is the accuracy the problem permits; asserting
		/// tighter would be asserting something untrue of correct arithmetic.
		var tolerance: Double { Swift.max(1e-12, 1e-11 * conditionNumber) }
	}

	private static func loadFixture() throws -> Fixture {
		guard let url = Bundle.module.url(forResource: "linearAlgebra",
										  withExtension: "json",
										  subdirectory: "Fixtures")
			?? Bundle.module.url(forResource: "linearAlgebra", withExtension: "json") else {
			struct Missing: Error { let name: String }
			throw Missing(name: "linearAlgebra")
		}
		return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
	}

	// MARK: - The fixture itself

	@Test("The fixture is present and spans a range of conditioning")
	func fixtureIsWellFormed() throws {
		let fixture = try Self.loadFixture()
		#expect(fixture.reference.contains("scipy"), "reference was '\(fixture.reference)'")
		#expect(fixture.cases.count >= 7, "only \(fixture.cases.count) matrices")

		// A fixture of nothing but well-conditioned problems would prove very little, so
		// the spread is asserted rather than assumed.
		let worst = fixture.cases.map(\.conditionNumber).max() ?? 0
		let best = fixture.cases.map(\.conditionNumber).min() ?? 0
		#expect(worst > 1e7, "worst conditioning is only \(worst)")
		#expect(best < 10, "best conditioning is only \(best)")

		for entry in fixture.cases {
			let n = entry.A.count
			#expect(entry.L.count == n && entry.inverse.count == n)
			#expect(entry.b.count == n && entry.x.count == n)
		}
	}

	// MARK: - The factorisation

	@Test("The Cholesky factor matches LAPACK")
	func choleskyMatchesLAPACK() throws {
		let fixture = try Self.loadFixture()
		var compared = 0

		for entry in fixture.cases {
			let a = try DenseMatrix(entry.A)
			let l = try a.cholesky()
			let n = entry.A.count

			#expect(l.rows == n && l.columns == n,
					"\(entry.name): L is \(l.rows)×\(l.columns), expected \(n)×\(n)")
			guard l.rows == n, l.columns == n else { continue }

			for i in 0..<n {
				for j in 0..<n {
					// Above the diagonal L must be exactly zero — a lower factor that
					// leaked into the upper triangle would still reproduce A and pass
					// every reconstruction test.
					if j > i {
						#expect(l[i, j].isEqual(to: 0.0),
								"\(entry.name): L[\(i),\(j)] = \(l[i, j]) above the diagonal")
					} else {
						#expect(abs(l[i, j] - entry.L[i][j]) < entry.tolerance,
								"\(entry.name) L[\(i),\(j)]: got \(l[i, j]), LAPACK \(entry.L[i][j])")
					}
					compared += 1
				}
			}
		}
		#expect(compared >= 100, "only \(compared) entries compared")
	}

	@Test("L times L transposed reconstructs the original")
	func factorReconstructs() throws {
		// The defining identity, and independent of LAPACK: it would catch a factor that
		// agreed with the fixture through some shared misunderstanding of the input.
		let fixture = try Self.loadFixture()

		for entry in fixture.cases {
			let a = try DenseMatrix(entry.A)
			let l = try a.cholesky()
			let reconstructed = try l.multiplied(by: l.transposed())
			let n = entry.A.count

			for i in 0..<n {
				for j in 0..<n {
					let scale = Swift.max(abs(entry.A[i][j]), 1.0)
					#expect(abs(reconstructed[i, j] - entry.A[i][j]) < entry.tolerance * scale,
							"\(entry.name): (LLᵀ)[\(i),\(j)] = \(reconstructed[i, j]), A = \(entry.A[i][j])")
				}
			}
		}
	}

	// MARK: - Solving

	@Test("choleskySolve matches LAPACK for a vector right-hand side")
	func solveVectorMatchesLAPACK() throws {
		let fixture = try Self.loadFixture()
		var compared = 0

		for entry in fixture.cases {
			let a = try DenseMatrix(entry.A)
			let solution = try a.choleskySolve(entry.b)
			#expect(solution.count == entry.x.count)
			guard solution.count == entry.x.count else { continue }

			for i in 0..<solution.count {
				let scale = Swift.max(abs(entry.x[i]), 1.0)
				#expect(abs(solution[i] - entry.x[i]) < entry.tolerance * scale,
						"\(entry.name) x[\(i)]: got \(solution[i]), LAPACK \(entry.x[i]), cond \(entry.conditionNumber)")
				compared += 1
			}
		}
		#expect(compared >= 25, "only \(compared) solution entries compared")
	}

	@Test("choleskySolve matches LAPACK for a matrix right-hand side")
	func solveMatrixMatchesLAPACK() throws {
		// The overload exists separately and could diverge from the vector one.
		let fixture = try Self.loadFixture()
		var compared = 0

		for entry in fixture.cases {
			let a = try DenseMatrix(entry.A)
			let rhs = try DenseMatrix(entry.B)
			let solution = try a.choleskySolve(rhs)
			let n = entry.A.count

			#expect(solution.rows == n && solution.columns == 2,
					"\(entry.name): solution is \(solution.rows)×\(solution.columns)")
			guard solution.rows == n, solution.columns == 2 else { continue }

			for i in 0..<n {
				for j in 0..<2 {
					let scale = Swift.max(abs(entry.X[i][j]), 1.0)
					#expect(abs(solution[i, j] - entry.X[i][j]) < entry.tolerance * scale,
							"\(entry.name) X[\(i),\(j)]: got \(solution[i, j]), LAPACK \(entry.X[i][j])")
					compared += 1
				}
			}
		}
		#expect(compared >= 50, "only \(compared) entries compared")
	}

	@Test("choleskyInverse matches LAPACK")
	func inverseMatchesLAPACK() throws {
		let fixture = try Self.loadFixture()
		var compared = 0

		for entry in fixture.cases {
			let a = try DenseMatrix(entry.A)
			let inverse = try a.choleskyInverse()
			let n = entry.A.count

			for i in 0..<n {
				for j in 0..<n {
					let scale = Swift.max(abs(entry.inverse[i][j]), 1.0)
					#expect(abs(inverse[i, j] - entry.inverse[i][j]) < entry.tolerance * scale,
							"\(entry.name) inv[\(i),\(j)]: got \(inverse[i, j]), LAPACK \(entry.inverse[i][j])")
					compared += 1
				}
			}
		}
		#expect(compared >= 100, "only \(compared) entries compared")
	}

	@Test("The inverse times the original is the identity")
	func inverseIsAnInverse() throws {
		// Again independent of the reference. A matrix that matched LAPACK's inverse but
		// failed this would mean the fixture and the code shared a wrong input.
		let fixture = try Self.loadFixture()

		for entry in fixture.cases {
			let a = try DenseMatrix(entry.A)
			let product = try a.multiplied(by: try a.choleskyInverse())
			let n = entry.A.count

			for i in 0..<n {
				for j in 0..<n {
					let expected: Double = i == j ? 1.0 : 0.0
					#expect(abs(product[i, j] - expected) < entry.tolerance,
							"\(entry.name): (A·A⁻¹)[\(i),\(j)] = \(product[i, j]), expected \(expected)")
				}
			}
		}
	}

	// MARK: - Rejecting what is not factorisable

	@Test("Cholesky refuses a matrix that is not positive definite")
	func rejectsIndefinite() throws {
		// Not in the fixture because there is no factor to record — but the refusal is
		// as much a part of the contract as the factor, and a routine that returned NaNs
		// here would poison everything downstream silently.
		let indefinite = try DenseMatrix([[1.0, 2.0], [2.0, 1.0]])   // eigenvalues 3, -1
		#expect(throws: (any Error).self) { _ = try indefinite.cholesky() }

		let singular = try DenseMatrix([[1.0, 1.0], [1.0, 1.0]])     // rank 1
		#expect(throws: (any Error).self) { _ = try singular.cholesky() }

		let negative = try DenseMatrix([[-4.0]])
		#expect(throws: (any Error).self) { _ = try negative.cholesky() }
	}
}
