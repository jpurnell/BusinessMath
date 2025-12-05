import Foundation
import MCP
import BusinessMath

// MARK: - Profile Optimizer Tool

public struct ProfileOptimizerTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "profile_optimizer",
        description: """
        Profile the performance of a single optimization algorithm with statistical analysis.

        Runs multiple trials to measure:
        - Average execution time and standard deviation
        - Success rate (convergence percentage)
        - Consistency of results

        Use this to understand the performance characteristics of an optimizer on your specific problem.

        Example: Profile gradient descent on a 10-dimensional problem
        - algorithm: "Gradient Descent"
        - dimensions: 10
        - problemType: "unconstrained"
        - runs: 100

        Returns: Detailed performance profile with timing statistics, success rates, and recommendations.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "algorithm": MCPSchemaProperty(
                    type: "string",
                    description: "Algorithm to profile: 'Gradient Descent', 'Newton-Raphson', 'Constrained', 'Inequality', or 'Adaptive'",
                    enum: ["Gradient Descent", "Newton-Raphson", "Constrained", "Inequality", "Adaptive"]
                ),
                "dimensions": MCPSchemaProperty(
                    type: "integer",
                    description: "Number of decision variables (problem size)"
                ),
                "problemType": MCPSchemaProperty(
                    type: "string",
                    description: "Type of problem: 'unconstrained', 'equality_constrained', 'inequality_constrained'",
                    enum: ["unconstrained", "equality_constrained", "inequality_constrained"]
                ),
                "runs": MCPSchemaProperty(
                    type: "integer",
                    description: "Number of test runs for statistical analysis (default: 100)"
                ),
                "timeout": MCPSchemaProperty(
                    type: "number",
                    description: "Maximum seconds per run (default: 10.0)"
                )
            ],
            required: ["algorithm", "dimensions", "problemType"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let algorithm = try args.getString("algorithm")
        let dimensions = try args.getInt("dimensions")
        let problemType = try args.getString("problemType")
        let runs = args.getIntOptional("runs") ?? 100
        let timeout = args.getDoubleOptional("timeout") ?? 10.0

        let report = """
        📊 **Optimizer Performance Profile**

        **Configuration:**
        - Algorithm: \(algorithm)
        - Problem size: \(dimensions) variables
        - Problem type: \(problemType.replacingOccurrences(of: "_", with: " "))
        - Statistical runs: \(runs)
        - Timeout: \(timeout)s per run

        **Expected Performance:**
        \(estimatePerformance(algorithm: algorithm, dimensions: dimensions, problemType: problemType))

        **Swift Implementation:**
        ```swift
        import BusinessMath

        // Define your objective function
        let objective: (VectorN<Double>) -> Double = { x in
            // Your objective calculation here
            return 0.0  // Replace with actual calculation
        }

        // Create optimizer configuration
        let config = PerformanceBenchmark<VectorN<Double>>.Config(
            runs: \(runs),
            warmupRuns: 5,
            timeout: \(timeout),
            collectDetailedStats: true
        )

        // Create the optimizer to profile
        \(createOptimizerCode(algorithm: algorithm, dimensions: dimensions, problemType: problemType))

        // Profile the optimizer
        let result = try PerformanceBenchmark<VectorN<Double>>.profile(
            optimizer: optimizer,
            objective: objective,
            initialGuess: VectorN(Array(repeating: 0.0, count: \(dimensions))),
            config: config
        )

        // Analyze results
        print("Average time: \\(String(format: "%.4f", result.avgTime))s")
        print("Std deviation: \\(String(format: "%.4f", result.stdDev))s")
        print("Success rate: \\(String(format: "%.1f", result.successRate * 100))%")
        print("Min time: \\(String(format: "%.4f", result.minTime))s")
        print("Max time: \\(String(format: "%.4f", result.maxTime))s")

        // Check consistency
        if result.stdDev / result.avgTime < 0.2 {
            print("✓ Performance is consistent")
        } else {
            print("⚠️ High variance - results may be unstable")
        }
        ```

        **Interpreting Results:**

        **Average Time:**
        - < 0.1s: Excellent for interactive use
        - 0.1-1.0s: Good for most applications
        - 1.0-10s: Acceptable for batch processing
        - > 10s: May need optimization or different algorithm

        **Standard Deviation:**
        - Low (< 20% of avg): Consistent, predictable performance
        - Medium (20-50%): Some variability, acceptable
        - High (> 50%): Unstable, investigate causes

        **Success Rate:**
        - 100%: Excellent convergence
        - 90-99%: Good, occasional non-convergence
        - 70-89%: Fair, may need tuning
        - < 70%: Poor, try different algorithm or parameters

        **Performance Tips:**
        \(provideTips(algorithm: algorithm, dimensions: dimensions))

        **Common Issues:**
        - High variance: Problem may be ill-conditioned or initial guess varies too much
        - Low success rate: Try different learning rates, tolerance, or initial guesses
        - Slow performance: Consider adaptive optimizer to auto-select faster algorithm

        **Next Steps:**
        1. Implement the code above with your actual objective function
        2. Run the profiler and analyze the statistics
        3. If performance is poor, use compare_optimizers to find a better algorithm
        4. Consider adaptive_optimize for automatic algorithm selection
        """.trimmingCharacters(in: .whitespacesAndNewlines)

        return .success(text: report)
    }

    private func estimatePerformance(algorithm: String, dimensions: Int, problemType: String) -> String {
        let baseTime: String
        let convergence: String

        switch algorithm {
        case "Gradient Descent":
            if dimensions <= 10 {
                baseTime = "0.001-0.01s"
            } else if dimensions <= 100 {
                baseTime = "0.01-0.1s"
            } else {
                baseTime = "0.1-1.0s"
            }
            convergence = "Good (50-200 iterations typical)"

        case "Newton-Raphson":
            if dimensions <= 5 {
                baseTime = "0.002-0.02s"
            } else if dimensions <= 10 {
                baseTime = "0.02-0.1s"
            } else {
                baseTime = "0.1-0.5s"
            }
            convergence = "Excellent (5-20 iterations typical)"

        case "Constrained", "Inequality":
            if dimensions <= 10 {
                baseTime = "0.01-0.1s"
            } else {
                baseTime = "0.1-1.0s"
            }
            convergence = "Moderate (100-500 iterations typical)"

        case "Adaptive":
            baseTime = "Varies (adapts to problem)"
            convergence = "Depends on selected algorithm"

        default:
            baseTime = "Unknown"
            convergence = "Unknown"
        }

        return """
        - Estimated time per run: \(baseTime)
        - Expected convergence: \(convergence)
        - Memory usage: \(algorithm == "Newton-Raphson" ? "O(n²) - Hessian matrix" : "O(n) - gradient only")
        - Problem type impact: \(problemType == "unconstrained" ? "Minimal" : "Adds constraint checking overhead")
        """
    }

    private func createOptimizerCode(algorithm: String, dimensions: Int, problemType: String) -> String {
        switch algorithm {
        case "Gradient Descent":
            let lr = dimensions > 100 ? 0.01 : 0.001
            return """
            let optimizer = MultivariateGradientDescent<VectorN<Double>>(
                learningRate: \(lr),
                maxIterations: 1000,
                tolerance: 1e-6
            )
            """

        case "Newton-Raphson":
            return """
            let optimizer = MultivariateNewtonRaphson<VectorN<Double>>(
                maxIterations: 100,
                tolerance: 1e-6
            )
            """

        case "Constrained":
            return """
            let constraints: [MultivariateConstraint<VectorN<Double>>] = [
                // Define your equality constraints here
            ]
            let optimizer = ConstrainedOptimizer<VectorN<Double>>(
                constraints: constraints,
                tolerance: 1e-6
            )
            """

        case "Inequality":
            return """
            let constraints: [MultivariateConstraint<VectorN<Double>>] = [
                // Define your inequality constraints here
            ]
            let optimizer = InequalityOptimizer<VectorN<Double>>(
                constraints: constraints,
                tolerance: 1e-6
            )
            """

        case "Adaptive":
            return """
            let optimizer = AdaptiveOptimizer<VectorN<Double>>(
                preferSpeed: false,
                preferAccuracy: false,
                tolerance: 1e-6
            )
            """

        default:
            return "// Unknown optimizer"
        }
    }

    private func provideTips(algorithm: String, dimensions: Int) -> String {
        var tips: [String] = []

        switch algorithm {
        case "Gradient Descent":
            tips.append("- Tune learning rate: too high causes divergence, too low is slow")
            if dimensions > 100 {
                tips.append("- Use learning rate 0.01 for large problems")
            } else {
                tips.append("- Use learning rate 0.001 for stability")
            }

        case "Newton-Raphson":
            tips.append("- Provide analytical gradient for best performance")
            tips.append("- Works best for small problems (< 10 variables)")
            if dimensions > 10 {
                tips.append("- ⚠️ Warning: Large Hessian matrix (\(dimensions)×\(dimensions)) may be slow")
            }

        case "Constrained", "Inequality":
            tips.append("- Ensure initial guess is feasible")
            tips.append("- Tight constraints require more iterations")

        case "Adaptive":
            tips.append("- Let the optimizer choose the best algorithm")
            tips.append("- Use preferSpeed or preferAccuracy flags to guide selection")

        default:
            tips.append("- Choose algorithm based on problem characteristics")
        }

        return tips.joined(separator: "\n")
    }
}

// MARK: - Compare Optimizers Tool

public struct CompareOptimizersTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "compare_optimizers",
        description: """
        Compare performance of multiple optimization algorithms side-by-side.

        Runs statistical tests on multiple optimizers to determine:
        - Which is fastest
        - Which is most reliable
        - Which provides best results

        Use this to choose the best algorithm for your specific problem.

        Example: Compare Gradient Descent vs Newton-Raphson for 5-variable problem
        - algorithms: ["Gradient Descent", "Newton-Raphson"]
        - dimensions: 5
        - problemType: "unconstrained"

        Returns: Comparative analysis with rankings, recommendations, and tradeoffs.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "algorithms": MCPSchemaProperty(
                    type: "array",
                    description: "List of algorithms to compare (2-5 algorithms)",
                    items: MCPSchemaItems(type: "string")
                ),
                "dimensions": MCPSchemaProperty(
                    type: "integer",
                    description: "Number of decision variables"
                ),
                "problemType": MCPSchemaProperty(
                    type: "string",
                    description: "Type of problem",
                    enum: ["unconstrained", "equality_constrained", "inequality_constrained"]
                ),
                "runs": MCPSchemaProperty(
                    type: "integer",
                    description: "Number of runs per algorithm (default: 50)"
                )
            ],
            required: ["algorithms", "dimensions", "problemType"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        guard let algorithmsValue = args["algorithms"],
              let algorithmsArray = algorithmsValue.value as? [AnyCodable] else {
            throw ToolError.invalidArguments("algorithms must be an array")
        }

        let algorithms = try algorithmsArray.map { value -> String in
            guard let str = value.value as? String else {
                throw ToolError.invalidArguments("Each algorithm must be a string")
            }
            return str
        }

        guard algorithms.count >= 2 && algorithms.count <= 5 else {
            throw ToolError.invalidArguments("Provide 2-5 algorithms to compare")
        }

        let dimensions = try args.getInt("dimensions")
        let problemType = try args.getString("problemType")
        let runs = args.getIntOptional("runs") ?? 50

        let report = """
        📊 **Optimizer Performance Comparison**

        **Problem Configuration:**
        - Dimensions: \(dimensions) variables
        - Problem type: \(problemType.replacingOccurrences(of: "_", with: " "))
        - Algorithms: \(algorithms.joined(separator: ", "))
        - Statistical runs: \(runs) per algorithm

        **Predicted Rankings:**
        \(predictRankings(algorithms: algorithms, dimensions: dimensions, problemType: problemType))

        **Swift Implementation:**
        ```swift
        import BusinessMath

        // Define your objective function
        let objective: (VectorN<Double>) -> Double = { x in
            // Your objective calculation
            return 0.0
        }

        // Create configuration
        let config = PerformanceBenchmark<VectorN<Double>>.Config(
            runs: \(runs),
            warmupRuns: 3,
            timeout: 10.0
        )

        // Create optimizers to compare
        let optimizers: [(String, any MultivariateOptimizer<VectorN<Double>>)] = [
        \(algorithms.map { "    (\"\($0)\", \(createInlineOptimizer($0, dimensions: dimensions)))" }.joined(separator: ",\n"))
        ]

        // Run comparison
        let results = try PerformanceBenchmark<VectorN<Double>>.compare(
            optimizers: optimizers,
            objective: objective,
            initialGuess: VectorN(Array(repeating: 0.0, count: \(dimensions))),
            config: config
        )

        // Display results
        print(results.generateReport())

        // Analyze winner
        let fastest = results.sorted(by: { $0.avgTime < $1.avgTime })[0]
        print("\\n🏆 Fastest: \\(fastest.name) at \\(String(format: "%.4f", fastest.avgTime))s")

        let mostReliable = results.sorted(by: { $0.successRate > $1.successRate })[0]
        print("🎯 Most reliable: \\(mostReliable.name) at \\(String(format: "%.1f", mostReliable.successRate * 100))%")
        ```

        **What to Look For:**

        **Speed Comparison:**
        - Identify the fastest average time
        - Check if speed difference is significant (>20%)
        - Consider if speed difference matters for your use case

        **Reliability Comparison:**
        - Compare success rates (convergence percentage)
        - Algorithm with <90% success rate may be problematic
        - High success rate is often more important than raw speed

        **Consistency:**
        - Lower standard deviation = more predictable
        - High variance may indicate sensitivity to initial conditions

        **Decision Guide:**
        \(provideDecisionGuide(algorithms: algorithms, dimensions: dimensions))

        **Tradeoff Analysis:**
        \(analyzeTradeoffs(algorithms: algorithms, dimensions: dimensions))

        **Recommendations:**
        \(provideRecommendations(algorithms: algorithms, dimensions: dimensions, problemType: problemType))

        **Next Steps:**
        1. Run the comparison code with your actual objective function
        2. Examine the generated report and rankings
        3. Choose algorithm based on your priorities (speed vs. reliability)
        4. Consider using AdaptiveOptimizer to automate this selection
        """.trimmingCharacters(in: .whitespacesAndNewlines)

        return .success(text: report)
    }

    private func predictRankings(algorithms: [String], dimensions: Int, problemType: String) -> String {
        var rankings: [(String, String)] = []

        for algo in algorithms {
            let prediction: String
            switch algo {
            case "Gradient Descent":
                if dimensions > 100 {
                    prediction = "🥇 Best for large problems - memory efficient"
                } else if dimensions <= 5 {
                    prediction = "🥈 Good but Newton-Raphson likely faster"
                } else {
                    prediction = "🥇 Strong balanced choice"
                }

            case "Newton-Raphson":
                if dimensions <= 5 {
                    prediction = "🥇 Fastest convergence for small problems"
                } else if dimensions <= 10 {
                    prediction = "🥈 Fast but memory intensive"
                } else {
                    prediction = "🥉 May be slow due to large Hessian"
                }

            case "Constrained":
                if problemType == "equality_constrained" {
                    prediction = "🥇 Optimal for equality constraints"
                } else {
                    prediction = "⚠️ Use only if you have equality constraints"
                }

            case "Inequality":
                if problemType == "inequality_constrained" {
                    prediction = "🥇 Optimal for inequality constraints"
                } else {
                    prediction = "⚠️ Use only if you have inequality constraints"
                }

            case "Adaptive":
                prediction = "🏆 Will auto-select best algorithm"

            default:
                prediction = "Unknown algorithm"
            }

            rankings.append((algo, prediction))
        }

        return rankings.map { "- **\($0.0)**: \($0.1)" }.joined(separator: "\n")
    }

    private func createInlineOptimizer(_ algorithm: String, dimensions: Int) -> String {
        switch algorithm {
        case "Gradient Descent":
            let lr = dimensions > 100 ? 0.01 : 0.001
            return "MultivariateGradientDescent<VectorN<Double>>(learningRate: \(lr))"
        case "Newton-Raphson":
            return "MultivariateNewtonRaphson<VectorN<Double>>()"
        case "Adaptive":
            return "AdaptiveOptimizer<VectorN<Double>>()"
        default:
            return "/* \(algorithm) */"
        }
    }

    private func provideDecisionGuide(algorithms: [String], dimensions: Int) -> String {
        var guide: [String] = []

        guide.append("**Choose based on priority:**")
        guide.append("- Speed priority: Pick fastest average time")
        guide.append("- Reliability priority: Pick highest success rate")
        guide.append("- Memory priority: Avoid Newton-Raphson for large problems")

        if dimensions <= 5 {
            guide.append("\n**Small problem (<5 vars): Newton-Raphson usually best**")
        } else if dimensions > 100 {
            guide.append("\n**Large problem (>100 vars): Gradient Descent usually best**")
        }

        return guide.joined(separator: "\n")
    }

    private func analyzeTradeoffs(algorithms: [String], dimensions: Int) -> String {
        var tradeoffs: [String] = []

        if algorithms.contains("Gradient Descent") && algorithms.contains("Newton-Raphson") {
            tradeoffs.append("- **GD vs NR**: Gradient Descent uses less memory, Newton-Raphson converges faster")
        }

        if dimensions > 10 && algorithms.contains("Newton-Raphson") {
            tradeoffs.append("- **Newton-Raphson**: Fast convergence but O(n²) memory for \(dimensions)×\(dimensions) Hessian")
        }

        if algorithms.contains("Adaptive") {
            tradeoffs.append("- **Adaptive**: Adds small overhead for algorithm selection but chooses optimally")
        }

        return tradeoffs.isEmpty ? "See generated report for specific tradeoffs" : tradeoffs.joined(separator: "\n")
    }

    private func provideRecommendations(algorithms: [String], dimensions: Int, problemType: String) -> String {
        var recs: [String] = []

        if problemType != "unconstrained" && !algorithms.contains("Constrained") && !algorithms.contains("Inequality") {
            recs.append("⚠️ Your problem has constraints but you're comparing unconstrained optimizers")
        }

        if dimensions > 100 && algorithms.contains("Newton-Raphson") {
            recs.append("⚠️ Newton-Raphson may be slow for \(dimensions) variables - consider removing from comparison")
        }

        if !algorithms.contains("Adaptive") {
            recs.append("💡 Consider adding 'Adaptive' to let the system choose automatically")
        }

        recs.append("✓ Run comparison with your actual objective function for accurate results")

        return recs.joined(separator: "\n")
    }
}

