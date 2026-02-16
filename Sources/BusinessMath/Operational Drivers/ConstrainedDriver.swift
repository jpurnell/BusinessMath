//
//  ConstrainedDriver.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

/// A driver that applies constraints to values from another driver.
///
/// `ConstrainedDriver` wraps any driver and applies transformations or constraints
/// to ensure values fall within acceptable ranges. This is essential for financial
/// modeling where certain values must be realistic (e.g., quantities can't be negative,
/// prices must be positive, headcount must be integers).
///
/// ## Common Use Cases
///
/// **Ensure Positive Values:**
/// ```swift
/// let price = uncertainPrice.positive()  // Never negative
/// let quantity = uncertainQuantity.positive()
/// ```
///
/// **Clamp to Range:**
/// ```swift
/// let utilization = uncertainUtilization.clamped(min: 0.0, max: 1.0)  // 0-100%
/// let growthRate = uncertainGrowth.clamped(min: -0.5, max: 2.0)  // -50% to +200%
/// ```
///
/// **Integer Values:**
/// ```swift
/// let headcount = uncertainHeadcount.rounded()  // Whole employees
/// let units = uncertainUnits.rounded()  // Can't sell 10.5 units
/// ```
///
/// **Floor Values:**
/// ```swift
/// let revenue = uncertainRevenue.clamped(min: 0.0)  // No negative revenue
/// ```
///
/// ## Creating Constrained Drivers
///
/// Use the convenient extension methods on any `Driver`:
///
/// ```swift
/// let basePrice = ProbabilisticDriver.normal(name: "Price", mean: 100.0, stdDev: 20.0)
///
/// // Ensure price is always positive (clamp negatives to 0)
/// let positivePrice = basePrice.positive()
///
/// // Or set a reasonable floor
/// let sensiblePrice = basePrice.clamped(min: 50.0, max: 150.0)
/// ```
///
/// ## Example: Revenue Model with Constraints
///
/// ```swift
/// // Quantity: must be positive integer
/// let quantity = ProbabilisticDriver.normal(name: "Units", mean: 1000.0, stdDev: 100.0)
///     .positive()
///     .rounded()
///
/// // Price: must be between $50 and $150
/// let price = ProbabilisticDriver.triangular(name: "Price", low: 80.0, high: 120.0, base: 100.0)
///     .clamped(min: 50.0, max: 150.0)
///
/// // Revenue automatically inherits constraints
/// let revenue = quantity * price
/// ```
///
/// ## Monte Carlo Analysis
///
/// Constraints are applied during every sample, so Monte Carlo statistics
/// reflect the constrained distribution:
///
/// ```swift
/// let uncertainValue = ProbabilisticDriver.normal(name: "Value", mean: 10.0, stdDev: 5.0)
///     .positive()  // Clamp negatives
///
/// let projection = DriverProjection(driver: uncertainValue, periods: quarters)
/// let results = projection.projectMonteCarlo(iterations: 10_000)
///
/// // Statistics will show:
/// // - No negative values in P5, min, etc.
/// // - Mean slightly higher than 10 (due to clamping)
/// // - Reduced standard deviation
/// ```
///
/// ## Performance Notes
///
/// Constraints are applied at sample time, so there's minimal overhead.
/// The constraint function runs once per sample, which is typically negligible
/// compared to distribution sampling.
public struct ConstrainedDriver<Base: Driver>: Driver, Sendable where Base.Value: BinaryFloatingPoint {
	// MARK: - Properties

	/// The name of this driver.
	public let name: String

	/// The underlying driver being constrained.
	private let base: Base

	/// The constraint function applied to each sample.
	private let constraint: @Sendable (Base.Value) -> Base.Value

	// MARK: - Initialization

	/// Creates a constrained driver that applies a transformation to the base driver's values.
	///
	/// - Parameters:
	///   - name: The name of this driver (defaults to base driver's name).
	///   - base: The underlying driver to constrain.
	///   - constraint: A function that transforms/constrains the value.
	///
	/// ## Example
	/// ```swift
	/// let base = ProbabilisticDriver.normal(name: "Value", mean: 100.0, stdDev: 20.0)
	/// let constrained = ConstrainedDriver(base: base) { value in
	///     max(0.0, value)  // Ensure non-negative
	/// }
	/// ```
	public init(
		name: String? = nil,
		base: Base,
		constraint: @escaping @Sendable (Base.Value) -> Base.Value
	) {
		self.name = name ?? base.name
		self.base = base
		self.constraint = constraint
	}

	// MARK: - Driver Protocol

