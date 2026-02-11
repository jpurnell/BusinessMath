import Foundation

/// Branch and Bound solver for Mixed-Integer Linear/Nonlinear Programs
public struct BranchAndBoundSolver<V: VectorSpace> where V.Scalar == Double, V: Sendable {

    /// Maximum nodes to explore before terminating
    public let maxNodes: Int

    /// Maximum time in seconds
    public let timeLimit: Double

    /// Relative optimality tolerance (stop when gap < tolerance)
    public let relativeGapTolerance: Double

    /// Node selection strategy
    public let nodeSelection: NodeSelectionStrategy

    /// Branching strategy
    public let branchingRule: BranchingRule

    /// Tolerance for LP solver
    public let lpTolerance: Double

    /// Tolerance for integrality (separate from LP to handle finite-difference noise)
    public let integralityTolerance: Double

    /// Whether to validate that objectives and constraints are linear
    ///
    /// When enabled, closure-based objectives/constraints are validated for linearity
    /// before solving. Rejects nonlinear models with `OptimizationError.nonlinearModel`.
    ///
    /// **Note**: Explicit `LinearFunction` objectives are always linear by construction.
    public let validateLinearity: Bool

    /// Whether to enable automatic variable shifting for negative bounds
    ///
    /// When enabled, variables with negative lower bounds (e.g., x ≥ -3) are
    /// automatically shifted to satisfy SimplexSolver's x ≥ 0 requirement.
    public let enableVariableShifting: Bool

    /// Whether to enable cutting plane generation
    ///
    /// When enabled, generates Gomory cuts and other cutting planes at each node
    /// before branching to strengthen the LP relaxation.
    public let enableCuttingPlanes: Bool

    /// Maximum number of cutting plane rounds per node
    ///
    /// Controls how many times to generate and add cuts before branching.
    /// More rounds can tighten bounds but increase solve time.
    public let maxCuttingRounds: Int

    /// Tolerance for considering a cut violated
    ///
    /// Cuts with violation below this threshold are not added.
    public let cutTolerance: Double

    /// Whether to normalize cuts to unit norm
    ///
    /// When enabled, cut coefficients are normalized (divided by Euclidean norm)
    /// to prevent ill-conditioned LPs and improve numerical stability.
    public let normalizeCuts: Bool

    /// Minimum coefficient magnitude threshold
    ///
    /// Cuts with all coefficients below this threshold are rejected as
    /// numerically insignificant. Applied after normalization.
    public let cutCoefficientThreshold: Double

    /// Whether to detect stagnation (no bound improvement)
    ///
    /// When enabled, cutting plane generation terminates early if the dual
    /// bound does not improve by at least stagnationTolerance.
    public let detectStagnation: Bool

    /// Minimum bound improvement required to continue cutting
    ///
    /// If the dual bound improves by less than this tolerance between rounds,
    /// stagnation is detected and cutting terminates.
    public let stagnationTolerance: Double

    /// Whether to detect cycling (repeated solutions)
    ///
    /// When enabled, checks if LP solutions repeat across cutting rounds,
    /// indicating a cycle. Terminates early if cycling is detected.
    public let detectCycling: Bool

    /// Number of recent solutions to check for cycling
    ///
    /// Larger windows detect longer cycles but use more memory.
    /// Typical values: 3-10.
    public let cyclingWindowSize: Int

    /// Solver for continuous relaxations
    ///
    /// Used at each node to compute LP/NLP bounds for pruning.
    /// Defaults to SimplexRelaxationSolver for fast linear relaxations.
    public let relaxationSolver: any RelaxationSolver

    /// Creates a branch-and-bound solver with comprehensive configuration options.
    ///
    /// - Parameters:
    ///   - maxNodes: Maximum nodes to explore before terminating (default: 10,000)
    ///   - timeLimit: Maximum time in seconds, 0 for no limit (default: 300.0)
    ///   - relativeGapTolerance: Relative optimality gap to stop when `gap < tolerance` (default: 1e-4 = 0.01%)
    ///   - nodeSelection: Strategy for selecting next node (default: `.bestBound`)
    ///   - branchingRule: Strategy for selecting branching variable (default: `.mostFractional`)
    ///   - lpTolerance: Tolerance for LP solver (default: 1e-8)
    ///   - integralityTolerance: Tolerance for integrality—values within this of an integer are rounded (default: 1e-6)
    ///   - validateLinearity: Whether to validate that objectives/constraints are linear (default: false)
    ///   - enableVariableShifting: Automatically shift variables with negative bounds to satisfy x ≥ 0 (default: false)
    ///   - enableCuttingPlanes: Enable Gomory cuts and other cutting planes (default: false)
    ///   - maxCuttingRounds: Maximum cutting plane rounds per node (default: 5)
    ///   - cutTolerance: Minimum violation for a cut to be added (default: 1e-6)
    ///   - normalizeCuts: Normalize cut coefficients to unit norm for numerical stability (default: true)
    ///   - cutCoefficientThreshold: Minimum coefficient magnitude after normalization (default: 1e-8)
    ///   - detectStagnation: Terminate cutting if bound doesn't improve (default: true)
    ///   - stagnationTolerance: Minimum bound improvement to continue cutting (default: 1e-8)
    ///   - detectCycling: Detect repeated LP solutions and terminate early (default: true)
    ///   - cyclingWindowSize: Number of recent solutions to check for cycles (default: 5)
    ///   - relaxationSolver: Custom relaxation solver, or `nil` for default `SimplexRelaxationSolver`
    public init(
        maxNodes: Int = 10_000,
        timeLimit: Double = 300.0,
        relativeGapTolerance: Double = 1e-4,
        nodeSelection: NodeSelectionStrategy = .bestBound,
        branchingRule: BranchingRule = .mostFractional,
        lpTolerance: Double = 1e-8,
        integralityTolerance: Double = 1e-6,
        validateLinearity: Bool = false,
        enableVariableShifting: Bool = false,
        enableCuttingPlanes: Bool = false,
        maxCuttingRounds: Int = 5,
        cutTolerance: Double = 1e-6,
        normalizeCuts: Bool = true,
        cutCoefficientThreshold: Double = 1e-8,
        detectStagnation: Bool = true,
        stagnationTolerance: Double = 1e-8,
        detectCycling: Bool = true,
        cyclingWindowSize: Int = 5,
        relaxationSolver: (any RelaxationSolver)? = nil
    ) {
        // Validate tolerance hierarchy
        // Mathematical requirement: lpTolerance ≤ integralityTolerance ≤ cutTolerance
        // Rationale:
        // - LP must be solved more accurately than we check integrality
        // - Integrality must be stricter than cut violation threshold
        // - Otherwise, we may reject integer solutions or add useless cuts
        precondition(lpTolerance > 0, "lpTolerance must be positive")
        precondition(integralityTolerance > 0, "integralityTolerance must be positive")
        precondition(cutTolerance > 0, "cutTolerance must be positive")
        precondition(lpTolerance <= integralityTolerance,
            "lpTolerance (\(lpTolerance)) must be ≤ integralityTolerance (\(integralityTolerance))")
        precondition(integralityTolerance <= cutTolerance,
            "integralityTolerance (\(integralityTolerance)) must be ≤ cutTolerance (\(cutTolerance))")

        self.maxNodes = maxNodes
        self.timeLimit = timeLimit
        self.relativeGapTolerance = relativeGapTolerance
        self.nodeSelection = nodeSelection
        self.branchingRule = branchingRule
        self.lpTolerance = lpTolerance
        self.integralityTolerance = integralityTolerance
        self.validateLinearity = validateLinearity
        self.enableVariableShifting = enableVariableShifting
        self.enableCuttingPlanes = enableCuttingPlanes
        self.maxCuttingRounds = maxCuttingRounds
        self.cutTolerance = cutTolerance
        self.normalizeCuts = normalizeCuts
        self.cutCoefficientThreshold = cutCoefficientThreshold
        self.detectStagnation = detectStagnation
        self.stagnationTolerance = stagnationTolerance
        self.detectCycling = detectCycling
        self.cyclingWindowSize = cyclingWindowSize

        // Default to SimplexRelaxationSolver for backward compatibility
        self.relaxationSolver = relaxationSolver ?? SimplexRelaxationSolver(lpTolerance: lpTolerance)
    }

