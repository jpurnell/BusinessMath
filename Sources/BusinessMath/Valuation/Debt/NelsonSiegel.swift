//
//  NelsonSiegel.swift
//  BusinessMath
//
//  Nelson-Siegel yield curve model for term structure of interest rates
//
//  Created by Claude Code on 2026-02-05.
//

import Foundation
import Numerics

// MARK: - Nelson-Siegel Parameters

/// Parameters for the Nelson-Siegel yield curve model
///
/// The Nelson-Siegel model represents the yield curve using four parameters:
/// ```
/// Y(τ) = β₀ + β₁·[(1-exp(-τ/λ))/(τ/λ)] + β₂·[(1-exp(-τ/λ))/(τ/λ) - exp(-τ/λ)]
/// ```
///
/// Where:
/// - **β₀** (level): Long-term rate (lim τ→∞ Y(τ))
/// - **β₁** (slope): Short-term component (determines Y(0) - Y(∞))
/// - **β₂** (curvature): Medium-term hump or trough
/// - **λ** (decay): Controls the decay rate and location of maximum curvature
public struct NelsonSiegelParameters: Sendable, Codable {
	/// Long-term interest rate level
	public var beta0: Double

	/// Short-term slope component
	public var beta1: Double

	/// Medium-term curvature component
	public var beta2: Double

	/// Decay parameter (controls shape flexibility)
	public var lambda: Double

	/// Creates Nelson-Siegel parameters with specified values
	///
	/// - Parameters:
	///   - beta0: Level parameter (typically 0.03-0.08 for 3-8%)
	///   - beta1: Slope parameter (typically -0.03 to 0.03)
	///   - beta2: Curvature parameter (typically -0.03 to 0.03)
	///   - lambda: Decay parameter (typically 1.0-5.0, default: 2.5)
	public init(beta0: Double, beta1: Double, beta2: Double, lambda: Double = 2.5) {
		self.beta0 = beta0
		self.beta1 = beta1
		self.beta2 = beta2
		self.lambda = lambda
	}

	/// Creates parameters with typical starting values for calibration
	public static func defaultInitial() -> NelsonSiegelParameters {
		NelsonSiegelParameters(beta0: 0.05, beta1: -0.01, beta2: 0.005, lambda: 2.5)
	}
}

// MARK: - Nelson-Siegel Yield Curve

/// Nelson-Siegel parametric yield curve model
///
/// The Nelson-Siegel model is a widely-used parametric model for fitting and forecasting
/// the term structure of interest rates. It was introduced by Nelson and Siegel (1987)
/// and is used by central banks and financial institutions worldwide.
///
/// ## Key Features
///
/// - **Parsimony**: Only 4 parameters describe entire yield curve
/// - **Flexibility**: Can capture level, slope, and curvature (humps/troughs)
/// - **Interpretability**: Parameters have economic meaning
/// - **Smoothness**: Produces smooth, realistic curves
///
/// ## Model Specification
///
/// ```
/// Y(τ) = β₀ + β₁·f₁(τ) + β₂·f₂(τ)
/// ```
///
/// Where:
/// - f₁(τ) = (1-exp(-τ/λ))/(τ/λ) → Short-term factor (1 at τ=0, decays to 0)
/// - f₂(τ) = f₁(τ) - exp(-τ/λ) → Medium-term factor (hump-shaped)
///
/// ## Usage Example
///
/// ```swift
/// // Calibrate to market bond prices
/// let bonds: [BondMarketData] = loadMarketData()
/// let curve = try NelsonSiegelYieldCurve.calibrate(to: bonds)
///
/// // Get yields at any maturity
/// let yield5Y = curve.yield(maturity: 5.0)
/// let yield10Y = curve.yield(maturity: 10.0)
///
/// // Price a bond using the fitted curve
/// let bond = Bond(faceValue: 100, couponRate: 0.05, maturity: 10.0)
/// let price = curve.price(bond: bond)
/// ```
public struct NelsonSiegelYieldCurve: Sendable, Codable {
	/// Model parameters
	public var parameters: NelsonSiegelParameters

	/// Creates a Nelson-Siegel yield curve with specified parameters
	public init(parameters: NelsonSiegelParameters) {
		self.parameters = parameters
	}

	// MARK: - Yield Calculation

