import Foundation

// MARK: - Mixed-Integer Nonlinear Programming

extension BranchAndBoundSolver {

    /// Branch-and-bound over a nonlinear relaxation — mixed-integer nonlinear programming.
    ///
    /// This is a **name for a composition that already existed**, not a new algorithm.
    /// ``BranchAndBoundSolver`` has always taken its continuous relaxation as a
    /// parameter, and ``NonlinearRelaxationSolver`` has always been a conforming
    /// relaxation; putting the two together is MINLP. What was missing was a way to
    /// discover that from the API, so callers wrote off nonlinear integer problems as
    /// unsupported. `minlp()` is exactly:
    ///
    /// ```swift
    /// BranchAndBoundSolver<VectorN<Double>>(
    ///     relaxationSolver: NonlinearRelaxationSolver()
    /// )
    /// ```
    ///
    /// and nothing else. Every branch-and-bound parameter keeps the meaning and the
    /// default it has on ``BranchAndBoundSolver/init(maxNodes:timeLimit:relativeGapTolerance:nodeSelection:branchingRule:lpTolerance:integralityTolerance:validateLinearity:enableVariableShifting:enableCuttingPlanes:maxCuttingRounds:cutTolerance:normalizeCuts:cutCoefficientThreshold:detectStagnation:stagnationTolerance:detectCycling:cyclingWindowSize:enableMIRCuts:enableCoverCuts:liftCoverCuts:filterDominatedCuts:enableCutAging:cutAgingLimit:maxCutPoolSize:cutScalingNorm:enableWarmStart:relaxationSolver:elapsedTime:)``.
    ///
    /// ## When to use this instead of the default
    ///
    /// The default relaxation is ``SimplexRelaxationSolver``, and for a linear model it
    /// is the right one: it is faster, it is exact rather than iterative, and it hands
    /// back a simplex tableau that cutting planes can be generated from. Reach for
    /// `minlp()` only when the model is *actually* nonlinear:
    ///
    /// - A nonlinear objective — portfolio variance `wᵀΣw`, a quadratic cost curve,
    ///   an economic-order-quantity term in `1/q`.
    /// - A nonlinear constraint — a risk budget `σ(w) ≤ σₘₐₓ`, a geometric or
    ///   engineering feasibility region, a chance constraint.
    /// - Both, together with integrality: how many facilities to open, how many lots to
    ///   order, which assets to hold at all.
    ///
    /// If the model is linear, do not use this. The NLP relaxation is an interior-point
    /// method solved to a tolerance, so it is slower per node and its bounds are looser
    /// than the simplex bounds a linear model deserves.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Choose integer production lots minimising a quadratic cost,
    /// // inside a nonlinear capacity region: x² + y² ≤ 9.
    /// let solver = BranchAndBoundSolver<VectorN<Double>>.minlp(maxNodes: 500)
    ///
    /// let objective: @Sendable (VectorN<Double>) -> Double = { v in
    ///     let quadratic = v[0] * v[0] + v[1] * v[1]
    ///     let linear = 4.0 * v[0] + 4.0 * v[1]
    ///     return quadratic - linear
    /// }
    ///
    /// let constraints: [MultivariateConstraint<VectorN<Double>>] = [
    ///     .inequality(
    ///         function: { v in v[0] * v[0] + v[1] * v[1] - 9.0 },
    ///         gradient: nil
    ///     )
    /// ] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)
    ///
    /// let result = try solver.solve(
    ///     objective: objective,
    ///     from: VectorN<Double>([1.0, 1.0]),
    ///     subjectTo: constraints,
    ///     integerSpec: .allInteger(dimension: 2)
    /// )
    ///
    /// print(result.integerSolution)   // [2, 2]
    /// print(result.objectiveValue)    // ≈ -8.0
    /// ```
    ///
    /// - Note: The cut-generation parameters are accepted so that this factory stays a
    ///   faithful mirror of the initializer, but they have no effect here. Gomory, MIR
    ///   and cover cuts are all read off a simplex tableau, and an NLP relaxation does
    ///   not produce one — the cutting loop finds no tableau and stops. Leave
    ///   `enableCuttingPlanes` at `false` for nonlinear models.
    ///
    /// - Important: Leave `validateLinearity` at `false`. It exists to reject nonlinear
    ///   models with ``OptimizationError/nonlinearModel(message:)``, which is precisely the class
    ///   of model this entry point is for.
    ///
    /// - Note: Branch-and-bound and the NLP relaxation share the injected
    ///   `elapsedTime`, so a ``ManualElapsedTimeSource`` advances both and the whole
    ///   solve can be tested against modelled time.
    ///
    /// - Parameters:
    ///   - maxNodes: Maximum nodes to explore before terminating (default: 10,000)
    ///   - timeLimit: How long the search may run, or `nil` for no limit (default: 300 seconds).
    ///     `.zero` is a deadline already missed, not a request for unlimited time.
    ///   - relativeGapTolerance: Relative optimality gap to stop when `gap < tolerance` (default: 1e-4 = 0.01%)
    ///   - nodeSelection: Strategy for selecting next node (default: `.bestBound`)
    ///   - branchingRule: Strategy for selecting branching variable (default: `.mostFractional`)
    ///   - lpTolerance: Tolerance for the bound comparisons in pruning (default: 1e-8)
    ///   - integralityTolerance: Tolerance for integrality—values within this of an integer are rounded (default: 1e-6)
    ///   - validateLinearity: Whether to validate that objectives/constraints are linear (default: false — see Important above)
    ///   - enableVariableShifting: Automatically shift variables with negative bounds to satisfy x ≥ 0 (default: false)
    ///   - enableCuttingPlanes: Enable cutting planes (default: false — inert for NLP relaxations)
    ///   - maxCuttingRounds: Maximum cutting plane rounds per node (default: 5)
    ///   - cutTolerance: Minimum violation for a cut to be added (default: 1e-6)
    ///   - normalizeCuts: Normalize cut coefficients to unit norm for numerical stability (default: true)
    ///   - cutCoefficientThreshold: Minimum coefficient magnitude after normalization (default: 1e-8)
    ///   - detectStagnation: Terminate cutting if bound doesn't improve (default: true)
    ///   - stagnationTolerance: Minimum bound improvement to continue cutting (default: 1e-8)
    ///   - detectCycling: Detect repeated relaxation solutions and terminate early (default: true)
    ///   - cyclingWindowSize: Number of recent solutions to check for cycles (default: 5)
    ///   - enableMIRCuts: Enable Mixed-Integer Rounding cuts (default: false)
    ///   - enableCoverCuts: Enable cover cuts for knapsack constraints (default: false)
    ///   - liftCoverCuts: Lift cover cuts for stronger bounds (default: false)
    ///   - filterDominatedCuts: Filter dominated cuts before adding (default: true)
    ///   - enableCutAging: Enable aging mechanism to remove inactive cuts (default: true)
    ///   - cutAgingLimit: Iterations before removing inactive cuts (default: 5)
    ///   - maxCutPoolSize: Maximum total cuts across all nodes, 0 for unlimited (default: 1000)
    ///   - cutScalingNorm: Norm used for cut normalization (default: `.euclidean`)
    ///   - enableWarmStart: Reuse the previous relaxation solution as the next initial guess (default: true)
    ///   - nlpMaxIterations: Inner iterations allowed to the NLP relaxation at each node (default: 1000)
    ///   - nlpTolerance: Constraint-feasibility and stationarity tolerance for the NLP relaxation (default: 1e-6)
    ///   - elapsedTime: Where the time-limit check reads the clock, shared with the NLP
    ///     relaxation (default: the system's monotonic counter)
    ///
    /// - Returns: A branch-and-bound solver whose relaxation is a
    ///   ``NonlinearRelaxationSolver``.
    ///
    /// - SeeAlso:
    ///   - ``NonlinearRelaxationSolver``
    ///   - ``SimplexRelaxationSolver``
    ///   - ``RelaxationSolver``
    public static func minlp(
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
        nlpMaxIterations: Int = 1000,
        nlpTolerance: Double = 1e-6,
        elapsedTime: any ElapsedTimeSource = SystemElapsedTimeSource()
    ) -> BranchAndBoundSolver<V> {

        // The one substantive line in this file. Everything above it is a
        // pass-through, and the initializer below owns all validation — including the
        // tolerance-hierarchy preconditions, which must not be duplicated here where
        // they could drift out of step with the ones that actually run.
        let relaxation = NonlinearRelaxationSolver(
            maxIterations: nlpMaxIterations,
            tolerance: nlpTolerance,
            elapsedTime: elapsedTime
        )

        return BranchAndBoundSolver<V>(
            maxNodes: maxNodes,
            timeLimit: timeLimit,
            relativeGapTolerance: relativeGapTolerance,
            nodeSelection: nodeSelection,
            branchingRule: branchingRule,
            lpTolerance: lpTolerance,
            integralityTolerance: integralityTolerance,
            validateLinearity: validateLinearity,
            enableVariableShifting: enableVariableShifting,
            enableCuttingPlanes: enableCuttingPlanes,
            maxCuttingRounds: maxCuttingRounds,
            cutTolerance: cutTolerance,
            normalizeCuts: normalizeCuts,
            cutCoefficientThreshold: cutCoefficientThreshold,
            detectStagnation: detectStagnation,
            stagnationTolerance: stagnationTolerance,
            detectCycling: detectCycling,
            cyclingWindowSize: cyclingWindowSize,
            enableMIRCuts: enableMIRCuts,
            enableCoverCuts: enableCoverCuts,
            liftCoverCuts: liftCoverCuts,
            filterDominatedCuts: filterDominatedCuts,
            enableCutAging: enableCutAging,
            cutAgingLimit: cutAgingLimit,
            maxCutPoolSize: maxCutPoolSize,
            cutScalingNorm: cutScalingNorm,
            enableWarmStart: enableWarmStart,
            relaxationSolver: relaxation,
            elapsedTime: elapsedTime
        )
    }
}
