//
//  Scenario.swift
//  BusinessMath
//
//  Created by Justin Purnell on 12/04/25.
//

import Foundation

// MARK: - OptimizationScenario Protocol

/// Protocol for random scenarios used in stochastic optimization.
///
/// A scenario represents one possible realization of uncertain parameters.
/// Stochastic optimization optimizes the expected value across many scenarios.
///
/// ## Example
/// ```swift
/// let historical = TimeSeries(periods: Period.documentationQuarters, values: [100, 120, 140, 160])
/// struct PortfolioScenario: OptimizationScenario {
///     let returns: [Double]  // Random returns for each asset
///     let probability: Double  // Optional: for discrete distributions
///
///     // Generate from historical data or Monte Carlo
///     static func generate() -> PortfolioScenario {
///         let returns = sampleFromHistoricalDistribution()
///         return PortfolioScenario(returns: returns, probability: 1.0)
///     }
/// }
/// ```
public protocol OptimizationScenario: Sendable {
	/// Optional probability for discrete scenarios.
	///
	/// For continuous distributions (Monte Carlo), this is typically 1/N.
	/// For discrete scenarios, this is the scenario probability.
	var probability: Double { get }
}

// MARK: - MonteCarloScenario

/// A scenario generated via Monte Carlo sampling.
///
/// This is a generic container for random parameters used in stochastic optimization.
///
/// ## Example
/// ```swift
/// let scenario = MonteCarloScenario(
///     parameters: [
///         "stock_return": 0.12,
///         "bond_return": 0.04,
///         "inflation": 0.02
///     ]
/// )
///
/// let stockReturn = scenario.parameters["stock_return"]!
/// ```
public struct MonteCarloScenario: OptimizationScenario {
	/// Random parameters for this scenario
	public let parameters: [String: Double]

	/// Probability (1/N for Monte Carlo)
	public let probability: Double

	/// Creates a Monte Carlo scenario.
	///
	/// - Parameters:
	///   - parameters: Dictionary of random parameter values
	///   - probability: Scenario probability (default: 1.0, will be normalized)
	public init(parameters: [String: Double], probability: Double = 1.0) {
		self.parameters = parameters
		self.probability = probability
	}

	/// Convenience accessor for parameters.
	public subscript(key: String) -> Double? {
		return parameters[key]
	}
}

// MARK: - DiscreteScenario

/// A scenario from a discrete probability distribution.
///
/// Used when there are a finite number of possible futures (e.g., bull/base/bear market).
///
/// ## Example
/// ```swift
/// let scenarios = [
///     DiscreteScenario(name: "Bull", probability: 0.30, parameters: ["return": 0.20]),
///     DiscreteScenario(name: "Base", probability: 0.50, parameters: ["return": 0.10]),
///     DiscreteScenario(name: "Bear", probability: 0.20, parameters: ["return": -0.05])
/// ]
/// ```
public struct DiscreteScenario: OptimizationScenario {
	/// Scenario name
	public let name: String

	/// Scenario probability (should sum to 1 across all scenarios)
	public let probability: Double

	/// Scenario-specific parameters
	public let parameters: [String: Double]

	/// Creates a discrete scenario.
	///
	/// - Parameters:
	///   - name: Descriptive name
	///   - probability: Probability of this scenario
	///   - parameters: Scenario-specific parameter values
	public init(name: String, probability: Double, parameters: [String: Double]) {
		self.name = name
		self.probability = probability
		self.parameters = parameters
	}

	/// Convenience accessor for parameters.
	public subscript(key: String) -> Double? {
		return parameters[key]
	}
}

// MARK: - Scenario Generation

