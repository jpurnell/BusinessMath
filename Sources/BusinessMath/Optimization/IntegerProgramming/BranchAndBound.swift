import Foundation
#if canImport(os)
import os
private let logger = Logger(subsystem: "com.businessmath", category: "BranchAndBound")
#endif

/// Norm used for cut coefficient scaling and normalization
public enum VectorNorm: Sendable {
    /// Euclidean norm (L2): √(∑a²)
    case euclidean
    /// Infinity norm (L∞): max(|a|)
    case infinity
}

/// Branch and Bound solver for Mixed-Integer Linear/Nonlinear Programs
public struct BranchAndBoundSolver<V: VectorSpace> where V.Scalar == Double, V: Sendable {

    /// Maximum nodes to explore before terminating
    public let maxNodes: Int

    /// How long the search may run, or `nil` for no limit.
    ///
    /// `nil` rather than a sentinel. This was `Double` with `0` meaning "no limit", which
    /// is the one value a caller is most likely to read as its opposite -- and did: an
    /// unguarded elapsed check made `.seconds(0)` expire at the first node, and
    /// ``BranchAndCutSolver`` *defaulted* to `0`, so a default-constructed solver failed
    /// every problem it was given. `Duration.zero` now means an already-missed deadline,
    /// which is what it reads like, and needs no guard to say so.
    public let timeLimit: Duration?

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

    // MARK: - Tier 2: Advanced Cutting Plane Features

    /// Whether to enable Mixed-Integer Rounding (MIR) cuts
    ///
    /// MIR cuts are stronger than Gomory cuts for mixed-integer problems
    /// where some variables are continuous. Only generated when both integer
    /// and continuous variables are present.
    public let enableMIRCuts: Bool

    /// Whether to enable cover cuts for knapsack constraints
    ///
    /// Cover cuts exploit the combinatorial structure of knapsack-type constraints
    /// (binary variables with positive coefficients). Effective for 0-1 knapsack problems.
    public let enableCoverCuts: Bool

    /// Whether to lift cover cuts
    ///
    /// Lifting strengthens cover cuts by including additional variables.
    /// Only applies when `enableCoverCuts` is true. More expensive but produces tighter cuts.
    public let liftCoverCuts: Bool

    /// Whether to filter dominated cuts before adding to LP
    ///
    /// Checks if a new cut is weaker than existing constraints/cuts and skips it.
    /// Reduces LP size and improves numerical stability.
    public let filterDominatedCuts: Bool

    /// Whether to enable cut aging mechanism
    ///
    /// Inactive cuts (not binding at optimal LP solution) accumulate an "age".
    /// Cuts exceeding `cutAgingLimit` are removed from the LP to prevent bloat.
    public let enableCutAging: Bool

    /// Number of iterations a cut can be inactive before removal
    ///
    /// Only applies when `enableCutAging` is true. Typical values: 3-10.
    /// Lower values keep LP smaller; higher values preserve potentially useful cuts.
    public let cutAgingLimit: Int

    /// Maximum size of the cut pool
    ///
    /// Limits total number of cuts generated across all nodes.
    /// When exceeded, oldest or weakest cuts are pruned. Set to 0 for unlimited.
    public let maxCutPoolSize: Int

    // MARK: - Tier 3: Numerical Robustness Features

    /// Norm used for cut scaling/normalization
    ///
    /// - `.euclidean` (L2): Standard normalization, divides by √(∑a²)
    /// - `.infinity` (L∞): Divides by max(|a|), keeps largest coefficient at 1.0
    ///
    /// Infinity norm is recommended for problems with widely varying coefficient scales.
    public let cutScalingNorm: VectorNorm

    /// Whether to enable warm starting of simplex basis
    ///
    /// When true, reuses the previous LP basis when re-solving after adding cuts.
    /// Significantly reduces simplex iterations but requires basis tracking.
    public let enableWarmStart: Bool

    /// Solver for continuous relaxations
    ///
    /// Used at each node to compute LP/NLP bounds for pruning.
    /// Defaults to SimplexRelaxationSolver for fast linear relaxations.
    public let relaxationSolver: any RelaxationSolver

    /// Where the time-limit check reads the clock, shared with the relaxation solver.
    ///
    /// Defaults to the system's monotonic counter. Inject ``ManualElapsedTimeSource``
    /// to assert on modelled time rather than measured time — see ``ElapsedTimeSource``.
    public let elapsedTime: any ElapsedTimeSource

