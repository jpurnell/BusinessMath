import Foundation

/// Represents a capital investment project with NPV and cost information.
///
/// Use `CapitalProject` to model investment opportunities in capital budgeting decisions.
/// Projects can have dependencies (must select another project first) and mutual exclusivity
/// constraints (cannot select both projects).
///
/// ## Example
/// ```swift
/// let project = CapitalProject(
///     name: "Factory Expansion",
///     npv: 500_000,
///     cost: 2_000_000,
///     requires: "Site Preparation",
///     mutuallyExclusiveWith: "Warehouse Renovation"
/// )
/// ```
public struct CapitalProject: Sendable {
    /// The project identifier/name.
    public let name: String

    /// The net present value of the project's cash flows.
    ///
    /// Projects with positive NPV add value; higher NPV is preferred.
    public let npv: Double

    /// The total capital cost across all periods.
    ///
    /// This is the sum of `periodicCosts`.
    public let cost: Double

    /// The capital costs required in each time period.
    ///
    /// For single-period projects, this contains one element equal to `cost`.
    /// For multi-period projects, this tracks when capital is deployed over time.
    public let periodicCosts: [Double]

    /// Optional dependency: name of another project that must be selected first.
    ///
    /// If specified, this project can only be selected if the required project is also selected.
    /// Use this to model logical dependencies (e.g., "Phase 2" requires "Phase 1").
    public let requires: String?

    /// Optional mutual exclusivity: name of another project that cannot be selected together.
    ///
    /// If specified, at most one of this project and the mutually exclusive project can be selected.
    /// Use this to model competing alternatives (e.g., "Build" vs "Buy").
    public let mutuallyExclusiveWith: String?

    /// Create a single-period capital project
    public init(
        name: String,
        npv: Double,
        cost: Double,
        requires: String? = nil,
        mutuallyExclusiveWith: String? = nil
    ) {
        self.name = name
        self.npv = npv
        self.cost = cost
        self.periodicCosts = [cost]
        self.requires = requires
        self.mutuallyExclusiveWith = mutuallyExclusiveWith
    }

    /// Create a multi-period capital project
    public init(
        name: String,
        npv: Double,
        periodicCosts: [Double],
        requires: String? = nil,
        mutuallyExclusiveWith: String? = nil
    ) {
        self.name = name
        self.npv = npv
        self.cost = periodicCosts.reduce(0, +)
        self.periodicCosts = periodicCosts
        self.requires = requires
        self.mutuallyExclusiveWith = mutuallyExclusiveWith
    }
}

/// Optimization objective for capital budgeting
public enum CapitalBudgetingObjective: Sendable {
    case totalNPV              // Maximize total NPV
    case profitabilityIndex    // Maximize NPV per dollar spent
}

/// Result of capital budgeting optimization.
///
/// Contains the optimal selection of projects that maximizes the objective function
/// while respecting budget constraints and project dependencies.
///
/// ## Example
/// ```swift
/// let result = try optimizer.selectProjects(projects: allProjects, budget: 10_000_000)
/// print("Selected \(result.selectedProjects.count) projects")
/// print("Total NPV: $\(result.totalNPV)")
/// print("Total Cost: $\(result.totalCost)")
/// print("Profitability Index: \(result.profitabilityIndex)")
/// ```
public struct CapitalBudgetingResult: Sendable {
    /// The projects selected by the optimizer.
    ///
    /// These projects jointly maximize the objective while satisfying all constraints.
    public let selectedProjects: [CapitalProject]

    /// The combined NPV of all selected projects.
    public let totalNPV: Double

    /// The combined capital cost of all selected projects.
    public let totalCost: Double

    /// The profitability index: total NPV divided by total cost.
    ///
    /// Measures the value created per dollar invested. Higher is better.
    /// Returns 0 if `totalCost` is 0.
    public let profitabilityIndex: Double

    /// The solution status from the integer programming solver.
    ///
    /// - `.optimal`: Found the best possible selection
    /// - `.feasible`: Found a valid selection but may not be optimal
    /// - `.infeasible`: No selection satisfies all constraints
    /// - `.unbounded`: Problem is not well-formed
    public let status: IntegerSolutionStatus

    /// Creates a capital budgeting result.
    ///
    /// - Parameters:
    ///   - selectedProjects: The projects chosen by the optimizer.
    ///   - totalNPV: The sum of NPVs for selected projects.
    ///   - totalCost: The sum of costs for selected projects.
    ///   - status: The optimization solution status.
    public init(
        selectedProjects: [CapitalProject],
        totalNPV: Double,
        totalCost: Double,
        status: IntegerSolutionStatus
    ) {
        self.selectedProjects = selectedProjects
        self.totalNPV = totalNPV
        self.totalCost = totalCost
        self.profitabilityIndex = totalCost > 0 ? totalNPV / totalCost : 0
        self.status = status
    }
}

/// Optimizer for capital budgeting and project selection problems.
///
/// Uses mixed-integer programming via branch-and-bound to find the optimal selection
/// of capital projects that maximizes NPV or profitability index while respecting
/// budget constraints, project dependencies, and mutual exclusivity.
///
/// ## Example
/// ```swift
/// let optimizer = CapitalBudgetingOptimizer(maxNodes: 50_000, timeLimit: 120.0)
///
/// let projects = [
///     CapitalProject(name: "Project A", npv: 100_000, cost: 300_000),
///     CapitalProject(name: "Project B", npv: 80_000, cost: 200_000),
///     CapitalProject(name: "Project C", npv: 60_000, cost: 150_000)
/// ]
///
/// let result = try optimizer.selectProjects(
///     projects: projects,
///     budget: 500_000,
///     objective: .totalNPV
/// )
/// ```
public struct CapitalBudgetingOptimizer: Sendable {
    private let maxNodes: Int
    private let timeLimit: Double

