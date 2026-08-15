//
//  SimulationInput.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

/// A type-erased wrapper for uncertain input variables in Monte Carlo simulations.
///
/// SimulationInput provides a flexible way to define uncertain variables using either:
/// 1. Any type conforming to `DistributionRandom` (Normal, Uniform, Weibull, etc.)
/// 2. Custom sampling closures for bespoke distributions
///
/// ## Type Erasure Benefits
///
/// The type erasure pattern allows you to store different distribution types in a single
/// collection, making it easy to define multi-variable Monte Carlo simulations.
///
/// ## Use Cases
///
/// - Financial modeling: Revenue, costs, growth rates
/// - Project management: Task durations, resource availability
/// - Risk analysis: Failure rates, demand volatility
/// - Operations: Processing times, yield rates
///
/// ## Example
///
/// ```swift
/// let simulation = try FinancialSimulation.documentationFixture
/// // Using built-in distributions
/// let revenueInput = SimulationInput(
///     name: "MonthlyRevenue",
///     distribution: DistributionNormal(100_000, 15_000),
///     metadata: ["unit": "USD", "category": "income"]
/// )
///
/// let costsInput = SimulationInput(
///     name: "OperatingCosts",
///     distribution: DistributionUniform(50_000, 70_000)
/// )
///
/// // Using custom sampling logic
/// let seasonalityInput = SimulationInput(name: "SeasonalFactor") {
///     let month = Calendar.current.component(.month, from: Date())
///     let baseFactor = 1.0
///     let seasonalBoost = month >= 11 ? 0.3 : 0.0  // Holiday season
///     return distributionNormal(mean: baseFactor + seasonalBoost, stdDev: 0.1)
/// }
///
/// // Combine in a simulation
/// let inputs = [revenueInput, costsInput, seasonalityInput]
/// ```
public struct SimulationInput: Sendable {

	// MARK: - Properties

	/// The name of this input variable (e.g., "Revenue", "Cost", "DemandGrowth")
	public let name: String

	/// Optional metadata for documentation and analysis
	///
	/// Use metadata to store:
	/// - Units: "USD", "days", "percent"
	/// - Categories: "financial", "operational", "market"
	/// - Descriptions: "Monthly recurring revenue"
	/// - Assumptions: "Based on historical data 2020-2024"
	public let metadata: [String: String]

	/// The type-erased sampling function
	///
	/// This closure encapsulates the distribution logic and can be called
	/// to generate random samples from the underlying distribution.
	private let sampler: @Sendable () -> Double

	/// Optional storage of the original distribution for GPU compatibility
	///
	/// When initialized with a distribution type (as opposed to a custom sampler),
	/// this property stores a reference to the original distribution object.
	/// This allows GPU acceleration to extract distribution parameters without
	/// breaking the type erasure abstraction.
	///
	/// - `nil` for inputs created with custom samplers (GPU incompatible)
	/// - Non-nil for inputs created with `DistributionRandom` types (GPU compatible)
	internal let originalDistribution: (Any & Sendable)?

	/// The type-erased seeded sampling function, when the distribution supports it.
	///
	/// Non-nil only when the input was created from a distribution conforming to
	/// ``SeedableDistribution``; drawing through it sources every uniform from the
	/// provided generator, so a seeded ``Xoshiro256StarStar`` reproduces the identical stream.
	/// `nil` for custom-closure inputs and non-seedable distributions.
	internal let seededSampler: (@Sendable (inout Xoshiro256StarStar) -> Double)?

	/// Whether this input can participate in seeded (deterministic) simulation runs.
	///
	/// `true` when the input was created from a ``SeedableDistribution``-conforming
	/// distribution. Seeded ``MonteCarloSimulation`` runs throw
	/// `SimulationError.seedingUnsupported` for inputs where this is `false`.
	public var supportsSeeding: Bool { seededSampler != nil }

	// MARK: - Initialization from Distribution

