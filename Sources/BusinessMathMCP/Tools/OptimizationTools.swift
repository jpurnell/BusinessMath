import Foundation
import MCP
import BusinessMath

// MARK: - Helper Functions

/// Evaluate a calculation string with a single input value
private func evaluateExpression(_ expression: String, withVariable x: Double) -> Double {
    let formula = expression.replacingOccurrences(of: "{0}", with: "\(x)")
                            .replacingOccurrences(of: "x", with: "\(x)")

    let nsExpression = NSExpression(format: formula)
    if let result = nsExpression.expressionValue(with: nil, context: nil) as? Double {
        return result
    } else if let result = nsExpression.expressionValue(with: nil, context: nil) as? NSNumber {
        return result.doubleValue
    }

    return 0.0
}

/// Evaluate a calculation string with multiple input values
private func evaluateMultivariateExpression(_ expression: String, withVariables values: [Double]) -> Double {
    var formula = expression
    for (index, value) in values.enumerated() {
        formula = formula.replacingOccurrences(of: "{\(index)}", with: "\(value)")
    }

    let nsExpression = NSExpression(format: formula)
    if let result = nsExpression.expressionValue(with: nil, context: nil) as? Double {
        return result
    } else if let result = nsExpression.expressionValue(with: nil, context: nil) as? NSNumber {
        return result.doubleValue
    }

    return 0.0
}

// MARK: - Newton-Raphson Optimizer Tool

public struct NewtonRaphsonOptimizeTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "newton_raphson_optimize",
        description: """
        Find the value where a function equals zero using Newton-Raphson method (root-finding). Perfect for break-even analysis, yield calculations, or any equation solving.

        Use {0} or 'x' as the variable placeholder in your formula.

        REQUIRED STRUCTURE:
        {
          "formula": "{0} * {0} - 25",
          "initialGuess": 3,
          "target": 0
        }

        Common Applications:
        • Break-even Analysis: Find quantity where profit = 0
        • Yield Calculations: Find rate where NPV = 0 (IRR)
        • Equation Solving: Find x where f(x) = target

        Examples:

        1. Find Square Root (solve x² = 25):
        {
          "formula": "{0} * {0} - 25",
          "initialGuess": 3,
          "target": 0
        }

        2. Break-even Price:
        {
          "formula": "{0} * 1000 - 500000 - 0.3 * {0} * 1000",
          "initialGuess": 800,
          "target": 0,
          "description": "Find price where profit = 0"
        }

        3. Compound Growth Rate:
        {
          "formula": "100000 * (1 + {0}) - 150000",
          "initialGuess": 0.4,
          "target": 0,
          "description": "What rate grows $100K to $150K?"
        }

        Returns the solution where formula(x) = target.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "formula": MCPSchemaProperty(
                    type: "string",
                    description: """
                    Formula using {0} or 'x' for the variable.
                    Examples:
                    • "{0} * {0} - 16" - quadratic
                    • "{0} * 1000 - 50000" - linear
                    • "1000 * (1 + {0}) * (1 + {0})" - compound growth
                    """
                ),
                "initialGuess": MCPSchemaProperty(
                    type: "number",
                    description: "Starting value for Newton-Raphson iteration"
                ),
                "target": MCPSchemaProperty(
                    type: "number",
                    description: "Target value (default: 0 for root-finding)"
                ),
                "tolerance": MCPSchemaProperty(
                    type: "number",
                    description: "Convergence tolerance (default: 0.000001)"
                ),
                "maxIterations": MCPSchemaProperty(
                    type: "number",
                    description: "Maximum iterations (default: 1000)"
                ),
                "description": MCPSchemaProperty(
                    type: "string",
                    description: "Optional description of what you're solving"
                )
            ],
            required: ["formula", "initialGuess"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let formula = try args.getString("formula")
        let initialGuess = try args.getDouble("initialGuess")
        let target = args.getDoubleOptional("target") ?? 0.0
        let tolerance = args.getDoubleOptional("tolerance") ?? 0.000001
        let maxIterations = args.getIntOptional("maxIterations") ?? 1000
        let description = args.getStringOptional("description")

        // Define the function: f(x) = formula(x) - target
        let function: @Sendable (Double) -> Double = { x in
            let result = evaluateExpression(formula, withVariable: x)
            return result - target
        }

        // Use Newton-Raphson via goalSeek
        let solution: Double
        do {
            solution = try goalSeek(
                function: function,
                target: 0.0,
                guess: initialGuess,
                tolerance: tolerance,
                maxIterations: maxIterations
            )
        } catch {
            return .error(message: """
                Newton-Raphson Failed

                Could not find solution within \(maxIterations) iterations.

                Possible reasons:
                • No solution exists for this target
                • Initial guess is too far from solution
                • Function has discontinuities or multiple roots

                Suggestions:
                • Try a different initial guess
                • Increase maxIterations
                • Check formula syntax

                Error: \(error.localizedDescription)
                """)
        }

        // Verify solution
        let actualValue = evaluateExpression(formula, withVariable: solution)
        let error = abs(actualValue - target)
        let errorPercent = target != 0 ? (error / abs(target)) * 100 : 0

        var output = """
        Newton-Raphson Optimization Result
        """

        if let desc = description {
            output += "\n\n\(desc)"
        }

        output += """


        Solution Found:
        • x = \(solution.formatDecimal(decimals: 8))
        • f(x) = \(actualValue.formatDecimal(decimals: 8))
        • Target = \(target.formatDecimal(decimals: 8))
        • Error: \(error.formatDecimal(decimals: 10)) (\(errorPercent.formatDecimal(decimals: 6))%)

        Verification:
        • Formula: \(formula)
        • When x = \(solution.formatDecimal(decimals: 6))
        • Result = \(actualValue.formatDecimal(decimals: 6))

        Convergence:
        • Initial Guess: \(initialGuess.formatDecimal(decimals: 2))
        • Converged within tolerance \((tolerance * 100).formatDecimal(decimals: 6))%
        • \(error < tolerance ? "✓ Solution verified" : "⚠️ Solution may need refinement")

        Method: Newton-Raphson root-finding algorithm
        """

        return .success(text: output)
    }
}

// MARK: - Gradient Descent Optimizer Tool

public struct GradientDescentOptimizeTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "gradient_descent_optimize",
        description: """
        Find minimum/maximum of a multi-variable function using gradient descent. Perfect for profit maximization, cost minimization, or optimization with multiple inputs.

        Use {0}, {1}, {2}, etc. as variable placeholders in your formula.

        REQUIRED STRUCTURE:
        {
          "formula": "({0} - 100) * ({0} - 100) + ({1} - 50) * ({1} - 50)",
          "initialValues": [0, 0],
          "sense": "minimize"
        }

        Common Applications:
        • Profit Maximization: Find optimal price and marketing spend
        • Cost Minimization: Minimize total production and distribution costs
        • Resource Allocation: Optimize allocation across multiple channels

        Examples:

        1. Minimize Quadratic Function:
        {
          "formula": "({0} - 100) * ({0} - 100) + ({1} - 50) * ({1} - 50)",
          "initialValues": [0, 0],
          "sense": "minimize",
          "learningRate": 0.1
        }

        2. Profit Maximization (price, quantity):
        {
          "formula": "{0} * {1} - {0} * {0} * 0.01 - {1} * 20 - 1000",
          "initialValues": [100, 500],
          "sense": "maximize",
          "description": "Maximize profit from price and quantity"
        }

        Returns optimal variable values and objective value.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "formula": MCPSchemaProperty(
                    type: "string",
                    description: """
                    Formula using {0}, {1}, {2}, etc. for variables.
                    Examples:
                    • "{0} * {0} + {1} * {1}" - sum of squares
                    • "{0} * {1} - {0} * {0}" - profit function
                    • "({0} - 10) * ({0} - 10) + ({1} - 5) * ({1} - 5)" - quadratic
                    """
                ),
                "initialValues": MCPSchemaProperty(
                    type: "array",
                    description: "Initial values for each variable (starting point for optimization)",
                    items: MCPSchemaItems(type: "number")
                ),
                "sense": MCPSchemaProperty(
                    type: "string",
                    description: "Optimization goal: 'minimize' or 'maximize'",
                    enum: ["minimize", "maximize"]
                ),
                "learningRate": MCPSchemaProperty(
                    type: "number",
                    description: "Step size (default: 0.01). Smaller = slower but more stable"
                ),
                "maxIterations": MCPSchemaProperty(
                    type: "number",
                    description: "Maximum iterations (default: 1000)"
                ),
                "tolerance": MCPSchemaProperty(
                    type: "number",
                    description: "Convergence tolerance (default: 0.0001)"
                ),
                "description": MCPSchemaProperty(
                    type: "string",
                    description: "Optional description of optimization goal"
                )
            ],
            required: ["formula", "initialValues", "sense"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let formula = try args.getString("formula")
        let sense = try args.getString("sense")
        let learningRate = args.getDoubleOptional("learningRate") ?? 0.01
        let maxIterations = args.getIntOptional("maxIterations") ?? 1000
        let tolerance = args.getDoubleOptional("tolerance") ?? 0.0001
        let description = args.getStringOptional("description")

        guard let initialValuesArray = args["initialValues"]?.value as? [AnyCodable] else {
            throw ToolError.invalidArguments("initialValues must be an array of numbers")
        }

        var initialValues: [Double] = []
        for value in initialValuesArray {
            if let d = value.value as? Double {
                initialValues.append(d)
            } else if let i = value.value as? Int {
                initialValues.append(Double(i))
            } else {
                throw ToolError.invalidArguments("All initial values must be numbers")
            }
        }

        guard !initialValues.isEmpty else {
            throw ToolError.invalidArguments("Must provide at least one initial value")
        }

        // Define objective function
        let objectiveFunction: @Sendable (VectorN<Double>) -> Double = { vector in
            let values = vector.toArray()
            let result = evaluateMultivariateExpression(formula, withVariables: values)
            return sense == "maximize" ? -result : result
        }

        // Use gradient descent optimizer
        let optimizer = MultivariateGradientDescent<VectorN<Double>>(
            learningRate: learningRate,
            maxIterations: maxIterations,
            tolerance: tolerance
        )

        let result: MultivariateOptimizationResult<VectorN<Double>>
        do {
            result = try optimizer.minimize(
                function: objectiveFunction,
                initialGuess: VectorN(initialValues)
            )
        } catch {
            return .error(message: """
                Gradient Descent Failed

                Optimization did not converge within \(maxIterations) iterations.

                Possible reasons:
                • Learning rate too large (try smaller value)
                • Starting point too far from optimum
                • Function may not be differentiable

                Suggestions:
                • Reduce learningRate (try 0.001 or 0.0001)
                • Try different initialValues
                • Increase maxIterations

                Error: \(error.localizedDescription)
                """)
        }

        // Get final solution
        let optimalValues = result.solution.toArray()
        let actualObjective = evaluateMultivariateExpression(formula, withVariables: optimalValues)
        _ = result.objectiveValue  // Discard optimizer's internal value

        var output = """
        Gradient Descent Optimization Result
        """

        if let desc = description {
            output += "\n\n\(desc)"
        }

        output += """


        Optimization Goal: \(sense.capitalized)

        Optimal Solution:
        """

        for (i, value) in optimalValues.enumerated() {
            output += "\n  Variable[\(i)] = \(value.formatDecimal(decimals: 6))"
        }

        output += """


        Results:
        • Objective Value: \(actualObjective.formatDecimal(decimals: 6)) (\(sense)d)
        • Iterations: \(result.iterations)
        • Convergence: \(result.convergenceReason)

        Verification:
        • Formula: \(formula)
        • Values: [\(optimalValues.map { $0.formatDecimal(decimals: 4) }.joined(separator: ", "))]
        • Result: \(actualObjective.formatDecimal(decimals: 6))

        Settings:
        • Learning Rate: \(learningRate)
        • Tolerance: \(tolerance)
        • Max Iterations: \(maxIterations)

        Method: Gradient descent with numerical differentiation
        """

        return .success(text: output)
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