    /// Solve mixed-integer program
    /// - Parameters:
    ///   - objective: Objective function to minimize
    ///   - initialGuess: Starting point for optimization
    ///   - constraints: Constraints that must be satisfied
    ///   - integerSpec: Specification of which variables must be integer
    ///   - minimize: True to minimize, false to maximize
    /// - Returns: Result containing best integer solution found
    public func solve(
        objective: @Sendable @escaping (V) -> Double,
        from initialGuess: V,
        subjectTo constraints: [MultivariateConstraint<V>],
        integerSpec: IntegerProgramSpecification,
        minimize: Bool = true
    ) throws -> IntegerOptimizationResult<V> {

        // Step 0a: Validate linearity if requested
        if validateLinearity && V.self == VectorN<Double>.self {
            let dimension = initialGuess.toArray().count
            let initialPoint = initialGuess

            // Validate objective linearity
            let _ = try validateLinearModel(
                objective,
                dimension: dimension,
                at: initialPoint
            )

            // Validate constraint linearity (for closure-based constraints)
            for constraint in constraints {
                switch constraint {
                case .inequality(let f, _), .equality(let f, _):
                    let _ = try validateLinearModel(
                        f,
                        dimension: dimension,
                        at: initialPoint
                    )
                case .linearInequality, .linearEquality:
                    // Already linear by construction
                    continue
                }
            }
        }

        // Step 0b: Apply variable shifting if requested and needed
        var shiftedObjective = objective
        var shiftedConstraints = constraints
        var shiftedInitialGuess = initialGuess
        var variableShift: VariableShift? = nil

        if enableVariableShifting && V.self == VectorN<Double>.self {
            let dimension = initialGuess.toArray().count
            let shift = try extractVariableShift(
                from: constraints as! [MultivariateConstraint<VectorN<Double>>],
                dimension: dimension
            )

            if shift.needsShift {
                variableShift = shift

                // Transform objective: f(x) → f(y + shift)
                shiftedObjective = { (y: V) -> Double in
                    let x = shift.unshiftPoint(y as! VectorN<Double>) as! V
                    return objective(x)
                }

                // Transform constraints
                shiftedConstraints = try constraints.map { constraint in
                    try shift.transformConstraint(constraint as! MultivariateConstraint<VectorN<Double>>) as! MultivariateConstraint<V>
                }

                // Transform initial guess
                shiftedInitialGuess = shift.shiftPoint(initialGuess as! VectorN<Double>) as! V
            }
        }

        let startTime = Date()
        var queue = NodeQueue<V>(strategy: nodeSelection, minimize: minimize)
        var incumbent: (solution: V, value: Double)? = nil
        var bestBound = minimize ? -Double.infinity : Double.infinity
        var nodesExplored = 0

        // Initialize cutting plane statistics tracker
        let cutStats = CutStatisticsTracker()

        // Initialize pseudo-cost tracker for intelligent branching
        let pseudoCostTracker = (branchingRule == .pseudoCost) ? PseudoCostTracker() : nil

        // Step 1: Solve root LP relaxation (with possibly shifted problem)
        let rootNode = try solveRelaxation(
            constraints: shiftedConstraints,
            objective: shiftedObjective,
            initialGuess: shiftedInitialGuess,
            minimize: minimize,
            integerSpec: integerSpec,
            depth: 0,
            cutStats: enableCuttingPlanes ? cutStats : nil
        )

        // Record root LP bound for cutting plane statistics
        if enableCuttingPlanes {
            cutStats.rootLPBoundBeforeCuts = rootNode.relaxationBound
            cutStats.rootLPBoundAfterCuts = rootNode.relaxationBound  // Will update after cuts
        }

        // Check if root is infeasible
        // if rootNode.relaxationSolution == nil {
        //     print("WARNING: Root LP relaxation is infeasible!")
        //     print("  Bound: \(rootNode.relaxationBound)")
        //     print("  Dimension: \(initialGuess.toArray().count)")
        // }

        queue.insert(rootNode)
        bestBound = rootNode.relaxationBound

        // Check if root LP is unbounded (has finite bound but no solution)
        // This indicates the problem may be unbounded even for integers
        if rootNode.relaxationSolution == nil && !rootNode.relaxationBound.isInfinite {
            // Unbounded LP - return with the safe bound
            return IntegerOptimizationResult(
                solution: initialGuess,
                objectiveValue: minimize ? -.infinity : .infinity,
                bestBound: bestBound,  // Use the safe finite bound
                relativeGap: .infinity,
                nodesExplored: nodesExplored,
                status: .infeasible,  // No integer solutions found
                solveTime: Date().timeIntervalSince(startTime),
                integerSpec: integerSpec,
                cuttingPlaneStats: nil
            )
        }

        // Step 2: Branch and bound loop
        while let node = queue.extractBest() {
            nodesExplored += 1

            // Debug: print node exploration for small problems
            // if initialGuess.toArray().count <= 5 && nodesExplored <= 10 {
            //     if let sol = node.relaxationSolution {
            //         let isInt = integerSpec.isIntegerFeasible(sol, tolerance: lpTolerance)
            //         print("Node \(nodesExplored): depth=\(node.depth), bound=\(node.relaxationBound), sol=\(sol.toArray()), isInteger=\(isInt)")
            //     } else {
            //         print("Node \(nodesExplored): depth=\(node.depth), bound=\(node.relaxationBound), sol=nil")
            //     }
            // }

            // Check termination conditions
            if nodesExplored >= maxNodes {
                let gap = incumbent.map { abs($0.value - bestBound) / max(abs($0.value), 1.0) } ?? .infinity

                // Unshift solution if variable shifting was applied
                let finalSolution: V
                if let shift = variableShift, let inc = incumbent {
                    finalSolution = shift.unshiftPoint(inc.solution as! VectorN<Double>) as! V
                } else {
                    finalSolution = incumbent?.solution ?? initialGuess
                }

                return IntegerOptimizationResult(
                    solution: finalSolution,
                    objectiveValue: incumbent?.value ?? .infinity,
                    bestBound: bestBound,
                    relativeGap: gap,
                    nodesExplored: nodesExplored,
                    status: .nodeLimit,
                    solveTime: Date().timeIntervalSince(startTime),
                    integerSpec: integerSpec,
                    cuttingPlaneStats: enableCuttingPlanes ? CuttingPlaneStats() : nil
                )
            }

            if Date().timeIntervalSince(startTime) > timeLimit {
                let gap = incumbent.map { abs($0.value - bestBound) / max(abs($0.value), 1.0) } ?? .infinity

                // Unshift solution if variable shifting was applied
                let finalSolution: V
                if let shift = variableShift, let inc = incumbent {
                    finalSolution = shift.unshiftPoint(inc.solution as! VectorN<Double>) as! V
                } else {
                    finalSolution = incumbent?.solution ?? initialGuess
                }

                return IntegerOptimizationResult(
                    solution: finalSolution,
                    objectiveValue: incumbent?.value ?? .infinity,
                    bestBound: bestBound,
                    relativeGap: gap,
                    nodesExplored: nodesExplored,
                    status: .timeLimit,
                    solveTime: Date().timeIntervalSince(startTime),
                    integerSpec: integerSpec,
                    cuttingPlaneStats: enableCuttingPlanes ? CuttingPlaneStats() : nil
                )
            }

            // Step 3: Pruning tests
            if shouldPrune(node, incumbent: incumbent, minimize: minimize) {
                // Update best bound from remaining nodes
                updateBestBound(&bestBound, from: queue, minimize: minimize, incumbent: incumbent)
                continue
            }

            // Step 4: Check integer feasibility
            guard let solution = node.relaxationSolution else {
                updateBestBound(&bestBound, from: queue, minimize: minimize, incumbent: incumbent)
                continue
            }

            if integerSpec.isIntegerFeasible(solution, tolerance: integralityTolerance) {
                // Found integer solution - update incumbent
                let value = shiftedObjective(solution)
                if incumbent == nil || (minimize ? value < incumbent!.value : value > incumbent!.value) {
                    incumbent = (solution, value)
                }
                updateBestBound(&bestBound, from: queue, minimize: minimize, incumbent: incumbent)

                // Check if we can terminate due to optimality gap
                if let inc = incumbent {
                    let gap = abs(inc.value - bestBound) / max(abs(inc.value), 1.0)
                    if gap < relativeGapTolerance {
                        // Unshift solution if variable shifting was applied
                        let finalSolution: V
                        if let shift = variableShift {
                            finalSolution = shift.unshiftPoint(inc.solution as! VectorN<Double>) as! V
                        } else {
                            finalSolution = inc.solution
                        }

                        return IntegerOptimizationResult(
                            solution: finalSolution,
                            objectiveValue: inc.value,
                            bestBound: bestBound,
                            relativeGap: gap,
                            nodesExplored: nodesExplored,
                            status: .optimal,
                            solveTime: Date().timeIntervalSince(startTime),
                            integerSpec: integerSpec,
                    cuttingPlaneStats: enableCuttingPlanes ? CuttingPlaneStats() : nil
                        )
                    }
                }
                continue
            }

            // Step 4.5: Try rounding heuristic on fractional solution
            // This can find integer solutions without branching
            if let rounded = roundingHeuristic(
                solution,
                objective: shiftedObjective,
                constraints: shiftedConstraints,
                integerSpec: integerSpec
            ) {
                // Rounding succeeded - update incumbent
                if incumbent == nil || (minimize ? rounded.value < incumbent!.value : rounded.value > incumbent!.value) {
                    incumbent = (solution: rounded.solution, value: rounded.value)
                }
                updateBestBound(&bestBound, from: queue, minimize: minimize, incumbent: incumbent)

                // Check if we can terminate due to optimality gap
                if let inc = incumbent {
                    let gap = abs(inc.value - bestBound) / max(abs(inc.value), 1.0)
                    if gap < relativeGapTolerance {
                        // Unshift solution if variable shifting was applied
                        let finalSolution: V
                        if let shift = variableShift {
                            finalSolution = shift.unshiftPoint(inc.solution as! VectorN<Double>) as! V
                        } else {
                            finalSolution = inc.solution
                        }

                        return IntegerOptimizationResult(
                            solution: finalSolution,
                            objectiveValue: inc.value,
                            bestBound: bestBound,
                            relativeGap: gap,
                            nodesExplored: nodesExplored,
                            status: .optimal,
                            solveTime: Date().timeIntervalSince(startTime),
                            integerSpec: integerSpec,
                            cuttingPlaneStats: enableCuttingPlanes ? CuttingPlaneStats() : nil
                        )
                    }
                }
                continue  // Don't branch - try next node
            }

            // Step 5: Branch on fractional variable
            guard let branchVar = selectBranchingVariable(
                solution,
                integerSpec,
                parentBound: node.relaxationBound,
                objective: shiftedObjective,
                constraints: shiftedConstraints,
                minimize: minimize,
                pseudoCostTracker: pseudoCostTracker
            ) else {
                updateBestBound(&bestBound, from: queue, minimize: minimize, incumbent: incumbent)
                continue
            }

            do {
                let (leftChild, rightChild) = try createBranches(
                    parent: node,
                    variable: branchVar,
                    solution: solution,
                    objective: shiftedObjective,
                    constraints: shiftedConstraints,
                    integerSpec: integerSpec,
                    minimize: minimize,
                    cutStats: enableCuttingPlanes ? cutStats : nil
                )

                // Track pseudo-costs if enabled
                if let tracker = pseudoCostTracker {
                    let parentBound = node.relaxationBound
                    let varValue = solution.toArray()[branchVar]
                    let fractionalPart = varValue - floor(varValue)

                    // Down branch (floor): bound improvement
                    let downImprovement = abs(leftChild.relaxationBound - parentBound)
                    tracker.updateCost(
                        variable: branchVar,
                        direction: .down,
                        boundImprovement: downImprovement,
                        fractionalChange: fractionalPart
                    )

                    // Up branch (ceiling): bound improvement
                    let upImprovement = abs(rightChild.relaxationBound - parentBound)
                    tracker.updateCost(
                        variable: branchVar,
                        direction: .up,
                        boundImprovement: upImprovement,
                        fractionalChange: 1.0 - fractionalPart
                    )
                }

                queue.insert(leftChild)
                queue.insert(rightChild)
                updateBestBound(&bestBound, from: queue, minimize: minimize, incumbent: incumbent)
            } catch {
                // Branching failed - node is infeasible
                updateBestBound(&bestBound, from: queue, minimize: minimize, incumbent: incumbent)
                continue
            }
        }

        // Step 6: Return result
        guard let final = incumbent else {
            // No solution found - return original initial guess (unshifted if needed)
            let finalSolution: V
            if let shift = variableShift {
                finalSolution = shift.unshiftPoint(initialGuess as! VectorN<Double>) as! V
            } else {
                finalSolution = initialGuess
            }

            return IntegerOptimizationResult(
                solution: finalSolution,
                objectiveValue: .infinity,
                bestBound: bestBound,
                relativeGap: .infinity,
                nodesExplored: nodesExplored,
                status: .infeasible,
                solveTime: Date().timeIntervalSince(startTime),
                integerSpec: integerSpec,
                    cuttingPlaneStats: enableCuttingPlanes ? CuttingPlaneStats() : nil
            )
        }

        let gap = abs(final.value - bestBound) / max(abs(final.value), 1.0)
        let status: IntegerSolutionStatus = gap < relativeGapTolerance ? .optimal : .feasible

        // Debug: print gap calculation
        // if initialGuess.toArray().count <= 5 {
        //     print("=== Final Result ===")
        //     print("Incumbent value: \(final.value)")
        //     print("Best bound: \(bestBound)")
        //     print("Gap: \(gap) (tolerance: \(relativeGapTolerance))")
        //     print("Status: \(status)")
        //     print("Nodes explored: \(nodesExplored)")
        // }

        // Unshift solution if variable shifting was applied
        let finalSolution: V
        if let shift = variableShift {
            finalSolution = shift.unshiftPoint(final.solution as! VectorN<Double>) as! V
        } else {
            finalSolution = final.solution
        }

        // Create cutting plane statistics if enabled
        let stats: CuttingPlaneStats? = enableCuttingPlanes ? cutStats.createStats(integerOptimum: final.value) : nil

        // Post-solve verification: validate final solution
        let verification = verifySolution(
            finalSolution,
            objective: objective,
            constraints: constraints,
            integerSpec: integerSpec,
            expectedObjective: final.value
        )

        // Warn if solution has violations (shouldn't happen if solver is correct)
        if !verification.isValid {
            print("⚠️ WARNING: Solution verification failed!")
            for violation in verification.violations {
                print("  - \(violation)")
            }
        }

        return IntegerOptimizationResult(
            solution: finalSolution,
            objectiveValue: final.value,
            bestBound: bestBound,
            relativeGap: gap,
            nodesExplored: nodesExplored,
            status: status,
            solveTime: Date().timeIntervalSince(startTime),
            integerSpec: integerSpec,
            cuttingPlaneStats: stats
        )
    }

