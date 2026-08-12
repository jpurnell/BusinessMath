//
//  DriverOptimization.swift
//  BusinessMath
//
//  Created by Justin Purnell on 12/04/25.
//

import Foundation
import Numerics

// MARK: - Optimizable Driver

/// Represents an operational driver that can be optimized.
///
/// ## Example
/// ```swift
/// let driver = OptimizableDriver(
///     name: "conversion_rate",
///     currentValue: 0.025,
///     range: 0.01...0.05,
///     changeConstraint: .percentageChange(max: 0.20)  // Max 20% change
/// )
/// ```
public struct OptimizableDriver: Sendable {
	/// Driver name (e.g., "conversion_rate", "churn_rate")
	public let name: String

	/// Current/baseline value
	public let currentValue: Double

	/// Feasible range for this driver
	public let range: ClosedRange<Double>

	/// Optional constraint on how much the driver can change
	public let changeConstraint: DriverChangeConstraint?

	/// Creates an optimizable driver.
	public init(
		name: String,
		currentValue: Double,
		range: ClosedRange<Double>,
		changeConstraint: DriverChangeConstraint? = nil
	) {
		self.name = name
		self.currentValue = currentValue
		self.range = range
		self.changeConstraint = changeConstraint
	}
}

// MARK: - Driver Change Constraint

/// Constraint on how much a driver can change from its current value.
public enum DriverChangeConstraint: Sendable {
	/// Absolute change limit: |new - current| ≤ max
	case absoluteChange(max: Double)

	/// Percentage change limit: |new/current - 1| ≤ max
	case percentageChange(max: Double)

	/// Step size for granular changes (e.g., 0.001)
	case stepSize(Double)
}

// MARK: - Financial Target

/// A financial metric target to achieve.
///
/// ## Example
/// ```swift
/// let target = FinancialTarget(
///     metric: "revenue",
///     target: .minimum(1_000_000),
///     weight: 1.0
/// )
/// ```
public struct FinancialTarget: Sendable {
	/// Metric name (e.g., "revenue", "EBITDA", "FCF")
	public let metric: String

	/// Target value or range
	public let target: TargetValue

	/// Weight for multi-objective optimization (higher = more important)
	public let weight: Double

	/// Creates a financial target.
	public init(
		metric: String,
		target: TargetValue,
		weight: Double = 1.0
	) {
		self.metric = metric
		self.target = target
		self.weight = weight
	}
}

// MARK: - Target Value

/// Target value specification for a financial metric.
public enum TargetValue: Sendable {
	/// Exact target value
	case exact(Double)

	/// Minimum acceptable value
	case minimum(Double)

	/// Maximum acceptable value
	case maximum(Double)

	/// Target range (min, max)
	case range(Double, Double)
}

// MARK: - Driver Objective

/// Objective function for driver optimization.
public enum DriverObjective: Sendable {
	/// Minimize changes to drivers (target seeking)
	case minimizeChange

	/// Minimize weighted cost of changes
	case minimizeCost([String: Double])  // driverName -> costPerUnitChange

	/// Maximize feasibility (soft penalties for missing targets)
	case maximizeFeasibility

	/// Custom objective
	case custom(@Sendable ([String: Double]) -> Double)  // driverValues -> score
}

// MARK: - Driver Optimization Result

/// Result from driver optimization.
public struct DriverOptimization: Sendable {
	/// Optimized driver values
	public let optimizedDrivers: [String: Double]

	/// Changes from current values
	public let driverChanges: [String: Double]

	/// Achieved metric values with optimized drivers
	public let achievedMetrics: [String: Double]

	/// Whether each target was fulfilled
	public let targetsFulfilled: [String: Bool]

	/// Whether all targets are feasible
	public let feasible: Bool

	/// Whether optimization converged
	public let converged: Bool

	/// Number of iterations
	public let iterations: Int

	/// Creates a driver optimization result.
	public init(
		optimizedDrivers: [String: Double],
		driverChanges: [String: Double],
		achievedMetrics: [String: Double],
		targetsFulfilled: [String: Bool],
		feasible: Bool,
		converged: Bool,
		iterations: Int
	) {
		self.optimizedDrivers = optimizedDrivers
		self.driverChanges = driverChanges
		self.achievedMetrics = achievedMetrics
		self.targetsFulfilled = targetsFulfilled
		self.feasible = feasible
		self.converged = converged
		self.iterations = iterations
	}
}

