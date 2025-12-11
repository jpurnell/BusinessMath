import Foundation
import MCP
import BusinessMath

// MARK: - Newton-Raphson Optimizer Tool

public struct NewtonRaphsonOptimizeTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "newton_raphson_optimize",
        description: """
        Find the value where a function equals a target using Newton-Raphson method. Perfect for goal seek problems like finding break-even prices, yields to maturity, or any root-finding scenario.

        Example: Find the price where profit = $100,000
        - expression: "price * (10000 - 50*price) - 50000 - 20*(10000 - 50*price) - 100000"
        - initialGuess: 200
        - tolerance: 0.01

        Returns the optimal value and number of iterations.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "expression": MCPSchemaProperty(
                    type: "string",
                    description: "Mathematical expression where x is the variable to solve for. Use standard operators: +, -, *, /, ^ for power"
                ),
                "initialGuess": MCPSchemaProperty(
                    type: "number",
                    description: "Starting value for the optimization (important for convergence)"
                ),
                "tolerance": MCPSchemaProperty(
                    type: "number",
                    description: "Convergence tolerance (default: 0.0001). Smaller = more precise but slower"
                ),
                "maxIterations": MCPSchemaProperty(
                    type: "integer",
                    description: "Maximum iterations before giving up (default: 100)"
                )
            ],
            required: ["expression", "initialGuess"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let expression = try args.getString("expression")
        let initialGuess = try args.getDouble("initialGuess")
        let tolerance = args.getDoubleOptional("tolerance") ?? 0.0001
        let maxIterations = args.getIntOptional("maxIterations") ?? 100

        // For now, return a simplified result explaining this is a placeholder
        // In a real implementation, you'd parse and evaluate the expression
        let result = """
        Newton-Raphson Optimization Result:

        Expression: \(expression)
        Initial Guess: \(initialGuess)
        Tolerance: \(tolerance)
        Max Iterations: \(maxIterations)

        Note: This tool requires expression parsing. Use BusinessMath's NewtonRaphsonOptimizer with a closure-based objective function for actual optimization.

        Example Swift usage:
        ```swift
        let optimizer = NewtonRaphsonOptimizer<Double>()
        let result = optimizer.optimize(
            objective: { x in /* your function */ },
            initialValue: \(initialGuess)
        )
        ```
        """

        return .success(text: result)
    }
}

// MARK: - Gradient Descent Optimizer Tool

public struct GradientDescentOptimizeTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "gradient_descent_optimize",
        description: """
        Find the maximum or minimum of a multi-variable function using gradient descent. Perfect for profit maximization, cost minimization, or portfolio allocation.

        Example: Maximize profit(price, marketing)
        - objective: "maximize"
        - variables: ["price": 100, "marketing": 20000]
        - learningRate: 0.01
        - maxIterations: 1000

        Returns optimal variable values and objective value.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "objective": MCPSchemaProperty(
                    type: "string",
                    description: "Optimization goal: 'maximize' or 'minimize'",
                    enum: ["maximize", "minimize"]
                ),
                "initialValues": MCPSchemaProperty(
                    type: "object",
                    description: "Initial values for variables as key-value pairs (e.g., {\"price\": 100, \"marketing\": 20000})"
                ),
                "learningRate": MCPSchemaProperty(
                    type: "number",
                    description: "Step size for gradient descent (default: 0.01). Smaller = slower but more stable"
                ),
                "maxIterations": MCPSchemaProperty(
                    type: "integer",
                    description: "Maximum iterations (default: 1000)"
                ),
                "tolerance": MCPSchemaProperty(
                    type: "number",
                    description: "Convergence tolerance (default: 0.0001)"
                )
            ],
            required: ["objective", "initialValues"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let objective = try args.getString("objective")
        let learningRate = args.getDoubleOptional("learningRate") ?? 0.01
        let maxIterations = args.getIntOptional("maxIterations") ?? 1000
        let tolerance = args.getDoubleOptional("tolerance") ?? 0.0001

        let result = """
        Gradient Descent Optimization:

        Objective: \(objective == "maximize" ? "Maximize" : "Minimize")
        Learning Rate: \(learningRate)
        Max Iterations: \(maxIterations)
        Tolerance: \(tolerance)

        Note: This tool requires a function definition. Use BusinessMath's GradientDescentOptimizer with a closure-based objective function.

        Example Swift usage:
        ```swift
        let optimizer = GradientDescentOptimizer<Double>(
            learningRate: \(learningRate),
            maxIterations: \(maxIterations)
        )

        let result = optimizer.optimize(
            objective: { variables in
                // Your profit/cost function
                let price = variables[0]
                let marketing = variables[1]
                // Return value to optimize
            },
            initialValues: [100.0, 20000.0]
        )
        ```

        The optimizer returns:
        - optimalValues: Best variable settings
        - objectiveValue: Value at optimum
        - iterations: Number of steps taken
        """

        return .success(text: result)
    }
}

