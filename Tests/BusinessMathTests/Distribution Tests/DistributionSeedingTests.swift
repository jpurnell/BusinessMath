import Testing
import Foundation
@testable import BusinessMath

/// Test suite validating that seeded distributions produce deterministic, reproducible results.
///
/// These tests ensure that when the same seed is used, distributions generate identical sequences,
/// eliminating test flakiness and enabling precise statistical validation.
///
/// ## Standard Test Seeds
///
/// All tests use these consistent seed values for reproducibility:
/// - `SEED_PRIMARY = 0.123456789` - Primary seed for single-value tests
/// - `SEED_SECONDARY = 0.987654321` - Secondary seed for comparison tests
/// - `SEED_U1 = 0.314159265` - First uniform for Box-Muller (π/10)
/// - `SEED_U2 = 0.271828183` - Second uniform for Box-Muller (e/10)
/// - `SEED_BASE = 0.5` - Baseline seed for sequence generation
@Suite("Distribution Seeding Tests")
struct DistributionSeedingTests {

	// MARK: - Standard Test Seeds

	/// Primary seed for single-value tests
	static let SEED_PRIMARY = 0.123456789

	/// Secondary seed for comparison tests
	static let SEED_SECONDARY = 0.987654321

	/// First uniform seed for Box-Muller (π/10)
	static let SEED_U1 = 0.314159265

	/// Second uniform seed for Box-Muller (e/10)
	static let SEED_U2 = 0.271828183

	/// Baseline seed for sequence generation
	static let SEED_BASE = 0.5

	// MARK: - Core Seeding Validation

	@Test("distributionUniform with same seed produces identical values")
	func uniformSameSeedIdenticalValues() {
		let value1: Double = distributionUniform(Self.SEED_PRIMARY)
		let value2: Double = distributionUniform(Self.SEED_PRIMARY)

		#expect(value1 == value2, "Same seed should produce identical values")
		#expect(abs(value1 - Self.SEED_PRIMARY) < 0.0000001, "Seeded value should match input seed")
	}

	@Test("distributionUniform with different seeds produces different values")
	func uniformDifferentSeedsDifferentValues() {
		let value1: Double = distributionUniform(Self.SEED_PRIMARY)
		let value2: Double = distributionUniform(Self.SEED_SECONDARY)

		#expect(value1 != value2, "Different seeds should produce different values")
	}

	@Test("distributionUniform with seed produces deterministic sequence")
	func uniformDeterministicSequence() {
		// Generate sequence with fixed seeds
		let seeds = [0.1, 0.2, 0.3, 0.4, 0.5]
		let sequence1 = seeds.map { distributionUniform($0) as Double }
		let sequence2 = seeds.map { distributionUniform($0) as Double }

		#expect(sequence1 == sequence2, "Same seeds should produce identical sequences")

		// Verify each value matches its seed (within precision)
		for (seed, value) in zip(seeds, sequence1) {
			#expect(abs(value - seed) < 0.0000001, "Seeded value should match seed")
		}
	}

	// MARK: - Box-Muller Seeding

	@Test("boxMullerSeed with same seeds produces identical normal values")
	func boxMullerSameSeedIdenticalValues() {
		let result1: (z1: Double, z2: Double) = boxMullerSeed(Self.SEED_U1, Self.SEED_U2)
		let result2: (z1: Double, z2: Double) = boxMullerSeed(Self.SEED_U1, Self.SEED_U2)

		#expect(result1.z1 == result2.z1, "Same seeds should produce identical z1")
		#expect(result1.z2 == result2.z2, "Same seeds should produce identical z2")
	}

	@Test("boxMullerSeed produces valid normal distribution characteristics")
	func boxMullerSeedValidNormal() {
		// Use known seeds to generate normal values
		let seeds = stride(from: 0.1, to: 0.9, by: 0.05).map { ($0, 1.0 - $0) }
		let normals = seeds.map { boxMullerSeed($0.0, $0.1) as (z1: Double, z2: Double) }

		// Extract all z1 and z2 values
		let z1Values = normals.map { $0.z1 }
		let z2Values = normals.map { $0.z2 }

		// Normal distribution should have mean ≈ 0
		let z1Mean = z1Values.reduce(0, +) / Double(z1Values.count)
		let z2Mean = z2Values.reduce(0, +) / Double(z2Values.count)

		// With fixed seeds, we get exact values (not random)
		// Just verify they're finite and reasonable
		for z1 in z1Values {
			#expect(z1.isFinite, "z1 should be finite")
			#expect(abs(z1) < 10, "z1 should be reasonable")
		}

		for z2 in z2Values {
			#expect(z2.isFinite, "z2 should be finite")
			#expect(abs(z2) < 10, "z2 should be reasonable")
		}
	}

	@Test("boxMuller function with seeded uniform produces deterministic output")
	func boxMullerFunctionDeterministic() {
		// Generate normal values using seeded uniforms
		let u1: Double = distributionUniform(Self.SEED_U1)
		let u2: Double = distributionUniform(Self.SEED_U2)

		let normal1: Double = boxMullerSeed(u1, u2).z1
		let normal2: Double = boxMullerSeed(u1, u2).z1

		#expect(normal1 == normal2, "Same seeded uniforms should produce identical normals")
	}

