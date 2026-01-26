import Foundation
import MCP
import BusinessMath

// MARK: - Multi-Period Optimization Tool

public struct MultiPeriodOptimizeTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "optimize_multiperiod",
        description: """
        Optimize decisions across multiple time periods with inter-temporal constraints.

        Perfect for:
        - Capital budgeting over multiple years
        - Portfolio rebalancing strategies
        - Production planning with inventory
        - Resource allocation over time
        - Financial planning across quarters/years

        Handles:
        - Time-varying decisions (xₜ for each period t)
        - Discount factors for time value of money
        - Intra-temporal constraints (within each period)
        - Inter-temporal constraints (linking periods)
        - Terminal constraints (final state requirements)

        Example: 3-year capital budgeting
        - numberOfPeriods: 3
        - discountRate: 0.08
        - problemType: "capital_budgeting"

        Returns implementation guidance with Swift code example.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "numberOfPeriods": MCPSchemaProperty(
                    type: "integer",
                    description: "Number of time periods to optimize over (e.g., 3 years, 12 quarters, 52 weeks)"
                ),
                "discountRate": MCPSchemaProperty(
                    type: "number",
                    description: "Discount rate per period for time value of money (e.g., 0.08 for 8% annual rate)"
                ),
                "problemType": MCPSchemaProperty(
                    type: "string",
                    description: "Type of problem: 'capital_budgeting', 'portfolio_rebalancing', 'production_planning', 'resource_allocation'",
                    enum: ["capital_budgeting", "portfolio_rebalancing", "production_planning", "resource_allocation"]
                ),
                "dimensions": MCPSchemaProperty(
                    type: "integer",
                    description: "Number of decision variables per period (e.g., 4 assets, 10 projects, 5 products)"
                ),
                "hasInterdependence": MCPSchemaProperty(
                    type: "boolean",
                    description: "Do decisions in one period affect constraints in the next? (e.g., inventory carryover, turnover limits)"
                )
            ],
            required: ["numberOfPeriods", "discountRate", "problemType", "dimensions"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let numberOfPeriods = try args.getInt("numberOfPeriods")
        let discountRate = try args.getDouble("discountRate")
        let problemType = try args.getString("problemType")
        let dimensions = try args.getInt("dimensions")
        let hasInterdependence = args.getBoolOptional("hasInterdependence") ?? false

        let discountFactor = 1.0 / (1.0 + discountRate)

        let guide = """
        📅 **Multi-Period Optimization Guide**

        **Problem Configuration:**
        - Periods: \(numberOfPeriods) time periods
        - Discount rate: \(String(format: "%.1f%%", discountRate * 100)) per period
        - Discount factor δ: \(String(format: "%.4f", discountFactor))
        - Problem type: \(problemType.replacingOccurrences(of: "_", with: " "))
        - Decision variables per period: \(dimensions)
        - Inter-temporal dependencies: \(hasInterdependence ? "Yes" : "No")

        **What This Optimizes:**
        ```
        minimize: Σₜ₌₀^T δᵗ f(xₜ)

        where:
        - xₜ = decision vector at period t
        - δ = discount factor (\(String(format: "%.4f", discountFactor)))
        - f(xₜ) = objective function at period t
        ```

        **Time Value Impact:**
        - Period 0 weight: 1.000 (present value)
        - Period 1 weight: \(String(format: "%.3f", discountFactor))
        - Period 2 weight: \(String(format: "%.3f", pow(discountFactor, 2)))
        - Period \(numberOfPeriods-1) weight: \(String(format: "%.3f", pow(discountFactor, Double(numberOfPeriods-1))))

        Future costs/revenues are automatically discounted to present value.

        **Swift Implementation:**
        ```swift
        import BusinessMath

        // Create multi-period optimizer
        let optimizer = MultiPeriodOptimizer<VectorN<Double>>(
            numberOfPeriods: \(numberOfPeriods),
            discountRate: \(discountRate),
            maxIterations: 1000,
            tolerance: 1e-6
        )

        // Define period-specific objective
        let objective: @Sendable (Int, VectorN<Double>) -> Double = { period, x in
            // x contains decisions for this period
            // Return objective value for this period (will be discounted automatically)
            \(getObjectiveExample(problemType: problemType, dimensions: dimensions))
        }

        // Initial state (starting point for period 0)
        let initialState = VectorN(Array(repeating: \(getInitialValue(problemType: problemType, dimensions: dimensions)), count: \(dimensions)))

        // Define constraints
        let constraints: [MultiPeriodConstraint<VectorN<Double>>] = [
            \(getConstraintsExample(problemType: problemType, hasInterdependence: hasInterdependence))
        ]

        // Optimize
        let result = try optimizer.optimize(
            objective: objective,
            initialState: initialState,
            constraints: constraints
        )

        // Analyze results
        print("Total discounted value: \\(result.totalObjective)")
        print("Converged: \\(result.converged) in \\(result.iterations) iterations")
        print("\\nOptimal trajectory:")
        for (t, state) in result.trajectory.enumerated() {
            let periodValue = result.periodObjectives[t]
            let discounted = periodValue * pow(\(discountFactor), Double(t))
            print("  Period \\(t): \\(state) → $\\(String(format: "%.2f", periodValue)) (PV: $\\(String(format: "%.2f", discounted)))")
        }
        ```

        **Common Patterns:**

        \(getPatternExamples(problemType: problemType))

        **Tips for Success:**
        - Start with fewer periods (3-5) to verify correctness
        - Use reasonable initial guesses close to feasibility
        - Inter-temporal constraints couple periods (slower but more realistic)
        - Higher discount rates favor early periods
        - Check constraint violations in result

        **Resources:**
        - Tutorial: Multi-Period Optimization Guide (TBD)
        - Example: Portfolio Rebalancing with Transaction Costs
        - API Reference: MultiPeriodOptimizer.swift
        """

        return .success(text: guide)
    }

    private func getObjectiveExample(problemType: String, dimensions: Int) -> String {
        switch problemType {
        case "capital_budgeting":
            return """
            // Maximize NPV of selected projects
                    let projectNPVs = getProjectNPVs(period: period)  // Your data
                    return -x.dot(VectorN(projectNPVs))  // Negative for maximization
            """
        case "portfolio_rebalancing":
            return """
            // Minimize risk or maximize return
                    let expectedReturns = getReturns(period: period)
                    let riskMatrix = getCovarianceMatrix()
                    let portfolioReturn = x.dot(VectorN(expectedReturns))
                    let portfolioRisk = x.dot(riskMatrix * x)
                    return portfolioRisk - portfolioReturn  // Risk-adjusted
            """
        case "production_planning":
            return """
            // Minimize production + inventory costs
                    let productionCosts = getProductionCosts(period: period)
                    let inventoryCosts = getInventoryCosts(period: period)
                    return x.dot(VectorN(productionCosts + inventoryCosts))
            """
        default:
            return """
            // Your objective function here
                    return someValue  // Calculated from x and period
            """
        }
    }

    private func getInitialValue(problemType: String, dimensions: Int) -> String {
        switch problemType {
        case "portfolio_rebalancing":
            return "1.0/\(dimensions)"  // Equal weights
        case "production_planning":
            return "100.0"  // Initial production level
        default:
            return "0.0"
        }
    }

    private func getConstraintsExample(problemType: String, hasInterdependence: Bool) -> String {
        var examples: [String] = []

        switch problemType {
        case "capital_budgeting":
            examples.append(".budgetConstraint(budget: 1_000_000)")
            examples.append(".binaryDecisions  // 0 or 1 for each project")
            if hasInterdependence {
                examples.append(".cumulativeBudget(totalBudget: 3_000_000)  // Across all periods")
            }

        case "portfolio_rebalancing":
            examples.append(".budgetEachPeriod  // Σw = 1 in each period")
            examples.append(".longOnly  // w ≥ 0")
            if hasInterdependence {
                examples.append(".turnoverLimit(0.20)  // Max 20% rebalancing between periods")
            }

        case "production_planning":
            examples.append(".capacityConstraint(maxProduction: 10000)")
            if hasInterdependence {
                examples.append(".inventoryBalance  // Links production to demand")
            }

        default:
            examples.append("// Your constraints here")
        }

        return examples.joined(separator: ",\n            ")
    }

    private func getPatternExamples(problemType: String) -> String {
        switch problemType {
        case "capital_budgeting":
            return """
            **Capital Budgeting:**
            - Period 0: Initial project selection
            - Period 1-N: Project continuation decisions
            - Terminal constraint: All projects must complete
            - Discount rate captures cost of capital
            """
        case "portfolio_rebalancing":
            return """
            **Portfolio Rebalancing:**
            - Each period: Rebalance portfolio weights
            - Turnover constraint: Limit trading costs
            - Transaction costs in objective
            - Terminal value: Final portfolio worth
            """
        case "production_planning":
            return """
            **Production Planning:**
            - Each period: Production quantities
            - Inventory carryover between periods
            - Demand satisfaction constraints
            - Minimize total production + inventory costs
            """
        default:
            return "See documentation for problem-specific patterns."
        }
    }
}

// MARK: - Stochastic Optimization Tool

public struct StochasticOptimizeTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "optimize_stochastic",
        description: """
        Optimize decisions under uncertainty using Sample Average Approximation (SAA).

        Perfect for:
        - Portfolio optimization with uncertain returns
        - Production planning with demand uncertainty
        - Supply chain with price volatility
        - Resource allocation under operational risk
        - Investment decisions with market uncertainty

        Uses Monte Carlo sampling to approximate:
        minimize E[f(x, ω)]

        where ω represents uncertain parameters (returns, demand, prices, etc.)

        Example: Portfolio with uncertain returns
        - numberOfSamples: 1000
        - problemType: "portfolio"
        - uncertainParameters: ["returns"]

        Returns implementation guidance with Swift code.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "numberOfSamples": MCPSchemaProperty(
                    type: "integer",
                    description: "Number of Monte Carlo scenarios to generate (more = accurate but slower, 500-5000 typical)"
                ),
                "problemType": MCPSchemaProperty(
                    type: "string",
                    description: "Type of problem under uncertainty",
                    enum: ["portfolio", "production", "supply_chain", "investment", "newsvendor"]
                ),
                "uncertainParameters": MCPSchemaProperty(
                    type: "array",
                    description: "Which parameters are uncertain (e.g., returns, demand, costs, prices)",
                    items: MCPSchemaItems(type: "string")
                ),
                "dimensions": MCPSchemaProperty(
                    type: "integer",
                    description: "Number of decision variables (e.g., 5 assets, 10 products)"
                )
            ],
            required: ["numberOfSamples", "problemType", "dimensions"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let numberOfSamples = try args.getInt("numberOfSamples")
        let problemType = try args.getString("problemType")
        let dimensions = try args.getInt("dimensions")

        let guide = """
        🎲 **Stochastic Optimization Guide**

        **Problem Configuration:**
        - Monte Carlo samples: \(numberOfSamples) scenarios
        - Problem type: \(problemType)
        - Decision variables: \(dimensions)

        **What This Optimizes:**
        ```
        minimize: E[f(x, ω)] ≈ (1/N) Σᵢ f(x, ωᵢ)

        where:
        - x = decision variables (same for all scenarios)
        - ω = uncertain parameters (different each scenario)
        - N = \(numberOfSamples) scenarios
        ```

        **Sample Efficiency:**
        - 100 samples: Quick exploration, rough estimate
        - 500 samples: Good balance, ~4.5% error
        - 1000 samples: Accurate, ~3.2% error ✓ Recommended
        - 5000 samples: Very accurate, ~1.4% error

        **Swift Implementation:**
        ```swift
        import BusinessMath

        // Create stochastic optimizer
        let optimizer = StochasticOptimizer<VectorN<Double>>(
            numberOfSamples: \(numberOfSamples),
            seed: 42,  // For reproducibility
            maxIterations: 1000,
            tolerance: 1e-6
        )

        // Define stochastic objective
        let objective: @Sendable (VectorN<Double>, OptimizationScenario) -> Double = { x, scenario in
            // x: your decision variables
            // scenario.parameters: uncertain parameters for this scenario

            \(getStochasticObjective(problemType: problemType))
        }

        // Define scenario generator (uncertainty model)
        let scenarioGenerator: () -> OptimizationScenario = {
            \(getScenarioGenerator(problemType: problemType, dimensions: dimensions))
        }

        // Initial solution
        let initialSolution = VectorN(Array(repeating: \(getStochasticInitial(problemType: problemType)), count: \(dimensions)))

        // Constraints (same across all scenarios)
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            \(getStochasticConstraints(problemType: problemType))
        ]

        // Optimize
        let result = try optimizer.optimize(
            objective: objective,
            scenarioGenerator: scenarioGenerator,
            initialSolution: initialSolution,
            constraints: constraints
        )

        // Analyze results
        print("Optimal solution: \\(result.solution)")
        print("Expected objective: \\(result.expectedObjective)")
        print("Standard deviation: \\(result.objectiveStdDev)")
        print("Converged: \\(result.converged)")

        // Risk analysis
        let sortedObjectives = result.scenarioObjectives.sorted()
        let var95 = sortedObjectives[Int(0.95 * Double(result.numberOfScenarios))]
        print("95% VaR: \\(var95)")  // 95% of scenarios better than this
        ```

        **Understanding Results:**

        **Expected Objective:** Average performance across all \(numberOfSamples) scenarios
        **Std Deviation:** Risk/variability of outcomes
        - Low: Consistent results regardless of uncertainty
        - High: Outcome highly dependent on which scenario occurs

        **Scenario Objectives:** Performance in each individual scenario
        - Analyze distribution to understand risk
        - Calculate VaR, CVaR for downside risk

        **Common Patterns:**

        \(getStochasticPatterns(problemType: problemType))

        **Tips for Success:**
        - Use \(max(500, numberOfSamples)) samples minimum for stable results
        - Set random seed for reproducibility
        - Compare expected objective vs. deterministic solution
        - Analyze worst-case scenarios (tail of distribution)
        - Higher variance = more important to use stochastic optimization

        **Resources:**
        - Tutorial: Stochastic Optimization Guide (TBD)
        - Example: Portfolio with Uncertain Returns
        - API Reference: StochasticOptimizer.swift
        """

        return .success(text: guide)
    }

    private func getStochasticObjective(problemType: String) -> String {
        switch problemType {
        case "portfolio":
            return """
            // Extract uncertain returns from scenario
                    let returns = scenario.parameters.compactMap { $0.value }
                    let portfolioReturn = x.dot(VectorN(returns))
                    return -portfolioReturn  // Negative for maximization
            """
        case "production", "newsvendor":
            return """
            // Extract uncertain demand from scenario
                    let demand = scenario.parameters.first!.value
                    let production = x[0]
                    let overageCost = max(0, production - demand) * 5.0
                    let underageCost = max(0, demand - production) * 20.0
                    return overageCost + underageCost
            """
        default:
            return """
            // Your stochastic objective
                    let uncertainValue = scenario.parameters.first!.value
                    return someFunction(x, uncertainValue)
            """
        }
    }

    private func getScenarioGenerator(problemType: String, dimensions: Int) -> String {
        switch problemType {
        case "portfolio":
            return """
            // Normal returns for each asset
                    let means = [0.10, 0.12, 0.08]  // Expected returns
                    let stdDevs = [0.15, 0.20, 0.12]  // Volatilities
                    return ScenarioGenerator.normal(
                        mean: means,
                        standardDeviation: stdDevs,
                        numberOfScenarios: 1,
                        seed: nil
                    ).first!
            """
        case "production", "newsvendor":
            return """
            // Normal demand with mean 1000, std 200
                    return ScenarioGenerator.normal(
                        mean: [1000.0],
                        standardDeviation: [200.0],
                        numberOfScenarios: 1,
                        seed: nil
                    ).first!
            """
        default:
            return """
            // Define your uncertainty distribution
                    return OptimizationScenario(parameters: [
                        ScenarioParameter(name: "uncertain_param", value: Double.random(in: 0...1))
                    ])
            """
        }
    }

    private func getStochasticInitial(problemType: String) -> String {
        switch problemType {
        case "portfolio":
            return "1.0/Double(dimensions)"  // Equal weights
        case "production", "newsvendor":
            return "1000.0"  // Initial production guess
        default:
            return "1.0"
        }
    }

    private func getStochasticConstraints(problemType: String) -> String {
        switch problemType {
        case "portfolio":
            return """
            .budgetConstraint,  // Σw = 1
                .longOnly  // w ≥ 0
            """
        case "production", "newsvendor":
            return """
            .nonNegativity,
                .upperBound(10000.0)  // Production capacity
            """
        default:
            return "// Your constraints"
        }
    }

    private func getStochasticPatterns(problemType: String) -> String {
        switch problemType {
        case "portfolio":
            return """
            **Portfolio Optimization:**
            - Uncertain: Future asset returns
            - Decision: Portfolio weights (must sum to 1)
            - Objective: Maximize expected return or Sharpe ratio
            - Stochastic solution typically more conservative than mean-return
            """
        case "production", "newsvendor":
            return """
            **Newsvendor / Production:**
            - Uncertain: Customer demand
            - Decision: Production quantity
            - Objective: Minimize overage + underage costs
            - Optimal = balance between waste and stockouts
            """
        default:
            return "See documentation for problem-specific patterns."
        }
    }
}