	/// Calculate the yield for a given maturity
	///
	/// - Parameter maturity: Time to maturity in years
	/// - Returns: Continuously compounded yield (as decimal, e.g., 0.05 = 5%)
	public func yield(maturity: Double) -> Double {
		let tau = maturity
		let beta0 = parameters.beta0
		let beta1 = parameters.beta1
		let beta2 = parameters.beta2
		let lambda = parameters.lambda

		// Handle very short maturities (numerical stability)
		guard tau > 1e-6 else {
			// Limit as tau → 0: Y(0) = β₀ + β₁
			return beta0 + beta1
		}

		// Calculate factors
		let expTerm = exp(-tau / lambda)
		let tauOverLambda = tau / lambda

		// f₁(τ) = (1 - exp(-τ/λ)) / (τ/λ)
		let factor1: Double
		if abs(tauOverLambda) > 1e-10 {
			factor1 = (1.0 - expTerm) / tauOverLambda
		} else {
			// Taylor expansion for small τ/λ: f₁ ≈ 1 - τ/(2λ)
			factor1 = 1.0 - tauOverLambda / 2.0
		}

		// f₂(τ) = f₁(τ) - exp(-τ/λ)
		let factor2 = factor1 - expTerm

		// Y(τ) = β₀ + β₁·f₁(τ) + β₂·f₂(τ)
		return beta0 + beta1 * factor1 + beta2 * factor2
	}

	/// Calculate yields for multiple maturities
	///
	/// - Parameter maturities: Array of maturities in years
	/// - Returns: Array of yields (same length as input)
	public func yields(maturities: [Double]) -> [Double] {
		maturities.map { yield(maturity: $0) }
	}

	// MARK: - Forward Rates

	/// Calculate the instantaneous forward rate at a given maturity
	///
	/// The forward rate f(τ) is the derivative of the yield curve:
	/// ```
	/// f(τ) = Y(τ) + τ·dY/dτ
	/// ```
	///
	/// - Parameter maturity: Time to maturity in years
	/// - Returns: Instantaneous forward rate
	public func forwardRate(maturity: Double) -> Double {
		let tau = maturity
		let beta1 = parameters.beta1
		let beta2 = parameters.beta2
		let lambda = parameters.lambda

		guard tau > 1e-6 else {
			return parameters.beta0 + beta1
		}

		let expTerm = exp(-tau / lambda)

		// f(τ) = β₀ + β₁·exp(-τ/λ) + β₂·(τ/λ)·exp(-τ/λ)
		return parameters.beta0 + beta1 * expTerm + beta2 * (tau / lambda) * expTerm
	}
}

// MARK: - Bond Market Data

/// Market data for a bond used in yield curve calibration
public struct BondMarketData: Sendable, Codable {
	/// Years to maturity
	public let maturity: Double

	/// Annual coupon rate (as decimal, e.g., 0.05 = 5%)
	public let couponRate: Double

	/// Face value (par value)
	public let faceValue: Double

	/// Observed market price
	public let marketPrice: Double

	/// Payment frequency (payments per year)
	public let frequency: Int

	public init(maturity: Double, couponRate: Double, faceValue: Double, marketPrice: Double, frequency: Int = 2) {
		self.maturity = maturity
		self.couponRate = couponRate
		self.faceValue = faceValue
		self.marketPrice = marketPrice
		self.frequency = frequency
	}
}

// MARK: - Calibration

extension NelsonSiegelYieldCurve {
	/// Bond pricing using the Nelson-Siegel yield curve
	///
	/// Prices a bond by discounting cash flows using yields from the curve.
	/// Uses continuous compounding: PV = CF · exp(-y·t)
	///
	/// - Parameter bond: Bond market data
	/// - Returns: Theoretical price based on the yield curve
	public func price(bond: BondMarketData) -> Double {
		let periodsPerYear = Double(bond.frequency)
		let totalPeriods = Int(bond.maturity * periodsPerYear)
		let couponPayment = bond.faceValue * bond.couponRate / periodsPerYear

		var price = 0.0

		// Present value of coupons
		for t in 1...max(1, totalPeriods) {
			let timeToPayment = Double(t) / periodsPerYear
			let yieldRate = yield(maturity: timeToPayment)
			let discountFactor = exp(-yieldRate * timeToPayment)
			price += couponPayment * discountFactor
		}

		// Present value of face value
		let finalYield = yield(maturity: bond.maturity)
		price += bond.faceValue * exp(-finalYield * bond.maturity)

		return price
	}

