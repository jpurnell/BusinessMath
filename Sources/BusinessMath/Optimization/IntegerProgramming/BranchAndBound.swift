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

    public init(
        maxNodes: Int = 10_000,
        timeLimit: Double = 300.0,
        relativeGapTolerance: Double = 1e-4,
        nodeSelection: NodeSelectionStrategy = .bestBound,
        branchingRule: BranchingRule = .mostFractional,
        lpTolerance: Double = 1e-8
    ) {
        self.maxNodes = maxNodes
        self.timeLimit = timeLimit
        self.relativeGapTolerance = relativeGapTolerance
        self.nodeSelection = nodeSelection
        self.branchingRule = branchingRule
        self.lpTolerance = lpTolerance
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

        let startTime = Date()
        var queue = NodeQueue<V>(strategy: nodeSelection, minimize: minimize)
        var incumbent: (solution: V, value: Double)? = nil
        var bestBound = minimize ? -Double.infinity : Double.infinity
        var nodesExplored = 0

        // Step 1: Solve root LP relaxation
        let rootNode = try solveRelaxation(
            constraints: constraints,
            objective: objective,
            initialGuess: initialGuess,
            minimize: minimize,
            integerSpec: integerSpec,
            depth: 0
        )

        // Check if root is infeasible
        // if rootNode.relaxationSolution == nil {
        //     print("WARNING: Root LP relaxation is infeasible!")
        //     print("  Bound: \(rootNode.relaxationBound)")
        //     print("  Dimension: \(initialGuess.toArray().count)")
        // }

        queue.insert(rootNode)
        bestBound = rootNode.relaxationBound

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
                return IntegerOptimizationResult(
                    solution: incumbent?.solution ?? initialGuess,
                    objectiveValue: incumbent?.value ?? .infinity,
                    bestBound: bestBound,
                    relativeGap: gap,
                    nodesExplored: nodesExplored,
                    status: .nodeLimit,
                    solveTime: Date().timeIntervalSince(startTime),
                    integerSpec: integerSpec
                )
            }

            if Date().timeIntervalSince(startTime) > timeLimit {
                let gap = incumbent.map { abs($0.value - bestBound) / max(abs($0.value), 1.0) } ?? .infinity
                return IntegerOptimizationResult(
                    solution: incumbent?.solution ?? initialGuess,
                    objectiveValue: incumbent?.value ?? .infinity,
                    bestBound: bestBound,
                    relativeGap: gap,
                    nodesExplored: nodesExplored,
                    status: .timeLimit,
                    solveTime: Date().timeIntervalSince(startTime),
                    integerSpec: integerSpec
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

            if integerSpec.isIntegerFeasible(solution, tolerance: lpTolerance) {
                // Found integer solution - update incumbent
                let value = objective(solution)
                if incumbent == nil || (minimize ? value < incumbent!.value : value > incumbent!.value) {
                    incumbent = (solution, value)
                }
                updateBestBound(&bestBound, from: queue, minimize: minimize, incumbent: incumbent)

                // Check if we can terminate due to optimality gap
                if let inc = incumbent {
                    let gap = abs(inc.value - bestBound) / max(abs(inc.value), 1.0)
                    if gap < relativeGapTolerance {
                        return IntegerOptimizationResult(
                            solution: inc.solution,
                            objectiveValue: inc.value,
                            bestBound: bestBound,
                            relativeGap: gap,
                            nodesExplored: nodesExplored,
                            status: .optimal,
                            solveTime: Date().timeIntervalSince(startTime),
                            integerSpec: integerSpec
                        )
                    }
                }
                continue
            }

            // Step 5: Branch on fractional variable
            guard let branchVar = selectBranchingVariable(solution, integerSpec) else {
                updateBestBound(&bestBound, from: queue, minimize: minimize, incumbent: incumbent)
                continue
            }

            do {
                let (leftChild, rightChild) = try createBranches(
                    parent: node,
                    variable: branchVar,
                    solution: solution,
                    objective: objective,
                    constraints: constraints,
                    integerSpec: integerSpec,
                    minimize: minimize
                )

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
            return IntegerOptimizationResult(
                solution: initialGuess,
                objectiveValue: .infinity,
                bestBound: bestBound,
                relativeGap: .infinity,
                nodesExplored: nodesExplored,
                status: .infeasible,
                solveTime: Date().timeIntervalSince(startTime),
                integerSpec: integerSpec
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

        return IntegerOptimizationResult(
            solution: final.solution,
            objectiveValue: final.value,
            bestBound: bestBound,
            relativeGap: gap,
            nodesExplored: nodesExplored,
            status: status,
            solveTime: Date().timeIntervalSince(startTime),
            integerSpec: integerSpec
        )
    }

    // MARK: - Private Helper Methods

    /// Solve LP relaxation at a node using SimplexSolver
    ///
    /// Converts the multivariate constraints to linear form and solves using simplex.
    private func solveRelaxation(
        constraints: [MultivariateConstraint<V>],
        objective: @Sendable @escaping (V) -> Double,
        initialGuess: V,
        minimize: Bool,
        integerSpec: IntegerProgramSpecification,
        depth: Int,
        parent: UUID? = nil,
        branchedVariable: Int? = nil
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

        // SimplexSolver assumes x ≥ 0, so we don't need to add lower bounds explicitly

        // Extract linear objective coefficients using finite differences
        let objectiveCoeffs = try extractLinearCoefficients(objective, at: initialGuess, dimension: dimension)

        // Convert constraints to simplex form
        // Our constraints are g(x) ≤ 0 or h(x) = 0
        // For linear g(x) = c·x + d, we have g(x) ≤ 0  =>  c·x ≤ -d
        var simplexConstraints: [SimplexConstraint] = []
        for constraint in allConstraints {
            let coeffs = try extractLinearCoefficients(constraint.function, at: initialGuess, dimension: dimension)

            // Compute constant term: For g(x) = c·x + d, evaluate g at origin
            // d = g(0), but we need to find it from g(x) = c·x + d
            // So: d = g(x) - c·x
            let gx = constraint.evaluate(at: initialGuess)
            let cx = coeffs.enumerated().reduce(0.0) { $0 + $1.element * initialGuess.toArray()[$1.offset] }
            let constantTerm = gx - cx

            // For g(x) ≤ 0: c·x + d ≤ 0  =>  c·x ≤ -d
            var rhs = -constantTerm

            // Clean up numerical noise - round near-integers to integers
            let roundedRHS = round(rhs)
            if abs(rhs - roundedRHS) < lpTolerance * 10 {
                rhs = roundedRHS
            }

            // Also clean up values very close to zero
            if abs(rhs) < lpTolerance {
                rhs = 0.0
            }

            // Skip non-negativity constraints (SimplexSolver assumes x ≥ 0)
            // These are constraints like -x_i ≤ 0 (single negative coefficient with others zero)
            // BUT: Don't skip constraints that look like branching constraints (rhs != 0)
            let nonzeroIndices = coeffs.enumerated().filter { abs($0.element) > lpTolerance }.map { $0.offset }
            if nonzeroIndices.count == 1 {
                let idx = nonzeroIndices[0]
                if coeffs[idx] < 0 {  // Negative coefficient
                    // Only skip if RHS is exactly zero (non-negativity constraint)
                    // Don't skip if RHS != 0 (could be a branching constraint)
                    if abs(rhs) < lpTolerance {
                        if depth <= 2 && dimension <= 5 {
                            print("Skipping non-negativity constraint: -x[\(idx)] ≤ 0")
                        }
                        continue  // Skip this constraint
                    }
                }
            }

            let relation: ConstraintRelation
            if constraint.isEquality {
                relation = .equal
            } else {
                relation = .lessOrEqual
            }

            let simConstraint = SimplexConstraint(
                coefficients: coeffs,
                relation: relation,
                rhs: rhs
            )
            simplexConstraints.append(simConstraint)

            // Debug: print all single-variable constraints
            // if depth >= 1 && depth <= 2 && dimension <= 5 && nonzeroIndices.count == 1 {
            //     let idx = nonzeroIndices[0]
            //     print("Depth \(depth): Added constraint for x[\(idx)]: \(coeffs) \(relation) \(rhs)")
            // }
        }

        // Debug: print constraints for small problems at root or first few depths
        // if depth <= 2 && dimension <= 5 {
        //     print("=== LP Relaxation (depth=\(depth), dim=\(dimension)) ===")
        //     print("Objective: \(objectiveCoeffs)")
        //     print("Constraints (\(simplexConstraints.count)):")
        //     for (i, c) in simplexConstraints.enumerated() {
        //         print("  [\(i)]: \(c.coefficients) \(c.relation) \(c.rhs)")
        //     }
        // }

        // Solve with simplex
        let solver = SimplexSolver(tolerance: lpTolerance)

        do {
            let result = minimize
                ? try solver.minimize(objective: objectiveCoeffs, subjectTo: simplexConstraints)
                : try solver.maximize(objective: objectiveCoeffs, subjectTo: simplexConstraints)

            // Debug: print result status
            // if depth == 0 && dimension <= 5 {
            //     print("SimplexSolver result: status=\(result.status), obj=\(result.objectiveValue), sol=\(result.solution)")
            // }

            // Check if solution is valid
            guard result.status == .optimal else {
                // Infeasible or unbounded
                return BranchNode(
                    depth: depth,
                    parent: parent,
                    constraints: constraints,
                    relaxationBound: result.status == .unbounded
                        ? (minimize ? -Double.infinity : Double.infinity)
                        : (minimize ? Double.infinity : -Double.infinity),
                    relaxationSolution: nil,
                    branchedVariable: branchedVariable
                )
            }

            // Convert solution back to VectorSpace type
            let solution = V.fromArray(result.solution) ?? initialGuess

            return BranchNode(
                depth: depth,
                parent: parent,
                constraints: constraints,
                relaxationBound: result.objectiveValue,
                relaxationSolution: solution,
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

    /// Extract linear coefficients from a function using finite differences
    ///
    /// For a linear function f(x) = c₁x₁ + c₂x₂ + ... + cₙxₙ + b,
    /// this computes the gradient which gives the coefficients [c₁, c₂, ..., cₙ]
    private func extractLinearCoefficients(
        _ function: @escaping (V) -> V.Scalar,
        at point: V,
        dimension: Int
    ) throws -> [Double] {
        var coeffs: [Double] = []
        let h = V.Scalar(1e-8)

        for i in 0..<dimension {
            var pointPlus = point.toArray()
            pointPlus[i] += Double(h)
            let vecPlus = V.fromArray(pointPlus) ?? point

            let derivative = (function(vecPlus) - function(point)) / h
            var coeff = Double(derivative)

            // Clean up numerical noise - round near-integers to integers
            let rounded = round(coeff)
            if abs(coeff - rounded) < lpTolerance * 10 {
                coeff = rounded
            }

            coeffs.append(coeff)
        }

        return coeffs
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
        minimize: Bool
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
            branchedVariable: variable
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
            branchedVariable: variable
        )

        return (leftNode, rightNode)
    }

    /// Select variable to branch on based on branching rule
    private func selectBranchingVariable(
        _ solution: V,
        _ spec: IntegerProgramSpecification
    ) -> Int? {
        switch branchingRule {
        case .mostFractional:
            return spec.mostFractionalVariable(solution)
        case .pseudoCost:
            // Use historical cost estimates (fallback to most fractional for now)
            return spec.mostFractionalVariable(solution)
        case .strongBranching:
            // Try multiple candidates, pick best (fallback to most fractional for now)
            return spec.mostFractionalVariable(solution)
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
}

// MARK: - Supporting Types

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

/// Priority queue for node selection in branch-and-bound
struct NodeQueue<V: VectorSpace>: Sendable where V.Scalar == Double {
    private var nodes: [BranchNode<V>] = []
    private let strategy: NodeSelectionStrategy
    private let minimize: Bool

    init(strategy: NodeSelectionStrategy, minimize: Bool) {
        self.strategy = strategy
        self.minimize = minimize
    }

    mutating func insert(_ node: BranchNode<V>) {
        nodes.append(node)
        // Keep sorted by strategy
        sortNodes()
    }

    mutating func extractBest() -> BranchNode<V>? {
        guard !nodes.isEmpty else { return nil }
        return nodes.removeFirst()
    }

    func peek() -> BranchNode<V>? {
        return nodes.first
    }

    var isEmpty: Bool {
        nodes.isEmpty
    }

    var count: Int {
        nodes.count
    }

    private mutating func sortNodes() {
        switch strategy {
        case .depthFirst:
            // Sort by depth (descending) - explore deepest first
            nodes.sort { $0.depth > $1.depth }

        case .breadthFirst:
            // Sort by depth (ascending) - explore shallowest first
            nodes.sort { $0.depth < $1.depth }

        case .bestBound:
            // Sort by bound - best bound first
            if minimize {
                nodes.sort { $0.relaxationBound < $1.relaxationBound }
            } else {
                nodes.sort { $0.relaxationBound > $1.relaxationBound }
            }

        case .bestEstimate:
            // Hybrid: use bound for now (could incorporate depth or other heuristics)
            if minimize {
                nodes.sort { $0.relaxationBound < $1.relaxationBound }
            } else {
                nodes.sort { $0.relaxationBound > $1.relaxationBound }
            }
        }
    }
}