// MARK: - Driver Optimizer

/// Optimizer for finding driver values that achieve financial targets.
///
/// Solves target-seeking problems by optimizing operational drivers to hit
/// financial goals while minimizing changes from current values.
///
/// ## Example
/// ```swift
/// let drivers = [
///     OptimizableDriver(
///         name: "price",
///         currentValue: 100,
///         range: 80...120,
///         changeConstraint: .percentageChange(max: 0.15)
///     ),
///     OptimizableDriver(
///         name: "volume",
///         currentValue: 1000,
///         range: 800...1500
///     )
/// ]
///
/// let targets = [
///     FinancialTarget(
///         metric: "revenue",
///         target: .minimum(120_000),
///         weight: 1.0
///     )
/// ]
///
/// let optimizer = DriverOptimizer()
/// let result = try optimizer.optimize(
///     drivers: drivers,
///     targets: targets,
///     model: { driverValues in
///         // The model closure is non-throwing. Returning no metrics for an
///         // unresolved name leaves the target unfulfilled and `feasible == false`,
///         // which is reported back — unlike a trap, which ends the process.
///         guard let price = driverValues["price"],
///               let volume = driverValues["volume"] else { return [:] }
///         return ["revenue": price * volume]
///     }
/// )
///
/// print("Optimized drivers: \(result.optimizedDrivers)")
/// if let revenue = result.achievedMetrics["revenue"] {
///     print("Revenue: \(revenue)")
/// }
/// ```
public struct DriverOptimizer: Sendable {

	/// Maximum iterations for optimization
	public let maxIterations: Int

	/// Creates a driver optimizer.
	public init(maxIterations: Int = 200) {
		self.maxIterations = maxIterations
	}

	// MARK: - Public API

	/// Optimize driver values to achieve financial targets.
	///
	/// ## Epigraph reformulation
	///
	/// Both the "cost of change" objective and the soft target penalty are written
	/// with `abs` and `max(0, ·)`, and their kinks sit exactly where the answer does:
	/// `|x − current|` bends where a driver does not move, and `max(0, target −
	/// actual)` bends where the target is met. A central finite difference straddling
	/// such a kink reports a gradient that never decays, so the solver's KKT
	/// stationarity test can never be met — it exhausts its iteration budget and
	/// reports `converged == false` even when sitting on the right answer.
	///
	/// Each of those terms is therefore lifted into an auxiliary variable, which is an
	/// exact restatement rather than a smoothing:
	/// - `|xᵢ − cᵢ|` becomes `tᵢ` with `xᵢ − cᵢ − tᵢ ≤ 0` and `cᵢ − xᵢ − tᵢ ≤ 0`;
	///   minimizing a non-negative cost times `tᵢ` drives `tᵢ` down to `|xᵢ − cᵢ|`.
	/// - `max(0, v(x))` becomes `sⱼ` with `v(x) − sⱼ ≤ 0` and `−sⱼ ≤ 0`; the penalty
	///   uses `sⱼ²`, which is increasing in `sⱼ ≥ 0`, so `sⱼ` is driven down to
	///   `max(0, v(x))`.
	///
	/// The optimum and the reported drivers are unchanged; what changes is that every
	/// function handed to the solver is now smooth at the solution. `.exact` targets
	/// need no auxiliary variable — `((actual − target)/scale)²` is already smooth.
	///
	/// - Note: A model with `s` one-sided targets is evaluated once per objective
	///   evaluation plus once per slack constraint, so an expensive model costs
	///   proportionally more than the previous single-penalty formulation.
	///
	/// - Parameters:
	///   - drivers: Array of optimizable drivers
	///   - targets: Array of financial targets to achieve
	///   - model: Model function that maps driver values to metrics
	///   - objective: Objective function (default: .minimizeChange)
	/// - Returns: Optimal driver values and achieved metrics
	/// - Throws: `OptimizationError` if optimization fails
	public func optimize(
		drivers: [OptimizableDriver],
		targets: [FinancialTarget],
		model: @escaping @Sendable ([String: Double]) -> [String: Double],
		objective: DriverObjective = .minimizeChange
	) throws -> DriverOptimization {

		guard !drivers.isEmpty else {
			throw OptimizationError.invalidInput(message: "No drivers provided")
		}

		guard !targets.isEmpty else {
			throw OptimizationError.invalidInput(message: "No targets provided")
		}

		// Variable layout of the smooth problem actually handed to the optimizer
		let layout = Self.buildLayout(
			drivers: drivers,
			targets: targets,
			objective: objective
		)

		// Build objective function
		let objectiveFunction = buildObjectiveFunction(
			drivers: drivers,
			targets: targets,
			model: model,
			objective: objective,
			layout: layout
		)

		// Build constraints
		let constraints = buildConstraints(
			drivers: drivers,
			model: model,
			layout: layout
		)

		// Initial guess: start from current values, with each auxiliary variable set to
		// the value its own epigraph constraints force it to at that point.
		let initialValues = buildInitialValues(
			drivers: drivers,
			model: model,
			layout: layout
		)

		// The objective and the constraints index the auxiliary blocks by offset, so a
		// starting vector of the wrong width would silently read zeros rather than fail.
		guard initialValues.count == layout.variableCount else {
			throw OptimizationError.invalidInput(
				message: "Initial values (\(initialValues.count)) do not match the reformulated problem (\(layout.variableCount) variables)"
			)
		}

		// Run optimization (minimize objective)
		let optimizer = InequalityOptimizer<VectorN<Double>>(maxIterations: maxIterations)
		let result = try optimizer.minimize(
			objectiveFunction,
			from: initialValues,
			subjectTo: constraints
		)

		// Build result
		return buildResult(
			drivers: drivers,
			targets: targets,
			values: result.solution,
			model: model,
			layout: layout,
			converged: result.converged,
			iterations: result.iterations
		)
	}