    /// Creates a branch-and-bound solver with comprehensive configuration options.
    ///
    /// - Parameters:
    ///   - maxNodes: Maximum nodes to explore before terminating (default: 10,000)
    ///   - timeLimit: How long the search may run, or `nil` for no limit (default: 300 seconds).
    ///     `.zero` is a deadline already missed, not a request for unlimited time.
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
    ///   - enableMIRCuts: Enable Mixed-Integer Rounding cuts for mixed-integer problems (default: false)
    ///   - enableCoverCuts: Enable cover cuts for knapsack constraints (default: false)
    ///   - liftCoverCuts: Lift cover cuts for stronger bounds (default: false)
    ///   - filterDominatedCuts: Filter dominated cuts before adding to LP (default: true)
    ///   - enableCutAging: Enable aging mechanism to remove inactive cuts (default: true)
    ///   - cutAgingLimit: Iterations before removing inactive cuts (default: 5)
    ///   - maxCutPoolSize: Maximum total cuts across all nodes, 0 for unlimited (default: 1000)
    ///   - cutScalingNorm: Norm used for cut normalization (default: `.euclidean`)
    ///   - enableWarmStart: Reuse simplex basis when re-solving with cuts (default: true)
    ///   - relaxationSolver: Custom relaxation solver, or `nil` for default `SimplexRelaxationSolver`
    ///   - elapsedTime: Where the time-limit check reads the clock (default: the
    ///     system's monotonic counter). Inject ``ManualElapsedTimeSource`` to assert
    ///     on modelled time rather than measured time.
    public init(
        maxNodes: Int = 10_000,
        timeLimit: Duration? = .seconds(300),
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
        enableMIRCuts: Bool = false,
        enableCoverCuts: Bool = false,
        liftCoverCuts: Bool = false,
        filterDominatedCuts: Bool = true,
        enableCutAging: Bool = true,
        cutAgingLimit: Int = 5,
        maxCutPoolSize: Int = 1000,
        cutScalingNorm: VectorNorm = .euclidean,
        enableWarmStart: Bool = true,
        relaxationSolver: (any RelaxationSolver)? = nil,
        elapsedTime: any ElapsedTimeSource = SystemElapsedTimeSource()
    ) {
        // Validate tolerance hierarchy
        // Mathematical requirement: lpTolerance ≤ integralityTolerance ≤ cutTolerance
        // Rationale:
        // - LP must be solved more accurately than we check integrality
        // - Integrality must be stricter than cut violation threshold
        // - Otherwise, we may reject integer solutions or add useless cuts
        guard lpTolerance > 0 else {
            preconditionFailure("lpTolerance must be positive")
        }
        guard integralityTolerance > 0 else {
            preconditionFailure("integralityTolerance must be positive")
        }
        guard cutTolerance > 0 else {
            preconditionFailure("cutTolerance must be positive")
        }
        guard lpTolerance <= integralityTolerance else {
            preconditionFailure("lpTolerance (\(lpTolerance)) must be ≤ integralityTolerance (\(integralityTolerance))")
        }
        guard integralityTolerance <= cutTolerance else {
            preconditionFailure("integralityTolerance (\(integralityTolerance)) must be ≤ cutTolerance (\(cutTolerance))")
        }

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
        self.enableMIRCuts = enableMIRCuts
        self.enableCoverCuts = enableCoverCuts
        self.liftCoverCuts = liftCoverCuts
        self.filterDominatedCuts = filterDominatedCuts
        self.enableCutAging = enableCutAging
        self.cutAgingLimit = cutAgingLimit
        self.maxCutPoolSize = maxCutPoolSize
        self.cutScalingNorm = cutScalingNorm
        self.enableWarmStart = enableWarmStart

        // Default to SimplexRelaxationSolver for backward compatibility
        self.relaxationSolver = relaxationSolver ?? SimplexRelaxationSolver(lpTolerance: lpTolerance)
        self.elapsedTime = elapsedTime
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
            // Safe casts protected by type check above
            if let doubleConstraints = constraints as? [MultivariateConstraint<VectorN<Double>>],
               let doubleGuess = initialGuess as? VectorN<Double> {
                let dimension = initialGuess.toArray().count
                let shift = try extractVariableShift(
                    from: doubleConstraints,
                    dimension: dimension
                )

                if shift.needsShift {
                    variableShift = shift

                    // Transform objective: f(x) → f(y + shift)
                    shiftedObjective = { (y: V) -> Double in
                        guard let yDouble = y as? VectorN<Double>,
                              let x = shift.unshiftPoint(yDouble) as? V else {
                            return objective(y)  // Fallback to original if cast fails
                        }
                        return objective(x)
                    }

                    // Transform constraints
                    shiftedConstraints = try constraints.compactMap { constraint -> MultivariateConstraint<V>? in
                        guard let doubleConstraint = constraint as? MultivariateConstraint<VectorN<Double>> else {
                            return constraint
                        }
                        let transformed = try shift.transformConstraint(doubleConstraint)
                        return transformed as? MultivariateConstraint<V> ?? constraint
                    }

                    // Transform initial guess
                    if let shiftedDouble = shift.shiftPoint(doubleGuess) as? V {
                        shiftedInitialGuess = shiftedDouble
                    }
                }
            }
        }

        // Monotonic: every use below is an elapsed interval or a time-limit check, and a
        // wall clock can be adjusted mid-solve. See ``Duration/inSeconds``.
        //
        // Read through ``ElapsedTimeSource`` rather than from a `ContinuousClock`
        // constructed here, so the time limit can be tested by advancing a counter
        // instead of by measuring the machine. A wall-clock assertion in a test is a
        // claim about the scheduler: a sleep sets a floor on elapsed time and no
        // ceiling, which is how this package once had a "fast" operation outlast a
        // "slow" one.
        let clock = elapsedTime
        let startTime = clock.now
        // The same limit the node loop tests, expressed as an instant so it can be
        // handed to the relaxation solver. Checking `timeLimit` only between nodes
        // bounds nothing: a node is an arbitrary program over the caller's
        // objective, and a one-second limit was measured taking 153 seconds.
        let deadline: ContinuousClock.Instant? = timeLimit.map { startTime.advanced(by: $0) }
        var queue = NodeQueue<V>(strategy: nodeSelection, minimize: minimize)
        var incumbent: (solution: V, value: Double)? = nil
        var bestBound = minimize ? -Double.infinity : Double.infinity
        var nodesExplored = 0