    /// Creates a capital budgeting optimizer with solver limits.
    ///
    /// - Parameters:
    ///   - maxNodes: Maximum number of branch-and-bound nodes to explore.
    ///     Higher values allow finding better solutions but take longer. Default: 10,000.
    ///   - timeLimit: Maximum solver time in seconds. Solver stops after this duration
    ///     and returns the best solution found. Default: 60 seconds.
    public init(
        maxNodes: Int = 10_000,
        timeLimit: Double = 60.0
    ) {
        self.maxNodes = maxNodes
        self.timeLimit = timeLimit
    }

    /// Select projects to maximize objective subject to budget constraint
    public func selectProjects(
        projects: [CapitalProject],
        budget: Double,
        objective: CapitalBudgetingObjective = .totalNPV
    ) throws -> CapitalBudgetingResult {
        // Single-period budgeting - convert to periodic form
        return try selectProjects(
            projects: projects,
            periodicBudgets: [budget],
            objective: objective
        )
    }

    /// Select projects with multi-period budget constraints
    public func selectProjects(
        projects: [CapitalProject],
        periodicBudgets: [Double],
        objective: CapitalBudgetingObjective = .totalNPV
    ) throws -> CapitalBudgetingResult {

        guard !projects.isEmpty else {
            return CapitalBudgetingResult(
                selectedProjects: [],
                totalNPV: 0,
                totalCost: 0,
                status: .optimal
            )
        }

        let n = projects.count
        let numPeriods = periodicBudgets.count

        // Create binary specification (one binary variable per project)
        let spec = IntegerProgramSpecification.allBinary(dimension: n)

        // Build objective function
        let objectiveFunction: @Sendable (VectorN<Double>) -> Double
        switch objective {
        case .totalNPV:
            // Maximize NPV = minimize negative NPV
            objectiveFunction = { x in
                let selections = x.toArray()
                let totalNPV = zip(projects, selections).map { $0.npv * $1 }.reduce(0, +)
                return -totalNPV
            }

        case .profitabilityIndex:
            // Maximize NPV/Cost - approximated by weighted objective
            objectiveFunction = { x in
                let selections = x.toArray()
                var totalNPV = 0.0
                var totalCost = 0.0
                for (project, selected) in zip(projects, selections) {
                    totalNPV += project.npv * selected
                    totalCost += project.cost * selected
                }
                // Minimize -(NPV/Cost) ≈ minimize -NPV + small_penalty*Cost
                // This encourages high NPV and low cost
                return -totalNPV + 0.01 * totalCost
            }
        }

        // Build constraints
        var constraints: [MultivariateConstraint<VectorN<Double>>] = []

        // Budget constraints for each period
        for period in 0..<numPeriods {
            let budget = periodicBudgets[period]
            constraints.append(.inequality { x in
                let selections = x.toArray()
                var periodCost = 0.0
                for (i, project) in projects.enumerated() {
                    if period < project.periodicCosts.count {
                        periodCost += project.periodicCosts[period] * selections[i]
                    }
                }
                return periodCost - budget  // Cost ≤ budget
            })
        }

        // Binary constraints (0 ≤ x ≤ 1)
        for i in 0..<n {
            constraints.append(.inequality { x in -x.toArray()[i] })        // x ≥ 0
            constraints.append(.inequality { x in x.toArray()[i] - 1.0 })   // x ≤ 1
        }

        // Dependency constraints
        let projectNameToIndex = Dictionary(uniqueKeysWithValues: projects.enumerated().map { ($1.name, $0) })
        for (i, project) in projects.enumerated() {
            if let requiredName = project.requires,
               let requiredIndex = projectNameToIndex[requiredName] {
                // If project i is selected, required project must be selected
                // x_i ≤ x_required  =>  x_i - x_required ≤ 0
                constraints.append(.inequality { x in
                    x.toArray()[i] - x.toArray()[requiredIndex]
                })
            }
        }

        // Mutual exclusivity constraints
        for (i, project) in projects.enumerated() {
            if let exclusiveName = project.mutuallyExclusiveWith,
               let exclusiveIndex = projectNameToIndex[exclusiveName],
               exclusiveIndex > i {  // Only add once per pair
                // x_i + x_j ≤ 1
                constraints.append(.inequality { x in
                    x.toArray()[i] + x.toArray()[exclusiveIndex] - 1.0
                })
            }
        }

        // Solve integer program
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: maxNodes,
            timeLimit: timeLimit
        )

        let initialGuess = VectorN(Array(repeating: 0.5, count: n))

        let result = try solver.solve(
            objective: objectiveFunction,
            from: initialGuess,
            subjectTo: constraints,
            integerSpec: spec,
            minimize: true
        )

        // Extract selected projects
        let selections = result.solution.toArray()
        var selectedProjects: [CapitalProject] = []
        var totalNPV = 0.0
        var totalCost = 0.0

        for (i, project) in projects.enumerated() {
            if selections[i] > 0.5 {  // Binary variable is "on"
                selectedProjects.append(project)
                totalNPV += project.npv
                totalCost += project.cost
            }
        }

        return CapitalBudgetingResult(
            selectedProjects: selectedProjects,
            totalNPV: totalNPV,
            totalCost: totalCost,
            status: result.status
        )
    }
}