    /// Solve mixed-integer program with explicit LinearFunction objective
    ///
    /// This overload provides enhanced correctness for linear programs:
    /// - Explicit coefficients avoid finite-difference errors (~1e-9 → ~1e-15)
    /// - Compile-time linearity guarantee (no need for validation)
    /// - Direct coefficient access for better performance
    ///
    /// ## Example
    /// ```swift
    /// let solver = BranchAndBoundSolver<VectorN<Double>>()
    ///
    /// // Explicit linear objective: minimize 2x + 3y
    /// let objective = StandardLinearFunction<VectorN<Double>>(
    ///     coefficients: [2.0, 3.0]
    /// )
    ///
    /// let result = try solver.solve(
    ///     objective: objective,
    ///     from: VectorN([0.5, 0.5]),
    ///     subjectTo: constraints,
    ///     integerSpec: .allBinary(dimension: 2)
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - objective: Linear objective function (explicit coefficients)
    ///   - initialGuess: Starting point for optimization
    ///   - constraints: Constraints that must be satisfied
    ///   - integerSpec: Specification of which variables must be integer
    ///   - minimize: True to minimize, false to maximize
    /// - Returns: Result containing best integer solution found
    public func solve<LF: LinearFunction>(
        objective: LF,
        from initialGuess: V,
        subjectTo constraints: [MultivariateConstraint<V>],
        integerSpec: IntegerProgramSpecification,
        minimize: Bool = true
    ) throws -> IntegerOptimizationResult<V> where LF.V == V {
        // Convert LinearFunction to closure for compatibility with existing solve()
        let objectiveClosure: @Sendable (V) -> Double = { point in
            objective.evaluate(at: point)
        }

        // Call existing solve() method
        // Note: No linearity validation needed - LinearFunction is linear by construction
        return try solve(
            objective: objectiveClosure,
            from: initialGuess,
            subjectTo: constraints,
            integerSpec: integerSpec,
            minimize: minimize
        )
    }

