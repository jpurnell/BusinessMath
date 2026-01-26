import Foundation
import MCP
import BusinessMath

// MARK: - Mean-Variance Portfolio Optimization Tool

public struct MeanVariancePortfolioTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "optimize_mean_variance_portfolio",
        description: """
        Optimize portfolio allocation using mean-variance optimization (Markowitz framework).
        Creates realistic, diversified portfolios by balancing expected return against risk.

        **Key Features:**
        - Risk-return tradeoff via mean-variance objective: E[r] - λ×σ²
        - Covariance matrix accounts for asset correlations
        - Concentration limits prevent extreme positions
        - Produces diversified portfolios (NOT trivial "all in highest return")

        **Perfect for:**
        - Portfolio construction with explicit risk control
        - Understanding diversification benefits
        - Comparing risk-averse vs. aggressive strategies
        - Demonstrating correlation effects on allocation

        **Example: Three-asset portfolio**
        ```json
        {
          "expectedReturns": [0.08, 0.12, 0.15],
          "covarianceMatrix": [
            [0.0100, 0.0036, 0.0075],
            [0.0036, 0.0324, 0.0270],
            [0.0075, 0.0270, 0.0625]
          ],
          "riskAversion": 2.0,
          "concentrationLimit": 0.60,
          "budget": 100000
        }
        ```

        **Returns:**
        - Optimal portfolio weights (NOT 100% in single asset!)
        - Expected portfolio return
        - Portfolio risk (volatility)
        - Sharpe ratio
        - Allocation breakdown with risk contribution

        **Based on:** Part5-Optimization.md validated examples (line 113+)
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "expectedReturns": MCPSchemaProperty(
                    type: "array",
                    description: """
                    Expected return for each asset (e.g., [0.08, 0.12, 0.15] for 8%, 12%, 15%).
                    Must be annualized rates in same units as covariance matrix.
                    """,
                    items: MCPSchemaItems(type: "number")
                ),
                "covarianceMatrix": MCPSchemaProperty(
                    type: "array",
                    description: """
                    Covariance matrix of asset returns (NxN where N = number of assets).
                    Diagonal elements are variances (σ²), off-diagonal are covariances.
                    Example for 3 assets:
                    [[var1, cov12, cov13],
                     [cov21, var2, cov23],
                     [cov31, cov32, var3]]
                    """,
                    items: MCPSchemaItems(type: "array")
                ),
                "riskAversion": MCPSchemaProperty(
                    type: "number",
                    description: """
                    Risk aversion parameter (λ). Higher values favor lower-risk portfolios.
                    - λ = 1.0: Moderate risk tolerance
                    - λ = 2.0: Conservative (recommended default)
                    - λ = 5.0: Very risk-averse

                    Objective: maximize E[r] - λ×σ²
                    """
                ),
                "concentrationLimit": MCPSchemaProperty(
                    type: "number",
                    description: """
                    Maximum weight allowed in any single asset (0.0 to 1.0).
                    - 0.60: Max 60% per asset (recommended)
                    - 0.40: Max 40% per asset (strict diversification)
                    - 1.00: No limit (may produce concentrated portfolios)

                    Prevents trivial "all in one asset" solutions.
                    """
                ),
                "budget": MCPSchemaProperty(
                    type: "number",
                    description: "Total capital to allocate (e.g., 100000 for $100K portfolio)"
                ),
                "riskFreeRate": MCPSchemaProperty(
                    type: "number",
                    description: "Risk-free rate for Sharpe ratio calculation (optional, default: 0.02 for 2%)"
                ),
                "assetNames": MCPSchemaProperty(
                    type: "array",
                    description: "Optional names for assets (e.g., ['Stocks', 'Bonds', 'Real Estate'])",
                    items: MCPSchemaItems(type: "string")
                )
            ],
            required: ["expectedReturns", "covarianceMatrix", "riskAversion", "budget"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        // Parse expected returns - handle both [Double] (testing) and [AnyCodable] (MCP)
        let expectedReturns: [Double]
        if let doubleArray = args["expectedReturns"]?.value as? [Double] {
            expectedReturns = doubleArray
        } else if let returnsArray = args["expectedReturns"]?.value as? [AnyCodable] {
            expectedReturns = try returnsArray.map { value -> Double in
                if let d = value.value as? Double {
                    return d
                } else if let i = value.value as? Int {
                    return Double(i)
                }
                throw ToolError.invalidArguments("expectedReturns must contain only numbers")
            }
        } else {
            throw ToolError.invalidArguments("expectedReturns must be an array of numbers")
        }

        let n = expectedReturns.count
        guard n >= 2 else {
            throw ToolError.invalidArguments("Must have at least 2 assets")
        }

        // Parse covariance matrix - handle both [[Double]] (testing) and [AnyCodable] (MCP)
        let covarianceMatrix: [[Double]]
        if let doubleMatrix = args["covarianceMatrix"]?.value as? [[Double]] {
            // Validate dimensions for [[Double]] case
            guard doubleMatrix.count == n else {
                throw ToolError.invalidArguments("covarianceMatrix must be \(n)x\(n) (got \(doubleMatrix.count) rows)")
            }
            for (i, row) in doubleMatrix.enumerated() {
                guard row.count == n else {
                    throw ToolError.invalidArguments("covarianceMatrix row \(i) must have \(n) elements (got \(row.count))")
                }
            }
            covarianceMatrix = doubleMatrix
        } else if let covMatrixArray = args["covarianceMatrix"]?.value as? [AnyCodable] {
            guard covMatrixArray.count == n else {
                throw ToolError.invalidArguments("covarianceMatrix must be \(n)x\(n) (got \(covMatrixArray.count) rows)")
            }

            var matrix: [[Double]] = []
            for (i, rowValue) in covMatrixArray.enumerated() {
                let rowDoubles: [Double]
                if let doubleRow = rowValue.value as? [Double] {
                    rowDoubles = doubleRow
                } else if let row = rowValue.value as? [AnyCodable] {
                    guard row.count == n else {
                        throw ToolError.invalidArguments("covarianceMatrix row \(i) must have \(n) elements (got \(row.count))")
                    }

                    rowDoubles = try row.map { value -> Double in
                        if let d = value.value as? Double {
                            return d
                        } else if let i = value.value as? Int {
                            return Double(i)
                        }
                        throw ToolError.invalidArguments("covarianceMatrix must contain only numbers")
                    }
                } else {
                    throw ToolError.invalidArguments("covarianceMatrix row \(i) must be an array")
                }

                guard rowDoubles.count == n else {
                    throw ToolError.invalidArguments("covarianceMatrix row \(i) must have \(n) elements (got \(rowDoubles.count))")
                }

                matrix.append(rowDoubles)
            }
            covarianceMatrix = matrix
        } else {
            throw ToolError.invalidArguments("covarianceMatrix must be an array of arrays")
        }

        // Parse other parameters
        let riskAversion = try args.getDouble("riskAversion")
        let budget = try args.getDouble("budget")
        let concentrationLimit = args.getDoubleOptional("concentrationLimit") ?? 1.0
        let riskFreeRate = args.getDoubleOptional("riskFreeRate") ?? 0.02

        // Validate concentration limit
        guard concentrationLimit > 0 && concentrationLimit <= 1.0 else {
            throw ToolError.invalidArguments("concentrationLimit must be between 0 and 1")
        }

        // Parse optional asset names
        var assetNames: [String] = []
        if let namesArray = args["assetNames"]?.value as? [AnyCodable] {
            assetNames = namesArray.compactMap { $0.value as? String }
        }
        if assetNames.isEmpty {
            assetNames = (0..<n).map { "Asset \($0 + 1)" }
        }

        // Validate covariance matrix symmetry
        for i in 0..<n {
            for j in 0..<n {
                if abs(covarianceMatrix[i][j] - covarianceMatrix[j][i]) > 1e-10 {
                    return .error(message: """
                        Invalid covariance matrix: not symmetric at [\(i)][\(j)]
                        Found: \(covarianceMatrix[i][j]) vs \(covarianceMatrix[j][i])
                        Covariance matrices must be symmetric.
                        """)
                }
            }
        }

        // Setup optimization
        let optimizer = InequalityOptimizer<VectorN<Double>>()

        // Objective: maximize risk-adjusted return (minimize negative)
        let objective: @Sendable (VectorN<Double>) -> Double = { capital in
            let allocation = capital.toArray()
            let weights = allocation.map { $0 / budget }

            // Expected return
            let totalReturn = zip(allocation, expectedReturns).map(*).reduce(0, +)

            // Portfolio variance
            let variance = (0..<n).map { i in
                (0..<n).map { j in
                    weights[i] * covarianceMatrix[i][j] * weights[j]
                }.reduce(0, +)
            }.reduce(0, +)

            // Risk-adjusted objective (mean-variance)
            return -(totalReturn - riskAversion * variance * budget * budget)
        }

        // Constraints
        var constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .equality { v in v.toArray().reduce(0, +) - budget }  // Use all budget
        ]

        // Non-negativity constraints
        for i in 0..<n {
            constraints.append(.inequality { v in -v[i] })
        }

        // Concentration limits
        for i in 0..<n {
            constraints.append(.inequality { v in v[i] - concentrationLimit * budget })
        }

        // Optimize
        let result: MultivariateOptimizationResult<VectorN<Double>>
        do {
            result = try optimizer.minimize(
                objective,
                from: VectorN(Array(repeating: budget / Double(n), count: n)),
                constraints: constraints
            )
        } catch {
            return .error(message: """
                Optimization Failed

                Could not find optimal portfolio allocation.

                Possible reasons:
                • Constraints may be too restrictive
                • Covariance matrix may not be positive definite
                • Initial guess may be infeasible

                Suggestions:
                • Check covariance matrix validity
                • Relax concentration limit
                • Verify expected returns are reasonable

                Error: \(error.localizedDescription)
                """)
        }

        // Extract solution
        let optimalAllocation = result.solution.toArray()
        let optimalWeights = optimalAllocation.map { $0 / budget }

        // Calculate portfolio metrics
        let portfolioReturn = zip(optimalWeights, expectedReturns).map(*).reduce(0, +)

        let portfolioVariance = (0..<n).map { i in
            (0..<n).map { j in
                optimalWeights[i] * covarianceMatrix[i][j] * optimalWeights[j]
            }.reduce(0, +)
        }.reduce(0, +)

        let portfolioVolatility = sqrt(portfolioVariance)
        let sharpeRatio = (portfolioReturn - riskFreeRate) / portfolioVolatility

        // Calculate risk contribution by asset
        var riskContributions: [Double] = []
        for i in 0..<n {
            let marginalRisk = (0..<n).map { j in
                covarianceMatrix[i][j] * optimalWeights[j]
            }.reduce(0, +)
            let contribution = (optimalWeights[i] * marginalRisk) / portfolioVariance
            riskContributions.append(contribution)
        }

        // Format output
        var output = """
        🎯 **Mean-Variance Portfolio Optimization**

        **Problem Configuration:**
        - Assets: \(n)
        - Risk Aversion (λ): \(String(format: "%.1f", riskAversion))
        - Concentration Limit: \(String(format: "%.0f%%", concentrationLimit * 100))
        - Total Budget: $\(String(format: "%.0f", budget))

        **Optimal Portfolio Allocation:**
        """

        for i in 0..<n {
            let allocation = optimalAllocation[i]
            let weight = optimalWeights[i]
            let riskContrib = riskContributions[i]

            output += """


            \(assetNames[i]):
              Allocation: $\(String(format: "%.0f", allocation)) (\(String(format: "%.1f%%", weight * 100)))
              Expected Return: \(String(format: "%.1f%%", expectedReturns[i] * 100))
              Risk Contribution: \(String(format: "%.1f%%", riskContrib * 100))
            """
        }

        output += """


        **Portfolio Metrics:**
        - Expected Return: \(String(format: "%.2f%%", portfolioReturn * 100))
        - Portfolio Volatility: \(String(format: "%.2f%%", portfolioVolatility * 100))
        - Sharpe Ratio: \(String(format: "%.3f", sharpeRatio)) (using \(String(format: "%.1f%%", riskFreeRate * 100)) risk-free rate)
        - Convergence: \(result.converged ? "✓ Yes" : "⚠️ No") in \(result.iterations) iterations

        **Risk-Return Tradeoff:**
        - Without risk penalty: Would invest 100% in highest return asset (\(String(format: "%.0f%%", expectedReturns.max()! * 100)))
        - With risk aversion λ=\(String(format: "%.1f", riskAversion)): Diversified across \(optimalWeights.filter { $0 > 0.01 }.count) assets
        - Diversification benefit: Lower volatility (\(String(format: "%.2f%%", portfolioVolatility * 100))) vs. single-asset risk

        **Interpretation:**
        This portfolio balances return maximization against risk minimization. Higher-return assets
        typically have higher allocations, but diversification reduces overall portfolio risk through
        correlation effects. The Sharpe ratio measures risk-adjusted performance.

        **Objective:** Maximized E[r] - \(String(format: "%.1f", riskAversion)) × σ² (mean-variance optimization)
        """

        return .success(text: output)
    }
}

// MARK: - Tool Registration

public func getMeanVariancePortfolioTools() -> [MCPToolHandler] {
    return [
        MeanVariancePortfolioTool()
    ]
}