	/// Samples from the base driver and applies the constraint.
	///
	/// - Parameter period: The time period for which to generate a value.
	/// - Returns: The constrained value.
	public func sample(for period: Period) -> Base.Value {
		let rawValue = base.sample(for: period)
		return constraint(rawValue)
	}
}

// MARK: - Convenience Extensions

extension Driver where Value: BinaryFloatingPoint {
	/// Clamps values to a specified range.
	///
	/// Values below `min` are set to `min`, values above `max` are set to `max`.
	///
	/// - Parameters:
	///   - minValue: The minimum allowed value (optional).
	///   - maxValue: The maximum allowed value (optional).
	/// - Returns: A constrained driver with values in the specified range.
	///
	/// ## Example
	/// ```swift
	/// // Utilization rate between 0 and 1
	/// let utilization = baseUtilization.clamped(min: 0.0, max: 1.0)
	///
	/// // Minimum revenue (no max)
	/// let revenue = baseRevenue.clamped(min: 0.0)
	///
	/// // Growth rate bounds
	/// let growth = baseGrowth.clamped(min: -0.50, max: 2.0)  // -50% to +200%
	/// ```
	public func clamped(min minValue: Value? = nil, max maxValue: Value? = nil) -> ConstrainedDriver<Self> {
		return ConstrainedDriver(name: "\(name) (clamped)", base: self) { value in
			var result = value
			if let min = minValue {
				result = Swift.max(result, min)
			}
			if let max = maxValue {
				result = Swift.min(result, max)
			}
			return result
		}
	}

	/// Ensures values are positive (>= 0).
	///
	/// Negative values are clamped to zero. This is a convenience method
	/// equivalent to `clamped(min: 0)`.
	///
	/// - Returns: A constrained driver with no negative values.
	///
	/// ## Example
	/// ```swift
	/// let price = uncertainPrice.positive()  // No negative prices
	/// let quantity = uncertainQuantity.positive()  // No negative quantities
	/// let revenue = (quantity * price).positive()  // Ensure positive revenue
	/// ```
	public func positive() -> ConstrainedDriver<Self> {
		return clamped(min: Value.zero)
	}

	/// Rounds values to the nearest integer.
	///
	/// This is essential for quantities that must be whole numbers,
	/// such as headcount, unit sales, or inventory counts.
	///
	/// - Returns: A constrained driver with integer values.
	///
	/// ## Example
	/// ```swift
	/// let headcount = uncertainHeadcount.rounded()  // 47 or 48, never 47.3
	/// let units = uncertainUnits.rounded()  // Whole units
	/// ```
	public func rounded() -> ConstrainedDriver<Self> {
		return ConstrainedDriver(name: "\(name) (rounded)", base: self) { value in
			return value.rounded()
		}
	}

	/// Rounds values down to the nearest integer (floor).
	///
	/// Useful when you want conservative estimates or when the
	/// fractional part has no meaning.
	///
	/// - Returns: A constrained driver with floored integer values.
	///
	/// ## Example
	/// ```swift
	/// let completedUnits = productionRate.floored()  // Conservative estimate
	/// ```
	public func floored() -> ConstrainedDriver<Self> {
		return ConstrainedDriver(name: "\(name) (floored)", base: self) { value in
			return value.rounded(.down)
		}
	}

	/// Rounds values up to the nearest integer (ceiling).
	///
	/// Useful for capacity planning or when you need to ensure
	/// sufficient resources.
	///
	/// - Returns: A constrained driver with ceiling integer values.
	///
	/// ## Example
	/// ```swift
	/// let requiredStaff = workload.ceiling()  // Always have enough people
	/// ```
	public func ceiling() -> ConstrainedDriver<Self> {
		return ConstrainedDriver(name: "\(name) (ceiling)", base: self) { value in
			return value.rounded(.up)
		}
	}

	/// Applies a custom transformation to the values.
	///
	/// This is the most flexible constraint method, allowing any
	/// transformation function.
	///
	/// - Parameter transform: A function that transforms the value.
	/// - Returns: A constrained driver with the transformation applied.
	///
	/// ## Example
	/// ```swift
	/// // Apply a floor with exponential damping
	/// let smoothed = driver.transformed { value in
	///     value < 0 ? 0 : pow(value, 0.9)
	/// }
	///
	/// // Snap to grid
	/// let snapped = driver.transformed { value in
	///     (value / 5.0).rounded() * 5.0  // Round to nearest 5
	/// }
	///
	/// // Apply business logic
	/// let adjusted = driver.transformed { value in
	///     if value < 1000 { return value * 0.9 }  // Volume discount
	///     else { return value * 0.85 }
	/// }
	/// ```
	public func transformed(_ transform: @escaping @Sendable (Value) -> Value) -> ConstrainedDriver<Self> {
		return ConstrainedDriver(name: "\(name) (transformed)", base: self, constraint: transform)
	}
}