        // Helper to safely unshift a solution if variable shifting was applied
        let safeUnshift: (V) -> V = { solution in
            guard let shift = variableShift,
                  let doubleVec = solution as? VectorN<Double>,
                  let unshifted = shift.unshiftPoint(doubleVec) as? V else {
                return solution
            }
            return unshifted
        }

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
            cutStats: enableCuttingPlanes ? cutStats : nil,
            deadline: deadline
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
                solveTime: (clock.now - startTime).inSeconds,
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
                if variableShift != nil, let inc = incumbent {
                    finalSolution = safeUnshift(inc.solution)
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
                    solveTime: (clock.now - startTime).inSeconds,
                    integerSpec: integerSpec,
                    cuttingPlaneStats: enableCuttingPlanes ? cutStats.createStats(integerOptimum: incumbent?.value) : nil
                )
            }

            // `if let` is the whole guard now. The `timeLimit > 0` test that used to stand
            // here was defending a sentinel: `0` meant "no limit", so the comparison
            // `elapsed > .seconds(0)` -- true as soon as the clock moves at all -- had to be
            // suppressed by hand. Forgetting to suppress it expired a zero budget at the
            // first node instead of never, and BranchAndCutSolver *defaulted* to 0, so a
            // default-constructed solver failed every problem it was ever given.
            //
            // With `Duration?` the absent case is absent from the expression entirely, so
            // there is no sentinel to forget. `.zero` falls through to the comparison and
            // expires immediately, which is now the correct answer rather than the bug.
            if let limit = timeLimit, (clock.now - startTime) > limit {
                let gap = incumbent.map { abs($0.value - bestBound) / max(abs($0.value), 1.0) } ?? .infinity

                // Unshift solution if variable shifting was applied
                let finalSolution: V
                if variableShift != nil, let inc = incumbent {
                    finalSolution = safeUnshift(inc.solution)
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
                    solveTime: (clock.now - startTime).inSeconds,
                    integerSpec: integerSpec,
                    cuttingPlaneStats: enableCuttingPlanes ? cutStats.createStats(integerOptimum: incumbent?.value) : nil
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
                let shouldUpdate: Bool
                if let inc = incumbent {
                    shouldUpdate = minimize ? value < inc.value : value > inc.value
                } else {
                    shouldUpdate = true
                }
                if shouldUpdate {
                    incumbent = (solution, value)
                }
                updateBestBound(&bestBound, from: queue, minimize: minimize, incumbent: incumbent)

                // Check if we can terminate due to optimality gap
                if let inc = incumbent {
                    let gap = abs(inc.value - bestBound) / max(abs(inc.value), 1.0)
                    if gap < relativeGapTolerance {
                        // Unshift solution if variable shifting was applied
                        let finalSolution: V
                        if variableShift != nil {
                            finalSolution = safeUnshift(inc.solution)
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
                            solveTime: (clock.now - startTime).inSeconds,
                            integerSpec: integerSpec,
                    cuttingPlaneStats: enableCuttingPlanes ? cutStats.createStats(integerOptimum: incumbent?.value) : nil
                        )
                    }
                }
                continue
            }

            // Step 4.5: Try a rounding heuristic on the fractional solution.
            //
            // A rounded point is an *incumbent*, never an answer. Its value bounds the
            // optimum from the near side, which lets later nodes be pruned sooner —
            // that is the whole benefit, and it is real. What it cannot do is stand in
            // for the subtree below this node.
            //
            // This block used to `continue` after rounding, abandoning the node
            // unbranched, and to recompute `bestBound` from a queue that at the root
            // is still empty. `updateBestBound` reads an empty queue as "search
            // exhausted" and collapses the bound onto the incumbent, so the gap closed
            // to zero and the rounded point was returned as `.optimal` after a single
            // node. On `max 3x - 2y + 4z` over `x - y + 2z ≤ 6`, `2x + y + z ≤ 8`,
            // `0 ≤ x,y,z ≤ 4` that returned 13 at (3, 0, 1); the optimum is 14 at
            // (2, 0, 2). Feasible, integral, and a full unit short.
            //
            // Nothing in the existing suite could see it: the point satisfies every
            // constraint, the objective matches the point, and the bound still pointed
            // the right way — because it had been set to the answer being checked.
            // Only enumerating the box exposed it.
            if let rounded = roundingHeuristic(
                solution,
                objective: shiftedObjective,
                constraints: shiftedConstraints,
                integerSpec: integerSpec
            ) {
                let shouldUpdateFromRounding: Bool
                if let inc = incumbent {
                    shouldUpdateFromRounding = minimize ? rounded.value < inc.value : rounded.value > inc.value
                } else {
                    shouldUpdateFromRounding = true
                }
                if shouldUpdateFromRounding {
                    incumbent = (solution: rounded.solution, value: rounded.value)
                }
                // Deliberately no bound update and no termination check here: this node
                // has not been explored, so there is nothing yet to conclude. Execution
                // falls through to Step 5 and branches.
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
                    cutStats: enableCuttingPlanes ? cutStats : nil,
                    deadline: deadline
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
            } catch { // logging: branching failed — node infeasible, continue search
                updateBestBound(&bestBound, from: queue, minimize: minimize, incumbent: incumbent)
                continue
            }
        }

        // Step 6: Return result
        guard let final = incumbent else {
            // No solution found - return original initial guess (unshifted if needed)
            let finalSolution: V
            if variableShift != nil {
                finalSolution = safeUnshift(initialGuess)
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
                solveTime: (clock.now - startTime).inSeconds,
                integerSpec: integerSpec,
                    cuttingPlaneStats: enableCuttingPlanes ? cutStats.createStats(integerOptimum: incumbent?.value) : nil
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
        if variableShift != nil {
            finalSolution = safeUnshift(final.solution)
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
            #if canImport(os)
            logger.warning("Solution verification failed!")
            for violation in verification.violations {
                logger.warning("  - \(violation, privacy: .public)")
            }
            #endif
        }

        return IntegerOptimizationResult(
            solution: finalSolution,
            objectiveValue: final.value,
            bestBound: bestBound,
            relativeGap: gap,
            nodesExplored: nodesExplored,
            status: status,
            solveTime: (clock.now - startTime).inSeconds,
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
    /// let constraints: [MultivariateConstraint<VectorN<Double>>] = [.budgetConstraint]
    ///
    /// let result = try solver.solve(
    ///     objective: { point in objective.evaluate(at: point) },
    ///     from: VectorN<Double>([0.5, 0.5]),
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
        cutStats: CutStatisticsTracker? = nil,
        deadline: ContinuousClock.Instant? = nil
    ) throws -> BranchNode<V> {

        // Get dimension from initial guess
        let dimension = initialGuess.toArray().count

        // Add bound constraints for integer/binary variables
        var allConstraints = constraints

        // Add upper bound constraints for binary variables: x[i] ≤ 1.
        //
        // Stated as `.linearInequality` rather than as a closure. The relaxation solver reads a
        // linear constraint's coefficients and right-hand side directly and differentiates only
        // what it must; a closure forces it to recover `[0, …, 1, …, 0]` and `1` numerically,
        // and the ~1e-10 error that comes back can decide feasibility for a binary node, whose
        // feasible region is a face of the unit cube.
        // Sorted, and this one matters most of the four. These constraints are appended to the
        // LP in iteration order, so an unsorted set gave the tableau a different row order in
        // every process — and with it different pivots, a different vertex chosen among ties,
        // and a different search downstream.
        for i in integerSpec.binaryVariables.sorted() where i < dimension {
            var unit = Array(repeating: 0.0, count: dimension)
            unit[i] = 1.0
            allConstraints.append(
                .linearInequality(coefficients: unit, rhs: 1.0, sense: .lessOrEqual)
            )
        }

        // Solve continuous relaxation using pluggable solver
        do {
            var result = try relaxationSolver.solveRelaxation(
                objective: objective,
                constraints: allConstraints,
                initialGuess: initialGuess,
                minimize: minimize,
                deadline: deadline
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

                // Cut signatures already added at this node, so a cut generated twice is
                // carried once.
                var generatedCuts: Set<String> = []

                // Per-cut age records: which constraint row, when added, when last active.
                var cutAges: [(constraintIndex: Int, roundAdded: Int, lastActiveRound: Int)] = []

                // Round-over-round history, read by the stagnation and cycling tests.
                var boundHistory: [Double] = []
                var solutionHistory: [[Double]] = []

                let cutGenerator = CuttingPlaneGenerator(
                    fractionalTolerance: integralityTolerance,
                    weakCutTolerance: cutTolerance
                )

                // One round is a pipeline, and each stage below is a named method on this type
                // — see `BranchAndBoundCutting.swift` for what each does and why. Read as a
                // sequence of `guard`s: every way out of the loop is stated here, at the loop's
                // own level, rather than buried in a scan that a `break` can bind to by mistake.
                for _ in 0..<maxCuttingRounds {
                    let solutionArray = currentSolution.toArray()

                    // Nothing fractional means nothing to separate.
                    guard hasFractionalIntegerVariable(
                        solutionArray,
                        integerSpec: integerSpec,
                        dimension: dimension
                    ) else { break }

                    // Gomory and MIR cuts are read off the tableau, so a solver that does not
                    // produce one — the nonlinear relaxation, for instance — cannot be cut.
                    guard let simplexResult = currentResult.simplexResult,
                          let tableau = simplexResult.tableau,
                          let basis = simplexResult.basis else { break }

                    // Tableau columns are the variables plus the right-hand side.
                    let totalVariableCount = tableau.columnCount - 1
                    let basisSet = Set(basis)
                    let nonBasicIndices = (0..<totalVariableCount).filter { !basisSet.contains($0) }

                    let simplexRows = fractionalSimplexRows(
                        tableau: tableau,
                        basis: basis,
                        solution: solutionArray,
                        integerSpec: integerSpec,
                        totalVariableCount: totalVariableCount,
                        nonBasicIndices: nonBasicIndices
                    )

                    var generatedCutList = try cutGenerator.generateCuts(
                        from: simplexRows,
                        currentSolution: solutionArray,
                        totalVariableCount: totalVariableCount,
                        integerVariables: integerSpec.integerVariables.union(integerSpec.binaryVariables),
                        enableGomory: true,
                        enableMIR: enableMIRCuts
                    )

                    if enableCoverCuts {
                        generatedCutList += try coverCuts(
                            from: constraints,
                            solution: solutionArray,
                            integerSpec: integerSpec,
                            dimension: dimension,
                            generator: cutGenerator
                        )
                    }

                    let freshCuts = normalisedAndDeduplicated(generatedCutList, seen: &generatedCuts)
                    guard !freshCuts.isEmpty else { break }

                    let filteredCuts = withoutDominatedCuts(freshCuts)

                    // `nil` is the pool being full, which ends the loop; an empty array would
                    // only mean this round contributed nothing.
                    guard let cutsToAdd = withinPoolBudget(
                        filteredCuts,
                        alreadyGenerated: stats.totalCutsGenerated
                    ) else { break }

                    if enableCutAging && roundsPerformed > 0 {
                        removeAgedCuts(
                            from: &currentConstraints,
                            ages: &cutAges,
                            round: roundsPerformed,
                            stats: stats
                        )
                    }

                    appendCuts(
                        cutsToAdd,
                        to: &currentConstraints,
                        ages: &cutAges,
                        tableau: tableau,
                        dimension: dimension,
                        round: roundsPerformed,
                        stats: stats
                    )

                    do {
                        // Warm starting hands the previous vertex back as the starting point,
                        // which is only sound because the cuts added are valid there or nearby.
                        let nextInitialGuess: V = enableWarmStart
                            ? (V.fromArray(currentSolution.toArray()) ?? initialGuess)
                            : initialGuess

                        let resolvedResult = try relaxationSolver.solveRelaxation(
                            objective: objective,
                            constraints: currentConstraints,
                            initialGuess: nextInitialGuess,
                            minimize: minimize,
                            deadline: deadline
                        )

                        guard resolvedResult.status == .optimal,
                              let newSolution = resolvedResult.solution else { break }

                        currentResult = resolvedResult
                        currentSolution = newSolution
                        roundsPerformed += 1

                        if cuttingShouldStop(
                            bound: resolvedResult.objectiveValue,
                            solution: newSolution.toArray(),
                            bounds: &boundHistory,
                            solutions: &solutionHistory
                        ) { break }

                    } catch { // logging: LP re-solve failed after cut — stop cutting rounds
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

        } catch { // logging: solver error — treat as infeasible branch
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
        cutStats: CutStatisticsTracker?,
        deadline: ContinuousClock.Instant?
    ) throws -> (BranchNode<V>, BranchNode<V>) {

        let components = solution.toArray()
        let dimension = components.count
        let value = components[variable]
        let floor = Foundation.floor(value)
        let ceil = Foundation.ceil(value)

        // Use parent's solution as starting point for both children
        // The InequalityOptimizer's ensureFeasibility will project it into the feasible region
        // This works better than trying to guess a good starting point ourselves
        let initialGuess = solution

        // The branch bound as a unit vector, which both children need.
        //
        // Both bounds are `.linearInequality` rather than closures, and that is the difference
        // between a correct search and one that discards its own subtrees. A closure sends the
        // relaxation solver back to central differences to recover coefficients it was handed,
        // at whatever point it was given — here `initialGuess`, the parent's *fractional*
        // vertex. Every node then solves a slightly different LP, and branching is precisely the
        // operation that makes a polytope thin enough for the difference to matter: on
        // `max 4x + 7y` subject to `7x+3y ≤ 19`, `8x+2y ≤ 27`, `3x+7y ≤ 21`, the child under
        // `y ≥ 3` has exactly one feasible point, and it was reported infeasible from the
        // parent's vertex and feasible from the origin. The search returned 18 where the
        // optimum is 21, with `status == .optimal`.
        var unit = Array(repeating: 0.0, count: dimension)
        unit[variable] = 1.0

        // Left branch: x_i ≤ floor
        let leftConstraints = parent.constraints + [
            .linearInequality(coefficients: unit, rhs: floor, sense: .lessOrEqual)
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
            cutStats: enableCuttingPlanes ? cutStats : nil,  // Generate cuts at all nodes
            deadline: deadline
        )

        // Right branch: x_i ≥ ceil
        let rightConstraints = parent.constraints + [
            .linearInequality(coefficients: unit, rhs: ceil, sense: .greaterOrEqual)
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
            cutStats: enableCuttingPlanes ? cutStats : nil,  // Generate cuts at all nodes
            deadline: deadline
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

            // Sorted, for the reason given on `mostFractionalVariable`: pseudo-cost scores tie
            // just as readily as fractionalities, and set order is a per-process coin flip.
            for variable in spec.allIntegerVariables.sorted() {
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

    /// Recompute the global bound from the open nodes.
    ///
    /// Takes the extremum over the whole queue rather than the bound of the node that is next
    /// in line — see ``NodeQueue/bestAvailableBound(minimize:)`` for why those differ under
    /// every selection strategy except best-bound, and for what it cost.
    private func updateBestBound(
        _ bestBound: inout Double,
        from queue: NodeQueue<V>,
        minimize: Bool,
        incumbent: (solution: V, value: Double)? = nil
    ) {
        if let openBound = queue.bestAvailableBound(minimize: minimize) {
            bestBound = openBound
        } else {
            // Nothing left to explore, so the incumbent is proven optimal and the
            // bound meets it.
            //
            // This is only true when the queue is empty *because the search finished*
            // — every node solved to integrality or pruned by bound. Call it while a
            // node is still unexplored and it manufactures a zero gap around whatever
            // has been found so far, which reads as proof and is not. Callers must
            // reach this only once the current node is genuinely disposed of.
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
        } catch { // logging: solver error treated as infeasible bound
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

        // Check constraint feasibility.
        //
        // `value > tolerance` is the test for an inequality g(x) ≤ 0. An equality
        // h(x) = 0 is violated in *either* direction, and rounding is exactly the
        // operation that breaks equalities: on `x + y = 4` the fractional point
        // (1.4, 2.4) rounds to (1, 2), where h = −1. Reading that as "no violation"
        // hands branch-and-bound an incumbent outside the feasible set, and because
        // an incumbent is what the solver ultimately returns, the answer is reported
        // as optimal. Measure |h(x)| for equalities and max(0, g(x)) for inequalities.
        for constraint in constraints {
            let value = constraint.evaluate(at: roundedSolution)
            let violation = constraint.isEquality ? abs(value) : value
            if violation > lpTolerance {
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
        // Sorted so the reported violations arrive in a stable order.
        for i in integerSpec.binaryVariables.sorted() {
            let value = arr[i]
            if value < -lpTolerance || value > 1.0 + lpTolerance {
                violations.append("Binary variable[\(i)] out of range [0,1]: \(value)")
            }
        }

        // Check 3: Constraint satisfaction
        //
        // For an inequality g(x) ≤ 0 the violation is max(0, g(x)); for an equality
        // h(x) = 0 it is |h(x)|. Using the inequality rule for both made this
        // verification blind to the one failure mode it exists to catch — a returned
        // solution that misses an equality on the low side.
        for (idx, constraint) in constraints.enumerated() {
            let value = constraint.evaluate(at: solution)
            let violation = constraint.isEquality ? abs(value) : value
            if violation > lpTolerance {
                violations.append("Constraint[\(idx)] violated: residual = \(value)")
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

    /// Check if one cut is dominated by another.
    ///
    /// For <= constraints, cut1 is dominated by cut2 if:
    /// - All coefficients of cut1 are >= corresponding coefficients of cut2
    /// - RHS of cut1 is >= RHS of cut2
    /// This means cut2 is at least as restrictive as cut1.
    ///
    /// - Parameters:
    ///   - cut1: The potentially dominated cut
    ///   - cut2: The potentially dominating cut
    ///   - tolerance: Numerical tolerance for comparisons
    /// - Returns: true if cut1 is dominated by cut2
    func isCutDominated(_ cut1: CuttingPlane, by cut2: CuttingPlane, tolerance: Double) -> Bool {
        guard cut1.coefficients.count == cut2.coefficients.count else {
            return false
        }

        // Check if cut2 dominates cut1
        // For <= constraints: if all a2[i] <= a1[i] and b2 <= b1, then cut2 dominates cut1
        var allCoeffsDominate = true
        for i in 0..<cut1.coefficients.count {
            if cut2.coefficients[i] > cut1.coefficients[i] + tolerance {
                allCoeffsDominate = false
                break
            }
        }

        return allCoeffsDominate && cut2.rhs <= cut1.rhs + tolerance
    }

    /// Check if two cuts are parallel (same coefficients, different RHS).
    ///
    /// - Parameters:
    ///   - cut1: First cut
    ///   - cut2: Second cut
    ///   - tolerance: Numerical tolerance for comparisons
    /// - Returns: true if cuts are parallel
    func areCutsParallel(_ cut1: CuttingPlane, _ cut2: CuttingPlane, tolerance: Double) -> Bool {
        guard cut1.coefficients.count == cut2.coefficients.count else {
            return false
        }

        // Compute norms to normalize for comparison
        let norm1 = sqrt(cut1.coefficients.reduce(0.0) { $0 + $1 * $1 })
        let norm2 = sqrt(cut2.coefficients.reduce(0.0) { $0 + $1 * $1 })

        guard norm1 > tolerance && norm2 > tolerance else {
            return false  // Degenerate cut
        }

        // Normalize coefficients
        let normalized1 = cut1.coefficients.map { $0 / norm1 }
        let normalized2 = cut2.coefficients.map { $0 / norm2 }

        // Check if normalized coefficients are equal
        for i in 0..<normalized1.count {
            if abs(normalized1[i] - normalized2[i]) > tolerance {
                return false
            }
        }

        return true
    }
}

// MARK: - Supporting Types

/// Tracks pseudo-costs for intelligent branching decisions
///
/// Maintains historical data about how branching on each variable affects bounds.
/// Used to predict which variables will lead to the best bound improvements.
// Justification: All mutable state (upCosts, downCosts) is protected by an NSLock; no unguarded access.
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
        let cost = boundImprovement / fractionalChange // fp-safety:disable — guarded > 1e-10 above

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

        let upAvg = upCosts[variable].map { $0.sum / Double($0.count) } ?? 0.0 // fp-safety:disable — count >= 1 when entry exists
        let downAvg = downCosts[variable].map { $0.sum / Double($0.count) } ?? 0.0 // fp-safety:disable — count >= 1 when entry exists

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
///
/// ## Two counters, measured at different moments
///
/// ``totalCutsGenerated`` counts **work attempted** and ``cuttingRounds`` counts **work
/// completed**, and they are deliberately not the same number. A cut is counted the moment
/// it joins the constraint set; a round is counted only once the LP has been re-solved and
/// come back optimal. Three exits sit between those points — the re-solve reports
/// infeasible, it reports a non-optimal status, or it throws — and each leaves cuts counted
/// with no round to show for them.
///
/// So `totalCutsGenerated > 0 && cuttingRounds == 0` is a *reachable* state and not a
/// contradiction: it says cuts were built and none of them survived a re-solve. Read it as
/// a diagnostic. On a feasible subproblem it should not happen, because a valid cut cannot
/// make a feasible LP infeasible while integer-feasible points remain — so seeing it there
/// means the cuts are wrong, which is exactly how the tableau-space defect fixed on
/// 2026-09-13 was found.
///
/// ``lpResolves`` and ``maxRoundsAtNode`` are derived from the same count as
/// ``cuttingRounds`` and share its meaning; a round *is* a successful re-solve.
public struct CuttingPlaneStats: Sendable {
    /// Total number of cuts generated across all nodes — **work attempted**.
    ///
    /// Incremented when a cut is added to the constraint set, before the LP is re-solved,
    /// so this counts cuts that were subsequently discarded. Compare ``cuttingRounds``.
    public let totalCutsGenerated: Int

    /// Total number of cutting plane rounds completed — **work that survived**.
    ///
    /// Incremented only after the LP re-solve returns an optimal solution, so a round that
    /// adds cuts and then fails to re-solve is not counted here. This is why it can be
    /// zero while ``totalCutsGenerated`` is positive; see the note on the type.
    public let cuttingRounds: Int

    /// Number of LP re-solves after adding cuts.
    ///
    /// Equal to ``cuttingRounds`` by construction — a completed round is a successful
    /// re-solve — and kept separate because they answer different questions of the reader.
    public let lpResolves: Int

    /// Maximum completed cutting rounds at any single node.
    ///
    /// Completed, on the same definition as ``cuttingRounds``.
    public let maxRoundsAtNode: Int

    /// Number of Gomory cuts generated
    public let gomoryCuts: Int

    /// Number of MIR cuts generated
    public let mirCuts: Int

    /// Number of cover cuts generated
    public let coverCuts: Int

    /// Number of cuts discarded by aging — **work undone**.
    ///
    /// Counts cuts removed from the LP because they reached ``BranchAndBoundSolver/cutAgingLimit``
    /// rounds of age, summed across every node. Zero when
    /// ``BranchAndBoundSolver/enableCutAging`` is false.
    ///
    /// This exists because aging previously had **no observable effect at all**. Removal
    /// does not move ``totalCutsGenerated``, which counts cuts generated rather than
    /// retained, and nothing else on this type reflected the size of the live constraint
    /// set — so working aging, broken aging and a deleted feature were indistinguishable
    /// from outside. A cut that is generated, counted, and then aged out now appears in
    /// both this and ``totalCutsGenerated``, which is why the two are not disjoint.
    public let cutsRemoved: Int

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
    ///   - cutsRemoved: Number of cuts discarded by aging (default: 0)
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
        cutsRemoved: Int = 0,
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
        self.cutsRemoved = cutsRemoved
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

    /// Maximum nodes to retain in the queue. Excess nodes with worst bounds are pruned.
    private let maxNodes: Int

    /// Default maximum node count
    static var defaultMaxNodes: Int { 100_000 } // LIVE: public API for external configuration of node queue limits

    init(strategy: NodeSelectionStrategy, minimize: Bool, maxNodes: Int = 100_000) {
        self.strategy = strategy
        self.minimize = minimize
        self.maxNodes = maxNodes
    }

    /// Insert node into queue - O(log n), with pruning if over capacity
    mutating func insert(_ node: BranchNode<V>) {
        heap.append(node)
        siftUp(from: heap.count - 1)

        // Prune worst nodes if over capacity to prevent unbounded memory growth
        if heap.count > maxNodes {
            pruneWorstNodes()
        }
    }

    /// Remove excess nodes with worst bounds
    private mutating func pruneWorstNodes() {
        // Sort by relaxation bound (keep better bounds)
        // For minimization: lower bound is better
        // For maximization: higher bound is better
        heap.sort { (node1: BranchNode<V>, node2: BranchNode<V>) -> Bool in
            if minimize {
                return node1.relaxationBound < node2.relaxationBound
            } else {
                return node1.relaxationBound > node2.relaxationBound
            }
        }
        // Keep only the best maxNodes/2 to amortize pruning cost
        let keepCount = maxNodes / 2
        if heap.count > keepCount {
            heap.removeLast(heap.count - keepCount)
        }
        // Rebuild heap after sorting/truncation
        buildHeap()
    }

    /// Rebuild heap from scratch - O(n)
    private mutating func buildHeap() {
        guard heap.count > 1 else { return }
        for i in stride(from: heap.count / 2 - 1, through: 0, by: -1) {
            siftDown(from: i)
        }
    }

    /// The best relaxation bound over **every** open node.
    ///
    /// The only valid global bound, and not the same thing as the bound of the node that
    /// happens to be next in line. ``peek()`` returns whatever the *selection strategy* would
    /// explore next: under ``NodeSelectionStrategy/bestBound`` that is the extremum and the two
    /// coincide, which is why reading the bound off `peek()` looked right. Under
    /// ``NodeSelectionStrategy/depthFirst`` it is the deepest node, whose bound is usually
    /// worse, and a "bound" worse than the true optimum is not a bound at all — it closes the
    /// relative gap around whatever incumbent is in hand and stops the search.
    ///
    /// Measured on `min 2x + 6y + 6z` subject to `x+8y+8z ≤ 49`, `3x+8y+3z ≥ 41` and
    /// `7x+8y+5z ≤ 49`: depth-first returned **36** at (0, 5, 1) with a reported gap of 5.2e-9,
    /// while (1, 5, 0) is feasible at **32**. Best-bound selection returned 32 on the same
    /// problem, and depth-first did too once the gap tolerance was tightened enough to stop it
    /// believing the bound.
    ///
    /// - Parameter minimize: Direction, which decides whether the extremum is a minimum.
    /// - Returns: The bound, or `nil` when no node is open.
    /// - Complexity: O(1) under best-bound selection, where the heap is already ordered by
    ///   bound; O(n) otherwise, where the heap is ordered by something else and the extremum has
    ///   to be looked for. Called once per explored node.
    func bestAvailableBound(minimize: Bool) -> Double? {
        guard let first = heap.first else { return nil }

        switch strategy {
        case .bestBound:
            return first.relaxationBound
        case .depthFirst, .breadthFirst, .bestEstimate:
            var best = first.relaxationBound
            for node in heap.dropFirst() {
                best = minimize
                    ? Swift.min(best, node.relaxationBound)
                    : Swift.max(best, node.relaxationBound)
            }
            return best
        }
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

        // Bounded by tree depth: parentIndex moves strictly downward toward leaf nodes
        while parentIndex < count {
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
// Justification: All mutable state (managedCuts) is protected by an NSLock; maxSize and maxAge are immutable.
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
    func addCut(_ cut: CuttingPlane) { // LIVE: cut pool management used by extended cutting plane strategies
        lock.lock()
        defer { lock.unlock() }

        managedCuts.append(ManagedCut(cut: cut))

        // Prune if pool is too large
        if managedCuts.count > maxSize {
            prunePool()
        }
    }

    /// Age all cuts and remove old inactive ones
    func ageCuts() { // LIVE: cut pool management used by extended cutting plane strategies
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
    func recordViolation(cutIndex: Int, violation: Double) { // LIVE: cut pool management used by extended cutting plane strategies
        lock.lock()
        defer { lock.unlock() }

        guard cutIndex < managedCuts.count else { return }

        managedCuts[cutIndex].activity = max(managedCuts[cutIndex].activity, violation)
        managedCuts[cutIndex].timesViolated += 1
        managedCuts[cutIndex].age = 0  // Reset age on activity
    }

    /// Get current cuts
    func getCuts() -> [CuttingPlane] { // LIVE: cut pool management used by extended cutting plane strategies
        lock.lock()
        defer { lock.unlock() }

        return managedCuts.map { $0.cut }
    }

    /// Prune pool to max size by removing least valuable cuts
    private func prunePool() {
        // Sort by value: prefer recently used (low age), highly active cuts
        managedCuts.sort { cut1, cut2 in
            let score1 = cut1.activity / Double(cut1.age + 1) // fp-safety:disable — age >= 0, so age + 1 >= 1
            let score2 = cut2.activity / Double(cut2.age + 1) // fp-safety:disable — age >= 0, so age + 1 >= 1
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
class CutStatisticsTracker {
    var totalCutsGenerated = 0
    var cuttingRounds = 0
    var lpResolves = 0
    var maxRoundsAtNode = 0
    var gomoryCuts = 0
    var mirCuts = 0
    var coverCuts = 0
    var cutsRemoved = 0
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
            cutsRemoved: cutsRemoved,
            rootLPBoundBeforeCuts: rootLPBoundBeforeCuts,
            rootLPBoundAfterCuts: rootLPBoundAfterCuts,
            percentageGapClosed: percentClosed
        )
    }

    /// Record cut generation at a node
    func recordCuts(generated: Int, rounds: Int, type: CutType) { // LIVE: statistics tracking used by extended cutting plane strategies
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