	// MARK: - Epigraph Reformulation

	/// One auxiliary variable standing in for a one-sided target violation.
	///
	/// The original penalty charged `max(0, v(x))²`. Here `v(x)` is pushed into a
	/// constraint and the variable carries the `max`, so the objective sees only `s²`.
	private struct TargetSlack: Sendable {
		/// Metric this slack watches.
		let metric: String
		/// The bound the metric is measured against.
		let bound: Double
		/// Normalizer, `max(|bound|, 1)` — never zero, so the division below is safe.
		let denominator: Double
		/// `true` when the violation is `(bound − actual)`, `false` when `(actual − bound)`.
		let measuresShortfall: Bool
		/// Weight the target carried.
		let weight: Double
	}

	/// Variable layout of the smooth problem handed to the optimizer.
	///
	/// Components are laid out as `[drivers | change magnitudes | target slacks]`.
	/// The driver block always comes first, so every consumer that reads only
	/// `values[0..<drivers.count]` keeps working unchanged.
	///
	/// Drivers are held in *normalised* coordinates: component `i` is `xᵢ / scaleᵢ`,
	/// where `scaleᵢ` is the largest magnitude driver `i` can take. Without this a
	/// model mixing a conversion rate near `0.03` with a traffic figure near `10 000`
	/// is handed to the solver with a Hessian spanning ten orders of magnitude, and
	/// the solver's own equilibration cannot repair it: it divides every variable by a
	/// *single* scalar (the largest component), which leaves the ratios between
	/// variables exactly as bad as they were. Normalising per driver is a change of
	/// variables — the feasible set and the optimum are untouched — but it is the
	/// difference between the augmented Lagrangian converging in single-digit outer
	/// iterations and it exhausting its budget.
	private struct ProblemLayout: Sendable {
		/// Number of decision drivers — also the offset of the first auxiliary block.
		let driverCount: Int
		/// Per-driver normalisation factor. Strictly positive.
		let scales: [Double]
		/// Each driver's current value in normalised coordinates, `cᵢ / scaleᵢ`.
		let centres: [Double]
		/// Offset of the `|xᵢ − cᵢ|` block. Meaningful only when ``usesChangeMagnitudes``.
		let changeOffset: Int
		/// Whether the `|xᵢ − cᵢ|` epigraph block is present (`.minimizeCost` only).
		let usesChangeMagnitudes: Bool
		/// Offset of the target-slack block.
		let slackOffset: Int
		/// One entry per slack variable, in component order.
		let slacks: [TargetSlack]
		/// Whether any `.exact` target remains in the objective (it needs no slack).
		let hasExactTargets: Bool
		/// Total number of components in the augmented decision vector.
		let variableCount: Int
	}

