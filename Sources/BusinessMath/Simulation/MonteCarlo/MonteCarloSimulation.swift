//
//  MonteCarloSimulation.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

/// A Monte Carlo simulation engine for modeling uncertainty in complex systems.
///
/// MonteCarloSimulation provides a powerful framework for:
/// - Modeling systems with multiple uncertain variables
/// - Analyzing complex interdependencies between variables
/// - Quantifying risk and uncertainty in outcomes
/// - Making data-driven decisions under uncertainty
///
/// ## How It Works
///
/// 1. Define uncertain input variables using `SimulationInput`
/// 2. Define a model function that computes an outcome from inputs
/// 3. Run thousands of iterations, sampling from input distributions
/// 4. Analyze the distribution of outcomes using `SimulationResults`
///
/// ## Example - Simple Financial Model
///
/// ```swift
/// // Model: Profit = Revenue - Costs
/// var simulation = MonteCarloSimulation(iterations: 10_000) { inputs in
///     let revenue = inputs[0]
///     let costs = inputs[1]
///     return revenue - costs
/// }
///
/// // Define uncertain variables
/// simulation.addInput(SimulationInput(
///     name: "Revenue",
///     distribution: DistributionNormal(mean: 1_000_000, stdDev: 100_000)
/// ))
///
/// simulation.addInput(SimulationInput(
///     name: "Costs",
///     distribution: DistributionNormal(mean: 700_000, stdDev: 50_000)
/// ))
///
/// // Run simulation
/// let results = try simulation.run()
///
/// // Analyze results
/// print("Mean profit: $\(results.statistics.mean)")
/// print("95% confidence: [$\(results.percentiles.p5), $\(results.percentiles.p95)]")
/// print("Probability of loss: \(results.probabilityBelow(0) * 100)%")
/// ```
///
/// ## Example - Complex Project Model
///
/// ```swift
/// // Model: Project NPV with multiple uncertainties
/// var simulation = MonteCarloSimulation(iterations: 10_000) { inputs in
///     let initialCost = inputs[0]
///     let annualRevenue = inputs[1]
///     let growthRate = inputs[2]
///     let discountRate = inputs[3]
///     let years = 5.0
///
///     var npv = -initialCost
///     for year in 1...Int(years) {
///         let revenue = annualRevenue * pow(1 + growthRate, Double(year))
///         let pv = revenue / pow(1 + discountRate, Double(year))
///         npv += pv
///     }
///     return npv
/// }
///
/// simulation.addInput(SimulationInput(name: "InitialCost",
///     distribution: DistributionTriangular(low: 800_000, high: 1_200_000, base: 1_000_000)))
/// simulation.addInput(SimulationInput(name: "AnnualRevenue",
///     distribution: DistributionNormal(mean: 500_000, stdDev: 50_000)))
/// simulation.addInput(SimulationInput(name: "GrowthRate",
///     distribution: DistributionUniform(0.05, 0.15)))
/// simulation.addInput(SimulationInput(name: "DiscountRate",
///     distribution: DistributionUniform(0.08, 0.12)))
///
/// let results = try simulation.run()
/// print("Expected NPV: $\(results.statistics.mean)")
/// print("P(NPV > 0): \(results.probabilityAbove(0) * 100)%")
/// ```
public struct MonteCarloSimulation: Sendable {

	// MARK: - Properties

	/// The number of iterations to run
	///
	/// More iterations provide more accurate results but take longer to compute.
	/// Typical values:
	/// - 1,000: Quick analysis
	/// - 10,000: Standard analysis
	/// - 100,000+: High-precision analysis
	public let iterations: Int

	/// The model function that computes outcomes from inputs
	///
	/// The function receives an array of sampled values (one per input variable)
	/// and returns a single outcome value.
	///
	/// - Parameter inputs: Array of sampled values in the order inputs were added
	/// - Returns: The computed outcome for this iteration
	private let model: @Sendable ([Double]) -> Double

	/// The uncertain input variables
	public private(set) var inputs: [SimulationInput]

	/// Whether GPU acceleration is enabled
	///
	/// When `true`, the simulation will use GPU acceleration for large simulations
	/// (≥ 1000 iterations) if Metal is available and the model is GPU-compatible.
	/// Automatically falls back to CPU if GPU is unavailable or model is not supported.
	public let enableGPU: Bool

