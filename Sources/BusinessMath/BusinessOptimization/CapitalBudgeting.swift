import Foundation

/// Represents a capital investment project with NPV and cost information
public struct CapitalProject: Sendable {
    public let name: String
    public let npv: Double
    public let cost: Double
    public let periodicCosts: [Double]
    public let requires: String?
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

/// Result of capital budgeting optimization
public struct CapitalBudgetingResult: Sendable {
    public let selectedProjects: [CapitalProject]
    public let totalNPV: Double
    public let totalCost: Double
    public let profitabilityIndex: Double
    public let status: IntegerSolutionStatus

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

/// Optimizer for capital budgeting and project selection problems
public struct CapitalBudgetingOptimizer: Sendable {
    private let maxNodes: Int
    private let timeLimit: Double

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