	/// Calculate sum of squared pricing errors across all bonds
	///
	/// This is the objective function for calibration:
	/// ```
	/// SSE = Σ(P_market - P_model)²
	/// ```
	///
	/// - Parameter bonds: Array of bond market data
	/// - Returns: Sum of squared errors
	public func sumSquaredErrors(bonds: [BondMarketData]) -> Double {
		bonds.reduce(0.0) { sum, bond in
			let modelPrice = price(bond: bond)
			let error = bond.marketPrice - modelPrice
			return sum + error * error
		}
	}

	/// Calibrate Nelson-Siegel parameters to fit bond market prices
	///
	/// Uses L-BFGS optimization to minimize sum of squared pricing errors.
	/// The optimization finds β₀, β₁, β₂ that best fit observed bond prices,
	/// while keeping λ fixed.
	///
	/// - Parameters:
	///   - bonds: Array of bond market observations
	///   - fixedLambda: Decay parameter (fixed during optimization, default: 2.5)
	///   - initialGuess: Starting parameter values (if nil, uses defaults)
	///   - maxIterations: Maximum optimization iterations
	///   - tolerance: Convergence tolerance
	///
	/// - Returns: Calibrated yield curve
	/// - Throws: OptimizationError if calibration fails
	///
	/// ## Example
	/// ```swift
	/// let treasuries = [
	///     BondMarketData(maturity: 1, couponRate: 0.05, faceValue: 100, marketPrice: 98.8),
	///     BondMarketData(maturity: 5, couponRate: 0.06, faceValue: 100, marketPrice: 96.5),
	///     BondMarketData(maturity: 10, couponRate: 0.062, faceValue: 100, marketPrice: 95.2)
	/// ]
	///
	/// let curve = try NelsonSiegelYieldCurve.calibrate(to: treasuries)
	/// print("Calibrated β₀: \(curve.parameters.beta0)")
	/// ```
	public static func calibrate(
		to bonds: [BondMarketData],
		fixedLambda: Double = 2.5,
		initialGuess: NelsonSiegelParameters? = nil,
		maxIterations: Int = 200,
		tolerance: Double = 1e-6
	) throws -> NelsonSiegelYieldCurve {
		// Get initial parameter guess
		let initial = initialGuess ?? estimateInitialParameters(bonds: bonds, lambda: fixedLambda)

		// Create objective function: minimize sum of squared pricing errors
		// We optimize over (β₀, β₁, β₂) with λ fixed
		let objective: (VectorN<Double>) -> Double = { params in
			let beta0 = params[0]
			let beta1 = params[1]
			let beta2 = params[2]

			let curve = NelsonSiegelYieldCurve(parameters: NelsonSiegelParameters(
				beta0: beta0,
				beta1: beta1,
				beta2: beta2,
				lambda: fixedLambda
			))

			return curve.sumSquaredErrors(bonds: bonds)
		}

		// Set up L-BFGS optimizer
		let optimizer = MultivariateLBFGS<VectorN<Double>>(
			memorySize: 10,
			maxIterations: maxIterations,
			tolerance: tolerance,
			useLineSearch: true,
			recordHistory: false
		)

		// Initial guess as vector
		let x0 = VectorN([initial.beta0, initial.beta1, initial.beta2])

		// Run optimization
		let result = try optimizer.minimizeLBFGS(function: objective, initialGuess: x0)

		// Extract optimized parameters
		let optimizedParams = NelsonSiegelParameters(
			beta0: result.solution[0],
			beta1: result.solution[1],
			beta2: result.solution[2],
			lambda: fixedLambda
		)

		return NelsonSiegelYieldCurve(parameters: optimizedParams)
	}

	/// Estimate initial parameters from bond data
	///
	/// Uses simple heuristics to provide a reasonable starting point:
	/// - β₀: Average yield across all bonds (proxy for long-term rate)
	/// - β₁: Difference between short and long rates (slope)
	/// - β₂: Small curvature to allow hump fitting
	///
	/// - Parameters:
	///   - bonds: Bond market data
	///   - lambda: Fixed decay parameter
	/// - Returns: Initial parameter guess
	private static func estimateInitialParameters(
		bonds: [BondMarketData],
		lambda: Double
	) -> NelsonSiegelParameters {
		// Approximate yields from bond prices
		let approxYields = bonds.map { bond -> Double in
			// Simple yield approximation: (FV - Price) / Price / Maturity + Coupon
			let yieldEst = (bond.faceValue - bond.marketPrice) / bond.marketPrice / bond.maturity + bond.couponRate
			return min(max(yieldEst, 0.01), 0.20)  // Clamp to [1%, 20%]
		}

		// β₀: Average yield (long-term level)
		let avgYield = approxYields.reduce(0, +) / Double(approxYields.count)
		let beta0 = min(max(avgYield, 0.03), 0.10)

		// β₁: Slope (short rate - long rate)
		// Approximate as difference between shortest and longest
		if let shortYield = approxYields.first, let longYield = approxYields.last {
			let slope = shortYield - longYield
			let beta1 = min(max(slope, -0.03), 0.03)

			// β₂: Small curvature
			let beta2 = 0.005

			return NelsonSiegelParameters(beta0: beta0, beta1: beta1, beta2: beta2, lambda: lambda)
		}

		// Fallback to defaults
		return NelsonSiegelParameters.defaultInitial()
	}
}