	/// The normalisation factor for one driver: the largest magnitude it can take.
	///
	/// Falls back to `1` for a driver pinned at zero, which is the only case where the
	/// magnitudes above are all zero and the division would not be safe.
	private static func normalisationScale(for driver: OptimizableDriver) -> Double {
		let currentMagnitude = abs(driver.currentValue)
		let lowerMagnitude = abs(driver.range.lowerBound)
		let upperMagnitude = abs(driver.range.upperBound)
		let boundsMagnitude = Swift.max(lowerMagnitude, upperMagnitude)
		let largest = Swift.max(currentMagnitude, boundsMagnitude)
		guard largest.isFinite, largest > 0 else { return 1.0 }
		return largest
	}

	/// The penalty the original formulation charged for a metric the model does not
	/// produce was a flat `1000 · weight`. A slack of `√1000` reproduces it exactly
	/// through the `s² · weight` term.
	private static let missingMetricSlack: Double = Double(1000).squareRoot()

	private static func buildLayout(
		drivers: [OptimizableDriver],
		targets: [FinancialTarget],
		objective: DriverObjective
	) -> ProblemLayout {

		let driverCount = drivers.count
		let scales = drivers.map { normalisationScale(for: $0) }
		let centres = zip(drivers, scales).map { $0.currentValue / $1 }

		// `.custom` hands the caller's own function to the optimizer untouched and
		// ignores the targets, so there is nothing here to reformulate. The driver
		// normalisation still applies — it is a change of variables, not a change of
		// objective, and the caller's function still sees real driver values.
		if case .custom = objective {
			return ProblemLayout(
				driverCount: driverCount,
				scales: scales,
				centres: centres,
				changeOffset: driverCount,
				usesChangeMagnitudes: false,
				slackOffset: driverCount,
				slacks: [],
				hasExactTargets: false,
				variableCount: driverCount
			)
		}

		var usesChangeMagnitudes = false
		if case .minimizeCost = objective {
			usesChangeMagnitudes = true
		}

		let changeOffset = driverCount
		let slackOffset = usesChangeMagnitudes ? (driverCount + driverCount) : driverCount

		var slacks: [TargetSlack] = []
		var hasExactTargets = false

		for target in targets {
			switch target.target {
			case .exact:
				// ((actual − target)/scale)² is smooth everywhere; no lift needed.
				hasExactTargets = true
			case .minimum(let value):
				slacks.append(TargetSlack(
					metric: target.metric,
					bound: value,
					denominator: Swift.max(abs(value), 1.0),
					measuresShortfall: true,
					weight: target.weight
				))
			case .maximum(let value):
				slacks.append(TargetSlack(
					metric: target.metric,
					bound: value,
					denominator: Swift.max(abs(value), 1.0),
					measuresShortfall: false,
					weight: target.weight
				))
			case .range(let minValue, let maxValue):
				// Falling below the floor and rising above the ceiling are mutually
				// exclusive, so summing the two squared slacks reproduces the single
				// piecewise violation the original penalty computed.
				slacks.append(TargetSlack(
					metric: target.metric,
					bound: minValue,
					denominator: Swift.max(abs(minValue), 1.0),
					measuresShortfall: true,
					weight: target.weight
				))
				slacks.append(TargetSlack(
					metric: target.metric,
					bound: maxValue,
					denominator: Swift.max(abs(maxValue), 1.0),
					measuresShortfall: false,
					weight: target.weight
				))
			}
		}

		let variableCount = slackOffset + slacks.count

		return ProblemLayout(
			driverCount: driverCount,
			scales: scales,
			centres: centres,
			changeOffset: changeOffset,
			usesChangeMagnitudes: usesChangeMagnitudes,
			slackOffset: slackOffset,
			slacks: slacks,
			hasExactTargets: hasExactTargets,
			variableCount: variableCount
		)
	}

	/// The normalized violation a slack variable must dominate.
	private static func slackViolation(
		_ slack: TargetSlack,
		metrics: [String: Double]
	) -> Double {
		guard let actual = metrics[slack.metric] else {
			return missingMetricSlack
		}
		let gap: Double = slack.measuresShortfall ? (slack.bound - actual) : (actual - slack.bound)
		return gap / slack.denominator
	}

	// MARK: - Private Helpers

