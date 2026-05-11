import Testing
@testable import BusinessMath

@Suite("DenseMatrix Cholesky Decomposition")
struct DenseMatrixCholeskyTests {

	@Test("Cholesky of 2x2 SPD matrix is correct")
	func cholesky2x2() throws {
		let A = try DenseMatrix([[4.0, 2.0], [2.0, 3.0]])
		let L = try A.cholesky()

		// L should be lower triangular
		#expect(abs(L[0, 1]) < 1e-10)

		// L[0,0] = sqrt(4) = 2
		#expect(abs(L[0, 0] - 2.0) < 1e-10)
		// L[1,0] = 2/2 = 1
		#expect(abs(L[1, 0] - 1.0) < 1e-10)
		// L[1,1] = sqrt(3 - 1) = sqrt(2)
		#expect(abs(L[1, 1] - Double.sqrt(2.0)) < 1e-10)
	}

	@Test("Cholesky of 3x3 SPD matrix satisfies A = LL'")
	func cholesky3x3Reconstruction() throws {
		let A = try DenseMatrix([
			[25.0, 15.0, -5.0],
			[15.0, 18.0,  0.0],
			[-5.0,  0.0, 11.0]
		])
		let L = try A.cholesky()
		let LLt = try L.multiplied(by: L.transposed())

		for i in 0..<3 {
			for j in 0..<3 {
				#expect(abs(LLt[i, j] - A[i, j]) < 1e-10)
			}
		}
	}

	@Test("Cholesky of identity is identity")
	func choleskyIdentity() throws {
		let I = DenseMatrix<Double>.identity(size: 4)
		let L = try I.cholesky()
		for i in 0..<4 {
			for j in 0..<4 {
				let expected: Double = i == j ? 1.0 : 0.0
				#expect(abs(L[i, j] - expected) < 1e-10)
			}
		}
	}

	@Test("Cholesky of non-SPD matrix throws")
	func choleskyNotSPD() throws {
		let A = try DenseMatrix([[1.0, 2.0], [2.0, 1.0]])
		#expect(throws: MatrixError.self) {
			try A.cholesky()
		}
	}

	@Test("Cholesky of non-square matrix throws")
	func choleskyNotSquare() throws {
		let A = try DenseMatrix([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]])
		#expect(throws: MatrixError.self) {
			try A.cholesky()
		}
	}

	@Test("Cholesky solve matches Gaussian elimination")
	func choleskySolveVector() throws {
		let A = try DenseMatrix([[4.0, 2.0], [2.0, 3.0]])
		let b = [8.0, 7.0]

		let xCholesky = try A.choleskySolve(b)
		let xGauss = try A.solve(b)

		for i in 0..<2 {
			#expect(abs(xCholesky[i] - xGauss[i]) < 1e-10)
		}
	}

	@Test("Cholesky solve for 3x3 system")
	func choleskySolve3x3() throws {
		let A = try DenseMatrix([
			[25.0, 15.0, -5.0],
			[15.0, 18.0,  0.0],
			[-5.0,  0.0, 11.0]
		])
		let b = [40.0, 33.0, 6.0]
		let x = try A.choleskySolve(b)

		let Ax = try A.multiplied(by: x)
		for i in 0..<3 {
			#expect(abs(Ax[i] - b[i]) < 1e-10)
		}
	}

	@Test("Cholesky solve with wrong vector length throws")
	func choleskySolveDimensionMismatch() throws {
		let A = try DenseMatrix([[4.0, 2.0], [2.0, 3.0]])
		#expect(throws: MatrixError.self) {
			try A.choleskySolve([1.0, 2.0, 3.0])
		}
	}

	@Test("Cholesky solve for matrix (multiple RHS)")
	func choleskySolveMatrix() throws {
		let A = try DenseMatrix([[4.0, 2.0], [2.0, 3.0]])
		let B = try DenseMatrix([[8.0, 4.0], [7.0, 5.0]])
		let X = try A.choleskySolve(B)

		let AX = try A.multiplied(by: X)
		for i in 0..<2 {
			for j in 0..<2 {
				#expect(abs(AX[i, j] - B[i, j]) < 1e-10)
			}
		}
	}

	@Test("logDeterminant of 2x2 matrix")
	func logDet2x2() throws {
		let A = try DenseMatrix([[4.0, 2.0], [2.0, 3.0]])
		let logDet = try A.logDeterminant()
		// det(A) = 4*3 - 2*2 = 8, log(8) ≈ 2.0794
		#expect(abs(logDet - Double.log(8.0)) < 1e-10)
	}

	@Test("logDeterminant of identity is zero")
	func logDetIdentity() throws {
		let I = DenseMatrix<Double>.identity(size: 5)
		let logDet = try I.logDeterminant()
		#expect(abs(logDet) < 1e-10)
	}

	@Test("logDeterminant of diagonal matrix")
	func logDetDiagonal() throws {
		let D = DenseMatrix<Double>.diagonal([2.0, 3.0, 5.0])
		let logDet = try D.logDeterminant()
		// det = 30, log(30) ≈ 3.4012
		#expect(abs(logDet - Double.log(30.0)) < 1e-10)
	}

	@Test("Cholesky inverse satisfies A * A^{-1} = I")
	func choleskyInverse() throws {
		let A = try DenseMatrix([
			[4.0, 2.0, 1.0],
			[2.0, 5.0, 3.0],
			[1.0, 3.0, 6.0]
		])
		let Ainv = try A.choleskyInverse()
		let product = try A.multiplied(by: Ainv)

		for i in 0..<3 {
			for j in 0..<3 {
				let expected: Double = i == j ? 1.0 : 0.0
				#expect(abs(product[i, j] - expected) < 1e-8)
			}
		}
	}

	@Test("Cholesky inverse of diagonal matrix")
	func choleskyInverseDiagonal() throws {
		let D = DenseMatrix<Double>.diagonal([2.0, 4.0, 8.0])
		let Dinv = try D.choleskyInverse()
		#expect(abs(Dinv[0, 0] - 0.5) < 1e-10)
		#expect(abs(Dinv[1, 1] - 0.25) < 1e-10)
		#expect(abs(Dinv[2, 2] - 0.125) < 1e-10)
	}

	@Test("Large 5x5 SPD matrix: full pipeline")
	func largeMatrix() throws {
		// Build SPD matrix as A'A + I
		let raw = try DenseMatrix([
			[1.0, 0.5, 0.3, 0.1, 0.0],
			[0.5, 1.0, 0.4, 0.2, 0.1],
			[0.3, 0.4, 1.0, 0.5, 0.2],
			[0.1, 0.2, 0.5, 1.0, 0.3],
			[0.0, 0.1, 0.2, 0.3, 1.0]
		])
		let A = try raw.multiplied(by: raw.transposed())
		let I5 = DenseMatrix<Double>.identity(size: 5)
		let SPD = try A + I5

		let L = try SPD.cholesky()
		let LLt = try L.multiplied(by: L.transposed())

		for i in 0..<5 {
			for j in 0..<5 {
				#expect(abs(LLt[i, j] - SPD[i, j]) < 1e-8)
			}
		}

		let b = [1.0, 2.0, 3.0, 4.0, 5.0]
		let x = try SPD.choleskySolve(b)
		let Ax = try SPD.multiplied(by: x)
		for i in 0..<5 {
			#expect(abs(Ax[i] - b[i]) < 1e-8)
		}
	}
}