    // MARK: - Private Helper Methods

    /// Solve continuous relaxation at a node using pluggable RelaxationSolver
    ///
    /// Delegates to the configured relaxation solver (SimplexRelaxationSolver by default,
    /// or NonlinearRelaxationSolver for MINLP).
    private func solveRelaxation(
        constraints: [MultivariateConstraint<V>],
        objective: @Sendable @escaping (V) -> Double,
        initialGuess: V,
        minimize: Bool,
        integerSpec: IntegerProgramSpecification,
        depth: Int,
        parent: UUID? = nil,
        branchedVariable: Int? = nil,
        cutStats: CutStatisticsTracker? = nil
    ) throws -> BranchNode<V> {

        // Get dimension from initial guess
        let dimension = initialGuess.toArray().count

        // Add bound constraints for integer/binary variables
        var allConstraints = constraints

        // Add upper bound constraints for binary variables: x[i] ≤ 1
        for i in integerSpec.binaryVariables where i < dimension {
            allConstraints.append(
                .inequality(
                    function: { v in v.toArray()[i] - 1.0 },
                    gradient: nil
                )
            )
        }

        // Solve continuous relaxation using pluggable solver
        do {
            var result = try relaxationSolver.solveRelaxation(
                objective: objective,
                constraints: allConstraints,
                initialGuess: initialGuess,
                minimize: minimize
            )

            // Check status
            guard result.status == .optimal, var solution = result.solution else {
                // Handle non-optimal status
                if result.status == .unbounded {
                    // Unbounded LP: use large but finite bound
                    // Integer constraints may still bound the problem
                    let safeBound = minimize ? -1e20 : 1e20
                    return BranchNode(
                        depth: depth,
                        parent: parent,
                        constraints: constraints,
                        relaxationBound: safeBound,
                        relaxationSolution: nil,
                        branchedVariable: branchedVariable
                    )
                } else {
                    // Infeasible or numerical failure
                    return BranchNode(
                        depth: depth,
                        parent: parent,
                        constraints: constraints,
                        relaxationBound: result.objectiveValue,
                        relaxationSolution: nil,
                        branchedVariable: branchedVariable
                    )
                }
            }

            // Cutting plane generation loop
            if enableCuttingPlanes, let stats = cutStats {
                var currentConstraints = allConstraints
                var currentResult = result
                var currentSolution = solution
                var roundsPerformed = 0
                var generatedCuts: Set<String> = []  // For deduplication

                // Stagnation and cycling detection
                var boundHistory: [Double] = []
                var solutionHistory: [[Double]] = []

                // Helper to check solution equality
                func areSolutionsEqual(_ a: [Double], _ b: [Double], tolerance: Double) -> Bool {
                    guard a.count == b.count else { return false }
                    return zip(a, b).allSatisfy { abs($0 - $1) < tolerance }
                }

                let cutGenerator = CuttingPlaneGenerator(
                    fractionalTolerance: integralityTolerance,
                    weakCutTolerance: cutTolerance
                )

                for _ in 0..<maxCuttingRounds {
                    // Check if solution is fractional for integer variables
                    let solutionArray = currentSolution.toArray()
                    var hasFractional = false

                    for i in 0..<min(dimension, solutionArray.count) {
                        // Check if this variable should be integer
                        let shouldBeInteger = integerSpec.integerVariables.contains(i) ||
                                            integerSpec.binaryVariables.contains(i)

                        guard shouldBeInteger else { continue }

                        // Check if value is fractional
                        let value = solutionArray[i]
                        let fractionalPart = value - floor(value)

                        if fractionalPart > integralityTolerance && fractionalPart < 1.0 - integralityTolerance {
                            hasFractional = true
                            break
                        }
                    }

                    // If no fractional variables, stop cutting
                    guard hasFractional else {
                        break
                    }

                    // Generate cuts from tableau
                    guard let simplexResult = currentResult.simplexResult,
                          let tableau = simplexResult.tableau,
                          let basis = simplexResult.basis else {
                        // No tableau available (might be nonlinear solver)
                        break
                    }

                    var cutsThisRound: [CuttingPlane] = []

                    // Generate Gomory cuts from fractional basic variables
                    for (rowIndex, basicVarIndex) in basis.enumerated() {
                        guard basicVarIndex < solutionArray.count else { continue }

                        let value = solutionArray[basicVarIndex]
                        let fractionalPart = value - floor(value)

                        // Only generate cut if this variable is fractional and should be integer
                        let shouldBeInteger = integerSpec.integerVariables.contains(basicVarIndex) ||
                                            integerSpec.binaryVariables.contains(basicVarIndex)

                        guard shouldBeInteger &&
                              fractionalPart > integralityTolerance &&
                              fractionalPart < 1.0 - integralityTolerance else {
                            continue
                        }

                        // Extract tableau row
                        let tableauRow = tableau.getRow(rowIndex)

                        // Generate Gomory cut
                        if var cut = try cutGenerator.generateGomoryCut(
                            tableauRow: tableauRow,
                            rhs: value,
                            basicVariableIndex: basicVarIndex
                        ) {
                            // Normalize cut if enabled
                            if normalizeCuts {
                                // Compute Euclidean norm of coefficients
                                let norm = sqrt(cut.coefficients.reduce(0.0) { $0 + $1 * $1 })

                                // Check if cut has meaningful coefficients
                                guard norm > cutCoefficientThreshold else {
                                    // Skip cut with tiny coefficients
                                    continue
                                }

                                // Normalize: divide coefficients and RHS by norm
                                let normalizedCoeffs = cut.coefficients.map { $0 / norm }
                                let normalizedRHS = cut.rhs / norm

                                cut = CuttingPlane(
                                    coefficients: normalizedCoeffs,
                                    rhs: normalizedRHS,
                                    type: cut.type
                                )
                            }

                            // Deduplicate: check if we've seen this cut before
                            let cutSignature = "\(cut.coefficients.map { String(format: "%.6f", $0) }.joined(separator:",")):\(String(format: "%.6f", cut.rhs))"

                            if !generatedCuts.contains(cutSignature) {
                                cutsThisRound.append(cut)
                                generatedCuts.insert(cutSignature)
                            }
                        }
                    }

                    // If no cuts generated, stop
                    guard !cutsThisRound.isEmpty else {
                        break
                    }

                    // Add cuts as new constraints
                    for cut in cutsThisRound {
                        // Convert CuttingPlane to MultivariateConstraint
                        // Cut is: sum(cut.coefficients[i] * x[i]) <= cut.rhs
                        let cutConstraint = MultivariateConstraint<V>.linearInequality(
                            coefficients: cut.coefficients,
                            rhs: cut.rhs,
                            sense: .lessOrEqual
                        )
                        currentConstraints.append(cutConstraint)

                        // Update statistics by type
                        stats.totalCutsGenerated += 1
                        switch cut.type {
                        case .gomory:
                            stats.gomoryCuts += 1
                        case .mixedIntegerRounding:
                            stats.mirCuts += 1
                        case .cover:
                            stats.coverCuts += 1
                        case .clique:
                            break
                        }
                    }

                    // Re-solve LP with augmented constraints
                    do {
                        let resolvedResult = try relaxationSolver.solveRelaxation(
                            objective: objective,
                            constraints: currentConstraints,
                            initialGuess: initialGuess,
                            minimize: minimize
                        )

                        guard resolvedResult.status == .optimal,
                              let newSolution = resolvedResult.solution else {
                            // LP became infeasible after adding cuts - stop
                            break
                        }

                        currentResult = resolvedResult
                        currentSolution = newSolution
                        roundsPerformed += 1

                        // Stagnation detection: check if bound improved
                        if detectStagnation {
                            boundHistory.append(resolvedResult.objectiveValue)

                            // Need at least 2 bounds to compare
                            if boundHistory.count >= 2 {
                                let previousBound = boundHistory[boundHistory.count - 2]
                                let currentBound = boundHistory.last!
                                let improvement = abs(currentBound - previousBound)

                                // If improvement is negligible, terminate
                                if improvement < stagnationTolerance {
                                    break
                                }
                            }
                        }

                        // Cycling detection: check for repeated solutions
                        if detectCycling {
                            let currentSolutionArray = newSolution.toArray()
                            solutionHistory.append(currentSolutionArray)

                            // Only check if we have enough history
                            if solutionHistory.count > cyclingWindowSize {
                                let recent = Array(solutionHistory.suffix(cyclingWindowSize))
                                let current = recent.last!

                                // Check if current solution matches any recent solution
                                for i in 0..<(recent.count - 1) {
                                    if areSolutionsEqual(current, recent[i], tolerance: stagnationTolerance) {
                                        // Cycling detected - terminate
                                        break
                                    }
                                }
                            }
                        }

                    } catch {
                        // Re-solve failed - stop cutting
                        break
                    }
                }

                // Update statistics
                if roundsPerformed > 0 {
                    stats.cuttingRounds += roundsPerformed
                    stats.lpResolves += roundsPerformed
                    stats.maxRoundsAtNode = max(stats.maxRoundsAtNode, roundsPerformed)

                    // Update root bounds if this is the root node
                    if stats.isRootNode {
                        stats.rootLPBoundAfterCuts = currentResult.objectiveValue
                        stats.isRootNode = false
                    }
                }

                // Use the result from last cutting round
                result = currentResult
                solution = currentSolution
            }

            // Convert VectorN<Double> to V
            let vectorSolution = V.fromArray(solution.toArray()) ?? initialGuess

            return BranchNode(
                depth: depth,
                parent: parent,
                constraints: constraints,
                relaxationBound: result.objectiveValue,
                relaxationSolution: vectorSolution,
                branchedVariable: branchedVariable
            )

        } catch {
            // Solver error - treat as infeasible
            return BranchNode(
                depth: depth,
                parent: parent,
                constraints: constraints,
                relaxationBound: minimize ? Double.infinity : -Double.infinity,
                relaxationSolution: nil,
                branchedVariable: branchedVariable
            )
        }
    }