	private func buildObjectiveFunction(
		drivers: [OptimizableDriver],
		targets: [FinancialTarget],
		model: @escaping @Sendable ([String: Double]) -> [String: Double],
		objective: DriverObjective,
		layout: ProblemLayout
	) -> @Sendable (VectorN<Double>) -> Double {

		// Create local copies for Sendable closures
		let driversCopy = drivers
		let targetsCopy = targets
		let modelCopy = model
		let layoutCopy = layout

		switch objective {
		case .minimizeChange:
			return { [self] values in
				let totalChange = Self.changeCost(
					values: values,
					drivers: driversCopy,
					layout: layoutCopy
				)

				// Soft penalty for missing targets, now read off the slack variables
				let penalty = self.smoothTargetPenalty(
					values: values,
					drivers: driversCopy,
					targets: targetsCopy,
					model: modelCopy,
					layout: layoutCopy
				)

				return totalChange + 100.0 * penalty  // Heavy penalty for missing targets
			}

		case .minimizeCost(let costs):
			let changeOffset = layout.changeOffset
			let scales = layout.scales
			return { [self] values in
				// Weighted sum of the |change| epigraph variables. Those live in
				// normalised coordinates, so each is restored to real driver units
				// before the caller's per-unit cost is applied.
				var totalCost = 0.0
				for (i, driver) in driversCopy.enumerated() {
					let magnitude = values[changeOffset + i]
					let realMagnitude = magnitude * scales[i]
					let cost = costs[driver.name] ?? 1.0
					totalCost += realMagnitude * cost
				}

				// Soft penalty for missing targets (high weight to ensure feasibility)
				let penalty = self.smoothTargetPenalty(
					values: values,
					drivers: driversCopy,
					targets: targetsCopy,
					model: modelCopy,
					layout: layoutCopy
				)

				return totalCost + 10000.0 * penalty
			}

		case .maximizeFeasibility:
			return { [self] values in
				// Just the penalty (minimize penalty = maximize feasibility)
				self.smoothTargetPenalty(
					values: values,
					drivers: driversCopy,
					targets: targetsCopy,
					model: modelCopy,
					layout: layoutCopy
				)
			}

		case .custom(let customFunction):
			return { [self] values in
				let driverDict = self.buildDriverDictionary(drivers: driversCopy, values: values, layout: layoutCopy)
				return customFunction(driverDict)
			}
		}
	}

	/// Sum of squared normalized driver changes: `Σ((new − current)/current)²`.
	///
	/// The change is taken in normalised coordinates and scaled back up, not the other
	/// way round. `(cᵢ/scaleᵢ)·scaleᵢ` is not exactly `cᵢ` in binary floating point, and
	/// at the starting point — where the change is genuinely zero — that round-trip
	/// leaves a residue near 1e-15. The solver reads the objective's scale off its
	/// finite-difference gradient there, accepts the residue as a real gradient, and
	/// divides the whole objective by ~1e-16, after which no stationarity test can ever
	/// be met. Differencing `values[i] − centre[i]` is exact when the driver has not
	/// moved, so a zero change reads as exactly zero.
	private static func changeCost(
		values: VectorN<Double>,
		drivers: [OptimizableDriver],
		layout: ProblemLayout
	) -> Double {
		var totalChange = 0.0
		for (i, driver) in drivers.enumerated() {
			let offset = values[i] - layout.centres[i]
			let change = offset * layout.scales[i]
			let normalizedChange = change / Swift.max(abs(driver.currentValue), 1e-6)
			totalChange += normalizedChange * normalizedChange
		}
		return totalChange
	}

	/// Target penalty in reformulated coordinates.
	///
	/// One-sided targets contribute `sⱼ² · weight` where `sⱼ` is the slack variable
	/// the epigraph constraints pin to `max(0, violation)`. `.exact` targets are
	/// already smooth and are evaluated directly from the model.
	private func smoothTargetPenalty(
		values: VectorN<Double>,
		drivers: [OptimizableDriver],
		targets: [FinancialTarget],
		model: @escaping ([String: Double]) -> [String: Double],
		layout: ProblemLayout
	) -> Double {

		var penalty = 0.0

		for (j, slack) in layout.slacks.enumerated() {
			let s = values[layout.slackOffset + j]
			let squared: Double = s * s
			penalty += squared * slack.weight
		}

		// Only `.exact` targets still need the model here; skipping the call otherwise
		// keeps the common case at one model evaluation per constraint, not two.
		guard layout.hasExactTargets else { return penalty }

		let driverDict = buildDriverDictionary(drivers: drivers, values: values, layout: layout)
		let metrics = model(driverDict)

		for target in targets {
			guard case .exact(let value) = target.target else { continue }

			guard let actual = metrics[target.metric] else {
				penalty += 1000.0 * target.weight  // Large penalty for missing metric
				continue
			}

			let denominator = Swift.max(abs(value), 1.0)
			let normalized: Double = (actual - value) / denominator
			let squared: Double = normalized * normalized
			penalty += squared * target.weight
		}

		return penalty
	}