/// Helper for generating scenarios from distributions.
///
/// ## Seeds and concurrency
///
/// Each generator comes in two forms. The `seed:` form owns its stream: it builds a
/// private ``DeterministicRNG`` from the seed, so the same seed yields the same scenarios
/// no matter what else the process is doing at the time. Passing `nil` (the default)
/// draws from system entropy and is non-reproducible *by contract* — that is the whole
/// difference between the two.
///
/// The `using:` form takes the caller's generator instead. Reach for it when one seed has
/// to drive more than one block of scenarios. Three `seed: 42` calls give three streams
/// that all start at the same place — the normal block and the uniform block would be
/// built from the same underlying uniforms, which is a correlation the caller did not ask
/// for. One generator threaded through three calls gives three independent blocks, and
/// the caller still owns reproducibility.
///
/// ```swift
/// var rng = DeterministicRNG(seed: 42)
/// let returns = ScenarioGenerator.normal(mean: mu, standardDeviation: sigma,
///                                        numberOfScenarios: 1_000, using: &rng)
/// let shocks  = ScenarioGenerator.uniform(lowerBounds: lo, upperBounds: hi,
///                                         numberOfScenarios: 1_000, using: &rng)
/// ```
///
/// ### Why the generator is passed rather than stored
///
/// These were `srand48`/`drand48`, which is one random stream shared by the entire
/// process. A seed set that way survives only until something else draws from it, so two
/// seeded generations running concurrently consumed each other's values and neither
/// reproduced. Nothing about the old signatures said so; the seed simply did not mean
/// what it said outside a single-threaded program. Threading the generator through as an
/// `inout` parameter is what makes each call's randomness its own.
public struct ScenarioGenerator {

	// MARK: - Normal

	/// Generate scenarios from normal distribution.
	///
	/// - Parameters:
	///   - mean: Mean vector
	///   - standardDeviation: Standard deviation vector
	///   - numberOfScenarios: Number of samples
	///   - seed: Seed for the private ``DeterministicRNG``. The same seed reproduces the
	///     same scenarios exactly, including when other seeded generations run at the same
	///     time. `nil` (the default) draws from system entropy and does not reproduce.
	/// - Returns: Array of Monte Carlo scenarios, or `[]` if the two vectors differ in
	///   length or `numberOfScenarios` is not positive.
	public static func normal(
		mean: [Double],
		standardDeviation: [Double],
		numberOfScenarios: Int,
		seed: UInt64? = nil
	) -> [MonteCarloScenario] {
		if let seed {
			var generator = DeterministicRNG(seed: seed)
			return normal(mean: mean, standardDeviation: standardDeviation,
						  numberOfScenarios: numberOfScenarios, using: &generator)
		}
		var generator = SystemRandomNumberGenerator() // stochastic:exempt — the documented unseeded path; pass `seed:` for reproducibility
		return normal(mean: mean, standardDeviation: standardDeviation,
					  numberOfScenarios: numberOfScenarios, using: &generator)
	}

	/// Generate normally distributed scenarios, drawing every value from `generator`.
	///
	/// The generator-parameterized form of
	/// ``normal(mean:standardDeviation:numberOfScenarios:seed:)``, following the same
	/// convention as ``SeedableDistribution/next(using:)``.
	///
	/// - Parameters:
	///   - mean: Mean vector
	///   - standardDeviation: Standard deviation vector
	///   - numberOfScenarios: Number of samples
	///   - generator: The random source. Advanced by two draws per parameter per scenario.
	/// - Returns: Array of Monte Carlo scenarios, or `[]` if the two vectors differ in
	///   length or `numberOfScenarios` is not positive.
	public static func normal<G: RandomNumberGenerator>(
		mean: [Double],
		standardDeviation: [Double],
		numberOfScenarios: Int,
		using generator: inout G
	) -> [MonteCarloScenario] {
		guard mean.count == standardDeviation.count else {
			return []
		}
		guard numberOfScenarios > 0 else {
			return []
		}

		var scenarios: [MonteCarloScenario] = []
		scenarios.reserveCapacity(numberOfScenarios)
		let dimension = mean.count

		for _ in 0..<numberOfScenarios {
			var parameters: [String: Double] = [:]

			for i in 0..<dimension {
				let z = standardNormal(using: &generator)
				parameters["param_\(i)"] = mean[i] + standardDeviation[i] * z
			}

			scenarios.append(MonteCarloScenario(
				parameters: parameters,
				probability: 1.0 / Double(numberOfScenarios) // fp-safety:disable — numberOfScenarios > 0 from guard
			))
		}

		return scenarios
	}