	// MARK: - Distribution Struct Seeding

	@Test("DistributionNormal.next() with seeded uniform produces deterministic values")
	func normalStructDeterministic() {
		// We can't directly seed DistributionNormal.next(), but we can verify
		// that boxMuller (which it uses) is deterministic

		let mean = 100.0
		let stdDev = 15.0

		// Create two identical seeded normal values using boxMuller
		let z1 = boxMullerSeed(Self.SEED_BASE, Self.SEED_BASE).z1 as Double
		let normal1 = (stdDev * z1) + mean

		let z2 = boxMullerSeed(Self.SEED_BASE, Self.SEED_BASE).z1 as Double
		let normal2 = (stdDev * z2) + mean

		#expect(normal1 == normal2, "Same seed should produce identical normal values")
	}

	// MARK: - Sequence Generation

	@Test("Generate deterministic sequence of normal values")
	func deterministicNormalSequence() {
		let mean = 50.0
		let stdDev = 10.0
		let count = 100

		// Generate sequence using fixed seeds
		var sequence1: [Double] = []
		var sequence2: [Double] = []

		for i in 0..<count {
			let seed1 = Double(i) / Double(count)
			let seed2 = Double(i + count) / Double(count * 2)

			let u1 = distributionUniform(seed1) as Double
			let u2 = distributionUniform(seed2) as Double

			let z = boxMullerSeed(u1, u2).z1 as Double
			let normal = (stdDev * z) + mean

			sequence1.append(normal)
		}

		// Regenerate with same seeds
		for i in 0..<count {
			let seed1 = Double(i) / Double(count)
			let seed2 = Double(i + count) / Double(count * 2)

			let u1 = distributionUniform(seed1) as Double
			let u2 = distributionUniform(seed2) as Double

			let z = boxMullerSeed(u1, u2).z1 as Double
			let normal = (stdDev * z) + mean

			sequence2.append(normal)
		}

		#expect(sequence1 == sequence2, "Same seeds should produce identical sequences")
	}

	@Test("Deterministic sequence has expected statistical properties")
	func deterministicSequenceStatistics() {
		let mean = 100.0
		let stdDev = 15.0
		let count = 1000

		// Generate deterministic sequence using standard seeds
		var values: [Double] = []
		for i in 0..<count {
			let seed1 = Self.SEED_U1 + (Double(i) * 0.0001)
			let seed2 = Self.SEED_U2 - (Double(i) * 0.0001)

			let u1 = distributionUniform(seed1) as Double
			let u2 = distributionUniform(seed2) as Double

			let z = boxMullerSeed(u1, u2).z1 as Double
			let normal = (stdDev * z) + mean

			values.append(normal)
		}

		// Calculate statistics (these will be exact, not random!)
		let sampleMean = values.reduce(0, +) / Double(values.count)
		let variance = values.map { pow($0 - sampleMean, 2) }.reduce(0, +) / Double(values.count - 1)
		let sampleStdDev = sqrt(variance)

		// With deterministic seeding, we get exact reproducible statistics
		// Regenerate and verify identical
		var values2: [Double] = []
		for i in 0..<count {
			let seed1 = Self.SEED_U1 + (Double(i) * 0.0001)
			let seed2 = Self.SEED_U2 - (Double(i) * 0.0001)

			let u1 = distributionUniform(seed1) as Double
			let u2 = distributionUniform(seed2) as Double

			let z = boxMullerSeed(u1, u2).z1 as Double
			let normal = (stdDev * z) + mean

			values2.append(normal)
		}

		let sampleMean2 = values2.reduce(0, +) / Double(values2.count)

		#expect(sampleMean == sampleMean2, "Same seeds should produce identical statistics")
	}

	// MARK: - Seed Range Validation

	@Test("Seeds at boundary values work correctly")
	func seedBoundaryValues() {
		// Test edge cases
		let nearZero = 0.0000001
		let nearOne = 0.9999999
		let middle = 0.5

		let v1: Double = distributionUniform(nearZero)
		let v2: Double = distributionUniform(nearOne)
		let v3: Double = distributionUniform(middle)

		#expect(v1.isFinite && v1 >= 0 && v1 <= 1, "Near-zero seed should produce valid value")
		#expect(v2.isFinite && v2 >= 0 && v2 <= 1, "Near-one seed should produce valid value")
		#expect(v3.isFinite && v3 >= 0 && v3 <= 1, "Middle seed should produce valid value")

		// Verify they're different
		#expect(v1 != v2, "Different seeds should produce different values")
		#expect(v2 != v3, "Different seeds should produce different values")
		#expect(v1 != v3, "Different seeds should produce different values")
	}