    /// Check if node should be pruned
    private func shouldPrune(
        _ node: BranchNode<V>,
        incumbent: (solution: V, value: Double)?,
        minimize: Bool
    ) -> Bool {
        // Prune by infeasibility
        guard node.relaxationSolution != nil else { return true }

        // Prune by bound
        if let inc = incumbent {
            if minimize && node.relaxationBound >= inc.value - lpTolerance { return true }
            if !minimize && node.relaxationBound <= inc.value + lpTolerance { return true }
        }

        return false
    }

    /// Create left and right child nodes by branching
    private func createBranches(
        parent: BranchNode<V>,
        variable: Int,
        solution: V,
        objective: @Sendable @escaping (V) -> Double,
        constraints: [MultivariateConstraint<V>],
        integerSpec: IntegerProgramSpecification,
        minimize: Bool,
        cutStats: CutStatisticsTracker?
    ) throws -> (BranchNode<V>, BranchNode<V>) {

        let value = solution.toArray()[variable]
        let floor = Foundation.floor(value)
        let ceil = Foundation.ceil(value)

        // Use parent's solution as starting point for both children
        // The InequalityOptimizer's ensureFeasibility will project it into the feasible region
        // This works better than trying to guess a good starting point ourselves
        let initialGuess = solution

        // Left branch: x_i ≤ floor
        let leftConstraints = parent.constraints + [
            .inequality(
                function: { v in v.toArray()[variable] - floor },
                gradient: nil
            )
        ]

        let leftNode = try solveRelaxation(
            constraints: leftConstraints,
            objective: objective,
            initialGuess: initialGuess,
            minimize: minimize,
            integerSpec: integerSpec,
            depth: parent.depth + 1,
            parent: parent.id,
            branchedVariable: variable,
            cutStats: enableCuttingPlanes ? cutStats : nil  // Generate cuts at all nodes
        )

        // Right branch: x_i ≥ ceil
        let rightConstraints = parent.constraints + [
            .inequality(
                function: { v in ceil - v.toArray()[variable] },
                gradient: nil
            )
        ]

        let rightNode = try solveRelaxation(
            constraints: rightConstraints,
            objective: objective,
            initialGuess: initialGuess,
            minimize: minimize,
            integerSpec: integerSpec,
            depth: parent.depth + 1,
            parent: parent.id,
            branchedVariable: variable,
            cutStats: enableCuttingPlanes ? cutStats : nil  // Generate cuts at all nodes
        )

        return (leftNode, rightNode)
    }

    /// Select variable to branch on based on branching rule
    private func selectBranchingVariable(
        _ solution: V,
        _ spec: IntegerProgramSpecification,
        parentBound: Double = 0.0,
        objective: (@Sendable (V) -> Double)? = nil,
        constraints: [MultivariateConstraint<V>] = [],
        minimize: Bool = true,
        pseudoCostTracker: PseudoCostTracker? = nil
    ) -> Int? {
        switch branchingRule {
        case .mostFractional:
            return spec.mostFractionalVariable(solution)

        case .pseudoCost:
            // Use historical cost estimates to select variable
            guard let tracker = pseudoCostTracker else {
                return spec.mostFractionalVariable(solution)
            }

            let arr = solution.toArray()
            var bestVariable: Int? = nil
            var bestScore = -Double.infinity

            for variable in spec.allIntegerVariables {
                let value = arr[variable]
                let fractionalPart = abs(value - round(value))

                // Skip nearly-integer variables
                guard fractionalPart > integralityTolerance else { continue }

                // Get pseudo-cost score (higher = better expected improvement)
                let score = tracker.hasHistory(variable: variable)
                    ? tracker.getScore(variable: variable, fractionalPart: fractionalPart)
                    : fractionalPart  // Fallback: use fractionality as score

                if score > bestScore {
                    bestScore = score
                    bestVariable = variable
                }
            }

            return bestVariable ?? spec.mostFractionalVariable(solution)

        case .strongBranching:
            // Strong branching: solve temporary LPs for candidates
            guard let obj = objective else {
                return spec.mostFractionalVariable(solution)
            }

            // Get top candidates by fractionality (most fractional variables)
            let arr = solution.toArray()
            let candidates = spec.allIntegerVariables
                .filter { variable in
                    let value = arr[variable]
                    let fractionalPart = abs(value - round(value))
                    return fractionalPart > integralityTolerance
                }
                .sorted { variable1, variable2 in
                    let frac1 = abs(arr[variable1] - round(arr[variable1]))
                    let frac2 = abs(arr[variable2] - round(arr[variable2]))
                    return abs(frac1 - 0.5) < abs(frac2 - 0.5)  // Prefer closer to 0.5
                }

            guard !candidates.isEmpty else {
                return nil
            }

            return strongBranching(
                candidates: Array(candidates),
                solution: solution,
                parentBound: parentBound,
                objective: obj,
                constraints: constraints,
                integerSpec: spec,
                minimize: minimize
            )
        }
    }

    /// Update best bound from active nodes in queue
    private func updateBestBound(
        _ bestBound: inout Double,
        from queue: NodeQueue<V>,
        minimize: Bool,
        incumbent: (solution: V, value: Double)? = nil
    ) {
        if let topNode = queue.peek() {
            bestBound = topNode.relaxationBound
        } else {
            // No nodes left
            // If we have an incumbent, the bound is the incumbent value (proven optimal)
            // Otherwise, the problem is infeasible
            if let inc = incumbent {
                bestBound = inc.value
            } else {
                bestBound = minimize ? .infinity : -.infinity
            }
        }
    }