	/// Creates a SimulationInput from any type conforming to `DistributionRandom`.
	///
	/// This initializer uses type erasure to wrap the distribution's `next()` method,
	/// allowing you to use any built-in or custom distribution type.
	///
	/// - Parameters:
	///   - name: A descriptive name for this input variable
	///   - distribution: Any type conforming to `DistributionRandom` with `T == Double`
	///   - metadata: Optional key-value pairs for documentation (default: empty)
	///
	/// ## Supported Distribution Types
	///
	/// All types conforming to `DistributionRandom`:
	/// - `DistributionNormal`: Normal/Gaussian distribution
	/// - `DistributionUniform`: Uniform distribution
	/// - `DistributionTriangular`: Triangular distribution
	/// - `DistributionWeibull`: Weibull distribution (reliability analysis)
	/// - `DistributionRayleigh`: Rayleigh distribution
	/// - And any custom types conforming to `DistributionRandom`
	///
	/// ## Example
	///
	/// ```swift
	/// let input = SimulationInput(
	///     name: "ProjectDuration",
	///     distribution: DistributionTriangular(low: 10, high: 25, base: 15),
	///     metadata: ["unit": "days", "type": "PERT"]
	/// )
	/// ```
	public init<D: DistributionRandom & Sendable>(
		name: String,
		distribution: D,
		metadata: [String: String] = [:]
	) where D.T == Double {
		self.name = name
		self.metadata = metadata

		// Type erasure: capture the distribution and wrap its next() method
		self.sampler = {
			distribution.next()
		}

		// Store original distribution for GPU compatibility
		self.originalDistribution = distribution

		// Only the SeedableDistribution overload can honor a seed
		self.seededSampler = nil
	}

	/// Creates a SimulationInput from a distribution that supports seeded sampling.
	///
	/// Swift prefers this overload when the concrete distribution conforms to
	/// ``SeedableDistribution``, capturing a seeded sampler alongside the ordinary
	/// one so the input can participate in deterministic
	/// (``MonteCarloSimulation/seed``-driven) runs.
	///
	/// - Parameters:
	///   - name: A descriptive name for this input variable
	///   - distribution: Any type conforming to `SeedableDistribution` with `T == Double`
	///   - metadata: Optional key-value pairs for documentation (default: empty)
	public init<D: SeedableDistribution & Sendable>(
		name: String,
		distribution: D,
		metadata: [String: String] = [:]
	) where D.T == Double {
		self.name = name
		self.metadata = metadata

		// Type erasure: capture the distribution and wrap its next() method
		self.sampler = {
			distribution.next()
		}

		// Store original distribution for GPU compatibility
		self.originalDistribution = distribution

		// Seeded sampling: every draw flows from the caller's generator
		self.seededSampler = { generator in
			distribution.next(using: &generator)
		}
	}

	// MARK: - Initialization from Custom Sampler

	/// Creates a SimulationInput from a custom sampling closure.
	///
	/// Use this initializer when you need:
	/// - Custom distribution logic not available in built-in types
	/// - Conditional sampling based on external state
	/// - Combination of multiple distributions
	/// - Time-dependent or context-aware sampling
	///
	/// - Parameters:
	///   - name: A descriptive name for this input variable
	///   - metadata: Optional key-value pairs for documentation (default: empty)
	///   - sampler: A closure that returns a random sample
	///
	/// - Note: The sampler closure must be `@Sendable` for thread-safety in concurrent simulations
	///
	/// ## Example
	///
	/// ```swift
	/// // Bimodal distribution (mixture of two normals)
	/// let bimodalInput = SimulationInput(name: "CustomerArrival") {
	///     if Double.random(in: 0...1) < 0.3 {
	///         // 30% chance: rush hour
	///         return distributionNormal(mean: 50, stdDev: 5)
	///     } else {
	///         // 70% chance: normal period
	///         return distributionNormal(mean: 20, stdDev: 3)
	///     }
	/// }
	///
	/// // Time-dependent sampling
	/// let seasonalInput = SimulationInput(name: "Demand") {
	///     let month = Calendar.current.component(.month, from: Date())
	///     let seasonalFactor = (1...12).contains(month) ? 1.0 + Double(month) / 100 : 1.0
	///     return distributionNormal(mean: 1000 * seasonalFactor, stdDev: 100)
	/// }
	/// ```
	public init(
		name: String,
		metadata: [String: String] = [:],
		sampler: @escaping @Sendable () -> Double
	) {
		self.name = name
		self.metadata = metadata
		self.sampler = sampler
		self.originalDistribution = nil  // Custom samplers are not GPU-compatible
		self.seededSampler = nil         // Custom samplers cannot honor a seed
	}

	// MARK: - Sampling

	/// Generates a random sample from the underlying distribution.
	///
	/// Each call to `sample()` produces a new independent random value according
	/// to the distribution or custom logic defined at initialization.
	///
	/// - Returns: A random sample value
	///
	/// ## Example
	///
	/// ```swift
	/// let simulation = try FinancialSimulation.documentationFixture
	/// let input = SimulationInput(
	///     name: "Revenue",
	///     distribution: DistributionNormal(100_000, 10_000)
	/// )
	///
	/// // Generate 10,000 samples for Monte Carlo simulation
	/// let samples = (0..<10_000).map { _ in input.sample() }
	/// ```
	public func sample() -> Double {
		return sampler()
	}
}