	/// Optional expression model for GPU acceleration
	///
	/// When present, the simulation can compile the model to GPU bytecode.
	/// Expression models provide automatic GPU acceleration for large simulations.
	private let expressionModel: MonteCarloExpressionModel?

	#if canImport(Metal)
	/// GPU device manager for Metal acceleration
	private let gpuDevice: MonteCarloGPUDevice?
	#endif

	// MARK: - Initialization

	/// Creates a new Monte Carlo simulation.
	///
	/// - Parameters:
	///   - iterations: Number of iterations to run (must be > 0)
	///   - enableGPU: Enable GPU acceleration for large simulations (default: true)
	///   - model: The model function that computes outcomes from sampled inputs
	///
	/// ## Example
	///
	/// ```swift
	/// let sim = MonteCarloSimulation(iterations: 10_000) { inputs in
	///     // Your model logic here
	///     return inputs[0] * inputs[1]
	/// }
	/// ```
	///
	/// ## GPU Acceleration
	///
	/// When `enableGPU` is `true` and iterations ≥ 1000:
	/// - Automatically uses GPU (Metal) if available
	/// - Falls back to CPU if GPU unavailable or model not supported
	/// - Typical speedup: 10-100x for large simulations
	public init(iterations: Int, enableGPU: Bool = true, model: @escaping @Sendable ([Double]) -> Double) {
		self.iterations = iterations
		self.enableGPU = enableGPU
		self.model = model
		self.inputs = []
		self.expressionModel = nil  // Closure-based models don't have expression representation

		#if canImport(Metal)
		// Initialize GPU device if enabled
		if enableGPU {
			self.gpuDevice = MonteCarloGPUDevice()
		} else {
			self.gpuDevice = nil
		}
		#endif
	}

	/// Creates a new Monte Carlo simulation with an expression-based model.
	///
	/// Expression models provide automatic GPU acceleration for large simulations
	/// (≥ 1000 iterations) when Metal is available. The model is automatically
	/// compiled to GPU bytecode for efficient parallel execution.
	///
	/// - Parameters:
	///   - iterations: Number of iterations to run (must be > 0)
	///   - enableGPU: Enable GPU acceleration (default: true)
	///   - expressionModel: Expression-based model for GPU acceleration
	///
	/// ## Example - GPU-Accelerated Simulation
	///
	/// ```swift
	/// // Define model using expression builder
	/// let model = MonteCarloExpressionModel { builder in
	///     let revenue = builder[0]
	///     let costs = builder[1]
	///     return revenue - costs
	/// }
	///
	/// // Create simulation with GPU acceleration
	/// var simulation = MonteCarloSimulation(
	///     iterations: 100_000,
	///     enableGPU: true,
	///     expressionModel: model
	/// )
	///
	/// // Add inputs
	/// simulation.addInput(SimulationInput(
	///     name: "Revenue",
	///     distribution: DistributionNormal(1_000_000, 100_000)
	/// ))
	/// simulation.addInput(SimulationInput(
	///     name: "Costs",
	///     distribution: DistributionNormal(700_000, 50_000)
	/// ))
	///
	/// // Run on GPU (if available) or CPU (fallback)
	/// let results = try simulation.run()
	///
	/// // Check execution path
	/// print("Executed on: \(results.usedGPU ? "GPU ⚡" : "CPU")")
	/// ```
	///
	/// ## Automatic Fallback
	///
	/// GPU execution automatically falls back to CPU when:
	/// - Metal is unavailable (older Macs, non-Apple platforms)
	/// - Iterations < 1000 (CPU is faster for small simulations)
	/// - GPU execution fails (rare)
	///
	/// Results are statistically equivalent regardless of execution path.
	public init(iterations: Int, enableGPU: Bool = true, expressionModel: MonteCarloExpressionModel) {
		self.iterations = iterations
		self.enableGPU = enableGPU
		self.expressionModel = expressionModel
		self.model = expressionModel.toClosure()  // Store closure for CPU fallback
		self.inputs = []

		#if canImport(Metal)
		// Initialize GPU device if enabled
		if enableGPU {
			self.gpuDevice = MonteCarloGPUDevice()
		} else {
			self.gpuDevice = nil
		}
		#endif
	}