    /// Strong branching: evaluate multiple candidates by solving temporary LPs
    ///
    /// Solves temporary LPs for each candidate variable to determine which will
    /// improve bounds most. More accurate than pseudo-costs but computationally expensive.
    ///
    /// - Parameters:
    ///   - candidates: Set of candidate variables to evaluate
    ///   - solution: Current fractional LP solution
    ///   - parentBound: Parent node's relaxation bound
    ///   - objective: Objective function
    ///   - constraints: Current constraints
    ///   - integerSpec: Integer variable specification
    ///   - minimize: Whether minimizing
    ///
    /// - Returns: Best variable to branch on
    private func strongBranching(
        candidates: [Int],
        solution: V,
        parentBound: Double,
        objective: @Sendable @escaping (V) -> Double,
        constraints: [MultivariateConstraint<V>],
        integerSpec: IntegerProgramSpecification,
        minimize: Bool
    ) -> Int {
        var bestVariable = candidates[0]
        var bestScore = -Double.infinity

        let solutionArray = solution.toArray()

        for variable in candidates.prefix(5) {  // Limit to 5 candidates for performance
            let value = solutionArray[variable]
            let floor = Foundation.floor(value)
            let ceil = Foundation.ceil(value)

            // Solve temporary LP with down branch constraint (x_i ≤ floor)
            var downConstraints = constraints
            downConstraints.append(.linearInequality(
                coefficients: Array(repeating: 0.0, count: solutionArray.count).enumerated().map { $0.offset == variable ? 1.0 : 0.0 },
                rhs: floor,
                sense: .lessOrEqual
            ))

            let downBound = solveTemporaryLP(
                objective: objective,
                constraints: downConstraints,
                initialGuess: solution,
                minimize: minimize
            )

            // Solve temporary LP with up branch constraint (x_i ≥ ceil)
            var upConstraints = constraints
            upConstraints.append(.linearInequality(
                coefficients: Array(repeating: 0.0, count: solutionArray.count).enumerated().map { $0.offset == variable ? -1.0 : 0.0 },
                rhs: -ceil,
                sense: .lessOrEqual
            ))

            let upBound = solveTemporaryLP(
                objective: objective,
                constraints: upConstraints,
                initialGuess: solution,
                minimize: minimize
            )

            // Compute improvements (how much worse each branch makes the bound)
            let downImprovement = minimize
                ? max(0, downBound - parentBound)  // Min: bound increases
                : max(0, parentBound - downBound)  // Max: bound decreases

            let upImprovement = minimize
                ? max(0, upBound - parentBound)
                : max(0, parentBound - upBound)

            // Score: product of improvements (prefer variables that make both branches hard)
            // Add small constant to avoid zero scores
            let score = (downImprovement + 1e-6) * (upImprovement + 1e-6)

            if score > bestScore {
                bestScore = score
                bestVariable = variable
            }
        }

        return bestVariable
    }

    /// Solve temporary LP for strong branching
    ///
    /// Solves LP with additional constraint to evaluate branching quality.
    /// Returns bound improvement or infinity if infeasible/unbounded.
    ///
    /// - Parameters:
    ///   - objective: Objective function
    ///   - constraints: Constraints including temporary branch constraint
    ///   - initialGuess: Starting point
    ///   - minimize: Whether minimizing
    ///
    /// - Returns: Objective bound from temporary LP
    private func solveTemporaryLP(
        objective: @Sendable @escaping (V) -> Double,
        constraints: [MultivariateConstraint<V>],
        initialGuess: V,
        minimize: Bool
    ) -> Double {
        do {
            let result = try relaxationSolver.solveRelaxation(
                objective: objective,
                constraints: constraints,
                initialGuess: initialGuess,
                minimize: minimize
            )

            switch result.status {
            case .optimal:
                return result.objectiveValue
            case .infeasible:
                // Infeasible branch has worst possible bound
                return minimize ? Double.infinity : -Double.infinity
            case .unbounded:
                // Unbounded has best possible bound (shouldn't happen with integer constraints)
                return minimize ? -Double.infinity : Double.infinity
            }
        } catch {
            // Error treated as infeasible
            return minimize ? Double.infinity : -Double.infinity
        }
    }

    /// Rounding heuristic: attempt to find integer solution by rounding fractional values
    ///
    /// Tries to quickly find feasible integer solutions by rounding fractional LP solutions.
    /// This primal heuristic can significantly reduce solve time by finding good incumbents early.
    ///
    /// - Parameters:
    ///   - fractionalSolution: LP solution with fractional values
    ///   - objective: Objective function
    ///   - constraints: Problem constraints
    ///   - integerSpec: Integer variable specification
    ///
    /// - Returns: Rounded solution if feasible, nil otherwise
    private func roundingHeuristic(
        _ fractionalSolution: V,
        objective: @Sendable (V) -> Double,
        constraints: [MultivariateConstraint<V>],
        integerSpec: IntegerProgramSpecification
    ) -> (solution: V, value: Double)? {
        var rounded = fractionalSolution.toArray()

        // Round all integer variables to nearest integer
        for i in integerSpec.allIntegerVariables {
            rounded[i] = round(rounded[i])
        }

        guard let roundedSolution = V.fromArray(rounded) else {
            return nil
        }

        // Check constraint feasibility
        for constraint in constraints {
            let value = constraint.evaluate(at: roundedSolution)
            if value > lpTolerance {
                // Constraint violated - rounded solution is infeasible
                return nil
            }
        }

        // Check integrality (should be satisfied by construction, but verify)
        for i in integerSpec.allIntegerVariables {
            let fractionalPart = abs(rounded[i] - round(rounded[i]))
            if fractionalPart > integralityTolerance {
                return nil
            }
        }

        // Rounded solution is feasible!
        let value = objective(roundedSolution)
        return (solution: roundedSolution, value: value)
    }

    /// Verify solution satisfies all constraints and integrality requirements
    ///
    /// Performs comprehensive post-solve validation to catch numerical errors,
    /// constraint violations, and objective mismatches.
    ///
    /// - Parameters:
    ///   - solution: Candidate solution to verify
    ///   - objective: Objective function
    ///   - constraints: All problem constraints
    ///   - integerSpec: Integer variable specification
    ///   - expectedObjective: Expected objective value from optimization
    ///
    /// - Returns: SolutionVerification with validation results
    private func verifySolution(
        _ solution: V,
        objective: @Sendable (V) -> Double,
        constraints: [MultivariateConstraint<V>],
        integerSpec: IntegerProgramSpecification,
        expectedObjective: Double
    ) -> SolutionVerification {
        var violations: [String] = []

        // Check 1: Integrality constraints
        let arr = solution.toArray()
        for i in integerSpec.allIntegerVariables {
            let value = arr[i]
            let fractionalPart = abs(value - round(value))
            if fractionalPart > integralityTolerance {
                violations.append("Variable[\(i)] not integer: \(value) (frac: \(fractionalPart))")
            }
        }

        // Check 2: Binary constraints
        for i in integerSpec.binaryVariables {
            let value = arr[i]
            if value < -lpTolerance || value > 1.0 + lpTolerance {
                violations.append("Binary variable[\(i)] out of range [0,1]: \(value)")
            }
        }

        // Check 3: Constraint satisfaction
        for (idx, constraint) in constraints.enumerated() {
            let value = constraint.evaluate(at: solution)
            // For constraints g(x) ≤ 0, violation is max(0, g(x))
            if value > lpTolerance {
                violations.append("Constraint[\(idx)] violated: g(x) = \(value) > 0")
            }
        }

        // Check 4: Objective value consistency
        let actualObjective = objective(solution)
        let objectiveMismatch = abs(actualObjective - expectedObjective)
        if objectiveMismatch > lpTolerance * max(1.0, abs(expectedObjective)) {
            violations.append("Objective mismatch: expected \(expectedObjective), got \(actualObjective) (diff: \(objectiveMismatch))")
        }

        return SolutionVerification(
            isValid: violations.isEmpty,
            violations: violations
        )
    }
}

// MARK: - Supporting Types

/// Tracks pseudo-costs for intelligent branching decisions
///
/// Maintains historical data about how branching on each variable affects bounds.
/// Used to predict which variables will lead to the best bound improvements.
class PseudoCostTracker: @unchecked Sendable {
    private var upCosts: [Int: (sum: Double, count: Int)] = [:]
    private var downCosts: [Int: (sum: Double, count: Int)] = [:]
    private let lock = NSLock()

    /// Update pseudo-cost for a variable after branching
    ///
    /// - Parameters:
    ///   - variable: Index of branched variable
    ///   - direction: Branch direction (up = ceiling, down = floor)
    ///   - boundImprovement: How much the bound improved
    ///   - fractionalChange: How much the variable's fractional part was
    func updateCost(
        variable: Int,
        direction: BranchDirection,
        boundImprovement: Double,
        fractionalChange: Double
    ) {
        guard fractionalChange > 1e-10 else { return }
        let cost = boundImprovement / fractionalChange

        lock.lock()
        defer { lock.unlock() }

        switch direction {
        case .up:
            let current = upCosts[variable] ?? (0.0, 0)
            upCosts[variable] = (current.sum + cost, current.count + 1)
        case .down:
            let current = downCosts[variable] ?? (0.0, 0)
            downCosts[variable] = (current.sum + cost, current.count + 1)
        }
    }