	/// A standard normal variate by the Box–Muller transform.
	///
	/// The first uniform is taken as `1 - u`, not `u`, and that is the whole point of the
	/// helper. `Double.random(in: 0..<1)` can return exactly `0.0` — the interval is
	/// half-open at the *bottom* as well as closed nowhere — and `log(0)` is `-infinity`,
	/// which makes `z` non-finite and poisons every downstream statistic. Reflecting the
	/// draw fixes it without distorting anything: `u < 1` implies `1 - u > 0` in IEEE
	/// arithmetic for every representable `u`, and `u ↦ 1 - u` is a measure-preserving
	/// bijection of the unit interval, so the transformed draw is still uniform. Clamping
	/// to a small epsilon would also avoid the pole, but at the cost of an atom of
	/// probability piled on the clamp value.
	///
	/// The second uniform sits under a cosine, which is total, so it is used as drawn.
	private static func standardNormal<G: RandomNumberGenerator>(using generator: inout G) -> Double {
		// The shared transform. It draws the same two uniforms this used to draw for
		// itself — `1 - Double.random(in: 0..<1)` and `Double.random(in: 0..<1)` — and
		// `z2` is the cosine branch, so the output is bit-identical to what stood here.
		// The reasoning above is now recorded in `boxMuellerSeed.swift`, where every
		// caller can find it instead of one caller keeping it.
		let (_, z): (Double, Double) = boxMullerSeed(using: &generator)
		return z
	}

	// MARK: - Bootstrap

	/// Generate scenarios from historical data (bootstrap resampling).
	///
	/// - Parameters:
	///   - historicalData: Historical observations
	///   - numberOfScenarios: Number of bootstrap samples
	///   - seed: Seed for the private ``DeterministicRNG``. The same seed reproduces the
	///     same resample exactly, including when other seeded generations run at the same
	///     time. `nil` (the default) draws from system entropy and does not reproduce.
	/// - Returns: Array of Monte Carlo scenarios
	/// - Throws: `BusinessMathError.insufficientData` if `historicalData` is empty, or
	///   `BusinessMathError.invalidInput` if `numberOfScenarios` is not positive.
	public static func bootstrap(
		historicalData: [[Double]],
		numberOfScenarios: Int,
		seed: UInt64? = nil
	) throws -> [MonteCarloScenario] {
		if let seed {
			var generator = DeterministicRNG(seed: seed)
			return try bootstrap(historicalData: historicalData,
								 numberOfScenarios: numberOfScenarios, using: &generator)
		}
		var generator = SystemRandomNumberGenerator() // stochastic:exempt — the documented unseeded path; pass `seed:` for reproducibility
		return try bootstrap(historicalData: historicalData,
							 numberOfScenarios: numberOfScenarios, using: &generator)
	}

	/// Resample historical observations, drawing every index from `generator`.
	///
	/// The generator-parameterized form of
	/// ``bootstrap(historicalData:numberOfScenarios:seed:)``.
	///
	/// - Parameters:
	///   - historicalData: Historical observations
	///   - numberOfScenarios: Number of bootstrap samples
	///   - generator: The random source. Advanced once per scenario.
	/// - Returns: Array of Monte Carlo scenarios
	/// - Throws: `BusinessMathError.insufficientData` if `historicalData` is empty, or
	///   `BusinessMathError.invalidInput` if `numberOfScenarios` is not positive.
	public static func bootstrap<G: RandomNumberGenerator>(
		historicalData: [[Double]],
		numberOfScenarios: Int,
		using generator: inout G
	) throws -> [MonteCarloScenario] {
		guard !historicalData.isEmpty else {
			throw BusinessMathError.insufficientData(
				required: 1,
				actual: 0,
				context: "Historical data cannot be empty for scenario generation"
			)
		}
		guard numberOfScenarios > 0 else {
			throw BusinessMathError.invalidInput(
				message: "Number of scenarios must be positive",
				value: String(numberOfScenarios),
				expectedRange: "> 0"
			)
		}

		var scenarios: [MonteCarloScenario] = []
		scenarios.reserveCapacity(numberOfScenarios)
		// Safe: guard above ensures at least one element
		let dimension = historicalData[0].count

		for _ in 0..<numberOfScenarios {
			// Drawn as an integer rather than by truncating a scaled uniform: the integer
			// form is exactly uniform over the observations, whereas `Int(u * count)`
			// inherits the rounding of the floating-point product at the interval edges.
			let index = Int.random(in: 0..<historicalData.count, using: &generator)
			let sample = historicalData[index]

			var parameters: [String: Double] = [:]
			for i in 0..<dimension {
				parameters["param_\(i)"] = sample[i]
			}

			scenarios.append(MonteCarloScenario(
				parameters: parameters,
				probability: 1.0 / Double(numberOfScenarios) // fp-safety:disable — numberOfScenarios > 0 from guard
			))
		}

		return scenarios
	}

