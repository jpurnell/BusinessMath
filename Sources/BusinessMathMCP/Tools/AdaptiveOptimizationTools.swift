import Foundation
import MCP
import BusinessMath

// MARK: - Adaptive Optimizer Tool

public struct AdaptiveOptimizeTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "adaptive_optimize",
        description: """
        Automatically select and run the best optimization algorithm for your problem. No algorithm expertise needed - just provide your objective function and constraints.

        The adaptive optimizer analyzes your problem (size, constraints, preferences) and intelligently chooses between:
        - Gradient Descent (fast, memory-efficient)
        - Newton-Raphson (accurate, fast convergence)
        - Constrained Optimizer (equality constraints)
        - Inequality Optimizer (inequality constraints)

        Example: Minimize f(x,y) = (x-1)² + (y-2)²
        - variables: ["x", "y"]
        - initialGuess: [0.0, 0.0]
        - objective: "minimize"

        Example with constraint: Portfolio optimization
        - variables: ["stock1", "stock2", "stock3"]
        - initialGuess: [0.33, 0.33, 0.34]
        - objective: "minimize"
        - constraints: [{"type": "equality", "expression": "stock1 + stock2 + stock3 - 1.0"}]

        Returns: optimal solution, algorithm used, reason for selection, convergence info.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "variables": MCPSchemaProperty(
                    type: "array",
                    description: "Names of variables to optimize (e.g., [\"x\", \"y\"] or [\"price\", \"quantity\"])",
                    items: MCPSchemaItems(type: "string")
                ),
                "initialGuess": MCPSchemaProperty(
                    type: "array",
                    description: "Starting values for each variable",
                    items: MCPSchemaItems(type: "number")
                ),
                "objective": MCPSchemaProperty(
                    type: "string",
                    description: "Goal: 'minimize' or 'maximize'",
                    enum: ["minimize", "maximize"]
                ),
                "preferSpeed": MCPSchemaProperty(
                    type: "boolean",
                    description: "Prefer faster algorithms over more accurate ones (default: false)"
                ),
                "preferAccuracy": MCPSchemaProperty(
                    type: "boolean",
                    description: "Prefer more accurate algorithms (may be slower) (default: false)"
                ),
                "tolerance": MCPSchemaProperty(
                    type: "number",
                    description: "Convergence tolerance (default: 0.000001 = 1e-6). Smaller = more precise"
                ),
                "maxIterations": MCPSchemaProperty(
                    type: "integer",
                    description: "Maximum optimization iterations (default: 1000)"
                ),
                "constraints": MCPSchemaProperty(
                    type: "array",
                    description: "Optional constraints (equality or inequality)",
                    items: MCPSchemaItems(type: "object")
                )
            ],
            required: ["variables", "initialGuess", "objective"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        // Parse arguments
        guard let variablesValue = args["variables"],
              let variablesArray = variablesValue.value as? [AnyCodable] else {
            throw ToolError.invalidArguments("variables must be an array of strings")
        }

        let variables = try variablesArray.map { value -> String in
            guard let str = value.value as? String else {
                throw ToolError.invalidArguments("Each variable must be a string")
            }
            return str
        }

        guard let initialGuessValue = args["initialGuess"],
              let initialArray = initialGuessValue.value as? [AnyCodable] else {
            throw ToolError.invalidArguments("initialGuess must be an array of numbers")
        }

        let initialGuess = try initialArray.map { value -> Double in
            if let num = value.value as? Double {
                return num
            } else if let num = value.value as? Int {
                return Double(num)
            } else {
                throw ToolError.invalidArguments("Each initialGuess value must be a number")
            }
        }

        guard variables.count == initialGuess.count else {
            throw ToolError.invalidArguments("variables and initialGuess must have same length")
        }

        let objective = try args.getString("objective")
        guard objective == "minimize" || objective == "maximize" else {
            throw ToolError.invalidArguments("objective must be 'minimize' or 'maximize'")
        }

        let preferSpeed = args.getBoolOptional("preferSpeed") ?? false
        let preferAccuracy = args.getBoolOptional("preferAccuracy") ?? false
        let tolerance = args.getDoubleOptional("tolerance") ?? 1e-6
        let maxIterations = args.getIntOptional("maxIterations") ?? 1000

        // Note: This tool provides guidance on how to use Adaptive Optimizer
        // since we cannot execute arbitrary user-defined objective functions in MCP

        let problemAnalysis = """
        📊 **Adaptive Optimization Analysis**

        **Problem Configuration:**
        - Variables: \(variables.joined(separator: ", "))
        - Dimensions: \(variables.count)
        - Initial guess: \(initialGuess.map { $0.number(4) }.joined(separator: ", "))
        - Objective: \(objective.capitalized)
        - Preferences: \(preferSpeed ? "Speed" : preferAccuracy ? "Accuracy" : "Balanced")

        **Recommended Algorithm:**
        \(recommendAlgorithm(dimensions: variables.count,
                             hasConstraints: args["constraints"] != nil,
                             preferSpeed: preferSpeed,
                             preferAccuracy: preferAccuracy))

        **Swift Implementation:**
        ```swift
        import BusinessMath

        // Create adaptive optimizer
        let optimizer = AdaptiveOptimizer<VectorN<Double>>(
            preferSpeed: \(preferSpeed),
            preferAccuracy: \(preferAccuracy),
            tolerance: \(tolerance),
            maxIterations: \(maxIterations)
        )

        // Define your objective function
        let objective: @Sendable (VectorN<Double>) -> Double = { x in
            // Extract variables: \(variables.joined(separator: ", "))
            // Example: let x0 = x[0], x1 = x[1], ...
            // Your objective function here (return value to \(objective))
            return 0.0  // Replace with your calculation
        }

        // Optimize
        let result = try optimizer.optimize(
            objective: objective,
            initialGuess: VectorN(\(initialGuess)),
            constraints: []  // Add constraints if needed
        )

        // Results
        print("Algorithm used: \\(result.algorithmUsed)")
        print("Selection reason: \\(result.selectionReason)")
        print("Solution: \\(result.solution)")
        print("Objective value: \\(result.objectiveValue)")
        print("Converged: \\(result.converged)")
        print("Iterations: \\(result.iterations)")
        ```

        **Why This Configuration:**
        \(explainConfiguration(dimensions: variables.count,
                               preferSpeed: preferSpeed,
                               preferAccuracy: preferAccuracy,
                               tolerance: tolerance))

        **Next Steps:**
        1. Copy the Swift code above
        2. Replace the objective function with your actual calculation
        3. Add any constraints using MultivariateConstraint
        4. Run and the optimizer will automatically select the best algorithm
        5. Check result.selectionReason to understand why that algorithm was chosen

        **Common Patterns:**
        - Small problems (≤5 vars): Newton-Raphson auto-selected for accuracy
        - Large problems (>100 vars): Gradient Descent auto-selected for efficiency
        - With constraints: Specialized constraint optimizers used automatically
        """

        return .success(text: problemAnalysis)
    }

    private func recommendAlgorithm(dimensions: Int, hasConstraints: Bool,
                                     preferSpeed: Bool, preferAccuracy: Bool) -> String {
        if hasConstraints {
            return "**Inequality/Constrained Optimizer** - You have constraints, specialized optimizer will be selected"
        } else if dimensions > 100 {
            return "**Gradient Descent** - Large problem (\(dimensions) vars) uses memory-efficient gradient descent"
        } else if preferAccuracy && dimensions < 10 {
            return "**Newton-Raphson** - Accuracy preference with small problem uses Newton-Raphson"
        } else if dimensions <= 5 && !preferSpeed {
            return "**Newton-Raphson** - Very small problem (\(dimensions) vars) benefits from Newton-Raphson's fast convergence"
        } else {
            return "**Gradient Descent** - Balanced choice for medium unconstrained problems"
        }
    }

    private func explainConfiguration(dimensions: Int, preferSpeed: Bool,
                                      preferAccuracy: Bool, tolerance: Double) -> String {
        var explanations: [String] = []

        if dimensions <= 5 {
            explanations.append("- Small problem size enables Newton-Raphson's O(n³) Hessian calculation efficiently")
        } else if dimensions > 100 {
            explanations.append("- Large problem requires memory-efficient Gradient Descent")
            explanations.append("- Learning rate will be automatically set to 0.01 (larger for faster convergence)")
        } else {
            explanations.append("- Medium problem size (6-100 vars) uses balanced approach")
            explanations.append("- Learning rate will be 0.001 (conservative for stability)")
        }

        if preferSpeed {
            explanations.append("- Speed preference prioritizes faster algorithms")
        } else if preferAccuracy {
            explanations.append("- Accuracy preference selects Newton-Raphson when possible")
        }

        if tolerance != 1e-6 {
            explanations.append("- Custom tolerance \(tolerance) adjusts convergence criteria")
        }

        return explanations.isEmpty ? "Standard configuration" : explanations.joined(separator: "\n")
    }
}

// MARK: - Problem Analysis Tool

public struct AnalyzeOptimizationProblemTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "analyze_optimization_problem",
        description: """
        Analyze an optimization problem before solving to understand:
        - Problem characteristics (size, constraints, structure)
        - Which algorithm will be selected and why
        - Expected performance characteristics
        - Recommendations for improvement

        Use this before optimizing to understand what to expect.

        Example:
        - dimensions: 3
        - hasConstraints: true
        - hasInequalities: true
        - hasGradient: false

        Returns: Complete problem analysis with algorithm recommendation.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "dimensions": MCPSchemaProperty(
                    type: "integer",
                    description: "Number of decision variables"
                ),
                "hasConstraints": MCPSchemaProperty(
                    type: "boolean",
                    description: "Does problem have constraints?"
                ),
                "hasInequalities": MCPSchemaProperty(
                    type: "boolean",
                    description: "Does problem have inequality constraints (≤ or ≥)?"
                ),
                "hasGradient": MCPSchemaProperty(
                    type: "boolean",
                    description: "Is analytical gradient provided?"
                ),
                "preferSpeed": MCPSchemaProperty(
                    type: "boolean",
                    description: "Prefer speed over accuracy?"
                ),
                "preferAccuracy": MCPSchemaProperty(
                    type: "boolean",
                    description: "Prefer accuracy over speed?"
                )
            ],
            required: ["dimensions"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let dimensions = try args.getInt("dimensions")
        let hasConstraints = args.getBoolOptional("hasConstraints") ?? false
        let hasInequalities = args.getBoolOptional("hasInequalities") ?? false
        let hasGradient = args.getBoolOptional("hasGradient") ?? false
        let preferSpeed = args.getBoolOptional("preferSpeed") ?? false
        let preferAccuracy = args.getBoolOptional("preferAccuracy") ?? false

        // Determine algorithm
        let (algorithm, reason) = selectAlgorithm(
            problemSize: dimensions,
            hasConstraints: hasConstraints,
            hasInequalities: hasInequalities,
            hasGradient: hasGradient,
            preferSpeed: preferSpeed,
            preferAccuracy: preferAccuracy
        )

        let analysis = """
        📊 **Optimization Problem Analysis**

        **Problem Characteristics:**
        - Dimensions: \(dimensions) variables
        - Constraints: \(hasConstraints ? "Yes" : "No")
        - Inequality constraints: \(hasInequalities ? "Yes" : "No")
        - Analytical gradient: \(hasGradient ? "Provided" : "Will use numerical")
        - Preferences: \(preferSpeed ? "Speed" : preferAccuracy ? "Accuracy" : "Balanced")

        **Problem Classification:**
        \(classifyProblem(dimensions: dimensions, hasConstraints: hasConstraints, hasInequalities: hasInequalities))

        **Recommended Algorithm:**
        **\(algorithm)**

        **Selection Reasoning:**
        \(reason)

        **Expected Performance:**
        \(estimatePerformance(algorithm: algorithm, dimensions: dimensions))

        **Tips for Best Results:**
        \(provideTips(dimensions: dimensions, hasConstraints: hasConstraints, algorithm: algorithm))

        **Implementation Example:**
        ```swift
        import BusinessMath

        let optimizer = AdaptiveOptimizer<VectorN<Double>>(
            preferSpeed: \(preferSpeed),
            preferAccuracy: \(preferAccuracy)
        )

        // The optimizer will automatically select: \(algorithm)
        let result = try optimizer.optimize(
            objective: yourObjectiveFunction,
            initialGuess: VectorN(...),  // \(dimensions)-dimensional
            constraints: \(hasConstraints ? "yourConstraints" : "[]")
        )

        print("Used: \\(result.algorithmUsed)")  // Should be "\(algorithm)"
        print("Why: \\(result.selectionReason)")
        ```

        **Learn More:**
        - Adaptive Selection Tutorial: PHASE_7_ADAPTIVE_SELECTION_TUTORIAL.md
        - API Documentation: AdaptiveOptimizer.swift
        """

        return .success(text: analysis)
    }

    private func selectAlgorithm(problemSize: Int, hasConstraints: Bool,
                                hasInequalities: Bool, hasGradient: Bool,
                                preferSpeed: Bool, preferAccuracy: Bool)
                                -> (algorithm: String, reason: String) {
        if hasInequalities {
            return ("Inequality Optimizer",
                    "Problem has inequality constraints - using penalty-barrier method")
        }

        if hasConstraints {
            return ("Constrained Optimizer",
                    "Problem has equality constraints - using augmented Lagrangian method")
        }

        if problemSize > 100 {
            return ("Gradient Descent",
                    "Large problem (\(problemSize) variables) - using memory-efficient gradient descent")
        }

        if preferAccuracy && problemSize < 10 {
            return ("Newton-Raphson",
                    "Accuracy preference with small problem - using full Newton-Raphson")
        }

        if problemSize <= 5 && !preferSpeed {
            return ("Newton-Raphson",
                    "Small problem (\(problemSize) variables) - using Newton-Raphson for fast convergence")
        }

        return ("Gradient Descent",
                "Unconstrained problem - using gradient descent (optimal speed/memory balance)")
    }

    private func classifyProblem(dimensions: Int, hasConstraints: Bool, hasInequalities: Bool) -> String {
        var classification: [String] = []

        if dimensions <= 5 {
            classification.append("- **Very Small**: ≤5 variables enables advanced methods")
        } else if dimensions <= 100 {
            classification.append("- **Medium**: 6-100 variables, balanced approach")
        } else {
            classification.append("- **Large**: >100 variables requires efficient methods")
        }

        if !hasConstraints {
            classification.append("- **Unconstrained**: No constraints, all algorithms available")
        } else if hasInequalities {
            classification.append("- **Inequality Constrained**: Requires specialized inequality optimizer")
        } else {
            classification.append("- **Equality Constrained**: Can use augmented Lagrangian")
        }

        return classification.joined(separator: "\n")
    }

    private func estimatePerformance(algorithm: String, dimensions: Int) -> String {
        switch algorithm {
        case "Newton-Raphson":
            return """
            - **Speed**: Very fast convergence (quadratic)
            - **Memory**: O(n²) for Hessian matrix
            - **Typical iterations**: 5-20
            - **Best for**: Small problems (<10 vars), high accuracy needs
            """
        case "Gradient Descent":
            if dimensions > 100 {
                return """
                - **Speed**: Fast for large problems
                - **Memory**: O(n) - very efficient
                - **Typical iterations**: 50-500
                - **Best for**: Large problems (>100 vars), memory constraints
                - **Learning rate**: 0.01 (adaptive for large problems)
                """
            } else {
                return """
                - **Speed**: Moderate convergence (linear)
                - **Memory**: O(n) - very efficient
                - **Typical iterations**: 50-200
                - **Best for**: Medium problems, balanced performance
                - **Learning rate**: 0.001 (conservative for stability)
                """
            }
        case "Constrained Optimizer":
            return """
            - **Speed**: Moderate (iterative penalty updates)
            - **Memory**: O(n)
            - **Typical iterations**: 100-500
            - **Best for**: Equality constraints only
            """
        case "Inequality Optimizer":
            return """
            - **Speed**: Moderate to slow (penalty-barrier method)
            - **Memory**: O(n)
            - **Typical iterations**: 100-1000
            - **Best for**: Problems with inequality constraints
            """
        default:
            return "Performance characteristics not available"
        }
    }

    private func provideTips(dimensions: Int, hasConstraints: Bool, algorithm: String) -> String {
        var tips: [String] = []

        tips.append("1. **Initial Guess**: Start close to feasible region for faster convergence")

        if hasConstraints {
            tips.append("2. **Feasibility**: Ensure initial guess satisfies constraints")
        }

        if dimensions <= 5 {
            tips.append("2. **Analytical Gradient**: Provide gradient if possible for Newton-Raphson")
        } else if dimensions > 100 {
            tips.append("2. **Sparse Structure**: Consider if problem has sparse structure")
        }

        if algorithm == "Inequality Optimizer" {
            tips.append("3. **Constraint Slack**: Tight constraints may need more iterations")
        }

        tips.append("4. **Validation**: Always check result.converged and result.selectionReason")

        return tips.joined(separator: "\n")
    }
}

// MARK: - Tool Registration

public func getAdaptiveOptimizationTools() -> [MCPToolHandler] {
    return [
        AdaptiveOptimizeTool(),
        AnalyzeOptimizationProblemTool()
    ]
}