    /// Get pseudo-cost score for variable selection
    ///
    /// Returns pessimistic estimate: min(upCost, downCost) averaged over history.
    /// Variables with high scores are expected to improve bounds significantly.
    ///
    /// - Parameter variable: Variable index
    /// - Returns: Pseudo-cost score (higher is better)
    func getScore(variable: Int, fractionalPart: Double) -> Double {
        lock.lock()
        defer { lock.unlock() }

        let upAvg = upCosts[variable].map { $0.sum / Double($0.count) } ?? 0.0
        let downAvg = downCosts[variable].map { $0.sum / Double($0.count) } ?? 0.0

        // Pessimistic estimate: min of up/down costs
        // Weight by fractional part (closer to 0.5 = more uncertain)
        let upWeight = fractionalPart
        let downWeight = 1.0 - fractionalPart
        return min(upAvg * upWeight, downAvg * downWeight)
    }

    /// Check if we have cost history for a variable
    func hasHistory(variable: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return upCosts[variable] != nil || downCosts[variable] != nil
    }
}

/// Branch direction for pseudo-cost tracking
enum BranchDirection {
    case up      // Branch to ceiling
    case down    // Branch to floor
}

/// Node selection strategy for branch-and-bound tree
public enum NodeSelectionStrategy: Sendable {
    case depthFirst       // DFS - fast for finding feasible solutions
    case breadthFirst     // BFS - explores tree uniformly
    case bestBound        // Best-first - exploits bounds for optimality
    case bestEstimate     // Hybrid - estimates subtree quality
}

/// Branching rule for selecting variable to branch on
public enum BranchingRule: Sendable {
    case mostFractional   // Branch on variable furthest from integer
    case pseudoCost       // Use historical improvement estimates
    case strongBranching  // Try both branches, pick best (expensive)
}

/// Statistics from cutting plane generation during branch-and-cut
public struct CuttingPlaneStats: Sendable {
    /// Total number of cuts generated across all nodes
    public let totalCutsGenerated: Int

    /// Total number of cutting plane rounds performed
    public let cuttingRounds: Int

    /// Number of LP re-solves after adding cuts
    public let lpResolves: Int

    /// Maximum cutting rounds at any single node
    public let maxRoundsAtNode: Int

    /// Number of Gomory cuts generated
    public let gomoryCuts: Int

    /// Number of MIR cuts generated
    public let mirCuts: Int

    /// Number of cover cuts generated
    public let coverCuts: Int

    /// Root LP bound before any cuts
    public let rootLPBoundBeforeCuts: Double

    /// Root LP bound after cut generation
    public let rootLPBoundAfterCuts: Double

    /// Percentage of integrality gap closed by cuts
    ///
    /// Computed as: (improvement / initialGap) * 100
    /// where improvement = |boundAfterCuts - boundBeforeCuts|
    public let percentageGapClosed: Double

    /// Creates cutting plane statistics for branch-and-bound results.
    ///
    /// - Parameters:
    ///   - totalCutsGenerated: Total number of cutting planes generated across all nodes (default: 0)
    ///   - cuttingRounds: Number of cutting plane rounds performed (default: 0)
    ///   - lpResolves: Number of LP re-solves after adding cuts (default: 0)
    ///   - maxRoundsAtNode: Maximum rounds performed at any single node (default: 0)
    ///   - gomoryCuts: Number of Gomory fractional cuts generated (default: 0)
    ///   - mirCuts: Number of mixed-integer rounding cuts generated (default: 0)
    ///   - coverCuts: Number of cover cuts generated (default: 0)
    ///   - rootLPBoundBeforeCuts: LP bound at root node before cut generation (default: 0.0)
    ///   - rootLPBoundAfterCuts: LP bound at root node after cut generation (default: 0.0)
    ///   - percentageGapClosed: Percentage of integrality gap closed by cuts (default: 0.0)
    public init(
        totalCutsGenerated: Int = 0,
        cuttingRounds: Int = 0,
        lpResolves: Int = 0,
        maxRoundsAtNode: Int = 0,
        gomoryCuts: Int = 0,
        mirCuts: Int = 0,
        coverCuts: Int = 0,
        rootLPBoundBeforeCuts: Double = 0.0,
        rootLPBoundAfterCuts: Double = 0.0,
        percentageGapClosed: Double = 0.0
    ) {
        self.totalCutsGenerated = totalCutsGenerated
        self.cuttingRounds = cuttingRounds
        self.lpResolves = lpResolves
        self.maxRoundsAtNode = maxRoundsAtNode
        self.gomoryCuts = gomoryCuts
        self.mirCuts = mirCuts
        self.coverCuts = coverCuts
        self.rootLPBoundBeforeCuts = rootLPBoundBeforeCuts
        self.rootLPBoundAfterCuts = rootLPBoundAfterCuts
        self.percentageGapClosed = percentageGapClosed
    }
}

/// Result from integer programming optimization
public struct IntegerOptimizationResult<V: VectorSpace>: Sendable where V.Scalar == Double {
    /// Best integer-feasible solution found
    public let solution: V

    /// Objective value at solution
    public let objectiveValue: Double

    /// Best lower bound (for minimization) from relaxations
    public let bestBound: Double

    /// Optimality gap: |objectiveValue - bestBound| / |objectiveValue|
    public let relativeGap: Double

    /// Total nodes explored in branch-and-bound tree
    public let nodesExplored: Int

    /// Solution status
    public let status: IntegerSolutionStatus

    /// Total solve time in seconds
    public let solveTime: Double

    /// Integer specification used
    public let integerSpec: IntegerProgramSpecification

    /// Cutting plane statistics (if enabled)
    ///
    /// Contains information about cuts generated, LP resolves, and bound improvements.
    /// Only populated when enableCuttingPlanes is true.
    public let cuttingPlaneStats: CuttingPlaneStats?

    /// Formatter used for displaying results (mutable for customization)
    public var formatter: FloatingPointFormatter = .optimization

    /// Integer solution with proper rounding (fixes production scheduling bug)
    ///
    /// CRITICAL: Uses round() instead of truncation to handle floating-point precision.
    /// For example, 99.99999999999999 rounds to 100, not 99.
    public var integerSolution: [Int] {
        solution.toArray().map { Int(round($0)) }
    }

    /// Formatted solution showing clean integer values
    public var formattedSolution: String {
        "[" + integerSolution.map { String($0) }.joined(separator: ", ") + "]"
    }

    /// Formatted objective value with clean floating-point display
    public var formattedObjectiveValue: String {
        formatter.format(objectiveValue).formatted
    }

    /// Formatted description showing clean results
    public var formattedDescription: String {
        var desc = "Integer Optimization Result:\n"
        desc += "  Solution: \(formattedSolution)\n"
        desc += "  Objective Value: \(formattedObjectiveValue)\n"
        desc += "  Status: \(status)\n"
        desc += "  Relative Gap: \(formatter.format(relativeGap).formatted)\n"
        desc += "  Nodes Explored: \(nodesExplored)\n"
        desc += "  Solve Time: \(formatter.format(solveTime).formatted)s"
        return desc
    }
}

/// Result of post-solve solution verification
///
/// Validates that a candidate solution satisfies all mathematical requirements:
/// - Integer variables are truly integer within tolerance
/// - Binary variables ∈ [0, 1]
/// - All constraints satisfied
/// - Objective value matches recomputation
struct SolutionVerification: Sendable {
    /// Whether the solution passes all validation checks
    let isValid: Bool

    /// List of validation violations (empty if valid)
    let violations: [String]
}

/// Status of integer programming solution
public enum IntegerSolutionStatus: Sendable {
    case optimal          // Proved optimal within tolerance
    case feasible         // Found integer solution, but not proved optimal
    case infeasible       // No integer-feasible solution exists
    case nodeLimit        // Hit maximum nodes
    case timeLimit        // Hit time limit
}

/// Internal node in branch-and-bound tree
struct BranchNode<V: VectorSpace>: Sendable where V.Scalar == Double {
    let id: UUID
    let depth: Int
    let parent: UUID?
    let constraints: [MultivariateConstraint<V>]
    let relaxationBound: Double
    let relaxationSolution: V?
    let branchedVariable: Int?

    init(
        depth: Int,
        parent: UUID?,
        constraints: [MultivariateConstraint<V>],
        relaxationBound: Double,
        relaxationSolution: V?,
        branchedVariable: Int?
    ) {
        self.id = UUID()
        self.depth = depth
        self.parent = parent
        self.constraints = constraints
        self.relaxationBound = relaxationBound
        self.relaxationSolution = relaxationSolution
        self.branchedVariable = branchedVariable
    }
}