	// MARK: - Uniform

	/// Generate uniform random scenarios.
	///
	/// - Parameters:
	///   - lowerBounds: Lower bounds for each parameter
	///   - upperBounds: Upper bounds for each parameter
	///   - numberOfScenarios: Number of samples
	///   - seed: Seed for the private ``DeterministicRNG``. The same seed reproduces the
	///     same scenarios exactly, including when other seeded generations run at the same
	///     time. `nil` (the default) draws from system entropy and does not reproduce.
	/// - Returns: Array of Monte Carlo scenarios, or `[]` if the two bound vectors differ
	///   in length or `numberOfScenarios` is not positive.
	public static func uniform(
		lowerBounds: [Double],
		upperBounds: [Double],
		numberOfScenarios: Int,
		seed: UInt64? = nil
	) -> [MonteCarloScenario] {
		if let seed {
			var generator = DeterministicRNG(seed: seed)
			return uniform(lowerBounds: lowerBounds, upperBounds: upperBounds,
						   numberOfScenarios: numberOfScenarios, using: &generator)
		}
		var generator = SystemRandomNumberGenerator() // stochastic:exempt — the documented unseeded path; pass `seed:` for reproducibility
		return uniform(lowerBounds: lowerBounds, upperBounds: upperBounds,
					   numberOfScenarios: numberOfScenarios, using: &generator)
	}

	/// Generate uniform random scenarios, drawing every value from `generator`.
	///
	/// The generator-parameterized form of
	/// ``uniform(lowerBounds:upperBounds:numberOfScenarios:seed:)``.
	///
	/// - Parameters:
	///   - lowerBounds: Lower bounds for each parameter
	///   - upperBounds: Upper bounds for each parameter
	///   - numberOfScenarios: Number of samples
	///   - generator: The random source. Advanced once per parameter per scenario.
	/// - Returns: Array of Monte Carlo scenarios, or `[]` if the two bound vectors differ
	///   in length or `numberOfScenarios` is not positive.
	public static func uniform<G: RandomNumberGenerator>(
		lowerBounds: [Double],
		upperBounds: [Double],
		numberOfScenarios: Int,
		using generator: inout G
	) -> [MonteCarloScenario] {
		guard lowerBounds.count == upperBounds.count else {
			return []
		}
		guard numberOfScenarios > 0 else {
			return []
		}

		var scenarios: [MonteCarloScenario] = []
		scenarios.reserveCapacity(numberOfScenarios)
		let dimension = lowerBounds.count

		for _ in 0..<numberOfScenarios {
			var parameters: [String: Double] = [:]

			for i in 0..<dimension {
				// Interpolated rather than `Double.random(in: lower...upper)`, which traps
				// when a caller passes bounds the wrong way round. Inverted bounds still
				// produce values between them here, which is the behaviour this has always
				// had, and a library should not kill the process over an argument order.
				let u = Double.random(in: 0..<1, using: &generator)
				parameters["param_\(i)"] = lowerBounds[i] + u * (upperBounds[i] - lowerBounds[i])
			}

			scenarios.append(MonteCarloScenario(
				parameters: parameters,
				probability: 1.0 / Double(numberOfScenarios) // fp-safety:disable — numberOfScenarios > 0 from guard
			))
		}

		return scenarios
	}
}