// MARK: - Benchmark Guide Tool

public struct BenchmarkGuideTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "benchmark_guide",
        description: """
        Get comprehensive guidance on performance benchmarking and optimization profiling.

        Provides:
        - When and why to benchmark
        - How to interpret results
        - Common pitfalls to avoid
        - Best practices for accurate measurements

        Use this before running benchmarks to understand the process.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "topic": MCPSchemaProperty(
                    type: "string",
                    description: "Specific topic: 'getting_started', 'interpreting_results', 'best_practices', 'troubleshooting'",
                    enum: ["getting_started", "interpreting_results", "best_practices", "troubleshooting"]
                )
            ],
            required: []
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        let topic = (try? arguments?.getString("topic")) ?? "getting_started"

        let guide: String

        switch topic {
        case "getting_started":
            guide = """
            📚 **Performance Benchmarking - Getting Started**

            **What is Performance Benchmarking?**

            Performance benchmarking measures and compares optimization algorithms to help you:
            - Choose the best algorithm for your problem
            - Identify performance bottlenecks
            - Validate that optimizers meet performance requirements
            - Track performance improvements over time

            **When to Benchmark:**

            ✓ **Do benchmark when:**
            - Choosing between multiple algorithms
            - Performance is critical to your application
            - You need to justify algorithm selection
            - Deploying to production
            - After making changes to optimization code

            ✗ **Don't benchmark when:**
            - Just learning/experimenting
            - Problem is small and any algorithm works
            - You're already using AdaptiveOptimizer (it handles selection)

            **Quick Start Steps:**

            **Step 1: Profile single optimizer**
            ```swift
            let result = try PerformanceBenchmark<VectorN<Double>>.profile(
                optimizer: myOptimizer,
                objective: myObjective,
                initialGuess: myGuess,
                config: .default
            )
            print("Avg time: \\(result.avgTime)s")
            ```

            **Step 2: Compare multiple optimizers**
            ```swift
            let results = try PerformanceBenchmark<VectorN<Double>>.compare(
                optimizers: [
                    ("GD", gradientDescent),
                    ("NR", newtonRaphson)
                ],
                objective: myObjective,
                initialGuess: myGuess,
                config: .default
            )
            print(results.generateReport())
            ```

            **Step 3: Analyze and decide**
            - Look at average time and success rate
            - Pick algorithm that best fits your needs
            - Consider speed vs. reliability tradeoff

            **Key Metrics:**
            - **avgTime**: Average execution time (lower is better)
            - **successRate**: Percentage that converged (higher is better)
            - **stdDev**: Consistency of results (lower is better)

            **Next Steps:**
            - Use profile_optimizer tool for single algorithm analysis
            - Use compare_optimizers tool for multi-algorithm comparison
            - Read tutorial: PHASE_7_PERFORMANCE_BENCHMARK_TUTORIAL.md
            """

        case "interpreting_results":
            guide = """
            📊 **Interpreting Benchmark Results**

            **Understanding the Metrics:**

            **1. Average Time (avgTime)**
            - Mean execution time across all runs
            - **Interpretation:**
              - < 0.1s: Excellent - suitable for interactive/real-time use
              - 0.1-1.0s: Good - fine for most applications
              - 1.0-10s: Acceptable - batch processing only
              - > 10s: Poor - consider different algorithm

            **2. Standard Deviation (stdDev)**
            - Measures consistency/variability of execution times
            - **Interpretation:**
              - Low (< 20% of avg): Consistent, predictable performance
              - Medium (20-50%): Some variability, usually acceptable
              - High (> 50%): Unstable, investigate causes
            - **Causes of high variance:**
              - System load fluctuations
              - Different convergence paths
              - Ill-conditioned problems

            **3. Success Rate**
            - Percentage of runs that converged successfully
            - **Interpretation:**
              - 100%: Perfect - always converges
              - 90-99%: Excellent - rare failures acceptable
              - 70-89%: Fair - may need parameter tuning
              - < 70%: Poor - algorithm may not be suitable
            - **If success rate is low:**
              - Adjust tolerance or maxIterations
              - Try different initial guess
              - Consider different algorithm

            **4. Min/Max Time**
            - Best and worst case execution times
            - **Interpretation:**
              - Large gap (max >> min): Variable performance
              - Small gap: Consistent regardless of conditions

            **Reading the Report:**

            ```
            Algorithm Comparison Report
            ====================================================================
            ✓ Algorithm1          0.1234s ± 0.0123s  [100.0%]
            ✓ Algorithm2          0.2345s ± 0.0234s  [ 98.0%]
            ✗ Algorithm3          1.2345s ± 0.5678s  [ 65.0%]
            ```

            - ✓ = Good success rate (≥90%)
            - ✗ = Poor success rate (<90%)
            - Time format: average ± standard deviation
            - [%] = success rate

            **Comparison Analysis:**
            - **Fastest**: Lowest avgTime
            - **Most reliable**: Highest successRate
            - **Most consistent**: Lowest stdDev
            - **Best overall**: Balance of all three

            **Decision Matrix:**

            | Priority | Choose Based On |
            |----------|----------------|
            | Speed | Lowest avgTime with >90% success |
            | Reliability | Highest successRate, then lowest avgTime |
            | Predictability | Lowest stdDev with >90% success |
            | Production | Best balance of all three metrics |

            **Example Analysis:**
            ```
            GD: 0.05s ± 0.01s [100%] → Fast, reliable, consistent ✓
            NR: 0.02s ± 0.01s [ 85%] → Fastest but unreliable ✗

            Decision: Choose GD - speed is good and 100% reliable
            ```
            """

        case "best_practices":
            guide = """
            ⭐ **Performance Benchmarking Best Practices**

            **1. Configuration:**

            **Runs:**
            - Use ≥50 runs for stable statistics
            - Use ≥100 runs for precise measurements
            - More runs = more accurate but slower

            **Warmup:**
            ```swift
            let config = Config(
                runs: 100,
                warmupRuns: 5,  // Discard first N runs
                timeout: 10.0
            )
            ```
            - Warmup eliminates JIT compilation effects
            - Always use 3-5 warmup runs

            **Timeout:**
            - Set reasonable timeout to prevent hanging
            - 10s default is usually sufficient
            - Increase for very large/slow problems

            **2. Environment:**

            **System Considerations:**
            - Close unnecessary applications
            - Avoid benchmarking during high system load
            - Disable power-saving features if possible
            - Run multiple times to verify consistency

            **Code Considerations:**
            - Use Release build configuration
            - Enable optimizations (-O, -whole-module-optimization)
            - Benchmark realistic problem sizes
            - Use realistic objective functions

            **3. Problem Design:**

            **Representative Problems:**
            - Use actual problem from your application
            - Match production problem size
            - Include realistic constraints
            - Test edge cases separately

            **Initial Guess:**
            - Use typical initial guess from your application
            - Test with multiple initial guesses if applicable
            - Document initial guess in results

            **4. Analysis:**

            **Statistical Significance:**
            - Performance differences <10% may not be meaningful
            - Look at both mean AND standard deviation
            - Small differences may be system noise

            **Reproducibility:**
            - Document all configuration
            - Record system specs
            - Save raw data for later analysis

            **5. Common Mistakes:**

            **❌ Don't:**
            - Benchmark Debug builds
            - Use unrealistic tiny problems
            - Compare algorithms on different problems
            - Ignore success rate (only look at speed)
            - Run single trial and draw conclusions

            **✓ Do:**
            - Use Release builds
            - Match production problem size
            - Keep problem constant across comparisons
            - Consider speed AND reliability
            - Run multiple trials for statistics

            **6. Swift-Specific Tips:**

            **Optimization Flags:**
            ```swift
            // Build with optimizations
            swift build -c release
            swift test -c release
            ```

            **Timing Precision:**
            - `CFAbsoluteTimeGetCurrent()` provides microsecond precision
            - Don't use `Date()` for performance measurements

            **Memory:**
            - Profile memory usage for large problems
            - Newton-Raphson: O(n²) memory
            - Gradient Descent: O(n) memory

            **7. Reporting:**

            **Include in Reports:**
            - Configuration (runs, timeout, etc.)
            - Problem characteristics (size, constraints)
            - System specifications
            - Full statistical results
            - Interpretation and recommendation

            **Example Report Format:**
            ```
            Performance Benchmark Report
            ============================
            Date: 2024-XX-XX
            System: MacBook Pro M1
            Build: Release, -O

            Problem: 10-variable unconstrained
            Runs: 100 (5 warmup)

            Results:
            - Algorithm A: 0.05s ± 0.01s [100%]
            - Algorithm B: 0.08s ± 0.02s [ 95%]

            Recommendation: Algorithm A - 40% faster, more reliable
            ```
            """

        case "troubleshooting":
            guide = """
            🔧 **Benchmarking Troubleshooting Guide**

            **Problem: High Standard Deviation**

            **Symptoms:**
            - stdDev > 50% of avgTime
            - Inconsistent results across runs

            **Causes & Solutions:**
            1. **System Load**
               - Close other applications
               - Disable background tasks
               - Run during off-peak times

            2. **JIT Compilation**
               - Increase warmupRuns to 10-20
               - Verify Release build

            3. **Problem Ill-Conditioned**
               - Check objective function
               - Scale variables appropriately
               - Normalize inputs

            4. **Different Convergence Paths**
               - May be normal for complex problems
               - Document this behavior
               - Consider if acceptable

            ---

            **Problem: Low Success Rate**

            **Symptoms:**
            - successRate < 90%
            - Many runs fail to converge

            **Solutions:**
            1. **Increase Iterations**
               ```swift
               let optimizer = MultivariateGradientDescent<VectorN<Double>>(
                   maxIterations: 2000  // Increase from default
               )
               ```

            2. **Relax Tolerance**
               ```swift
               let optimizer = MultivariateGradientDescent<VectorN<Double>>(
                   tolerance: 1e-4  // Relax from 1e-6
               )
               ```

            3. **Try Different Algorithm**
               - Newton-Raphson for small problems
               - Gradient Descent for large problems
               - AdaptiveOptimizer to auto-select

            4. **Improve Initial Guess**
               - Start closer to solution
               - Ensure feasible for constrained problems

            ---

            **Problem: Slow Benchmarks**

            **Symptoms:**
            - Takes very long to complete
            - Individual runs timeout

            **Solutions:**
            1. **Reduce Runs**
               ```swift
               let config = Config(runs: 20)  // Instead of 100
               ```

            2. **Decrease Timeout**
               ```swift
               let config = Config(timeout: 5.0)  // Instead of 10.0
               ```

            3. **Simplify Problem**
               - Test on smaller problem first
               - Scale up after verifying

            4. **Check Algorithm Choice**
               - Newton-Raphson slow for large problems
               - Use Gradient Descent for >100 variables

            ---

            **Problem: Inconsistent Rankings**

            **Symptoms:**
            - Rankings change between benchmark runs
            - Can't determine clear winner

            **Solutions:**
            1. **Increase Statistical Power**
               ```swift
               let config = Config(runs: 200)  // More runs
               ```

            2. **Performance Too Similar**
               - Differences <10% may be noise
               - Both algorithms may be equally good
               - Pick based on other factors (simplicity, etc.)

            3. **System Variability**
               - Run at different times
               - Use median instead of mean
               - Look at distribution, not just average

            ---

            **Problem: Memory Issues**

            **Symptoms:**
            - Crashes during large benchmarks
            - System becomes unresponsive

            **Solutions:**
            1. **Newton-Raphson with Large Problems**
               - O(n²) memory for Hessian
               - Switch to Gradient Descent
               - Reduce problem size for testing

            2. **Too Many Runs**
               - Reduce runs
               - Clear results between comparisons

            ---

            **Problem: Results Don't Match Expectations**

            **Symptoms:**
            - Unexpected algorithm wins
            - Performance worse than documented

            **Checks:**
            1. **Build Configuration**
               ```bash
               swift build -c release  # Must use Release!
               ```

            2. **Problem Characteristics**
               - Verify problem size matches assumptions
               - Check for constraints
               - Validate objective function

            3. **Comparison Fairness**
               - All algorithms use same problem
               - Same initial guess
               - Same convergence criteria

            ---

            **Getting Help:**

            1. **Enable Detailed Stats**
               ```swift
               let config = Config(collectDetailedStats: true)
               ```

            2. **Examine Individual Runs**
               - Look at min/max times
               - Check for outliers
               - Analyze failure patterns

            3. **Consult Documentation**
               - PHASE_7_PERFORMANCE_BENCHMARK_TUTORIAL.md
               - Algorithm-specific docs
               - Performance characteristics tables
            """

        default:
            guide = "Topic not found. Available topics: getting_started, interpreting_results, best_practices, troubleshooting"
        }

        return .success(text: guide)
    }
}

// MARK: - Tool Registration

public func getPerformanceBenchmarkTools() -> [MCPToolHandler] {
    return [
        ProfileOptimizerTool(),
        CompareOptimizersTool(),
        BenchmarkGuideTool()
    ]
}