	/// Creates a new Monte Carlo simulation with default parameters.
	///
	/// This initializer is useful when using the `runCorrelated` method
	/// which accepts all parameters directly.
	///
	/// ## Example
	///
	/// ```swift
	/// let sim = MonteCarloSimulation()
	/// let results = try sim.runCorrelated(
	///     inputs: [input1, input2],
	///     correlationMatrix: correlation,
	///     iterations: 10_000
	/// ) { samples in
	///     return samples[0] - samples[1]
	/// }
	/// ```
	public init() {
		self.iterations = 0
		self.enableGPU = false
		self.model = { _ in 0.0 }
		self.inputs = []
		self.expressionModel = nil

		#if canImport(Metal)
		self.gpuDevice = nil
		#endif
	}

	// MARK: - Input Management

	/// Adds an uncertain input variable to the simulation.
	///
	/// Inputs are stored in the order they are added. The model function receives
	/// sampled values in this same order.
	///
	/// - Parameter input: The input variable to add
	///
	/// ## Example
	///
	/// ```swift
	/// var simulation = MonteCarloSimulation(iterations: 10_000) { inputs in
	///     return inputs[0] + inputs[1]  // inputs[0] is Revenue, inputs[1] is Costs
	/// }
	///
	/// simulation.addInput(SimulationInput(name: "Revenue",
	///     distribution: DistributionNormal(mean: 1_000_000, stdDev: 100_000)))
	/// simulation.addInput(SimulationInput(name: "Costs",
	///     distribution: DistributionNormal(mean: 700_000, stdDev: 50_000)))
	/// ```
	public mutating func addInput(_ input: SimulationInput) {
		inputs.append(input)
	}

	// MARK: - Execution

	/// Runs the Monte Carlo simulation and returns comprehensive results.
	///
	/// This method:
	/// 1. Validates that iterations > 0 and at least one input exists
	/// 2. Runs the specified number of iterations
	/// 3. For each iteration, samples from all input distributions
	/// 4. Passes sampled values to the model function
	/// 5. Collects all outcomes
	/// 6. Computes statistics and percentiles
	///
	/// - Returns: Complete simulation results including statistics, percentiles, and probabilities
	/// - Throws: `SimulationError` if validation fails or model produces invalid results
	///
	/// ## Example
	///
	/// ```swift
	/// var simulation = MonteCarloSimulation(iterations: 10_000) { inputs in
	///     return inputs[0] - inputs[1]
	/// }
	///
	/// simulation.addInput(SimulationInput(name: "Revenue",
	///     distribution: DistributionNormal(mean: 1_000_000, stdDev: 100_000)))
	/// simulation.addInput(SimulationInput(name: "Costs",
	///     distribution: DistributionNormal(mean: 700_000, stdDev: 50_000)))
	///
	/// do {
	///     let results = try simulation.run()
	///     print("Expected profit: $\(results.statistics.mean)")
	///     print("Risk of loss: \(results.probabilityBelow(0) * 100)%")
	/// } catch {
	///     print("Simulation failed: \(error)")
	/// }
	/// ```
	public func run() throws -> SimulationResults {
		// Validate inputs
		guard iterations > 0 else {
			throw SimulationError.insufficientIterations
		}

		guard !inputs.isEmpty else {
			throw SimulationError.noInputs
		}

		#if canImport(Metal)
		// Try GPU path if eligible
		if enableGPU && iterations >= 1000 && gpuDevice != nil {
			// Check if inputs are GPU-compatible
			if let distributionConfigs = getGPUDistributionConfigs() {
				// Check if model can be compiled for GPU
				if let modelBytecode = compileModelForGPU() {
					// Attempt GPU execution
					do {
						let gpuResults = try gpuDevice!.runSimulation(
							distributions: distributionConfigs,
							modelBytecode: modelBytecode,
							iterations: iterations
						)

						// Convert Float results to Double
						let outcomes = gpuResults.map { Double($0) }

						// Return GPU results
						return SimulationResults(values: outcomes, usedGPU: true)
					} catch {
						// GPU failed, fall back to CPU
						// (Error is silently caught - automatic fallback behavior)
					}
				}
			}
		}
		#endif

		// CPU path (original implementation)
		var outcomes: [Double] = []
		outcomes.reserveCapacity(iterations)

		for iteration in 0..<iterations {
			// Sample from all input distributions
			let sampledValues = inputs.map { $0.sample() }

			// Run model function
			let outcome = model(sampledValues)

			// Validate outcome
			guard outcome.isFinite else {
				throw SimulationError.invalidModel(
					iteration: iteration,
					details: outcome.isNaN ? "NaN result" : "Infinite result"
				)
			}

			outcomes.append(outcome)
		}

		// Create and return results
		return SimulationResults(values: outcomes, usedGPU: false)
	}