	private func buildConstraints(
		drivers: [OptimizableDriver],
		model: @escaping @Sendable ([String: Double]) -> [String: Double],
		layout: ProblemLayout
	) -> [MultivariateConstraint<VectorN<Double>>] {

		var constraints: [MultivariateConstraint<VectorN<Double>>] = []

		// Every bound below is divided by the driver's own normalisation scale, which
		// is strictly positive — a restatement of the same constraint in the
		// coordinates the solver actually works in, not a relaxation of it.
		let scales = layout.scales
		let centres = layout.centres

		// Range constraints for each driver
		for (i, driver) in drivers.enumerated() {
			let scale = scales[i]
			let lower = driver.range.lowerBound / scale
			let upper = driver.range.upperBound / scale

			// Lower bound: z[i] ≥ lower  =>  lower - z[i] ≤ 0
			constraints.append(.inequality { values in
				lower - values[i]
			})

			// Upper bound: z[i] ≤ upper  =>  z[i] - upper ≤ 0
			constraints.append(.inequality { values in
				values[i] - upper
			})
		}

		// Change constraints
		for (i, driver) in drivers.enumerated() {
			guard let changeConstraint = driver.changeConstraint else { continue }

			let scale = scales[i]
			let centre = centres[i]

			switch changeConstraint {
			case .absoluteChange(let max):
				// |new - current| ≤ max
				// Enforce as two constraints, in normalised coordinates:
				let allowance = max / scale
				// new - current ≤ max
				constraints.append(.inequality { values in
					let change = values[i] - centre
					return change - allowance
				})
				// current - new ≤ max
				constraints.append(.inequality { values in
					let change = centre - values[i]
					return change - allowance
				})

			case .percentageChange(let max):
				// |new/current - 1| ≤ max
				let upperCentre = centre * (1.0 + max)
				let lowerCentre = centre * (1.0 - max)
				// new ≤ current * (1 + max)
				constraints.append(.inequality { values in
					values[i] - upperCentre
				})
				// new ≥ current * (1 - max)
				constraints.append(.inequality { values in
					lowerCentre - values[i]
				})

			case .stepSize:
				// Step size constraints require integer programming - not supported
				// Ignore for continuous optimization
				break
			}
		}

		// Epigraph constraints for |xᵢ − cᵢ|: tᵢ ≥ zᵢ − centreᵢ and tᵢ ≥ centreᵢ − zᵢ,
		// with tᵢ carried in the same normalised units as zᵢ.
		if layout.usesChangeMagnitudes {
			let changeOffset = layout.changeOffset
			for i in drivers.indices {
				let centre = centres[i]
				// zᵢ − centreᵢ − tᵢ ≤ 0
				constraints.append(.inequality { values in
					let change = values[i] - centre
					return change - values[changeOffset + i]
				})
				// centreᵢ − zᵢ − tᵢ ≤ 0
				constraints.append(.inequality { values in
					let change = centre - values[i]
					return change - values[changeOffset + i]
				})
			}
		}

		// Epigraph constraint for max(0, violation): sⱼ ≥ violationⱼ(x).
		//
		// `sⱼ ≥ 0` is *not* stated. It would be redundant and actively harmful: the
		// objective charges `sⱼ²`, whose minimum over `sⱼ ≥ violation` is already
		// `max(0, violation)` — a negative `sⱼ` costs more than zero does, so nothing
		// drives it below zero. Stating it anyway adds a constraint that is weakly
		// active, with a zero multiplier, at exactly the solutions where a target is
		// comfortably met (`sⱼ = 0`), which is the degenerate case the KKT residual has
		// the hardest time certifying.
		let slackOffset = layout.slackOffset
		let driversCopy = drivers
		for (j, slack) in layout.slacks.enumerated() {
			let slackIndex = slackOffset + j
			constraints.append(.inequality { values in
				let dict = Self.driverDictionary(drivers: driversCopy, values: values, layout: layout)
				let metrics = model(dict)
				let violation = Self.slackViolation(slack, metrics: metrics)
				return violation - values[slackIndex]
			})
		}

		return constraints
	}