/// Priority queue for node selection in branch-and-bound using binary heap
///
/// Efficient O(log n) insert and extractBest operations using a min/max heap.
/// Previous implementation sorted on every insert (O(n log n)), which collapsed at scale.
struct NodeQueue<V: VectorSpace>: Sendable where V.Scalar == Double {
    private var heap: [BranchNode<V>] = []
    private let strategy: NodeSelectionStrategy
    private let minimize: Bool

    init(strategy: NodeSelectionStrategy, minimize: Bool) {
        self.strategy = strategy
        self.minimize = minimize
    }

    /// Insert node into queue - O(log n)
    mutating func insert(_ node: BranchNode<V>) {
        heap.append(node)
        siftUp(from: heap.count - 1)
    }

    /// Extract best node according to strategy - O(log n)
    mutating func extractBest() -> BranchNode<V>? {
        guard !heap.isEmpty else { return nil }

        if heap.count == 1 {
            return heap.removeLast()
        }

        let best = heap[0]
        heap[0] = heap.removeLast()
        siftDown(from: 0)

        return best
    }

    /// Peek at best node without removing - O(1)
    func peek() -> BranchNode<V>? {
        return heap.first
    }

    var isEmpty: Bool {
        heap.isEmpty
    }

    var count: Int {
        heap.count
    }

    // MARK: - Binary Heap Operations

    /// Sift node up to maintain heap property
    private mutating func siftUp(from index: Int) {
        var childIndex = index
        let child = heap[childIndex]

        while childIndex > 0 {
            let parentIndex = (childIndex - 1) / 2
            let parent = heap[parentIndex]

            // Check if heap property is satisfied
            if isBetter(child, than: parent) {
                heap[childIndex] = parent
                childIndex = parentIndex
            } else {
                break
            }
        }

        heap[childIndex] = child
    }

    /// Sift node down to maintain heap property
    private mutating func siftDown(from index: Int) {
        var parentIndex = index
        let parent = heap[parentIndex]
        let count = heap.count

        while true {
            let leftChildIndex = 2 * parentIndex + 1
            let rightChildIndex = 2 * parentIndex + 2
            var bestIndex = parentIndex

            // Check left child
            if leftChildIndex < count && isBetter(heap[leftChildIndex], than: heap[bestIndex]) {
                bestIndex = leftChildIndex
            }

            // Check right child
            if rightChildIndex < count && isBetter(heap[rightChildIndex], than: heap[bestIndex]) {
                bestIndex = rightChildIndex
            }

            // If parent is still best, we're done
            if bestIndex == parentIndex {
                heap[parentIndex] = parent
                break
            }

            // Otherwise, swap and continue
            heap[parentIndex] = heap[bestIndex]
            parentIndex = bestIndex
        }

        heap[parentIndex] = parent
    }

    /// Determine if node1 is "better" than node2 according to strategy
    private func isBetter(_ node1: BranchNode<V>, than node2: BranchNode<V>) -> Bool {
        switch strategy {
        case .depthFirst:
            // Deeper nodes are better (max heap on depth)
            return node1.depth > node2.depth

        case .breadthFirst:
            // Shallower nodes are better (min heap on depth)
            return node1.depth < node2.depth

        case .bestBound:
            // Better bound is better
            if minimize {
                // Minimization: smaller bound is better
                return node1.relaxationBound < node2.relaxationBound
            } else {
                // Maximization: larger bound is better
                return node1.relaxationBound > node2.relaxationBound
            }

        case .bestEstimate:
            // Hybrid: use bound (could incorporate depth or other heuristics)
            if minimize {
                return node1.relaxationBound < node2.relaxationBound
            } else {
                return node1.relaxationBound > node2.relaxationBound
            }
        }
    }
}

// MARK: - Cut Pool Management

/// Managed cut with aging and activity tracking
///
/// Tracks metadata about cuts to enable intelligent pool management.
/// Old inactive cuts can be removed to prevent memory growth.
private struct ManagedCut: Sendable {
    let cut: CuttingPlane
    var age: Int = 0
    var activity: Double = 0.0
    var timesViolated: Int = 0

    init(cut: CuttingPlane) {
        self.cut = cut
    }
}

/// Cut pool with aging and automatic pruning
///
/// Manages a bounded pool of cutting planes, removing old inactive cuts
/// to prevent unbounded memory growth during long solves.
private class CutPool: @unchecked Sendable {
    private var managedCuts: [ManagedCut] = []
    private let maxSize: Int
    private let maxAge: Int
    private let lock = NSLock()

    init(maxSize: Int = 10_000, maxAge: Int = 100) {
        self.maxSize = maxSize
        self.maxAge = maxAge
    }

    /// Add a cut to the pool
    func addCut(_ cut: CuttingPlane) {
        lock.lock()
        defer { lock.unlock() }

        managedCuts.append(ManagedCut(cut: cut))

        // Prune if pool is too large
        if managedCuts.count > maxSize {
            prunePool()
        }
    }

    /// Age all cuts and remove old inactive ones
    func ageCuts() {
        lock.lock()
        defer { lock.unlock() }

        // Increment age
        managedCuts = managedCuts.map { cut in
            var aged = cut
            aged.age += 1
            return aged
        }

        // Remove old cuts with low activity
        managedCuts.removeAll { cut in
            cut.age > maxAge && cut.activity < 1e-6 && cut.timesViolated < 3
        }
    }

    /// Update activity when a cut is violated
    func recordViolation(cutIndex: Int, violation: Double) {
        lock.lock()
        defer { lock.unlock() }

        guard cutIndex < managedCuts.count else { return }

        managedCuts[cutIndex].activity = max(managedCuts[cutIndex].activity, violation)
        managedCuts[cutIndex].timesViolated += 1
        managedCuts[cutIndex].age = 0  // Reset age on activity
    }

    /// Get current cuts
    func getCuts() -> [CuttingPlane] {
        lock.lock()
        defer { lock.unlock() }

        return managedCuts.map { $0.cut }
    }

    /// Prune pool to max size by removing least valuable cuts
    private func prunePool() {
        // Sort by value: prefer recently used (low age), highly active cuts
        managedCuts.sort { cut1, cut2 in
            let score1 = cut1.activity / Double(cut1.age + 1)
            let score2 = cut2.activity / Double(cut2.age + 1)
            return score1 > score2
        }

        // Keep only top maxSize cuts
        if managedCuts.count > maxSize {
            managedCuts = Array(managedCuts.prefix(maxSize))
        }
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return managedCuts.count
    }
}

// MARK: - Cut Statistics Tracker

/// Mutable statistics tracker for cutting plane generation during solve
private class CutStatisticsTracker {
    var totalCutsGenerated = 0
    var cuttingRounds = 0
    var lpResolves = 0
    var maxRoundsAtNode = 0
    var gomoryCuts = 0
    var mirCuts = 0
    var coverCuts = 0
    var rootLPBoundBeforeCuts: Double = 0.0
    var rootLPBoundAfterCuts: Double = 0.0
    var isRootNode = true

    /// Create immutable CuttingPlaneStats from tracker
    func createStats(integerOptimum: Double?) -> CuttingPlaneStats {
        // Calculate percentage gap closed
        let initialGap = abs(rootLPBoundBeforeCuts - (integerOptimum ?? rootLPBoundAfterCuts))
        let improvement = abs(rootLPBoundBeforeCuts - rootLPBoundAfterCuts)
        let percentClosed = initialGap > 1e-10 ? (improvement / initialGap) * 100.0 : 0.0

        return CuttingPlaneStats(
            totalCutsGenerated: totalCutsGenerated,
            cuttingRounds: cuttingRounds,
            lpResolves: lpResolves,
            maxRoundsAtNode: maxRoundsAtNode,
            gomoryCuts: gomoryCuts,
            mirCuts: mirCuts,
            coverCuts: coverCuts,
            rootLPBoundBeforeCuts: rootLPBoundBeforeCuts,
            rootLPBoundAfterCuts: rootLPBoundAfterCuts,
            percentageGapClosed: percentClosed
        )
    }

    /// Record cut generation at a node
    func recordCuts(generated: Int, rounds: Int, type: CutType) {
        totalCutsGenerated += generated
        cuttingRounds += rounds
        lpResolves += rounds  // Each round requires an LP re-solve
        maxRoundsAtNode = max(maxRoundsAtNode, rounds)

        // Track by type
        switch type {
        case .gomory:
            gomoryCuts += generated
        case .mixedIntegerRounding:
            mirCuts += generated
        case .cover:
            coverCuts += generated
        case .clique:
            break  // Not tracking clique cuts yet
        }
    }
}