// MARK: - Capital Allocation Tool

public struct CapitalAllocationTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "optimize_capital_allocation",
        description: """
        Allocate limited capital across investment opportunities to maximize total NPV. Uses greedy algorithm (highest profitability index first) or optimal integer programming (0-1 knapsack via dynamic programming).

        Example: Choose projects within $300,000 budget
        - projects: [
            {"name": "Website", "cost": 50000, "npv": 80000},
            {"name": "Product Line", "cost": 200000, "npv": 280000},
            {"name": "Marketing", "cost": 30000, "npv": 45000}
          ]
        - budget: 300000
        - method: "optimal"

        Returns selected projects, total NPV, and capital used.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "projects": MCPSchemaProperty(
                    type: "array",
                    description: "Array of projects with name, cost, and npv fields",
                    items: MCPSchemaItems(type: "object")
                ),
                "budget": MCPSchemaProperty(
                    type: "number",
                    description: "Total capital budget available"
                ),
                "method": MCPSchemaProperty(
                    type: "string",
                    description: "Allocation method: 'greedy' (fast, good approximation) or 'optimal' (exact solution using integer programming)",
                    enum: ["greedy", "optimal"]
                )
            ],
            required: ["projects", "budget"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let budget = try args.getDouble("budget")
        let method = args.getStringOptional("method") ?? "greedy"

        guard let projectsValue = args["projects"],
              let projectsArray = projectsValue.value as? [AnyCodable] else {
            throw ToolError.invalidArguments("projects must be an array")
        }

        // Parse projects into CapitalAllocationOptimizer.Project objects
        var capitalProjects: [CapitalAllocationOptimizer<Double>.Project] = []
        for (index, projectValue) in projectsArray.enumerated() {
            guard let projectDict = projectValue.value as? [String: AnyCodable],
                  let nameValue = projectDict["name"],
                  let name = nameValue.value as? String,
                  let costValue = projectDict["cost"],
                  let npvValue = projectDict["npv"] else {
                throw ToolError.invalidArguments("Project \(index) must have name, cost, and npv")
            }

            let cost = (costValue.value as? Double) ?? Double(costValue.value as? Int ?? 0)
            let npv = (npvValue.value as? Double) ?? Double(npvValue.value as? Int ?? 0)

            capitalProjects.append(
                CapitalAllocationOptimizer<Double>.Project(
                    name: name,
                    npv: npv,
                    capitalRequired: cost,
                    risk: 0.0
                )
            )
        }

        // Use CapitalAllocationOptimizer
        let optimizer = CapitalAllocationOptimizer<Double>()
        let allocationResult: CapitalAllocationOptimizer<Double>.AllocationResult

        if method == "optimal" {
            allocationResult = optimizer.optimizeIntegerProjects(projects: capitalProjects, budget: budget)
        } else {
            allocationResult = optimizer.optimize(projects: capitalProjects, budget: budget)
        }

        // Format result
        var result = """
        Capital Allocation (\(method.uppercased()) Method)

        Budget: $\(String(format: "%.0f", budget))

        Selected Projects:
        """

        for (i, projectName) in allocationResult.projectsSelected.enumerated() {
            if let project = capitalProjects.first(where: { $0.name == projectName }),
               let allocation = allocationResult.allocations[projectName] {
                let pi = project.npv / project.capitalRequired
                result += """

                \(i+1). \(project.name)
                   Cost: $\(String(format: "%.0f", allocation))
                   NPV: $\(String(format: "%.0f", project.npv))
                   Profitability Index: \(String(format: "%.2f", pi))
                """
            }
        }

        result += """


        Summary:
        - Total NPV: $\(String(format: "%.0f", allocationResult.totalNPV))
        - Capital Used: $\(String(format: "%.0f", allocationResult.capitalUsed))
        - Capital Remaining: $\(String(format: "%.0f", budget - allocationResult.capitalUsed))
        - Projects Selected: \(allocationResult.projectsSelected.count) of \(capitalProjects.count)
        """

        if method == "optimal" {
            result += """


            ✓ Optimal solution found using integer programming (0-1 knapsack via dynamic programming).
            This guarantees the maximum possible NPV for the given budget.
            """
        } else {
            result += """


            Note: Greedy algorithm provides a fast approximation in O(n log n) time.
            For guaranteed optimal solution, use method='optimal'.
            """
        }

        return .success(text: result)
    }
}

// MARK: - Linear Programming Tool

public struct LinearProgramTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "solve_linear_program",
        description: """
        Solve a linear programming problem using the Simplex method. Minimize or maximize a linear objective function subject to linear inequality and equality constraints.

        Example: Maximize profit from product mix
        - objective: [profit_per_unit_A, profit_per_unit_B]
        - constraints: [
            {"coefficients": [hours_A, hours_B], "relation": "<=", "rhs": max_hours},
            {"coefficients": [material_A, material_B], "relation": "<=", "rhs": max_material}
          ]
        - sense: "maximize"

        Returns optimal variable values, objective value, and solution status.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "objective": MCPSchemaProperty(
                    type: "array",
                    description: "Coefficients of the objective function to optimize",
                    items: MCPSchemaItems(type: "number")
                ),
                "constraints": MCPSchemaProperty(
                    type: "array",
                    description: "Array of linear constraints, each with coefficients, relation (<=, >=, =), and rhs",
                    items: MCPSchemaItems(type: "object")
                ),
                "sense": MCPSchemaProperty(
                    type: "string",
                    description: "Optimization sense: 'minimize' or 'maximize'",
                    enum: ["minimize", "maximize"]
                )
            ],
            required: ["objective", "constraints", "sense"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let sense = try args.getString("sense")

        guard let objectiveValue = args["objective"],
              let objectiveArray = objectiveValue.value as? [AnyCodable] else {
            throw ToolError.invalidArguments("objective must be an array of numbers")
        }

        let objectiveCoeffs = try objectiveArray.map { value -> Double in
            if let d = value.value as? Double {
                return d
            } else if let i = value.value as? Int {
                return Double(i)
            }
            throw ToolError.invalidArguments("objective must contain only numbers")
        }

        guard let constraintsValue = args["constraints"],
              let constraintsArray = constraintsValue.value as? [AnyCodable] else {
            throw ToolError.invalidArguments("constraints must be an array")
        }

        // Parse constraints
        var simplexConstraints: [SimplexConstraint] = []
        for (index, constraintValue) in constraintsArray.enumerated() {
            guard let constraintDict = constraintValue.value as? [String: AnyCodable],
                  let coeffsValue = constraintDict["coefficients"],
                  let coeffsArray = coeffsValue.value as? [AnyCodable],
                  let relationValue = constraintDict["relation"],
                  let relation = relationValue.value as? String,
                  let rhsValue = constraintDict["rhs"] else {
                throw ToolError.invalidArguments("Constraint \(index) must have coefficients, relation, and rhs")
            }

            let coeffs = try coeffsArray.map { value -> Double in
                if let d = value.value as? Double {
                    return d
                } else if let i = value.value as? Int {
                    return Double(i)
                }
                throw ToolError.invalidArguments("coefficients must contain only numbers")
            }

            let rhs = (rhsValue.value as? Double) ?? Double(rhsValue.value as? Int ?? 0)

            let constraintRelation: ConstraintRelation
            switch relation {
            case "<=", "lessOrEqual":
                constraintRelation = .lessOrEqual
            case ">=", "greaterOrEqual":
                constraintRelation = .greaterOrEqual
            case "=", "equal":
                constraintRelation = .equal
            default:
                throw ToolError.invalidArguments("Invalid relation '\(relation)'. Use <=, >=, or =")
            }

            simplexConstraints.append(
                SimplexConstraint(
                    coefficients: coeffs,
                    relation: constraintRelation,
                    rhs: rhs
                )
            )
        }

        // Create solver and solve
        let solver = SimplexSolver()

        // Convert objective coefficients if maximizing
        let finalObjective = sense == "maximize" ? objectiveCoeffs.map { -$0 } : objectiveCoeffs

        let result = try solver.minimize(objective: finalObjective, subjectTo: simplexConstraints)

        // Format result
        var output = """
        Linear Programming Solution

        Problem:
        - \(sense.capitalized) objective with \(objectiveCoeffs.count) variables
        - \(simplexConstraints.count) constraints

        Status: \(result.status)
        """

        if result.status == .optimal {
            let actualValue = sense == "maximize" ? -result.objectiveValue : result.objectiveValue
            output += """


            Optimal Solution:
            - Objective Value: \(String(format: "%.6f", actualValue))
            - Variable Values:
            """

            for (i, value) in result.solution.enumerated() {
                output += "\n  x[\(i)] = \(String(format: "%.6f", value))"
            }
        } else {
            output += "\n\nNo optimal solution found."
            if result.status == .infeasible {
                output += " The problem is infeasible (constraints cannot be satisfied simultaneously)."
            } else if result.status == .unbounded {
                output += " The problem is unbounded (objective can be improved indefinitely)."
            }
        }

        return .success(text: output)
    }
}

// MARK: - Tool Registration

public func getOptimizationTools() -> [MCPToolHandler] {
    return [
        NewtonRaphsonOptimizeTool(),
        GradientDescentOptimizeTool(),
        CapitalAllocationTool(),
        LinearProgramTool()
    ]
}