	// MARK: - Correlated Variables

	/// Runs a Monte Carlo simulation with correlated input variables.
	///
	/// This method allows you to model dependencies between uncertain variables
	/// using a correlation matrix. It uses Cholesky decomposition to generate
	/// correlated random samples that preserve the specified correlation structure.
	///
	/// ## Correlation Matrix Requirements
	///
	/// The correlation matrix must:
	/// - Be square (n×n for n inputs)
	/// - Be symmetric: matrix[i][j] == matrix[j][i]
	/// - Have unit diagonal: matrix[i][i] == 1.0
	/// - Have bounded values: -1.0 ≤ matrix[i][j] ≤ 1.0
	/// - Be positive semi-definite
	///
	/// ## Example
	///
	/// ```swift
	/// // Model revenue with positively correlated costs
	/// let revenue = SimulationInput(name: "Revenue",
	///     distribution: DistributionNormal(1_000_000, 100_000))
	/// let costs = SimulationInput(name: "Costs",
	///     distribution: DistributionNormal(700_000, 50_000))
	///
	/// // 70% correlation between revenue and costs
	/// let correlation = [
	///     [1.0, 0.7],
	///     [0.7, 1.0]
	/// ]
	///
	/// let simulation = MonteCarloSimulation()
	/// let results = try simulation.runCorrelated(
	///     inputs: [revenue, costs],
	///     correlationMatrix: correlation,
	///     iterations: 10_000
	/// ) { samples in
	///     return samples[0] - samples[1]  // Profit = Revenue - Costs
	/// }
	/// ```
	///
	/// - Parameters:
	///   - inputs: Array of uncertain input variables
	///   - correlationMatrix: n×n correlation matrix where n = inputs.count
	///   - iterations: Number of simulation iterations to run
	///   - calculation: Function that computes outcome from correlated samples
	/// - Returns: Complete simulation results with statistics and percentiles
	/// - Throws: `SimulationError` if validation fails or calculation produces invalid results
	public func runCorrelated(
		inputs: [SimulationInput],
		correlationMatrix: [[Double]],
		iterations: Int,
		calculation: @Sendable ([Double]) -> Double
	) throws -> SimulationResults {
		// Validate parameters
		guard iterations > 0 else {
			throw SimulationError.insufficientIterations
		}

		guard !inputs.isEmpty else {
			throw SimulationError.noInputs
		}

		// Validate correlation matrix dimensions
		guard correlationMatrix.count == inputs.count else {
			throw SimulationError.correlationDimensionMismatch
		}

		// Validate correlation matrix properties
		guard isValidCorrelationMatrix(correlationMatrix) else {
			throw SimulationError.invalidCorrelationMatrix
		}

		// Use Iman-Conover method to induce correlation:
		// 1. Generate independent samples from each distribution
		// 2. Generate correlated ranks using CorrelatedNormals
		// 3. Reorder samples according to correlated ranks

		// Step 1: Generate independent samples for each input
		var independentSamples: [[Double]] = []
		for input in inputs {
			var samples: [Double] = []
			samples.reserveCapacity(iterations)
			for _ in 0..<iterations {
				samples.append(input.sample())
			}
			// Sort samples to enable rank-based reordering
			samples.sort()
			independentSamples.append(samples)
		}

		// Step 2: Generate correlated ranks
		let means = Array(repeating: 0.0, count: inputs.count)
		let correlatedNormals = try CorrelatedNormals(
			means: means,
			correlationMatrix: correlationMatrix
		)

		// Generate correlated uniform values for ranking
		var correlatedRanks: [[Double]] = Array(repeating: [], count: inputs.count)
		for i in 0..<inputs.count {
			correlatedRanks[i].reserveCapacity(iterations)
		}

		for _ in 0..<iterations {
			let correlatedSample = correlatedNormals.sample()
			for i in 0..<inputs.count {
				// Convert standard normal to uniform [0,1]
				let uniformValue = normalCDF(correlatedSample[i])
				correlatedRanks[i].append(uniformValue)
			}
		}

		// Step 3: Reorder samples and run calculations
		var outcomes: [Double] = []
		outcomes.reserveCapacity(iterations)

		for iteration in 0..<iterations {
			var sampledValues: [Double] = []
			sampledValues.reserveCapacity(inputs.count)

			for i in 0..<inputs.count {
				// Use the correlated rank to select from sorted samples
				let uniformRank = correlatedRanks[i][iteration]
				let index = Int(uniformRank * Double(iterations - 1))
				let clampedIndex = min(max(index, 0), iterations - 1)
				sampledValues.append(independentSamples[i][clampedIndex])
			}

			// Run calculation
			let outcome = calculation(sampledValues)

			// Validate outcome
			guard outcome.isFinite else {
				throw SimulationError.invalidModel(
					iteration: iteration,
					details: outcome.isNaN ? "NaN result" : "Infinite result"
				)
			}

			outcomes.append(outcome)
		}

		return SimulationResults(values: outcomes)
	}

