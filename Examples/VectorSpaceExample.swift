//
//  VectorSpaceExample.swift
//  BusinessMath Examples
//
//  Demonstrates VectorSpace protocol and vector operations from Phase 2
//

import Foundation
@testable import BusinessMath

/// Example: Vector2D operations
func vector2DExample() {
	print("=== Vector2D Operations ===\n")

	// Create 2D vectors
	let v = Vector2D<Double>(x: 3.0, y: 4.0)
	let w = Vector2D<Double>(x: 1.0, y: 2.0)

	print("Vectors:")
	print("  v = (\(v.x.number()), \(v.y.number()))")
	print("  w = (\(w.x.number()), \(w.y.number()))")
	print()

	// Basic operations
	print("Basic Operations:")
	let sum = v + w
	print("  v + w = (\(sum.x.number()), \(sum.y.number()))")

	let diff = v - w
	print("  v - w = (\(diff.x.number()), \(diff.y.number()))")

	let scaled = 2.0 * v
	print("  2v = (\(scaled.x.number()), \(scaled.y.number()))")

	let negated = -v
	print("  -v = (\(negated.x.number()), \(negated.y.number()))")

	print()

	// Norms and distances
	print("Norms and Distances:")
	print("  ‖v‖ = \(v.norm.number()) (√(3² + 4²) = √25 = 5)")
	print("  ‖w‖ = \(w.norm.number())")
	print("  ‖v - w‖ = \(v.distance(to: w).number())")

	print()

	// Dot product
	print("Dot Product:")
	let dot = v.dot(w)
	print("  v · w = \(dot) (3×1 + 4×2 = 11)")

	print()

	// 2D-specific: cross product (returns scalar)
	print("2D Cross Product (signed area):")
	let cross = v.cross(w)
	print("  v × w = \(cross) (3×2 - 4×1 = 2)")

	print()

	// Rotation
	print("Rotation:")
	let rotated90 = v.rotated(by: .pi / 2)
	print("  v rotated 90°: (\(rotated90.x.number()), \(rotated90.y.number()))")

	let angle = v.angle
	print("  Angle from x-axis: \(angle.number()) radians (\((angle * 180 / .pi).number())°)")

	print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Vector3D operations
func vector3DExample() {
	print("=== Vector3D Operations ===\n")

	let v = Vector3D<Double>(x: 1.0, y: 2.0, z: 3.0)
	let w = Vector3D<Double>(x: 4.0, y: 5.0, z: 6.0)

	print("Vectors:")
	print("  v = (\(v.x.number()), \(v.y.number()), \(v.z.number()))")
	print("  w = (\(w.x.number()), \(w.y.number()), \(w.z.number()))")
	print()

	// Basic operations
	print("Basic Operations:")
	print("  v + w = \((v + w).toArray())")
	print("  v - w = \((v - w).toArray())")
	print("  2v = \((2.0 * v).toArray())")

	print()

	// Norms
	print("Norms:")
	print("  ‖v‖ = \(v.norm.number()) (√(1² + 2² + 3²) = √14)")
	print("  ‖w‖ = \(w.norm.number())")

	print()

	// Dot product
	print("Dot Product:")
	let dot = v.dot(w)
	print("  v · w = \(dot.number()) (1×4 + 2×5 + 3×6 = 32)")

	print()

	// 3D cross product (returns vector)
	print("3D Cross Product:")
	let cross = v.cross(w)
	print("  v × w = \(cross.toArray())")
	print("  (perpendicular to both v and w)")

	// Verify perpendicularity
	let dotCrossV = cross.dot(v)
	let dotCrossW = cross.dot(w)
	print("  Verification: (v×w)·v = \(dotCrossV.number()) (should be ~0)")
	print("                (v×w)·w = \(dotCrossW.number()) (should be ~0)")

	print()

	// Triple products
	print("Triple Products:")
	let u = Vector3D<Double>(x: 1.0, y: 0.0, z: 0.0)
	let tripleScalar = u.tripleProduct(v, w)
	print("  Scalar triple product: \(tripleScalar.number()) (signed volume)")

	print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: VectorN operations
func vectorNExample() {
	print("=== VectorN Operations ===\n")

	let v = VectorN<Double>([1.0, 2.0, 3.0, 4.0, 5.0])
	let w = VectorN<Double>([5.0, 4.0, 3.0, 2.0, 1.0])

	print("Vectors:")
	print("  v = \(v.toArray())")
	print("  w = \(w.toArray())")
	print()

	// Basic operations
	print("Basic Operations:")
	print("  v + w = \((v + w).toArray())")
	print("  v - w = \((v - w).toArray())")
	print("  2v = \((2.0 * v).toArray())")
	print("  v / 2 = \((v / 2.0).toArray())")

	print()

	// Element access
	print("Element Access:")
	print("  v[0] = \(v[0])")
	print("  v[2] = \(v[2])")
	print("  v[4] = \(v[4])")

	print()

	// Statistical operations
	print("Statistical Operations:")
	print("  sum(v) = \(v.sum.number())")
	print("  mean(v) = \(v.mean.number())")
	print("  std(v) = \(v.standardDeviation().number())")
	print("  min(v) = \(v.min!)")
	print("  max(v) = \(v.max!)")
	if let range = v.range {
		print("  range(v) = [\(range.min.number()), \(range.max.number())]")
	}

	print()

	// Element-wise operations
	print("Element-Wise Operations:")
	let hadamard = v.hadamardProduct(with: w)
	print("  v ⊙ w = \(hadamard.toArray()) (element-wise product)")

	let quotient = v.elementwiseDivide(by: w)
	print("  v ⊘ w = \(quotient.toArray().map { $0.number() })")

	print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Distance metrics
func distanceMetricsExample() {
	print("=== Distance Metrics ===\n")

	let p1 = VectorN([0.0, 0.0])
	let p2 = VectorN([3.0, 4.0])

	print("Points:")
	print("  p1 = \(p1.toArray())")
	print("  p2 = \(p2.toArray())")
	print()

	// Euclidean distance (L2 norm)
	let euclidean = p1.distance(to: p2)
	print("Euclidean distance (L2): \(euclidean.number())")
	print("  √((3-0)² + (4-0)²) = √25 = 5")

	print()

	// Manhattan distance (L1 norm)
	let manhattan = p1.manhattanDistance(to: p2)
	print("Manhattan distance (L1): \(manhattan.number())")
	print("  |3-0| + |4-0| = 7 (city blocks)")

	print()

	// Chebyshev distance (L∞ norm)
	let chebyshev = p1.chebyshevDistance(to: p2)
	print("Chebyshev distance (L∞): \(chebyshev.number())")
	print("  max(|3-0|, |4-0|) = 4 (chess king moves)")

	print()

	// Cosine similarity
	let v1 = VectorN([1.0, 2.0, 3.0])
	let v2 = VectorN([2.0, 4.0, 6.0])
	let similarity = v1.cosineSimilarity(with: v2)
	print("Cosine Similarity:")
	print("  v1 = \(v1.toArray())")
	print("  v2 = \(v2.toArray())")
	print("  similarity = \(similarity.number()) (1.0 means same direction)")

	print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Projections and orthogonality
func projectionsExample() {
	print("=== Projections and Orthogonality ===\n")

	let v = VectorN([3.0, 4.0])
	let w = VectorN([1.0, 0.0])

	print("Vectors:")
	print("  v = \(v.toArray())")
	print("  w = \(w.toArray()) (unit vector along x-axis)")
	print()

	// Project v onto w
	let projection = v.projection(onto: w)
	print("Projection of v onto w:")
	print("  proj_w(v) = \(projection.toArray())")
	print("  (component of v in direction of w)")

	print()

	// Rejection (perpendicular component)
	let rejection = v.rejection(from: w)
	print("Rejection of v from w:")
	print("  rej_w(v) = \(rejection.toArray())")
	print("  (component of v perpendicular to w)")

	print()

	// Verify decomposition
	let reconstructed = projection + rejection
	print("Verify decomposition:")
	print("  proj + rej = \(reconstructed.toArray())")
	print("  original v = \(v.toArray())")

	print()

	// Check orthogonality
	print("Orthogonality:")
	let x = VectorN([1.0, 0.0, 0.0])
	let y = VectorN([0.0, 1.0, 0.0])
	let z = VectorN([1.0, 1.0, 0.0])

	print("  x = \(x.toArray())")
	print("  y = \(y.toArray())")
	print("  z = \(z.toArray())")
	print("  x ⊥ y? \(x.isOrthogonal(to: y)) (dot product = 0)")
	print("  x ⊥ z? \(x.isOrthogonal(to: z)) (dot product ≠ 0)")
	print("  y ⊥ z? \(y.isOrthogonal(to: z))")

	print()

	// Check parallelism
	print("Parallelism:")
	let a = VectorN([2.0, 4.0])
	let b = VectorN([1.0, 2.0])
	let c = VectorN([1.0, 0.0])

	print("  a = \(a.toArray())")
	print("  b = \(b.toArray())")
	print("  c = \(c.toArray())")
	print("  a ∥ b? \(a.isParallel(to: b)) (same direction)")
	print("  a ∥ c? \(a.isParallel(to: c)) (different directions)")

	print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Vector construction and manipulation
func constructionExample() {
	print("=== Vector Construction ===\n")

	// Standard construction
	print("Standard Construction:")
	let v1 = VectorN([1.0, 2.0, 3.0])
	print("  From array: \(v1.toArray())")

	let v2 = VectorN(repeating: 5.0, count: 4)
	print("  Repeating value: \(v2.toArray())")

	let v3 = VectorN<Double>.zero
	print("  Zero vector: \(v3.toArray())")

	print()

	// Factory methods
	print("Factory Methods:")

	let ones = VectorN<Double>.ones(dimension: 5)
	print("  Ones: \(ones.toArray())")

	let basis = VectorN<Double>.basisVector(dimension: 5, index: 2)
	print("  Basis vector e₂: \(basis.toArray())")

	let linspace = VectorN<Double>.linearSpace(from: 0.0, to: 10.0, count: 6)
	print("  Linear space [0, 10]: \(linspace.toArray().map { $0.number() })")

	let logspace = VectorN<Double>.logSpace(from: 1.0, to: 100.0, count: 3)
	print("  Log space [1, 100]: \(logspace.toArray().map { $0.number() })")

	print()

	// Manipulation
	print("Manipulation:")
	var v = VectorN([1.0, 2.0, 3.0])
	print("  Original: \(v.toArray())")

	let appended = v.appending(4.0)
	print("  Appended: \(appended.toArray())")

	if let removed = appended.removingLast() {
		print("  Removed last: \(removed.toArray())")
	}

	let w = VectorN([5.0, 6.0])
	let concatenated = v.concatenated(with: w)
	print("  Concatenated: \(concatenated.toArray())")

	if let sliced = concatenated.slice(1..<4) {
		print("  Sliced [1:4]: \(sliced.toArray())")
	}

	print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Functional operations
func functionalOperationsExample() {
	print("=== Functional Operations ===\n")

	let v = VectorN([1.0, 2.0, 3.0, 4.0, 5.0])
	print("Original vector: \(v.toArray())")
	print()

	// Map
	print("Map Operations:")
	let squared = v.map { $0 * $0 }
	print("  Squared: \(squared.toArray())")

	let doubled = v.map { $0 * 2 }
	print("  Doubled: \(doubled.toArray())")

	print()

	// Filter
	print("Filter Operations:")
	let evens = v.filter { $0.truncatingRemainder(dividingBy: 2) == 0 }
	print("  Even values: \(evens.toArray())")

	let large = v.filter { $0 > 3 }
	print("  Values > 3: \(large.toArray())")

	print()

	// Reduce
	print("Reduce Operations:")
	let sum = v.reduce(0.0, +)
	print("  Sum: \(sum.number())")

	let product = v.reduce(1.0, *)
	print("  Product: \(product.number())")

	print()

	// ZipWith
	print("ZipWith Operations:")
	let w = VectorN([5.0, 4.0, 3.0, 2.0, 1.0])
	print("  w = \(w.toArray())")

	let summed = v.zipWith(w, +)
	print("  v + w (zipWith): \(summed.toArray())")

	let multiplied = v.zipWith(w, *)
	print("  v * w (zipWith): \(multiplied.toArray())")

	print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Portfolio weights (practical application)
func portfolioWeightsExample() {
	print("=== Portfolio Weights Application ===\n")

	let assets = ["AAPL", "GOOGL", "MSFT", "AMZN"]
	var weights = VectorN([0.25, 0.30, 0.25, 0.20])

	print("Portfolio:")
	for (i, asset) in assets.enumerated() {
		print("  \(asset.paddingLeft(toLength: 5)): \((weights[i] * 100).number())%")
	}
	print()

	// Check if weights sum to 1
	print("Sum of weights: \(weights.sum)")
	if abs(weights.sum - 1.0) > 0.001 {
		print("  ⚠️ Weights don't sum to 1 - normalizing...")
		weights = weights / weights.sum
		print("  After normalization: \(weights.sum.number())")
	} else {
		print("  ✓ Weights sum to 1")
	}

	print()

	// Expected returns
	let returns = VectorN([0.12, 0.15, 0.10, 0.18])
	print("Expected Returns:")
	for (i, asset) in assets.enumerated() {
		print("  \(asset.paddingLeft(toLength: 5)): \((returns[i] * 100).number())%")
	}

	print()

	// Portfolio return (weighted average)
	let portfolioReturn = weights.dot(returns)
	print("Portfolio Return: \((portfolioReturn * 100).number())%")

	print()

	// Risk contribution
	print("Weight × Return (contribution to portfolio):")
	let contributions = weights.hadamardProduct(with: returns)
	for (i, asset) in assets.enumerated() {
		print("  \(asset.paddingLeft(toLength: 5)): \((weights[i] * 100).number())% × \((returns[i] * 100).number())% = \((contributions[i] * 100).number())%")
	}

	print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Normalization and unit vectors
func normalizationExample() {
	print("=== Normalization ===\n")

	let v = VectorN([3.0, 4.0])
	print("Original vector: \(v.toArray())")
	print("Norm: \(v.norm)")
	print()

	// Normalize to unit length
	let unit = v.normalized()
	print("Normalized (unit vector): \(unit.toArray().map { $0.number() })")
	print("Norm: \(unit.norm.number()) (should be 1.0)")

	print()

	// Verify direction preserved
	let similarity = v.cosineSimilarity(with: unit)
	print("Cosine similarity with original: \(similarity.number()) (should be 1.0)")

	print()

	// Feature normalization example
	print("Feature Normalization Example:")
	let features = VectorN([100.0, 200.0, 150.0, 300.0])
	print("  Raw features: \(features.toArray())")

	// Min-max normalization to [0, 1]
	if let min = features.min, let max = features.max {
		let range = max - min
		let normalized = features.map { ($0 - min) / range }
		print("  Min-max normalized: \(normalized.toArray().map { $0 })")
	}

	// Z-score normalization
	let mean = features.mean
	let std = features.standardDeviation()
	let zScores = features.map { ($0 - mean) / std }
	print("  Z-scores: \(zScores.toArray().map { $0.number() })")

	print("\n" + String(repeating: "=", count: 50) + "\n")
}

// Run examples
print("\n")
print("BusinessMath - VectorSpace Examples")
print(String(repeating: "=", count: 50))
print("\n")

vector2DExample()
vector3DExample()
vectorNExample()
distanceMetricsExample()
projectionsExample()
constructionExample()
functionalOperationsExample()
portfolioWeightsExample()
normalizationExample()

print("Examples complete!")
print()
print("Key Concepts:")
print("  • VectorSpace protocol: generic interface for all vectors")
print("  • Vector2D/3D: Fixed dimension, compile-time optimization")
print("  • VectorN: Variable dimension, flexible but has overhead")
print("  • Distance metrics: Euclidean, Manhattan, Chebyshev")
print("  • Projections: Decompose vectors into parallel/perpendicular")
print("  • Functional operations: map, filter, reduce, zipWith")
print()
print("Next Steps:")
print("  • For optimization using vectors, see OptimizationExample.swift")
print("  • For constrained optimization, see ConstrainedOptimizationExample.swift")
print("  • For portfolio optimization, see PortfolioOptimizationExample.swift")