// MARK: - Calibration Result

/// Result of Nelson-Siegel calibration with diagnostics
public struct NelsonSiegelCalibrationResult: Sendable {
	/// Calibrated yield curve
	public let curve: NelsonSiegelYieldCurve

	/// Sum of squared pricing errors
	public let sumSquaredErrors: Double

	/// Mean absolute pricing error
	public let meanAbsoluteError: Double

	/// Root mean squared error
	public let rootMeanSquaredError: Double

	/// Number of optimization iterations
	public let iterations: Int

	/// Whether optimization converged
	public let converged: Bool

	/// Individual bond pricing errors
	public let bondErrors: [(maturity: Double, marketPrice: Double, modelPrice: Double, error: Double)]

	public init(
		curve: NelsonSiegelYieldCurve,
		bonds: [BondMarketData],
		iterations: Int,
		converged: Bool
	) {
		self.curve = curve
		self.iterations = iterations
		self.converged = converged

		// Calculate pricing errors
		var errors: [(Double, Double, Double, Double)] = []
		var sumSquaredErr = 0.0
		var sumAbsErr = 0.0

		for bond in bonds {
			let modelPrice = curve.price(bond: bond)
			let error = bond.marketPrice - modelPrice
			errors.append((bond.maturity, bond.marketPrice, modelPrice, error))
			sumSquaredErr += error * error
			sumAbsErr += abs(error)
		}

		self.sumSquaredErrors = sumSquaredErr
		self.meanAbsoluteError = sumAbsErr / Double(bonds.count)
		self.rootMeanSquaredError = sqrt(sumSquaredErr / Double(bonds.count))
		self.bondErrors = errors
	}
}

extension NelsonSiegelYieldCurve {
	/// Calibrate with detailed diagnostic results
	///
	/// Same as `calibrate(to:)` but returns comprehensive calibration diagnostics
	/// including pricing errors, convergence info, and fit statistics.
	///
	/// - Parameters:
	///   - bonds: Bond market data
	///   - fixedLambda: Decay parameter (default: 2.5)
	///   - initialGuess: Starting parameters (optional)
	///   - maxIterations: Maximum iterations
	///   - tolerance: Convergence tolerance
	///
	/// - Returns: Detailed calibration result with diagnostics
	/// - Throws: OptimizationError if calibration fails
	public static func calibrateWithDiagnostics(
		to bonds: [BondMarketData],
		fixedLambda: Double = 2.5,
		initialGuess: NelsonSiegelParameters? = nil,
		maxIterations: Int = 200,
		tolerance: Double = 1e-6
	) throws -> NelsonSiegelCalibrationResult {
		let initial = initialGuess ?? estimateInitialParameters(bonds: bonds, lambda: fixedLambda)

		let objective: (VectorN<Double>) -> Double = { params in
			let curve = NelsonSiegelYieldCurve(parameters: NelsonSiegelParameters(
				beta0: params[0],
				beta1: params[1],
				beta2: params[2],
				lambda: fixedLambda
			))
			return curve.sumSquaredErrors(bonds: bonds)
		}

		let optimizer = MultivariateLBFGS<VectorN<Double>>(
			memorySize: 10,
			maxIterations: maxIterations,
			tolerance: tolerance,
			useLineSearch: true,
			recordHistory: true
		)

		let x0 = VectorN([initial.beta0, initial.beta1, initial.beta2])
		let result = try optimizer.minimizeLBFGS(function: objective, initialGuess: x0)

		let curve = NelsonSiegelYieldCurve(parameters: NelsonSiegelParameters(
			beta0: result.solution[0],
			beta1: result.solution[1],
			beta2: result.solution[2],
			lambda: fixedLambda
		))

		return NelsonSiegelCalibrationResult(
			curve: curve,
			bonds: bonds,
			iterations: result.iterations,
			converged: result.converged
		)
	}
}