// MARK: - Robust Optimization Tool

public struct RobustOptimizeTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "optimize_robust",
        description: """
        Optimize for worst-case performance across uncertainty scenarios (min-max optimization).

        Perfect for:
        - Conservative planning (guarantee minimum performance)
        - Risk management (protect against worst outcomes)
        - Adversarial scenarios (competitive markets)
        - Regulatory compliance (meet requirements in all cases)
        - Safety-critical decisions

        Solves: minimize max_ω f(x, ω)

        More conservative than stochastic optimization - guarantees good performance
        even in worst-case scenarios.

        Example: Robust production planning
        - numberOfScenarios: 100
        - problemType: "production"
        - robustnessFactor: 0.95

        Returns implementation guidance.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "numberOfScenarios": MCPSchemaProperty(
                    type: "integer",
                    description: "Number of scenarios to consider for worst-case (50-200 typical)"
                ),
                "problemType": MCPSchemaProperty(
                    type: "string",
                    description: "Type of robust planning problem",
                    enum: ["production", "portfolio", "supply_chain", "capacity_planning"]
                ),
                "robustnessFactor": MCPSchemaProperty(
                    type: "number",
                    description: "Robustness level: 1.0 = full worst-case, 0.95 = 95th percentile (default: 1.0)"
                ),
                "dimensions": MCPSchemaProperty(
                    type: "integer",
                    description: "Number of decision variables"
                )
            ],
            required: ["numberOfScenarios", "problemType", "dimensions"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let numberOfScenarios = try args.getInt("numberOfScenarios")
        let problemType = try args.getString("problemType")
        let robustnessFactor = args.getDoubleOptional("robustnessFactor") ?? 1.0
        let dimensions = try args.getInt("dimensions")

        let guide = """
        🛡️ **Robust Optimization Guide**

        **Problem Configuration:**
        - Scenarios to protect against: \(numberOfScenarios)
        - Problem type: \(problemType)
        - Robustness factor: \(String(format: "%.0f%%", robustnessFactor * 100))
        - Decision variables: \(dimensions)

        **What This Optimizes:**
        ```
        minimize: max_ω f(x, ω)

        where:
        - x = decision variables (robust choice)
        - ω = worst-case uncertain parameters
        - Protects against worst \(String(format: "%.0f%%", (1-robustnessFactor) * 100)) of scenarios
        ```

        **Robustness Interpretation:**
        - 1.00 (100%): Protect against absolute worst case
        - 0.95 (95%): Protect against 95th percentile
        - 0.90 (90%): Less conservative, better average performance

        **Stochastic vs. Robust:**
        - Stochastic: Minimize E[f(x, ω)] (average case)
        - Robust: Minimize max_ω f(x, ω) (worst case)
        - Robust solutions sacrifice average for reliability

        **Swift Implementation:**
        ```swift
        import BusinessMath

        // Create robust optimizer
        let optimizer = RobustOptimizer<VectorN<Double>>(
            numberOfScenarios: \(numberOfScenarios),
            robustnessFactor: \(robustnessFactor),
            seed: 42,
            maxIterations: 1000
        )

        // Define objective (evaluated in each scenario)
        let objective: @Sendable (VectorN<Double>, OptimizationScenario) -> Double = { x, scenario in
            \(getRobustObjective(problemType: problemType))
        }

        // Scenario generator (uncertainty model)
        let scenarioGenerator: () -> OptimizationScenario = {
            \(getRobustScenarioGen(problemType: problemType))
        }

        // Initial solution
        let initialSolution = VectorN(Array(repeating: \(getRobustInitial(problemType: problemType)), count: \(dimensions)))

        // Constraints (must be satisfied in ALL scenarios)
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            \(getRobustConstraints(problemType: problemType))
        ]

        // Optimize
        let result = try optimizer.optimize(
            objective: objective,
            scenarioGenerator: scenarioGenerator,
            initialSolution: initialSolution,
            constraints: constraints
        )

        // Analyze results
        print("Robust solution: \\(result.solution)")
        print("Worst-case objective: \\(result.worstCaseObjective)")
        print("Average objective: \\(result.averageObjective)")
        print("Best-case objective: \\(result.bestCaseObjective)")
        print("Converged: \\(result.converged)")

        // Compare to stochastic
        print("\\nPrice of robustness:")
        print("  Worst case guaranteed: \\(result.worstCaseObjective)")
        print("  Could average: \\(result.averageObjective)")
        print("  Gap: \\(result.averageObjective - result.worstCaseObjective)")
        ```

        **Understanding Results:**

        **Worst-Case Objective:** Guaranteed performance level
        - Decision protects against this scenario
        - \(String(format: "%.0f%%", robustnessFactor * 100)) of scenarios will be better

        **Average Objective:** Expected performance
        - Usually worse than pure stochastic solution
        - Price paid for robustness

        **Robustness Gap:** Difference between worst and average
        - Large gap: High uncertainty, robustness very valuable
        - Small gap: Low uncertainty, less benefit from robustness

        **Common Patterns:**

        \(getRobustPatterns(problemType: problemType))

        **When to Use Robust vs. Stochastic:**

        ✓ Use Robust When:
        - Can't tolerate bad outcomes (safety, compliance)
        - Downside risk is asymmetric (bankruptcy, reputation)
        - Limited information about probability distributions
        - Adversarial or competitive environment

        ✓ Use Stochastic When:
        - Can tolerate some bad outcomes
        - Good probability models available
        - Want best average performance
        - Many independent trials

        **Tips for Success:**
        - Start with fewer scenarios (50-100) for speed
        - Compare robust vs. stochastic solutions
        - Adjust robustnessFactor based on risk tolerance
        - Check constraint satisfaction in all scenarios
        - Test sensitivity to uncertainty bounds

        **Resources:**
        - Tutorial: Robust Optimization Guide (TBD)
        - Example: Robust Production Planning
        - API Reference: RobustOptimizer.swift
        """

        return .success(text: guide)
    }

    private func getRobustObjective(problemType: String) -> String {
        switch problemType {
        case "production":
            return """
            let demand = scenario.parameters.first!.value
                    let production = x[0]
                    let shortage = max(0, demand - production)
                    let excess = max(0, production - demand)
                    return shortage * 50 + excess * 10  // Asymmetric costs
            """
        case "portfolio":
            return """
            let returns = scenario.parameters.map { $0.value }
                    return -x.dot(VectorN(returns))  // Worst-case return
            """
        default:
            return """
            // Objective for this scenario
                    return someValue
            """
        }
    }

    private func getRobustScenarioGen(problemType: String) -> String {
        switch problemType {
        case "production":
            return """
            // Demand uncertainty: uniform 800-1200
                    return OptimizationScenario(parameters: [
                        ScenarioParameter(name: "demand", value: Double.random(in: 800...1200))
                    ])
            """
        case "portfolio":
            return """
            // Returns: normal with uncertainty
                    let means = [0.10, 0.12]
                    let stdDevs = [0.20, 0.25]
                    return ScenarioGenerator.normal(mean: means, standardDeviation: stdDevs, numberOfScenarios: 1).first!
            """
        default:
            return """
            // Your uncertainty model
                    return OptimizationScenario(parameters: [...])
            """
        }
    }

    private func getRobustInitial(problemType: String) -> String {
        switch problemType {
        case "production":
            return "1000.0"
        case "portfolio":
            return "0.5"
        default:
            return "1.0"
        }
    }

    private func getRobustConstraints(problemType: String) -> String {
        switch problemType {
        case "production":
            return ".nonNegativity, .upperBound(2000)"
        case "portfolio":
            return ".budgetConstraint, .longOnly"
        default:
            return "// Your constraints"
        }
    }

    private func getRobustPatterns(problemType: String) -> String {
        switch problemType {
        case "production":
            return """
            **Robust Production:**
            - Protects against demand spikes
            - Higher safety stock than stochastic
            - Guarantees no stockouts (within scenarios)
            - More expensive on average but safe
            """
        case "portfolio":
            return """
            **Robust Portfolio:**
            - Protects against market crashes
            - More diversified than mean-variance
            - Lower expected return but bounded loss
            - Good for risk-averse investors
            """
        default:
            return "See documentation for patterns."
        }
    }
}

// MARK: - Scenario-Based Optimization Tool

public struct ScenarioOptimizeTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "optimize_scenarios",
        description: """
        Optimize decisions across multiple discrete future scenarios with probabilities.

        Perfect for:
        - Strategic planning (recession vs. growth scenarios)
        - Decision trees (discrete outcomes)
        - Contingency planning (what-if analysis)
        - Hedging strategies (multiple market conditions)
        - Project selection under different futures

        Different from stochastic: Uses discrete scenarios with explicit probabilities
        rather than continuous distributions.

        Example: Capacity planning under 3 demand scenarios
        - scenarios: [{"name": "Low", "probability": 0.2}, {"name": "Base", "probability": 0.5}, {"name": "High", "probability": 0.3}]

        Returns implementation guidance.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "numberOfScenarios": MCPSchemaProperty(
                    type: "integer",
                    description: "Number of discrete scenarios (typically 3-10 for strategic planning)"
                ),
                "problemType": MCPSchemaProperty(
                    type: "string",
                    description: "Type of scenario planning problem",
                    enum: ["strategic_planning", "capacity_planning", "hedging", "project_selection", "decision_tree"]
                ),
                "dimensions": MCPSchemaProperty(
                    type: "integer",
                    description: "Number of decision variables"
                ),
                "hasProbabilities": MCPSchemaProperty(
                    type: "boolean",
                    description: "Do you know the probability of each scenario? (If false, assumes equal probabilities)"
                )
            ],
            required: ["numberOfScenarios", "problemType", "dimensions"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let numberOfScenarios = try args.getInt("numberOfScenarios")
        let problemType = try args.getString("problemType")
        let dimensions = try args.getInt("dimensions")
        let hasProbabilities = args.getBoolOptional("hasProbabilities") ?? true

        let equalProb = 1.0 / Double(numberOfScenarios)

        let guide = """
        🌲 **Scenario-Based Optimization Guide**

        **Problem Configuration:**
        - Number of scenarios: \(numberOfScenarios) discrete futures
        - Problem type: \(problemType.replacingOccurrences(of: "_", with: " "))
        - Decision variables: \(dimensions)
        - Probabilities: \(hasProbabilities ? "Specified" : "Equal (\(String(format: "%.1f%%", equalProb * 100)) each)")

        **What This Optimizes:**
        ```
        minimize: Σᵢ pᵢ · f(x, sᵢ)

        where:
        - x = decision (same across scenarios)
        - sᵢ = discrete scenario i
        - pᵢ = probability of scenario i
        - Σpᵢ = 1.0
        ```

        **Scenario Planning Approach:**
        - Define \(numberOfScenarios) plausible future states
        - Assign probability to each (\(hasProbabilities ? "known" : "equal assumed"))
        - Find decision that performs well across all
        - Trade off between scenarios based on probabilities

        **Swift Implementation:**
        ```swift
        import BusinessMath

        // Define scenarios
        let scenarios: [Scenario<VectorN<Double>>] = [
            \(getExampleScenarios(problemType: problemType, numberOfScenarios: numberOfScenarios, hasProbabilities: hasProbabilities))
        ]

        // Create scenario optimizer
        let optimizer = ScenarioOptimizer<VectorN<Double>>(
            scenarios: scenarios,
            maxIterations: 1000,
            tolerance: 1e-6
        )

        // Define scenario-specific objective
        let objective: @Sendable (VectorN<Double>, Scenario<VectorN<Double>>) -> Double = { x, scenario in
            \(getScenarioObjective(problemType: problemType))
        }

        // Initial solution
        let initialSolution = VectorN(Array(repeating: \(getScenarioInitial(problemType: problemType)), count: \(dimensions)))

        // Constraints (same across all scenarios)
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            \(getScenarioConstraints(problemType: problemType))
        ]

        // Optimize
        let result = try optimizer.optimize(
            objective: objective,
            initialSolution: initialSolution,
            constraints: constraints
        )

        // Analyze results
        print("Optimal solution: \\(result.solution)")
        print("Expected objective: \\(result.expectedObjective)")
        print("Converged: \\(result.converged)")

        print("\\nPerformance by scenario:")
        for (i, scenarioObj) in result.scenarioObjectives.enumerated() {
            let scenario = scenarios[i]
            print("  \\(scenario.name): \\(scenarioObj) (probability: \\(scenario.probability))")
        }

        // Worst-case analysis
        let worstScenario = result.scenarioObjectives.max()!
        let bestScenario = result.scenarioObjectives.min()!
        print("\\nRange: \\(bestScenario) to \\(worstScenario)")
        print("Spread: \\(worstScenario - bestScenario)")
        ```

        **Scenario Design Tips:**

        \(getScenarioDesignTips(problemType: problemType, numberOfScenarios: numberOfScenarios))

        **Understanding Results:**

        **Expected Objective:** Probability-weighted average
        - This is what you optimize for
        - Good overall performance across scenarios

        **Scenario Objectives:** Performance in each specific scenario
        - Shows how decision performs if that future occurs
        - Identify scenarios where solution struggles

        **Range Analysis:** Best to worst scenario
        - Large range: Decision is sensitive to future
        - Small range: Decision is robust across scenarios

        **Common Patterns:**

        \(getScenarioPatterns(problemType: problemType))

        **Scenario Planning vs. Other Approaches:**

        | Approach | Best For | Number of Futures |
        |----------|----------|-------------------|
        | Scenario | Strategic planning | 3-10 discrete scenarios |
        | Stochastic | Operational planning | 100s-1000s continuous |
        | Robust | Worst-case protection | 50-200 adversarial |
        | Deterministic | No uncertainty | 1 (expected case) |

        **Tips for Success:**
        - Use 3-5 scenarios for strategic decisions
        - Make scenarios distinct and plausible
        - Consider: pessimistic, base, optimistic
        - Assign probabilities based on analysis
        - Test sensitivity to probabilities
        - Document scenario assumptions

        **Resources:**
        - Tutorial: Scenario-Based Planning Guide (TBD)
        - Example: Capacity Planning Under Demand Scenarios
        - API Reference: ScenarioOptimizer.swift
        """

        return .success(text: guide)
    }

    private func getExampleScenarios(problemType: String, numberOfScenarios: Int, hasProbabilities: Bool) -> String {
        let probs = hasProbabilities ?
            ["0.2", "0.5", "0.3"] :
            Array(repeating: String(format: "%.2f", 1.0/Double(numberOfScenarios)), count: numberOfScenarios)

        switch problemType {
        case "capacity_planning", "strategic_planning":
            return """
            Scenario(name: "Recession", probability: \(probs[0]), parameters: OptimizationScenario(parameters: [
                        ScenarioParameter(name: "demand_growth", value: -0.05)
                    ])),
                    Scenario(name: "Base Case", probability: \(probs.count > 1 ? probs[1] : probs[0]), parameters: OptimizationScenario(parameters: [
                        ScenarioParameter(name: "demand_growth", value: 0.03)
                    ])),
                    Scenario(name: "Boom", probability: \(probs.count > 2 ? probs[2] : probs[0]), parameters: OptimizationScenario(parameters: [
                        ScenarioParameter(name: "demand_growth", value: 0.10)
                    ]))
            """
        default:
            return """
            // Define your scenarios
                    Scenario(name: "Scenario 1", probability: \(probs[0]), parameters: ...)
            """
        }
    }

    private func getScenarioObjective(problemType: String) -> String {
        switch problemType {
        case "capacity_planning":
            return """
            let demandGrowth = scenario.parameters.parameters.first!.value
                    let capacity = x[0]
                    let expectedDemand = 1000 * (1 + demandGrowth)
                    let shortage = max(0, expectedDemand - capacity) * 100  // Lost sales
                    let excess = max(0, capacity - expectedDemand) * 10  // Idle capacity
                    return shortage + excess
            """
        case "project_selection":
            return """
            let marketCondition = scenario.parameters.parameters.first!.value
                    let projectReturns = getReturns(marketCondition)
                    return -x.dot(VectorN(projectReturns))  // Negative for max
            """
        default:
            return """
            // Scenario-specific objective
                    return someValue(x, scenario)
            """
        }
    }

    private func getScenarioInitial(problemType: String) -> String {
        switch problemType {
        case "capacity_planning":
            return "1000.0"
        case "project_selection":
            return "0.0"
        default:
            return "1.0"
        }
    }

    private func getScenarioConstraints(problemType: String) -> String {
        switch problemType {
        case "capacity_planning":
            return ".nonNegativity, .upperBound(5000)"
        case "project_selection":
            return ".budgetConstraint(1_000_000), .binaryDecisions"
        default:
            return "// Your constraints"
        }
    }

    private func getScenarioDesignTips(problemType: String, numberOfScenarios: Int) -> String {
        let common = """
        **Good Scenarios Are:**
        1. **Plausible** - Could realistically happen
        2. **Distinct** - Different enough to matter
        3. **Comprehensive** - Cover range of possibilities
        4. **Actionable** - You can respond to them
        """

        switch problemType {
        case "strategic_planning":
            return """
            \(common)

            **Typical 3-Scenario Structure:**
            - Pessimistic (20%): Recession, low growth, high competition
            - Base Case (50%): Expected trajectory, moderate growth
            - Optimistic (30%): Economic boom, market expansion
            """
        case "capacity_planning":
            return """
            \(common)

            **Demand-Driven Scenarios:**
            - Low Demand: Market contraction, substitute products
            - Medium Demand: Steady growth, market share stable
            - High Demand: Market expansion, new customers
            """
        default:
            return common
        }
    }

    private func getScenarioPatterns(problemType: String) -> String {
        switch problemType {
        case "capacity_planning":
            return """
            **Capacity Planning:**
            - Scenarios: Low/Medium/High demand
            - Decision: Capacity investment level
            - Tradeoff: Underutilization vs. shortage
            - Optimal: Balances scenarios by probability
            """
        case "project_selection":
            return """
            **Project Selection:**
            - Scenarios: Different market conditions
            - Decision: Which projects to fund
            - Consider: Project synergies, diversification
            - Robust projects selected across scenarios
            """
        default:
            return "See documentation for problem-specific patterns."
        }
    }
}

// MARK: - Tool Registration

public func getAdvancedOptimizationTools() -> [MCPToolHandler] {
    return [
        MultiPeriodOptimizeTool(),
        StochasticOptimizeTool(),
        RobustOptimizeTool(),
        ScenarioOptimizeTool()
    ]
}