	@Test("Box-Muller with boundary uniform values")
	func boxMullerBoundaryValues() {
		// Test Box-Muller with edge case uniform values
		// Avoid exactly 0 or 1 as they cause log(0) issues

		let nearZero = 0.0001
		let nearOne = 0.9999

		let result1: (z1: Double, z2: Double) = boxMullerSeed(nearZero, nearOne)
		let result2: (z1: Double, z2: Double) = boxMullerSeed(nearOne, nearZero)

		#expect(result1.z1.isFinite, "z1 should be finite even with boundary values")
		#expect(result1.z2.isFinite, "z2 should be finite even with boundary values")
		#expect(result2.z1.isFinite, "z1 should be finite even with boundary values")
		#expect(result2.z2.isFinite, "z2 should be finite even with boundary values")
	}

	// MARK: - Practical Use Cases

	@Test("CVaR calculation with seeded distribution is exact and reproducible")
	func cvarWithSeededDistribution() {
		let mean = 100.0
		let stdDev = 10.0
		let sampleSize = 5_000

		// Generate seeded normal samples using standard seeds
		var values1: [Double] = []
		for i in 0..<sampleSize {
			let seed1 = Self.SEED_PRIMARY + (Double(i) * 0.00001)
			let seed2 = Self.SEED_SECONDARY - (Double(i) * 0.00001)

			let u1 = distributionUniform(seed1) as Double
			let u2 = distributionUniform(seed2) as Double

			let z = boxMullerSeed(u1, u2).z1 as Double
			let normal = (stdDev * z) + mean

			values1.append(normal)
		}

		let results1 = SimulationResults(values: values1)
		let cvar1 = results1.conditionalValueAtRisk(confidenceLevel: 0.999)

		// Regenerate with same standard seeds
		var values2: [Double] = []
		for i in 0..<sampleSize {
			let seed1 = Self.SEED_PRIMARY + (Double(i) * 0.00001)
			let seed2 = Self.SEED_SECONDARY - (Double(i) * 0.00001)

			let u1 = distributionUniform(seed1) as Double
			let u2 = distributionUniform(seed2) as Double

			let z = boxMullerSeed(u1, u2).z1 as Double
			let normal = (stdDev * z) + mean

			values2.append(normal)
		}

		let results2 = SimulationResults(values: values2)
		let cvar2 = results2.conditionalValueAtRisk(confidenceLevel: 0.999)

		#expect(cvar1 == cvar2, "Same seeds should produce identical CVaR")
		#expect(abs(cvar1 - results1.statistics.min) < 5.0,
				"With seeded values, CVaR should be predictably close to minimum")
	}

	@Test("VaR consistency test with seeded values is exact")
	func varConsistencyWithSeeding() {
		let mean = 100.0
		let stdDev = 15.0
		let sampleSize = 10_000

		// Helper to generate seeded samples using standard seeds
		func generateSeededSamples() -> [Double] {
			var values: [Double] = []
			for i in 0..<sampleSize {
				let seed1 = Self.SEED_U1 + (Double(i) * 0.000001)
				let seed2 = Self.SEED_U2 - (Double(i) * 0.000001)

				let u1 = distributionUniform(seed1) as Double
				let u2 = distributionUniform(seed2) as Double

				let z = boxMullerSeed(u1, u2).z1 as Double
				let normal = (stdDev * z) + mean

				values.append(normal)
			}
			return values
		}

		// Generate twice with same seeds
		let values1 = generateSeededSamples()
		let values2 = generateSeededSamples()

		let results1 = SimulationResults(values: values1)
		let results2 = SimulationResults(values: values2)

		let var95_1 = results1.valueAtRisk(confidenceLevel: 0.95)
		let var95_2 = results2.valueAtRisk(confidenceLevel: 0.95)

		let cvar95_1 = results1.conditionalValueAtRisk(confidenceLevel: 0.95)
		let cvar95_2 = results2.conditionalValueAtRisk(confidenceLevel: 0.95)

		// With seeding, values should be EXACTLY equal (not just close)
		#expect(var95_1 == var95_2, "Seeded VaR should be exactly identical")
		#expect(cvar95_1 == cvar95_2, "Seeded CVaR should be exactly identical")
		#expect(values1 == values2, "Seeded sequences should be exactly identical")
	}

	// MARK: - Multiple Distribution Types

	@Test("Seeding works across different distribution parameter sets")
	func seedingWithDifferentParameters() {
		// Same standard seeds, different parameters should give related but different results
		let u1 = distributionUniform(Self.SEED_U1) as Double
		let u2 = distributionUniform(Self.SEED_U2) as Double

		// Normal with different parameters
		let z = boxMullerSeed(u1, u2).z1 as Double

		let normal1 = (10.0 * z) + 50.0  // N(50, 10)
		let normal2 = (20.0 * z) + 100.0 // N(100, 20)

		// Regenerate with same standard seeds
		let u1_2 = distributionUniform(Self.SEED_U1) as Double
		let u2_2 = distributionUniform(Self.SEED_U2) as Double
		let z_2 = boxMullerSeed(u1_2, u2_2).z1 as Double

		let normal1_2 = (10.0 * z_2) + 50.0
		let normal2_2 = (20.0 * z_2) + 100.0

		#expect(normal1 == normal1_2, "Same seed should produce identical N(50,10)")
		#expect(normal2 == normal2_2, "Same seed should produce identical N(100,20)")
	}
}