	private func buildInitialValues(
		drivers: [OptimizableDriver],
		model: @escaping @Sendable ([String: Double]) -> [String: Double],
		layout: ProblemLayout
	) -> VectorN<Double> {
		// Start from current values (likely feasible), in normalised coordinates
		var values = layout.centres

		// Every change magnitude starts at |cᵢ − cᵢ| = 0, its exact epigraph value here.
		if layout.usesChangeMagnitudes {
			values.append(contentsOf: [Double](repeating: 0.0, count: layout.driverCount))
		}

		// Each slack starts at max(0, violation) at the current drivers, so the
		// starting point is feasible for its own epigraph constraints.
		if !layout.slacks.isEmpty {
			var dict: [String: Double] = [:]
			for driver in drivers {
				dict[driver.name] = driver.currentValue
			}
			let metrics = model(dict)
			for slack in layout.slacks {
				let violation = Self.slackViolation(slack, metrics: metrics)
				values.append(Swift.max(0.0, violation))
			}
		}

		return VectorN(values)
	}

	/// Driver values in real units, from a vector in normalised coordinates.
	///
	/// Written as `current + offset·scale` rather than `value·scale` so that a driver
	/// sitting at its starting point reproduces `currentValue` bit for bit; the direct
	/// product does not, and the residue shows up in reported results and in
	/// finite-difference gradients alike.
	private static func driverDictionary(
		drivers: [OptimizableDriver],
		values: VectorN<Double>,
		layout: ProblemLayout
	) -> [String: Double] {
		var dict: [String: Double] = [:]
		for (i, driver) in drivers.enumerated() {
			let offset = values[i] - layout.centres[i]
			let change = offset * layout.scales[i]
			dict[driver.name] = driver.currentValue + change
		}
		return dict
	}

	private func buildDriverDictionary(
		drivers: [OptimizableDriver],
		values: VectorN<Double>,
		layout: ProblemLayout
	) -> [String: Double] {
		Self.driverDictionary(drivers: drivers, values: values, layout: layout)
	}

	private func buildResult(
		drivers: [OptimizableDriver],
		targets: [FinancialTarget],
		values: VectorN<Double>,
		model: ([String: Double]) -> [String: Double],
		layout: ProblemLayout,
		converged: Bool,
		iterations: Int
	) -> DriverOptimization {

		// Build driver dictionaries, back in the caller's own units
		let optimizedDrivers = buildDriverDictionary(drivers: drivers, values: values, layout: layout)

		var driverChanges: [String: Double] = [:]
		for (i, driver) in drivers.enumerated() {
			// Differenced in normalised coordinates so an untouched driver reports
			// exactly 0.0 rather than the residue of a round-trip through its scale.
			let offset = values[i] - layout.centres[i]
			driverChanges[driver.name] = offset * layout.scales[i]
		}

		// Run model with optimized drivers
		let achievedMetrics = model(optimizedDrivers)

		// Check target fulfillment
		var targetsFulfilled: [String: Bool] = [:]
		var allFeasible = true

		for target in targets {
			guard let actual = achievedMetrics[target.metric] else {
				targetsFulfilled[target.metric] = false
				allFeasible = false
				continue
			}

			let fulfilled: Bool
			switch target.target {
			case .exact(let value):
				// Allow 1% tolerance for "exact"
				fulfilled = abs(actual - value) / max(abs(value), 1.0) < 0.01
			case .minimum(let value):
				fulfilled = actual >= value * 0.99  // 1% tolerance
			case .maximum(let value):
				fulfilled = actual <= value * 1.01  // 1% tolerance
			case .range(let minValue, let maxValue):
				fulfilled = actual >= minValue * 0.99 && actual <= maxValue * 1.01
			}

			targetsFulfilled[target.metric] = fulfilled
			if !fulfilled {
				allFeasible = false
			}
		}

		return DriverOptimization(
			optimizedDrivers: optimizedDrivers,
			driverChanges: driverChanges,
			achievedMetrics: achievedMetrics,
			targetsFulfilled: targetsFulfilled,
			feasible: allFeasible,
			converged: converged,
			iterations: iterations
		)
	}
}
