import Foundation
import BusinessMath
import OSLog
import PlaygroundSupport

	// 10,000-point discretization
	let n = 10_000
	var triplets: [(Int, Int, Double)] = []

	for i in 0..<n {
		triplets.append((i, i, 2.0))      // Diagonal
		if i > 0 {
			triplets.append((i, i-1, -1.0)) // Sub-diagonal
		}
		if i < n-1 {
			triplets.append((i, i+1, -1.0)) // Super-diagonal
		}
	}

	let A = SparseMatrix(rows: n, columns: n, triplets: triplets)
	let b = [Double](repeating: 0.0, count: n)
	// Set boundary conditions
	var b_modified = b
	b_modified[0] = 100.0      // Hot end
	b_modified[n-1] = 0.0      // Cold end

	let solver = SparseSolver()
	let temperature = try solver.solve(
		A: A,
		b: b_modified,
		method: .conjugateGradient,
		tolerance: 1e-10
	)

	print("Solved 10,000-point heat equation")
	print("Temperature range: \(temperature.min()!) to \(temperature.max()!)")