/// A driver that validates values and can throw errors for invalid inputs.
///
/// Unlike `ConstrainedDriver` which silently clamps/transforms values,
/// `ValidatedDriver` throws errors when values don't meet requirements.
/// This is useful when you want to detect and handle invalid scenarios
/// explicitly rather than silently correcting them.
///
/// **Note**: `ValidatedDriver` does not conform to the `Driver` protocol
/// because its `sample(for:)` method can throw errors. Use it when you
/// need explicit error handling rather than silent correction.
///
/// ## Example
/// ```swift
/// let price = basePrice.validated { value throws -> Double in
///     guard value > 0 else {
///         throw ValidationError.negativePrice
///     }
///     guard value <= 1000 else {
///         throw ValidationError.unrealisticPrice
///     }
///     return value
/// }
///
/// // Use with error handling
/// do {
///     let value = try price.sample(for: period)
///     print("Valid price: \(value)")
/// } catch {
///     print("Invalid price: \(error)")
/// }
/// ```
public struct ValidatedDriver<Base: Driver>: Sendable where Base.Value: BinaryFloatingPoint {
	// MARK: - Type Aliases

	/// The value type of this validated driver (matches the base driver).
	public typealias Value = Base.Value

	// MARK: - Properties
        /// - Parameters:
        ///   - name: The name of this driver (defaults to base driver's name).
        ///   - base: The underlying driver to validate.
        ///   - validator: A function that validates and potentially transforms the value.
	public let name: String
	private let base: Base
	private let validator: @Sendable (Base.Value) throws -> Base.Value

	// MARK: - Initialization

	/// Creates a validated driver.
	///
	/// - Parameters:
	///   - name: The name of this driver (defaults to base driver's name).
	///   - base: The underlying driver to validate.
	///   - validator: A function that validates and potentially transforms the value.
	///
	/// ## Example
	/// ```swift
	/// enum PriceError: Error {
	///     case negative
	///     case tooHigh
	/// }
	///
	/// let validatedPrice = ValidatedDriver(base: uncertainPrice) { value in
	///     guard value >= 0 else { throw PriceError.negative }
	///     guard value <= 1000 else { throw PriceError.tooHigh }
	///     return value
	/// }
	/// ```
	public init(
		name: String? = nil,
		base: Base,
		validator: @escaping @Sendable (Base.Value) throws -> Base.Value
	) {
		self.name = name ?? "\(base.name) (validated)"
		self.base = base
		self.validator = validator
	}

	// MARK: - Driver Protocol

	/// Samples from the base driver and validates the result.
	///
	/// - Parameter period: The time period for which to generate a value.
	/// - Returns: The validated value.
	/// - Throws: Any error thrown by the validator function.
	public func sample(for period: Period) throws -> Base.Value {
		let rawValue = base.sample(for: period)
		return try validator(rawValue)
	}

	// Note: This doesn't conform to Driver protocol's non-throwing sample(for:)
	// But we can add a failable version that returns nil on validation failure

	/// Samples with a fallback value on validation failure.
	///
	/// - Parameters:
	///   - period: The time period for which to generate a value.
	///   - fallback: Value to return if validation fails.
	/// - Returns: The validated value, or the fallback if validation fails.
	public func sample(for period: Period, fallback: Base.Value) -> Base.Value {
		let rawValue = base.sample(for: period)
		do {
			return try validator(rawValue)
		} catch {
			return fallback
		}
	}
}

extension Driver where Value: BinaryFloatingPoint {
	/// Validates values with a throwing function.
	///
	/// Returns a `ValidatedDriver` that throws errors when validation fails.
	/// Use this when you want explicit error handling rather than silent correction.
	///
	/// - Parameter validator: A function that validates the value and may throw errors.
	/// - Returns: A validated driver.
	///
	/// ## Example
	/// ```swift
	/// enum RevenueError: Error {
	///     case unrealisticValue
	/// }
	///
	/// let validatedRevenue = baseRevenue.validated { value in
	///     guard value >= 0 && value <= 10_000_000 else {
	///         throw RevenueError.unrealisticValue
	///     }
	///     return value
	/// }
	/// ```
	public func validated(
		_ validator: @escaping @Sendable (Value) throws -> Value
	) -> ValidatedDriver<Self> {
		return ValidatedDriver(base: self, validator: validator)
	}
}