	// MARK: - GPU Support

	#if canImport(Metal)
	/// Checks if the simulation inputs are GPU-compatible
	///
	/// GPU-compatible distributions:
	/// - DistributionNormal
	/// - DistributionUniform
	/// - DistributionTriangular
	///
	/// - Returns: true if all inputs are GPU-compatible
	private func areInputsGPUCompatible() -> Bool {
		for input in inputs {
			guard let dist = input.originalDistribution else {
				return false  // Custom sampler, not GPU-compatible
			}
			// Check if distribution is one of the supported types
			if !(dist is DistributionNormal ||
				 dist is DistributionUniform ||
				 dist is DistributionTriangular) {
				return false
			}
		}
		return true
	}

	/// Extracts GPU distribution configurations from inputs
	///
	/// Maps SimulationInput distributions to GPU-compatible format:
	/// - Normal(mean, stdDev) → (type: 0, params: (mean, stdDev, 0))
	/// - Uniform(min, max) → (type: 1, params: (min, max, 0))
	/// - Triangular(min, max, mode) → (type: 2, params: (min, max, mode))
	///
	/// - Returns: Array of (type, params) tuples for GPU
	private func getGPUDistributionConfigs() -> [(type: Int32, params: (Float, Float, Float))]? {
		guard areInputsGPUCompatible() else { return nil }

		var configs: [(type: Int32, params: (Float, Float, Float))] = []

		for input in inputs {
			guard let dist = input.originalDistribution else {
				return nil  // Custom sampler
			}

			if let normal = dist as? DistributionNormal {
				// Normal distribution: type = 0
				configs.append((type: 0, params: (Float(normal.mean), Float(normal.stdDev), 0.0)))
			} else if let uniform = dist as? DistributionUniform {
				// Uniform distribution: type = 1
				configs.append((type: 1, params: (Float(uniform.min), Float(uniform.max), 0.0)))
			} else if let triangular = dist as? DistributionTriangular {
				// Triangular distribution: type = 2
				configs.append((type: 2, params: (Float(triangular.low), Float(triangular.high), Float(triangular.base))))
			} else {
				return nil  // Unsupported distribution
			}
		}

		return configs
	}

	/// Compiles the model function into GPU bytecode
	///
	/// If an expression model is present, returns its pre-compiled GPU bytecode.
	/// For closure-based models, returns nil (triggers CPU fallback).
	///
	/// - Returns: Array of bytecode operations or nil if not GPU-compatible
	private func compileModelForGPU() -> [(opcode: Int32, arg1: Int32, arg2: Float)]? {
		// If we have an expression model, use its pre-compiled bytecode
		guard let expressionModel = self.expressionModel else {
			// Closure-based model - cannot compile to GPU bytecode
			return nil
		}

		// Get GPU-compatible bytecode from expression model
		let bytecode = expressionModel.gpuBytecode()

		// Validate bytecode is not empty
		guard !bytecode.isEmpty else {
			return nil
		}

		return bytecode
	}
	#endif
}

// MARK: - Helper Functions

/// Computes the cumulative distribution function (CDF) of the standard normal distribution.
///
/// - Parameter x: The value at which to evaluate the CDF
/// - Returns: The probability that a standard normal random variable is less than or equal to x
private func normalCDF(_ x: Double) -> Double {
	// Standard normal CDF: Φ(x) = 0.5 * (1 + erf(x / sqrt(2)))
	return 0.5 * (1.0 + erf(x / sqrt(2.0)))
}
