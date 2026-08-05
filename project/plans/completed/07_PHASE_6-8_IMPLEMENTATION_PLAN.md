# BusinessMath Phases 6-8: Detailed Implementation Plan

**Document Version:** 1.0
**Created:** 2025-12-10
**Status:** Planning Complete, Ready for Implementation

---

## Overview

This document provides comprehensive implementation plans for Phases 6-8 of the BusinessMath optimization framework. Each phase is broken down into sub-phases with detailed tasks, file structures, implementation strategies, and testing requirements.

**Architecture Context:**
- All optimizers are generic over `VectorSpace` protocol
- Constraint system uses `MultivariateConstraint<V>` enum
- Mixed-integer solutions store as `VectorN<Double>` with integer index tracking
- Existing Monte Carlo infrastructure ready for scenario generation
- Current test suite: 2,757 tests in 219 suites, all passing

---

## Phase 6: Advanced Solvers and Uncertainty Quantification

**Goal:** Add discrete optimization (integer/binary variables), heuristic solvers for nonsmooth functions, and enhanced stochastic programming with recourse.

**Split into 3 Sub-Phases:**
- Phase 6.1: Integer Programming (IP)
- Phase 6.2: Heuristic/Evolutionary Solvers
- Phase 6.3: Stochastic Programming Enhancements

---

### Phase 6.1: Integer Programming Solver

**Estimated Time:** 3-4 weeks
**Priority:** CRITICAL - Unlocks capital budgeting, project selection, facility location, production with setup costs

#### Core Components

##### 1. Integer Variable Specification

**File:** `Sources/BusinessMath/Optimization/IntegerProgramming/IntegerSpecification.swift`

```swift
/// Specifies which variables must be integer or binary
public struct IntegerProgramSpecification {
    /// Variables that must take integer values
    public let integerVariables: Set<Int>

    /// Variables that must be binary (0 or 1)
    public let binaryVariables: Set<Int>

    /// Special Ordered Sets Type 1 (at most one variable is nonzero)
    public let sosType1: [[Int]]

    /// Special Ordered Sets Type 2 (at most two adjacent variables are nonzero)
    public let sosType2: [[Int]]

    public init(
        integerVariables: Set<Int> = [],
        binaryVariables: Set<Int> = [],
        sosType1: [[Int]] = [],
        sosType2: [[Int]] = []
    )

    /// Check if a solution satisfies integer requirements
    public func isIntegerFeasible<V: VectorSpace>(
        _ solution: V,
        tolerance: V.Scalar = 1e-6
    ) -> Bool where V.Scalar == Double

    /// Round solution to nearest integer values
    public func rounded<V: VectorSpace>(_ solution: V) -> V where V.Scalar == Double

    /// Get most fractional variable index (for branching)
    public func mostFractionalVariable<V: VectorSpace>(_ solution: V) -> Int?
        where V.Scalar == Double
}
```

**Implementation Notes:**
- Store as `Set<Int>` for O(1) membership checking
- `mostFractionalVariable`: Returns index i where |xᵢ - round(xᵢ)| is maximum
- `isIntegerFeasible`: Check ∀i ∈ integerVars: |xᵢ - round(xᵢ)| < tolerance
- SOS constraints checked separately during branching

**Tests Required:**
- ✅ Rounding preserves non-integer variables
- ✅ Fractional variable selection (0.1 vs 0.9 vs 0.5)
- ✅ Binary vs general integer distinction
- ✅ SOS constraint validation

---

##### 2. Branch and Bound Solver

**File:** `Sources/BusinessMath/Optimization/IntegerProgramming/BranchAndBound.swift`

```swift
/// Branch and Bound solver for Mixed-Integer Linear/Nonlinear Programs
public struct BranchAndBoundSolver<V: VectorSpace> where V.Scalar == Double {

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

    public init(
        maxNodes: Int = 10_000,
        timeLimit: Double = 300.0,
        relativeGapTolerance: Double = 1e-4,
        nodeSelection: NodeSelectionStrategy = .bestBound,
        branchingRule: BranchingRule = .mostFractional
    )

    /// Solve mixed-integer program
    public func solve(
        objective: @escaping (V) -> Double,
        from initialGuess: V,
        subjectTo constraints: [MultivariateConstraint<V>],
        integerSpec: IntegerProgramSpecification,
        minimize: Bool = true
    ) throws -> IntegerOptimizationResult<V>
}

/// Node selection strategy for branch-and-bound tree
public enum NodeSelectionStrategy {
    case depthFirst       // DFS - fast for finding feasible solutions
    case breadthFirst     // BFS - explores tree uniformly
    case bestBound        // Best-first - exploits bounds for optimality
    case bestEstimate     // Hybrid - estimates subtree quality
}

/// Branching rule for selecting variable to branch on
public enum BranchingRule {
    case mostFractional   // Branch on variable furthest from integer
    case pseudoCost       // Use historical improvement estimates
    case strongBranching  // Try both branches, pick best (expensive)
}

/// Result from integer programming optimization
public struct IntegerOptimizationResult<V: VectorSpace> where V.Scalar == Double {
    /// Best integer-feasible solution found
    public let solution: V

    /// Objective value at solution
    public let objectiveValue: Double

    /// Best lower bound (for minimization) from relaxations
    public let bestBound: Double

    /// Optimality gap: (objectiveValue - bestBound) / objectiveValue
    public let relativeGap: Double

    /// Total nodes explored in branch-and-bound tree
    public let nodesExplored: Int

    /// Solution status
    public let status: IntegerSolutionStatus

    /// Total solve time
    public let solveTime: Double

    /// Integer specification used
    public let integerSpec: IntegerProgramSpecification
}

public enum IntegerSolutionStatus {
    case optimal          // Proved optimal within tolerance
    case feasible         // Found integer solution, but not proved optimal
    case infeasible       // No integer-feasible solution exists
    case nodeLimit        // Hit maximum nodes
    case timeLimit        // Hit time limit
}
```

**Implementation Strategy:**

1. **Data Structures**:
```swift
/// Internal node in branch-and-bound tree
struct BranchNode<V: VectorSpace> where V.Scalar == Double {
    let depth: Int
    let parent: UUID?
    let constraints: [MultivariateConstraint<V>]  // Accumulated from branching
    let relaxationBound: Double
    let relaxationSolution: V?
    let branchedVariable: Int?
}

/// Priority queue for node selection
struct NodeQueue<V: VectorSpace> where V.Scalar == Double {
    private var heap: [BranchNode<V>]
    private let strategy: NodeSelectionStrategy

    mutating func insert(_ node: BranchNode<V>)
    mutating func extractBest() -> BranchNode<V>?
    var isEmpty: Bool { heap.isEmpty }
}
```

2. **Core Algorithm**:
```swift
func solve(...) throws -> IntegerOptimizationResult<V> {
    let startTime = Date()
    var queue = NodeQueue<V>(strategy: nodeSelection)
    var incumbent: (solution: V, value: Double)? = nil
    var bestBound = minimize ? -.infinity : .infinity
    var nodesExplored = 0

    // Step 1: Solve root LP relaxation
    let rootNode = try solveRelaxation(
        constraints: constraints,
        objective: objective,
        initialGuess: initialGuess
    )
    queue.insert(rootNode)
    bestBound = rootNode.relaxationBound

    // Step 2: Branch and bound loop
    while let node = queue.extractBest() {
        nodesExplored += 1

        // Check termination conditions
        if nodesExplored >= maxNodes {
            return IntegerOptimizationResult(..., status: .nodeLimit)
        }
        if Date().timeIntervalSince(startTime) > timeLimit {
            return IntegerOptimizationResult(..., status: .timeLimit)
        }

        // Step 3: Pruning tests
        if shouldPrune(node, incumbent: incumbent, bestBound: bestBound) {
            continue
        }

        // Step 4: Check integer feasibility
        guard let solution = node.relaxationSolution else { continue }

        if integerSpec.isIntegerFeasible(solution) {
            // Found integer solution - update incumbent
            let value = objective(solution)
            if incumbent == nil || (minimize ? value < incumbent!.value : value > incumbent!.value) {
                incumbent = (solution, value)
            }
            updateBestBound(&bestBound, from: queue, minimize: minimize)
            continue
        }

        // Step 5: Branch on fractional variable
        guard let branchVar = selectBranchingVariable(solution, integerSpec) else {
            continue
        }

        let (leftChild, rightChild) = try createBranches(
            parent: node,
            variable: branchVar,
            solution: solution,
            objective: objective
        )

        queue.insert(leftChild)
        queue.insert(rightChild)
        updateBestBound(&bestBound, from: queue, minimize: minimize)
    }

    // Step 6: Return result
    guard let final = incumbent else {
        return IntegerOptimizationResult(..., status: .infeasible)
    }

    let gap = abs(final.value - bestBound) / abs(final.value)
    let status: IntegerSolutionStatus = gap < relativeGapTolerance ? .optimal : .feasible

    return IntegerOptimizationResult(
        solution: final.solution,
        objectiveValue: final.value,
        bestBound: bestBound,
        relativeGap: gap,
        nodesExplored: nodesExplored,
        status: status,
        solveTime: Date().timeIntervalSince(startTime)
    )
}
```

3. **Key Helper Functions**:
```swift
/// Solve LP relaxation at a node using InequalityOptimizer
private func solveRelaxation(
    constraints: [MultivariateConstraint<V>],
    objective: @escaping (V) -> Double,
    initialGuess: V
) throws -> BranchNode<V> {
    let optimizer = InequalityOptimizer<V>()
    let result = try optimizer.minimize(
        objective,
        from: initialGuess,
        subjectTo: constraints
    )

    return BranchNode(
        depth: 0,
        parent: nil,
        constraints: constraints,
        relaxationBound: result.objectiveValue,
        relaxationSolution: result.solution,
        branchedVariable: nil
    )
}

/// Check if node should be pruned
private func shouldPrune(
    _ node: BranchNode<V>,
    incumbent: (solution: V, value: Double)?,
    bestBound: Double
) -> Bool {
    // Prune by infeasibility
    guard node.relaxationSolution != nil else { return true }

    // Prune by bound
    if let inc = incumbent {
        if minimize && node.relaxationBound >= inc.value { return true }
        if !minimize && node.relaxationBound <= inc.value { return true }
    }

    return false
}

/// Create left and right child nodes by branching
private func createBranches(
    parent: BranchNode<V>,
    variable: Int,
    solution: V,
    objective: @escaping (V) -> Double
) throws -> (BranchNode<V>, BranchNode<V>) {
    let value = solution.toArray()[variable]
    let floor = Swift.floor(value)
    let ceil = Swift.ceil(value)

    // Left branch: xᵢ ≤ floor
    let leftConstraints = parent.constraints + [
        .inequality { v in v.toArray()[variable] - floor }
    ]
    let leftNode = try solveRelaxation(
        constraints: leftConstraints,
        objective: objective,
        initialGuess: solution
    )

    // Right branch: xᵢ ≥ ceil
    let rightConstraints = parent.constraints + [
        .inequality { v in ceil - v.toArray()[variable] }
    ]
    let rightNode = try solveRelaxation(
        constraints: rightConstraints,
        objective: objective,
        initialGuess: solution
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
        // Use historical cost estimates (implement if time permits)
        return spec.mostFractionalVariable(solution)

    case .strongBranching:
        // Try multiple candidates, pick best (expensive, implement later)
        return spec.mostFractionalVariable(solution)
    }
}
```

**Implementation Notes:**
- Start with `.bestBound` node selection (best-first search)
- Use `.mostFractional` branching (simplest, effective)
- Store constraints in array (grows by 1 per branch level)
- Use `InequalityOptimizer` for LP relaxations
- Track best bound by taking min/max over all active nodes

**Estimated LOC:** 600-800 lines

**Tests Required (15-20 tests):**
1. **Knapsack Problems**:
   - ✅ Simple knapsack (5 items)
   - ✅ 0-1 knapsack with optimal solution known
   - ✅ Unbounded knapsack

2. **Binary Variable Problems**:
   - ✅ Binary portfolio selection (choose 5 of 10 assets)
   - ✅ Facility location (open 3 of 5 facilities)
   - ✅ Set covering problem

3. **Mixed-Integer Problems**:
   - ✅ Production planning with setup costs (binary + continuous)
   - ✅ Lot sizing problem

4. **Edge Cases**:
   - ✅ All variables already integer at root (no branching needed)
   - ✅ Infeasible integer program
   - ✅ Unbounded relaxation
   - ✅ Node limit reached
   - ✅ Time limit reached

5. **Performance**:
   - ✅ 10-variable problem solves in < 1 second
   - ✅ 20-variable problem solves in < 10 seconds
   - ✅ Optimality gap correctly calculated

---

##### 3. Constraint Extensions for Integer Programs

**File:** `Sources/BusinessMath/Optimization/Constraint.swift` (extension)

```swift
extension MultivariateConstraint where V == VectorN<Double> {

    /// Variable bounds: lower ≤ xᵢ ≤ upper
    public static func variableBounds(
        index: Int,
        lower: Double = 0.0,
        upper: Double = 1.0
    ) -> [MultivariateConstraint<V>] {
        return [
            .inequality { v in lower - v.toArray()[index] },  // xᵢ ≥ lower
            .inequality { v in v.toArray()[index] - upper }   // xᵢ ≤ upper
        ]
    }

    /// Linear constraint: aᵀx ≤ b
    public static func linearInequality(
        coefficients: [Double],
        rhs: Double
    ) -> MultivariateConstraint<V> {
        .inequality { v in
            let x = v.toArray()
            let lhs = zip(coefficients, x).map(*).reduce(0, +)
            return lhs - rhs
        }
    }

    /// Linear equality: aᵀx = b
    public static func linearEquality(
        coefficients: [Double],
        rhs: Double
    ) -> MultivariateConstraint<V> {
        .equality { v in
            let x = v.toArray()
            let lhs = zip(coefficients, x).map(*).reduce(0, +)
            return lhs - rhs
        }
    }

    /// Cardinality constraint: exactly k variables must be nonzero
    public static func cardinality(
        indices: [Int],
        k: Int
    ) -> MultivariateConstraint<V> {
        .equality { v in
            let x = v.toArray()
            let count = indices.filter { abs(x[$0]) > 1e-8 }.count
            return Double(count) - Double(k)
        }
    }
}
```

**Tests Required:**
- ✅ Variable bounds correctly enforced
- ✅ Linear constraints with negative coefficients
- ✅ Cardinality constraint for portfolio (max 5 assets)

---

##### 4. Business Applications Using Integer Programming

**File:** `Sources/BusinessMath/BusinessOptimization/CapitalBudgeting.swift`

```swift
/// Project selection problem with binary variables
public struct CapitalBudgetingProblem {

    public struct Project {
        public let id: String
        public let npv: Double           // Net present value
        public let capitalRequired: Double
        public let ongoingCost: Double   // Annual operating cost
        public let dependencies: [String] // Required predecessor projects
        public let mutuallyExclusive: [String]?  // Can't select both
    }

    public let projects: [Project]
    public let capitalBudget: Double
    public let annualBudget: Double?
    public let minProjects: Int?
    public let maxProjects: Int?

    /// Solve using branch and bound
    public func solve() throws -> CapitalBudgetingSolution
}

public struct CapitalBudgetingSolution {
    public let selectedProjects: [String]
    public let totalNPV: Double
    public let capitalUsed: Double
    public let annualCostUsed: Double
    public let optimizationResult: IntegerOptimizationResult<VectorN<Double>>
}
```

**Implementation:**
- Binary variable xᵢ = 1 if project i selected
- Maximize: Σ NPVᵢ · xᵢ
- Subject to: Σ Capitalᵢ · xᵢ ≤ Budget
- Dependencies: xⱼ ≥ xᵢ if j depends on i
- Mutual exclusivity: xᵢ + xⱼ ≤ 1

**Tests Required:**
- ✅ Simple project selection (5 projects, budget constraint)
- ✅ Dependencies enforced correctly
- ✅ Mutual exclusivity enforced
- ✅ Min/max project constraints

---

#### Phase 6.1 Summary

**Files to Create:**
1. `IntegerSpecification.swift` (~150 lines)
2. `BranchAndBound.swift` (~700 lines)
3. `CapitalBudgeting.swift` (~200 lines)
4. Constraint extensions (~100 lines)

**Total:** ~1,150 lines source code

**Tests to Create:**
- `IntegerSpecificationTests.swift` (~200 lines, 5 tests)
- `BranchAndBoundTests.swift` (~600 lines, 15 tests)
- `CapitalBudgetingTests.swift` (~300 lines, 6 tests)

**Total:** ~1,100 lines test code, 26 tests

**Success Criteria:**
- ✅ Knapsack problem with 10 items solves optimally in < 1 second
- ✅ Binary portfolio selection (choose 5 of 15 stocks) solves correctly
- ✅ Capital budgeting with dependencies produces feasible selections
- ✅ All 26 tests pass
- ✅ No compiler warnings

---

### Phase 6.2: Heuristic/Evolutionary Solvers

**Estimated Time:** 2-3 weeks
**Priority:** HIGH - Handles nonsmooth, non-convex, discontinuous functions that gradients can't solve

#### Core Components

##### 1. Heuristic Optimizer Base

**File:** `Sources/BusinessMath/Optimization/Heuristic/HeuristicOptimizer.swift`

```swift
/// Heuristic optimization for nonsmooth, non-convex problems
public struct HeuristicOptimizer<V: VectorSpace> where V.Scalar: Real {

    public let algorithm: HeuristicAlgorithm
    public let populationSize: Int
    public let maxGenerations: Int
    public let convergenceTolerance: V.Scalar
    public let seed: UInt64?

    public init(
        algorithm: HeuristicAlgorithm = .geneticAlgorithm(),
        populationSize: Int = 100,
        maxGenerations: Int = 1000,
        convergenceTolerance: V.Scalar = 1e-6,
        seed: UInt64? = nil
    )

    public func optimize(
        _ objective: @escaping (V) -> V.Scalar,
        searchSpace: [(lower: V.Scalar, upper: V.Scalar)],
        constraints: [MultivariateConstraint<V>] = [],
        minimize: Bool = true
    ) throws -> HeuristicOptimizationResult<V>
}

public enum HeuristicAlgorithm {
    case geneticAlgorithm(
        crossoverRate: Double = 0.8,
        mutationRate: Double = 0.1,
        selection: SelectionMethod = .tournament(size: 3)
    )
    case particleSwarm(
        inertia: Double = 0.7,
        cognitive: Double = 1.5,
        social: Double = 1.5
    )
    case differentialEvolution(
        scalingFactor: Double = 0.8,
        crossoverRate: Double = 0.9
    )
    case simulatedAnnealing(
        initialTemperature: Double = 100.0,
        coolingRate: Double = 0.95,
        neighborsPerTemp: Int = 100
    )
}

public enum SelectionMethod {
    case tournament(size: Int)
    case rouletteWheel
    case rank
    case elitist(keepBest: Int)
}

public struct HeuristicOptimizationResult<V: VectorSpace> where V.Scalar: Real {
    public let solution: V
    public let objectiveValue: V.Scalar
    public let generations: Int
    public let evaluations: Int
    public let converged: Bool
    public let convergenceHistory: [V.Scalar]  // Best value per generation
    public let diversityHistory: [V.Scalar]    // Population diversity metric
}
```

**Implementation Notes:**
- Population stored as `[V]` (works for any VectorSpace)
- Fitness = objective value (minimize: lower is better)
- Constraint handling via death penalty or adaptive penalty

---

##### 2. Genetic Algorithm Implementation

**File:** `Sources/BusinessMath/Optimization/Heuristic/GeneticAlgorithm.swift`

```swift
/// Genetic Algorithm implementation
struct GeneticAlgorithmEngine<V: VectorSpace> where V.Scalar: Real {
    let crossoverRate: V.Scalar
    let mutationRate: V.Scalar
    let selection: SelectionMethod

    /// Initialize random population within search space
    func initializePopulation(
        size: Int,
        searchSpace: [(lower: V.Scalar, upper: V.Scalar)],
        seed: UInt64?
    ) -> [V] {
        var rng = seed.map { SeededRandomNumberGenerator(seed: $0) } ??
                  SeededRandomNumberGenerator(seed: UInt64.random(in: 0...UInt64.max))

        return (0..<size).map { _ in
            let values = searchSpace.map { bounds in
                V.Scalar.random(in: bounds.lower...bounds.upper, using: &rng)
            }
            return V.fromArray(values)!
        }
    }

    /// Evaluate fitness for population
    func evaluateFitness(
        population: [V],
        objective: (V) -> V.Scalar,
        constraints: [MultivariateConstraint<V>],
        minimize: Bool
    ) -> [(individual: V, fitness: V.Scalar)] {
        return population.map { individual in
            var fitness = objective(individual)

            // Penalty for constraint violations
            let penalty = constraints.reduce(V.Scalar.zero) { total, constraint in
                let violation = max(V.Scalar.zero, constraint.evaluate(at: individual))
                return total + 1000 * violation * violation  // Quadratic penalty
            }

            fitness = minimize ? fitness + penalty : fitness - penalty
            return (individual, fitness)
        }
    }

    /// Select parents using tournament selection
    func selectParents(
        population: [(individual: V, fitness: V.Scalar)],
        count: Int,
        minimize: Bool
    ) -> [V] {
        switch selection {
        case .tournament(let size):
            return (0..<count).map { _ in
                let tournament = (0..<size).map { _ in population.randomElement()! }
                let winner = tournament.min { a, b in
                    minimize ? a.fitness < b.fitness : a.fitness > b.fitness
                }!
                return winner.individual
            }

        case .rouletteWheel:
            // Fitness-proportionate selection
            let total = population.map(\.fitness).reduce(0, +)
            return (0..<count).map { _ in
                let target = V.Scalar.random(in: 0...total)
                var cumulative = V.Scalar.zero
                for (individual, fitness) in population {
                    cumulative += fitness
                    if cumulative >= target { return individual }
                }
                return population.last!.individual
            }

        case .rank:
            // Rank-based selection
            let sorted = population.sorted { a, b in
                minimize ? a.fitness < b.fitness : a.fitness > b.fitness
            }
            let ranks = (1...sorted.count).map { V.Scalar($0) }
            let totalRank = ranks.reduce(0, +)

            return (0..<count).map { _ in
                let target = V.Scalar.random(in: 0...totalRank)
                var cumulative = V.Scalar.zero
                for (rank, (individual, _)) in zip(ranks, sorted) {
                    cumulative += rank
                    if cumulative >= target { return individual }
                }
                return sorted.last!.individual
            }

        case .elitist(let keepBest):
            // Keep best, random for rest
            let sorted = population.sorted { a, b in
                minimize ? a.fitness < b.fitness : a.fitness > b.fitness
            }
            let elite = sorted.prefix(keepBest).map(\.individual)
            let random = (0..<(count - keepBest)).map { _ in population.randomElement()!.individual }
            return elite + random
        }
    }

    /// Crossover two parents to create offspring
    func crossover(parent1: V, parent2: V, searchSpace: [(lower: V.Scalar, upper: V.Scalar)]) -> (V, V) {
        guard V.Scalar.random(in: 0...1) < crossoverRate else {
            return (parent1, parent2)  // No crossover
        }

        let p1 = parent1.toArray()
        let p2 = parent2.toArray()

        // Uniform crossover
        var child1 = p1
        var child2 = p2

        for i in 0..<p1.count {
            if Bool.random() {
                swap(&child1[i], &child2[i])
            }
        }

        // Blend crossover (BLX-α) for continuous variables
        let alpha = V.Scalar(0.5)
        for i in 0..<p1.count {
            let minVal = min(p1[i], p2[i])
            let maxVal = max(p1[i], p2[i])
            let range = maxVal - minVal
            let lower = max(searchSpace[i].lower, minVal - alpha * range)
            let upper = min(searchSpace[i].upper, maxVal + alpha * range)

            child1[i] = V.Scalar.random(in: lower...upper)
            child2[i] = V.Scalar.random(in: lower...upper)
        }

        return (V.fromArray(child1)!, V.fromArray(child2)!)
    }

    /// Mutate individual
    func mutate(_ individual: V, searchSpace: [(lower: V.Scalar, upper: V.Scalar)]) -> V {
        var genes = individual.toArray()

        for i in 0..<genes.count {
            if V.Scalar.random(in: 0...1) < mutationRate {
                // Gaussian mutation
                let range = searchSpace[i].upper - searchSpace[i].lower
                let sigma = range * V.Scalar(0.1)  // 10% of range
                let normal = V.Scalar.random(in: -1...1)  // Approximate normal
                genes[i] += sigma * normal
                genes[i] = max(searchSpace[i].lower, min(searchSpace[i].upper, genes[i]))
            }
        }

        return V.fromArray(genes)!
    }

    /// Run one generation
    func evolve(
        population: [(individual: V, fitness: V.Scalar)],
        objective: (V) -> V.Scalar,
        constraints: [MultivariateConstraint<V>],
        searchSpace: [(lower: V.Scalar, upper: V.Scalar)],
        minimize: Bool
    ) -> [V] {
        let populationSize = population.count

        // Elitism: keep best individual
        let elite = population.min { a, b in
            minimize ? a.fitness < b.fitness : a.fitness > b.fitness
        }!.individual

        // Select parents
        let parents = selectParents(population: population, count: populationSize, minimize: minimize)

        // Create offspring through crossover and mutation
        var offspring: [V] = [elite]  // Start with elite

        for i in stride(from: 0, to: populationSize - 1, by: 2) {
            let (child1, child2) = crossover(
                parent1: parents[i],
                parent2: parents[min(i + 1, parents.count - 1)],
                searchSpace: searchSpace
            )
            offspring.append(mutate(child1, searchSpace: searchSpace))
            if offspring.count < populationSize {
                offspring.append(mutate(child2, searchSpace: searchSpace))
            }
        }

        return offspring
    }
}
```

**Implementation Notes:**
- Use tournament selection (simple, effective)
- Blend crossover (BLX-α) for continuous variables
- Gaussian mutation with adaptive step size
- Elitism preserves best solution
- Penalty method for constraints

**Estimated LOC:** 400-500 lines

---

##### 3. Particle Swarm Optimization

**File:** `Sources/BusinessMath/Optimization/Heuristic/ParticleSwarmOptimization.swift`

```swift
/// Particle Swarm Optimization implementation
struct ParticleSwarmEngine<V: VectorSpace> where V.Scalar: Real {
    let inertia: V.Scalar
    let cognitive: V.Scalar  // c₁ - attraction to personal best
    let social: V.Scalar     // c₂ - attraction to global best

    struct Particle {
        var position: V
        var velocity: V
        var personalBest: V
        var personalBestFitness: V.Scalar
    }

    /// Initialize swarm
    func initializeSwarm(
        size: Int,
        searchSpace: [(lower: V.Scalar, upper: V.Scalar)],
        seed: UInt64?
    ) -> [Particle] {
        var rng = seed.map { SeededRandomNumberGenerator(seed: $0) } ??
                  SeededRandomNumberGenerator(seed: UInt64.random(in: 0...UInt64.max))

        return (0..<size).map { _ in
            let position = V.fromArray(searchSpace.map { bounds in
                V.Scalar.random(in: bounds.lower...bounds.upper, using: &rng)
            })!

            let maxVelocity = searchSpace.map { ($0.upper - $0.lower) * V.Scalar(0.1) }
            let velocity = V.fromArray(maxVelocity.map { max in
                V.Scalar.random(in: -max...max, using: &rng)
            })!

            return Particle(
                position: position,
                velocity: velocity,
                personalBest: position,
                personalBestFitness: V.Scalar.infinity
            )
        }
    }

    /// Update particle velocity and position
    func updateParticle(
        _ particle: inout Particle,
        globalBest: V,
        searchSpace: [(lower: V.Scalar, upper: V.Scalar)]
    ) {
        let r1 = V.Scalar.random(in: 0...1)
        let r2 = V.Scalar.random(in: 0...1)

        // v = w*v + c₁*r₁*(pBest - x) + c₂*r₂*(gBest - x)
        let cognitiveComponent = cognitive * r1 * (particle.personalBest - particle.position)
        let socialComponent = social * r2 * (globalBest - particle.position)

        particle.velocity = inertia * particle.velocity + cognitiveComponent + socialComponent

        // Clamp velocity
        var velArray = particle.velocity.toArray()
        for i in 0..<velArray.count {
            let maxVel = (searchSpace[i].upper - searchSpace[i].lower) * V.Scalar(0.2)
            velArray[i] = max(-maxVel, min(maxVel, velArray[i]))
        }
        particle.velocity = V.fromArray(velArray)!

        // Update position
        particle.position = particle.position + particle.velocity

        // Clamp position to search space
        var posArray = particle.position.toArray()
        for i in 0..<posArray.count {
            posArray[i] = max(searchSpace[i].lower, min(searchSpace[i].upper, posArray[i]))
        }
        particle.position = V.fromArray(posArray)!
    }
}
```

**Implementation Notes:**
- Velocity clamping prevents explosion
- Position clamping maintains feasibility
- Adaptive inertia weight (decrease over time) improves convergence

**Estimated LOC:** 300-400 lines

---

##### 4. Application: Nonsmooth Portfolio Optimization

**File:** `Sources/BusinessMath/Finance/Portfolio/NonsmoothPortfolioOptimizer.swift`

```swift
/// Portfolio optimization with nonsmooth constraints (e.g., transaction costs, IF/MAX functions)
public struct NonsmoothPortfolioOptimizer {

    public struct TransactionCost {
        public let fixedCost: Double      // Fixed cost per transaction
        public let variableCost: Double   // Percentage cost
    }

    /// Optimize portfolio with transaction costs (nonsmooth due to IF logic)
    public func optimizeWithTransactionCosts(
        expectedReturns: VectorN<Double>,
        covarianceMatrix: [[Double]],
        currentWeights: VectorN<Double>,
        transactionCosts: TransactionCost,
        targetReturn: Double? = nil
    ) throws -> HeuristicOptimizationResult<VectorN<Double>> {

        let n = expectedReturns.toArray().count

        // Objective: maximize return - risk - transaction costs
        let objective: (VectorN<Double>) -> Double = { weights in
            let w = weights.toArray()

            // Expected return
            let expectedReturn = zip(expectedReturns.toArray(), w).map(*).reduce(0, +)

            // Risk (variance)
            var variance = 0.0
            for i in 0..<n {
                for j in 0..<n {
                    variance += w[i] * covarianceMatrix[i][j] * w[j]
                }
            }

            // Transaction costs (NONSMOOTH: contains IF logic)
            let current = currentWeights.toArray()
            var totalCost = 0.0
            for i in 0..<n {
                let change = abs(w[i] - current[i])
                if change > 1e-6 {  // IF there's a trade
                    totalCost += transactionCosts.fixedCost
                    totalCost += transactionCosts.variableCost * change
                }
            }

            // Return objective (minimize negative return + risk + costs)
            return -expectedReturn + variance + totalCost
        }

        // Constraints
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .budgetConstraint,
        ] + .nonNegativity(dimension: n)

        // Search space: [0, 1] for each weight
        let searchSpace = (0..<n).map { _ in (lower: 0.0, upper: 1.0) }

        // Use genetic algorithm (handles nonsmooth well)
        let optimizer = HeuristicOptimizer<VectorN<Double>>(
            algorithm: .geneticAlgorithm(
                crossoverRate: 0.8,
                mutationRate: 0.1,
                selection: .tournament(size: 5)
            ),
            populationSize: 200,
            maxGenerations: 500
        )

        return try optimizer.optimize(
            objective,
            searchSpace: searchSpace,
            constraints: constraints,
            minimize: true
        )
    }
}
```

**Implementation Notes:**
- Transaction costs create discontinuities (IF logic)
- Gradient-based methods fail due to discontinuities
- Genetic algorithm explores discrete changes naturally

**Tests Required:**
- ✅ Optimization avoids small trades (fixed cost dominates)
- ✅ Finds better solution than ignoring transaction costs
- ✅ Converges in reasonable time (< 5 seconds)

---

#### Phase 6.2 Summary

**Files to Create:**
1. `HeuristicOptimizer.swift` (~250 lines)
2. `GeneticAlgorithm.swift` (~500 lines)
3. `ParticleSwarmOptimization.swift` (~350 lines)
4. `NonsmoothPortfolioOptimizer.swift` (~200 lines)

**Total:** ~1,300 lines source code

**Tests to Create:**
- `GeneticAlgorithmTests.swift` (~400 lines, 8 tests)
- `ParticleSwarmTests.swift` (~300 lines, 6 tests)
- `NonsmoothPortfolioTests.swift` (~200 lines, 4 tests)

**Total:** ~900 lines test code, 18 tests

**Success Criteria:**
- ✅ GA finds global minimum of Rastrigin function (highly multimodal)
- ✅ PSO optimizes 10D Rosenbrock function
- ✅ Portfolio with transaction costs produces feasible allocation
- ✅ All 18 tests pass
- ✅ No compiler warnings

---

### Phase 6.3: Stochastic Programming Enhancements

**Estimated Time:** 2-3 weeks
**Priority:** MEDIUM - Builds on existing `StochasticOptimizer` with Monte Carlo integration

#### Core Components

##### 1. Two-Stage Stochastic Programming

**File:** `Sources/BusinessMath/AdvancedOptimization/TwoStageStochasticProgram.swift`

```swift
/// Two-stage stochastic program: first-stage decisions before uncertainty, second-stage recourse after
public struct TwoStageStochasticProgram<V: VectorSpace, Scenario> where V.Scalar == Double {

    /// First-stage objective: f(x)
    public let firstStageObjective: (V) -> Double

    /// First-stage constraints: h(x) = 0, g(x) ≤ 0
    public let firstStageConstraints: [MultivariateConstraint<V>]

    /// Second-stage objective: Q(x, ω) for given first-stage x and scenario ω
    public let recourseObjective: (V, Scenario) -> Double

    /// Second-stage constraints (may depend on scenario): h(y, ω) = 0, g(y, ω) ≤ 0
    public let recourseConstraints: (Scenario) -> [MultivariateConstraint<V>]

    /// Scenario generator (uses existing MonteCarlo infrastructure)
    public let scenarioGenerator: () -> Scenario

    /// Number of scenarios to sample
    public let numberOfScenarios: Int

    public init(
        firstStageObjective: @escaping (V) -> Double,
        firstStageConstraints: [MultivariateConstraint<V>] = [],
        recourseObjective: @escaping (V, Scenario) -> Double,
        recourseConstraints: @escaping (Scenario) -> [MultivariateConstraint<V>] = { _ in [] },
        scenarioGenerator: @escaping () -> Scenario,
        numberOfScenarios: Int = 1000
    )

    /// Solve two-stage problem using L-shaped method or SAA
    public func solve(
        from initialGuess: V,
        method: TwoStageMethod = .sampleAverageApproximation
    ) throws -> TwoStageResult<V, Scenario>
}

public enum TwoStageMethod {
    case sampleAverageApproximation  // Convert to deterministic equivalent
    case lShaped                     // Benders decomposition (advanced)
}

public struct TwoStageResult<V: VectorSpace, Scenario> where V.Scalar == Double {
    /// Optimal first-stage decision
    public let firstStageDecision: V

    /// Expected value of first-stage objective
    public let firstStageCost: Double

    /// Expected value of recourse
    public let expectedRecourse: Double

    /// Total objective: first stage + expected recourse
    public let totalObjective: Double

    /// Sample scenarios used
    public let scenarios: [Scenario]

    /// Recourse decisions for each scenario (if stored)
    public let recourseDecisions: [V]?
}
```

**Implementation Strategy:**

```swift
public func solve(
    from initialGuess: V,
    method: TwoStageMethod = .sampleAverageApproximation
) throws -> TwoStageResult<V, Scenario> {

    // Step 1: Generate scenarios
    let scenarios = (0..<numberOfScenarios).map { _ in scenarioGenerator() }

    switch method {
    case .sampleAverageApproximation:
        // SAA: Solve deterministic equivalent
        // min f(x) + (1/N) Σᵢ Q(x, ωᵢ)

        let saaObjective: (V) -> Double = { x in
            let firstStageCost = firstStageObjective(x)
            let averageRecourse = scenarios.map { scenario in
                // For each scenario, solve recourse problem
                self.solveRecourse(firstStageDecision: x, scenario: scenario)
            }.reduce(0.0, +) / Double(numberOfScenarios)

            return firstStageCost + averageRecourse
        }

        // Use InequalityOptimizer for combined problem
        let optimizer = InequalityOptimizer<V>()
        let result = try optimizer.minimize(
            saaObjective,
            from: initialGuess,
            subjectTo: firstStageConstraints
        )

        return TwoStageResult(
            firstStageDecision: result.solution,
            firstStageCost: firstStageObjective(result.solution),
            expectedRecourse: result.objectiveValue - firstStageObjective(result.solution),
            totalObjective: result.objectiveValue,
            scenarios: scenarios,
            recourseDecisions: nil
        )

    case .lShaped:
        // L-shaped decomposition (Benders) - advanced, implement later
        fatalError("L-shaped method not yet implemented")
    }
}

/// Solve second-stage recourse problem for given first-stage decision and scenario
private func solveRecourse(firstStageDecision: V, scenario: Scenario) -> Double {
    // This is problem-specific; typically solved using InequalityOptimizer
    // For now, assume user provides recourseObjective that handles this
    return recourseObjective(firstStageDecision, scenario)
}
```

**Example Usage:**

```swift
// Newsvendor problem: Order quantity before knowing demand
let newsvendor = TwoStageStochasticProgram<VectorN<Double>, Double>(
    firstStageObjective: { q in
        let orderQuantity = q.toArray()[0]
        return 5.0 * orderQuantity  // Cost to order
    },
    firstStageConstraints: [
        .inequality { q in -q.toArray()[0] }  // q ≥ 0
    ],
    recourseObjective: { q, demand in
        let orderQuantity = q.toArray()[0]
        let shortage = max(0, demand - orderQuantity)
        let excess = max(0, orderQuantity - demand)
        return -10.0 * min(orderQuantity, demand) + 2.0 * shortage + 1.0 * excess
        // Revenue from sales - shortage penalty - excess holding cost
    },
    scenarioGenerator: {
        // Demand follows normal distribution
        let normal = DistributionNormal(mean: 100, standardDeviation: 20)
        return normal.next()
    },
    numberOfScenarios: 1000
)

let result = try newsvendor.solve(from: VectorN([100.0]))
// Finds optimal order quantity considering uncertain demand
```

**Tests Required:**
- ✅ Newsvendor problem (known closed-form solution)
- ✅ Portfolio rebalancing with transaction costs
- ✅ Production planning with uncertain demand
- ✅ Expected value of perfect information (EVPI) calculation

---

##### 2. Chance Constraints

**File:** `Sources/BusinessMath/AdvancedOptimization/ChanceConstraint.swift`

```swift
/// Probabilistic constraint: P(g(x, ω) ≤ 0) ≥ α
public struct ChanceConstraint<V: VectorSpace, Scenario> where V.Scalar == Double {

    /// Constraint function that depends on decision and scenario
    public let constraintFunction: (V, Scenario) -> Double

    /// Required probability level (e.g., 0.95 = 95% confidence)
    public let probabilityLevel: Double

    /// Scenario generator
    public let scenarioGenerator: () -> Scenario

    /// Number of scenarios for sampling
    public let numberOfScenarios: Int

    public init(
        constraintFunction: @escaping (V, Scenario) -> Double,
        probabilityLevel: Double,
        scenarioGenerator: @escaping () -> Scenario,
        numberOfScenarios: Int = 1000
    )

    /// Convert to deterministic constraints via scenario sampling
    /// Enforces: at least (α * N) scenarios must satisfy constraint
    public func toDeterministicConstraints() -> [MultivariateConstraint<V>] {
        let scenarios = (0..<numberOfScenarios).map { _ in scenarioGenerator() }
        let requiredSatisfied = Int(ceil(probabilityLevel * Double(numberOfScenarios)))

        // Big-M formulation with binary variables (requires integer programming)
        // For now, use conservative approximation

        // Conservative: Find α-quantile and enforce deterministically
        // This is equivalent to CVaR constraint

        return []  // Implementation requires integer variables (Phase 6.1)
    }

    /// Check if solution satisfies chance constraint (Monte Carlo)
    public func isSatisfied(at solution: V, trials: Int = 10000) -> (satisfied: Bool, probability: Double) {
        let scenarios = (0..<trials).map { _ in scenarioGenerator() }
        let satisfiedCount = scenarios.filter { scenario in
            constraintFunction(solution, scenario) <= 0
        }.count

        let empiricalProbability = Double(satisfiedCount) / Double(trials)
        return (empiricalProbability >= probabilityLevel, empiricalProbability)
    }
}
```

**Example:**
```swift
// Portfolio constraint: Return must exceed threshold with 95% probability
let chanceConstraint = ChanceConstraint<VectorN<Double>, [Double]>(
    constraintFunction: { weights, returns in
        let portfolioReturn = zip(weights.toArray(), returns).map(*).reduce(0, +)
        return 0.05 - portfolioReturn  // g(x,ω) = 0.05 - r(x,ω) ≤ 0
    },
    probabilityLevel: 0.95,
    scenarioGenerator: {
        // Sample returns from historical distribution
        let returns = (0..<10).map { _ in Double.random(in: -0.1...0.3) }
        return returns
    },
    numberOfScenarios: 1000
)

// Check if candidate portfolio satisfies constraint
let (satisfied, prob) = chanceConstraint.isSatisfied(at: candidateWeights)
print("Probability of meeting return target: \(prob)")
```

---

##### 3. Conditional Value at Risk (CVaR)

**File:** `Sources/BusinessMath/AdvancedOptimization/CVaROptimization.swift`

```swift
/// CVaR (Conditional Value at Risk) optimization
public struct CVaROptimizer<V: VectorSpace> where V.Scalar == Double {

    public let confidenceLevel: Double  // α (e.g., 0.95 for 95% CVaR)
    public let numberOfScenarios: Int

    /// Optimize CVaR of loss function
    /// CVaR_α(x) = E[L(x, ω) | L(x, ω) ≥ VaR_α(x)]
    public func minimize<Scenario>(
        lossFunction: @escaping (V, Scenario) -> Double,
        scenarioGenerator: @escaping () -> Scenario,
        initialGuess: V,
        constraints: [MultivariateConstraint<V>] = []
    ) throws -> CVaRResult<V> {

        // Generate scenarios
        let scenarios = (0..<numberOfScenarios).map { _ in scenarioGenerator() }

        // CVaR optimization via auxiliary variable formulation
        // Minimize: VaR + (1/(1-α)) * E[max(L - VaR, 0)]
        //
        // Introduce auxiliary variable: z = [x, VaR]
        // Objective: VaR + (1/(1-α)) * (1/N) * Σᵢ max(Lᵢ(x) - VaR, 0)

        let dimension = initialGuess.toArray().count + 1  // Add VaR variable
        let augmentedInitial = VectorN(initialGuess.toArray() + [0.0])  // VaR starts at 0

        let cvarObjective: (VectorN<Double>) -> Double = { z in
            let x = VectorN(Array(z.toArray().dropLast()))
            let VaR = z.toArray().last!

            let expectedExcess = scenarios.map { scenario in
                let loss = lossFunction(x as! V, scenario)
                return max(0.0, loss - VaR)
            }.reduce(0.0, +) / Double(numberOfScenarios)

            return VaR + (1.0 / (1.0 - confidenceLevel)) * expectedExcess
        }

        // Augment constraints to apply only to x (not VaR)
        let augmentedConstraints = constraints.map { originalConstraint -> MultivariateConstraint<VectorN<Double>> in
            switch originalConstraint {
            case .equality(let f, let g):
                return .equality(
                    function: { z in
                        let x = VectorN(Array(z.toArray().dropLast()))
                        return f(x as! V)
                    },
                    gradient: g.map { grad in
                        { z in
                            let x = VectorN(Array(z.toArray().dropLast()))
                            let originalGrad = grad(x as! V).toArray()
                            return VectorN(originalGrad + [0.0])  // VaR not in constraint
                        }
                    }
                )
            case .inequality(let f, let g):
                return .inequality(
                    function: { z in
                        let x = VectorN(Array(z.toArray().dropLast()))
                        return f(x as! V)
                    },
                    gradient: g.map { grad in
                        { z in
                            let x = VectorN(Array(z.toArray().dropLast()))
                            let originalGrad = grad(x as! V).toArray()
                            return VectorN(originalGrad + [0.0])
                        }
                    }
                )
            }
        }

        // Solve augmented problem
        let optimizer = InequalityOptimizer<VectorN<Double>>()
        let result = try optimizer.minimize(
            cvarObjective,
            from: augmentedInitial,
            subjectTo: augmentedConstraints
        )

        let x = VectorN(Array(result.solution.toArray().dropLast()))
        let VaR = result.solution.toArray().last!
        let CVaR = result.objectiveValue

        return CVaRResult(
            solution: x as! V,
            VaR: VaR,
            CVaR: CVaR,
            scenarios: scenarios
        )
    }
}

public struct CVaRResult<V: VectorSpace> where V.Scalar == Double {
    /// Optimal solution
    public let solution: V

    /// Value at Risk (α-quantile of loss distribution)
    public let VaR: Double

    /// Conditional Value at Risk (expected loss beyond VaR)
    public let CVaR: Double

    /// Scenarios used
    public let scenarios: [Any]
}
```

**Example:**
```swift
// Minimize CVaR of portfolio losses
let cvarOptimizer = CVaROptimizer<VectorN<Double>>(
    confidenceLevel: 0.95,
    numberOfScenarios: 1000
)

let result = try cvarOptimizer.minimize(
    lossFunction: { weights, returns in
        // Loss = negative return
        let portfolioReturn = zip(weights.toArray(), returns).map(*).reduce(0, +)
        return -portfolioReturn
    },
    scenarioGenerator: {
        // Sample from historical returns
        let returns = historicalData.randomElement()!
        return returns
    },
    initialGuess: equalWeights,
    constraints: [.budgetConstraint] + .nonNegativity(dimension: n)
)

print("95% CVaR: \(result.CVaR)")  // Expected loss in worst 5% of scenarios
print("95% VaR: \(result.VaR)")    // Threshold for worst 5%
```

**Tests Required:**
- ✅ CVaR equals VaR for confidence level 1.0
- ✅ CVaR ≥ VaR always (mathematical property)
- ✅ Portfolio CVaR optimization produces sensible weights
- ✅ Comparison with mean-variance optimization

---

##### 4. Scenario Tree Infrastructure (Foundation for Phase 8)

**File:** `Sources/BusinessMath/AdvancedOptimization/ScenarioTree.swift`

```swift
/// Scenario tree for multi-stage stochastic programming
public class ScenarioNode<State>: Identifiable {
    public let id: UUID
    public let stage: Int
    public let state: State
    public let probability: Double

    public weak var parent: ScenarioNode<State>?
    public var children: [ScenarioNode<State>]

    public init(
        stage: Int,
        state: State,
        probability: Double,
        parent: ScenarioNode<State>? = nil
    ) {
        self.id = UUID()
        self.stage = stage
        self.state = state
        self.probability = probability
        self.parent = parent
        self.children = []
    }

    /// Conditional probability given parent
    public var conditionalProbability: Double {
        guard let parent = parent else { return probability }
        return probability / parent.probability
    }

    /// Path from root to this node
    public var path: [ScenarioNode<State>] {
        var nodes: [ScenarioNode<State>] = [self]
        var current = self.parent
        while let node = current {
            nodes.insert(node, at: 0)
            current = node.parent
        }
        return nodes
    }
}

public struct ScenarioTree<State> {
    public let root: ScenarioNode<State>
    public let stages: Int

    /// Get all nodes at a given stage
    public func nodes(at stage: Int) -> [ScenarioNode<State>] {
        guard stage >= 0 && stage < stages else { return [] }

        if stage == 0 { return [root] }

        var currentLevel = [root]
        for _ in 0..<stage {
            currentLevel = currentLevel.flatMap { $0.children }
        }
        return currentLevel
    }

    /// Get all leaf nodes
    public var leafNodes: [ScenarioNode<State>] {
        return nodes(at: stages - 1)
    }

    /// Build scenario tree from Monte Carlo samples
    public static func fromMonteCarloSamples(
        samples: [[State]],  // Array of paths (each path is array of states per stage)
        stages: Int
    ) -> ScenarioTree<State> where State: Hashable {
        // This is complex - need to cluster similar states at each stage
        // For Phase 6, just provide the structure; full implementation in Phase 8
        fatalError("Scenario tree construction from samples not yet implemented")
    }
}
```

**Implementation Notes:**
- Foundation for multi-period optimization (Phase 8)
- Scenario tree construction is nontrivial (clustering required)
- For Phase 6, focus on data structure and basic operations
- Full construction algorithms deferred to Phase 8

---

#### Phase 6.3 Summary

**Files to Create:**
1. `TwoStageStochasticProgram.swift` (~300 lines)
2. `ChanceConstraint.swift` (~150 lines)
3. `CVaROptimization.swift` (~250 lines)
4. `ScenarioTree.swift` (~200 lines)

**Total:** ~900 lines source code

**Tests to Create:**
- `TwoStageStochasticProgramTests.swift` (~400 lines, 8 tests)
- `ChanceConstraintTests.swift` (~200 lines, 4 tests)
- `CVaROptimizationTests.swift` (~300 lines, 6 tests)
- `ScenarioTreeTests.swift` (~150 lines, 3 tests)

**Total:** ~1,050 lines test code, 21 tests

**Success Criteria:**
- ✅ Newsvendor problem solves correctly (compare to closed-form solution)
- ✅ CVaR portfolio optimization produces risk-averse allocation
- ✅ Chance constraint validation works via Monte Carlo
- ✅ All 21 tests pass
- ✅ Integration with existing `MonteCarloSimulation` infrastructure

---

## Phase 7: Specialized Application Modeling

**Goal:** Implement classical OR structures leveraging LP/IP solvers for domain-specific problems.

**Components:**
1. Specialized LP Structures (Network Flow, Covering/Packing/Partitioning)
2. Data Envelopment Analysis (DEA)
3. Assignment Problem
4. Traveling Salesman Problem (TSP)

**Estimated Time:** 3-4 weeks total

---

### Phase 7.1: Network Flow Models

**Estimated Time:** 1 week

#### Components

##### 1. Network Flow Optimizer

**File:** `Sources/BusinessMath/BusinessOptimization/NetworkFlow.swift`

```swift
/// Network flow optimization (Transportation, Transshipment, Max Flow)
public struct NetworkFlowOptimizer {

    public struct Node {
        public let id: String
        public let supply: Double  // Positive = supply, negative = demand, 0 = transshipment
    }

    public struct Arc {
        public let from: String
        public let to: String
        public let capacity: Double?    // nil = unlimited
        public let cost: Double
        public let lowerBound: Double  // Minimum flow
    }

    public enum Objective {
        case minimizeCost
        case maximizeFlow
        case minimizeCostSubjectToMinFlow(Double)
    }

    /// Solve network flow problem
    public func solve(
        nodes: [Node],
        arcs: [Arc],
        objective: Objective
    ) throws -> NetworkFlowSolution
}

public struct NetworkFlowSolution {
    public let flows: [String: Double]  // Arc ID -> flow
    public let objectiveValue: Double
    public let shadowPrices: [String: Double]  // Node ID -> shadow price
}
```

**Implementation Strategy:**
- Build constraint matrix from network structure
- Flow conservation: Σ(inflow) - Σ(outflow) = supply/demand
- Use `InequalityOptimizer` for LP formulation
- For integer flows, use `BranchAndBoundSolver`

**Tests Required:**
- ✅ Transportation problem (5 suppliers, 7 customers)
- ✅ Max flow problem (compare with Ford-Fulkerson)
- ✅ Minimum cost flow
- ✅ Transshipment with intermediate nodes

---

### Phase 7.2: Set Covering/Packing/Partitioning

**File:** `Sources/BusinessMath/BusinessOptimization/SetProblems.swift`

```swift
/// Set covering, packing, and partitioning problems
public struct SetOptimizer {

    /// Set covering: Select minimum cost subsets that cover all elements
    /// Example: Facility location (every customer must be covered by at least one facility)
    public func solveCovering(
        elements: Set<String>,
        subsets: [(id: String, elements: Set<String>, cost: Double)]
    ) throws -> SetSolution {
        // min Σ cⱼxⱼ
        // s.t. Σⱼ: i∈Sⱼ xⱼ ≥ 1  ∀i ∈ elements
        //      xⱼ ∈ {0,1}

        let n = subsets.count
        let spec = IntegerProgramSpecification(binaryVariables: Set(0..<n))

        let objective: (VectorN<Double>) -> Double = { x in
            zip(x.toArray(), subsets.map(\.cost)).map(*).reduce(0, +)
        }

        let constraints = elements.map { element -> MultivariateConstraint<VectorN<Double>> in
            .inequality { x in
                let coverage = subsets.enumerated()
                    .filter { $0.element.elements.contains(element) }
                    .map { x.toArray()[$0.offset] }
                    .reduce(0, +)
                return 1.0 - coverage  // coverage ≥ 1
            }
        }

        let solver = BranchAndBoundSolver<VectorN<Double>>()
        let result = try solver.solve(
            objective: objective,
            from: VectorN(Array(repeating: 0.5, count: n)),
            subjectTo: constraints,
            integerSpec: spec,
            minimize: true
        )

        let selected = result.solution.toArray()
            .enumerated()
            .filter { $0.element > 0.5 }
            .map { subsets[$0.offset].id }

        return SetSolution(selected: selected, cost: result.objectiveValue)
    }

    /// Set packing: Select maximum value subsets with no overlap
    /// Example: Resource allocation (each task can be assigned to at most one machine)
    public func solvePacking(
        elements: Set<String>,
        subsets: [(id: String, elements: Set<String>, value: Double)]
    ) throws -> SetSolution {
        // max Σ vⱼxⱼ
        // s.t. Σⱼ: i∈Sⱼ xⱼ ≤ 1  ∀i ∈ elements
        //      xⱼ ∈ {0,1}

        // Similar to covering, but ≤ 1 instead of ≥ 1, and maximize
        // Implementation analogous to solveCovering
        fatalError("Not yet implemented")
    }

    /// Set partitioning: Select subsets that partition all elements exactly once
    /// Example: Vehicle routing (each customer visited by exactly one route)
    public func solvePartitioning(
        elements: Set<String>,
        subsets: [(id: String, elements: Set<String>, cost: Double)]
    ) throws -> SetSolution {
        // min Σ cⱼxⱼ
        // s.t. Σⱼ: i∈Sⱼ xⱼ = 1  ∀i ∈ elements
        //      xⱼ ∈ {0,1}

        // Use = 1 instead of ≥ 1 or ≤ 1
        fatalError("Not yet implemented")
    }
}

public struct SetSolution {
    public let selected: [String]
    public let cost: Double
}
```

**Tests Required:**
- ✅ Set covering: Facility location problem
- ✅ Set packing: Task allocation
- ✅ Set partitioning: Simple partitioning example

---

### Phase 7.3: Data Envelopment Analysis (DEA)

**File:** `Sources/BusinessMath/BusinessOptimization/DataEnvelopmentAnalysis.swift`

```swift
/// Data Envelopment Analysis for efficiency measurement
public struct DEAOptimizer {

    public struct DecisionMakingUnit {
        public let id: String
        public let inputs: [Double]   // Resources consumed
        public let outputs: [Double]  // Products/services produced
    }

    public enum Model {
        case CCR  // Constant Returns to Scale (Charnes-Cooper-Rhodes)
        case BCC  // Variable Returns to Scale (Banker-Charnes-Cooper)
        case slackBased
    }

    public let model: Model

    /// Compute efficiency scores for all DMUs
    public func analyzeEfficiency(
        units: [DecisionMakingUnit]
    ) throws -> [String: DEAResult] {

        var results: [String: DEAResult] = [:]

        for unit in units {
            let result = try computeEfficiency(for: unit, benchmark: units)
            results[unit.id] = result
        }

        return results
    }

    /// Compute efficiency for a single DMU
    private func computeEfficiency(
        for unit: DecisionMakingUnit,
        benchmark: [DecisionMakingUnit]
    ) throws -> DEAResult {

        switch model {
        case .CCR:
            return try computeCCREfficiency(for: unit, benchmark: benchmark)
        case .BCC:
            return try computeBCCEfficiency(for: unit, benchmark: benchmark)
        case .slackBased:
            fatalError("Slack-based model not yet implemented")
        }
    }

    /// CCR model (Constant Returns to Scale)
    private func computeCCREfficiency(
        for unit: DecisionMakingUnit,
        benchmark: [DecisionMakingUnit]
    ) throws -> DEAResult {

        let m = unit.inputs.count
        let s = unit.outputs.count
        let n = benchmark.count

        // Dual formulation:
        // max Σᵣ uᵣ yᵣ₀
        // s.t. Σᵢ vᵢ xᵢ₀ = 1
        //      Σᵣ uᵣ yᵣⱼ - Σᵢ vᵢ xᵢⱼ ≤ 0  ∀j
        //      uᵣ, vᵢ ≥ ε

        let dimension = s + m  // Output weights (u) + Input weights (v)
        let epsilon = 1e-6

        let objective: (VectorN<Double>) -> Double = { weights in
            let u = Array(weights.toArray().prefix(s))  // Output weights
            let outputValue = zip(u, unit.outputs).map(*).reduce(0, +)
            return -outputValue  // Maximize = minimize negative
        }

        var constraints: [MultivariateConstraint<VectorN<Double>>] = []

        // Normalization: Σᵢ vᵢ xᵢ₀ = 1
        constraints.append(.equality { weights in
            let v = Array(weights.toArray().suffix(m))  // Input weights
            let inputValue = zip(v, unit.inputs).map(*).reduce(0, +)
            return inputValue - 1.0
        })

        // Efficiency constraints: Σᵣ uᵣ yᵣⱼ - Σᵢ vᵢ xᵢⱼ ≤ 0
        for dmu in benchmark {
            constraints.append(.inequality { weights in
                let u = Array(weights.toArray().prefix(s))
                let v = Array(weights.toArray().suffix(m))
                let outputValue = zip(u, dmu.outputs).map(*).reduce(0, +)
                let inputValue = zip(v, dmu.inputs).map(*).reduce(0, +)
                return outputValue - inputValue
            })
        }

        // Non-negativity with lower bound ε
        for i in 0..<dimension {
            constraints.append(.inequality { weights in
                epsilon - weights.toArray()[i]
            })
        }

        // Solve
        let optimizer = InequalityOptimizer<VectorN<Double>>()
        let initialGuess = VectorN(Array(repeating: 1.0 / Double(dimension), count: dimension))

        let result = try optimizer.minimize(
            objective,
            from: initialGuess,
            subjectTo: constraints
        )

        let efficiency = -result.objectiveValue  // Convert back from minimization
        let u = Array(result.solution.toArray().prefix(s))
        let v = Array(result.solution.toArray().suffix(m))

        // Identify reference set (DMUs with non-zero dual weights)
        // This requires solving primal problem or analyzing dual solution
        let referenceSet = benchmark.filter { _ in
            // Simplified: mark efficient DMUs (efficiency ≈ 1)
            abs(efficiency - 1.0) < 1e-4
        }.map(\.id)

        return DEAResult(
            unit: unit,
            efficiencyScore: min(efficiency, 1.0),  // Clamp to [0,1]
            inputWeights: v,
            outputWeights: u,
            referenceSet: referenceSet,
            inputSlacks: nil,
            outputSlacks: nil
        )
    }

    /// BCC model (Variable Returns to Scale)
    private func computeBCCEfficiency(
        for unit: DecisionMakingUnit,
        benchmark: [DecisionMakingUnit]
    ) throws -> DEAResult {
        // Similar to CCR, but adds convexity constraint: Σ λⱼ = 1
        fatalError("BCC model not yet implemented")
    }
}

public struct DEAResult {
    public let unit: DecisionMakingUnit

    /// Efficiency score ∈ [0, 1] (1 = fully efficient)
    public let efficiencyScore: Double

    /// Optimal input weights (dual variables)
    public let inputWeights: [Double]

    /// Optimal output weights (dual variables)
    public let outputWeights: [Double]

    /// Reference set of efficient DMUs
    public let referenceSet: [String]

    /// Input slacks (excess inputs that could be reduced)
    public let inputSlacks: [Double]?

    /// Output slacks (shortfalls in outputs)
    public let outputSlacks: [Double]?

    /// Is this DMU efficient?
    public var isEfficient: Bool {
        efficiencyScore >= 1.0 - 1e-4
    }
}
```

**Tests Required:**
- ✅ Simple DEA example (3 DMUs, 1 input, 1 output) - manual verification
- ✅ Multi-input multi-output (banks with assets, employees → loans, deposits)
- ✅ Efficient DMUs have score = 1.0
- ✅ Inefficient DMU has reference set of efficient peers

---

### Phase 7.4: Assignment and TSP

#### Assignment Problem

**File:** `Sources/BusinessMath/BusinessOptimization/Assignment.swift`

```swift
/// Assignment problem: Assign n agents to n tasks with minimum cost
public struct AssignmentOptimizer {

    public enum Method {
        case hungarian         // Specialized O(n³) algorithm
        case integerProgramming  // Generic IP solver
    }

    public let method: Method

    /// Solve assignment problem
    public func solve(costMatrix: [[Double]]) throws -> AssignmentSolution {
        switch method {
        case .hungarian:
            return try hungarianAlgorithm(costMatrix: costMatrix)
        case .integerProgramming:
            return try solveViaIP(costMatrix: costMatrix)
        }
    }

    /// Hungarian algorithm (Kuhn-Munkres)
    private func hungarianAlgorithm(costMatrix: [[Double]]) throws -> AssignmentSolution {
        // Step 1: Row reduction
        // Step 2: Column reduction
        // Step 3: Cover zeros with minimum lines
        // Step 4: If cover < n, find minimum uncovered element and adjust
        // Step 5: Repeat until optimal assignment found

        // This is a well-known algorithm - implementation is ~200 lines
        fatalError("Hungarian algorithm not yet implemented")
    }

    /// Solve via integer programming
    private func solveViaIP(costMatrix: [[Double]]) throws -> AssignmentSolution {
        let n = costMatrix.count

        // Variables: xᵢⱼ = 1 if agent i assigned to task j
        let dimension = n * n
        let spec = IntegerProgramSpecification(binaryVariables: Set(0..<dimension))

        // Objective: min Σᵢ Σⱼ cᵢⱼ xᵢⱼ
        let objective: (VectorN<Double>) -> Double = { x in
            var cost = 0.0
            for i in 0..<n {
                for j in 0..<n {
                    cost += costMatrix[i][j] * x.toArray()[i * n + j]
                }
            }
            return cost
        }

        var constraints: [MultivariateConstraint<VectorN<Double>>] = []

        // Each agent assigned to exactly one task: Σⱼ xᵢⱼ = 1
        for i in 0..<n {
            constraints.append(.equality { x in
                let sum = (0..<n).map { j in x.toArray()[i * n + j] }.reduce(0, +)
                return sum - 1.0
            })
        }

        // Each task assigned to exactly one agent: Σᵢ xᵢⱼ = 1
        for j in 0..<n {
            constraints.append(.equality { x in
                let sum = (0..<n).map { i in x.toArray()[i * n + j] }.reduce(0, +)
                return sum - 1.0
            })
        }

        let solver = BranchAndBoundSolver<VectorN<Double>>()
        let result = try solver.solve(
            objective: objective,
            from: VectorN(Array(repeating: 0.5, count: dimension)),
            subjectTo: constraints,
            integerSpec: spec,
            minimize: true
        )

        // Extract assignments
        var assignments: [(agent: Int, task: Int)] = []
        for i in 0..<n {
            for j in 0..<n {
                if result.solution.toArray()[i * n + j] > 0.5 {
                    assignments.append((agent: i, task: j))
                }
            }
        }

        return AssignmentSolution(
            assignments: assignments,
            totalCost: result.objectiveValue
        )
    }
}

public struct AssignmentSolution {
    public let assignments: [(agent: Int, task: Int)]
    public let totalCost: Double
}
```

**Tests Required:**
- ✅ Small assignment (4×4) with known optimal solution
- ✅ Degenerate case (multiple optimal solutions)
- ✅ Comparison: Hungarian vs IP should give same cost

---

#### Traveling Salesman Problem

**File:** `Sources/BusinessMath/BusinessOptimization/TravelingSalesman.swift`

```swift
/// Traveling Salesman Problem
public struct TSPOptimizer {

    public enum Algorithm {
        case nearestNeighbor   // O(n²) heuristic
        case twoOpt            // Local search
        case geneticAlgorithm  // Uses HeuristicOptimizer
        case integerProgramming(subtourElimination: SubtourMethod)
    }

    public enum SubtourMethod {
        case mtz           // Miller-Tucker-Zemlin
        case dantzig      // Dantzig-Fulkerson-Johnson (cutting plane)
    }

    public let algorithm: Algorithm

    /// Solve TSP
    public func solve(distanceMatrix: [[Double]]) throws -> TSPSolution {
        switch algorithm {
        case .nearestNeighbor:
            return nearestNeighborHeuristic(distanceMatrix: distanceMatrix)
        case .twoOpt:
            let initial = nearestNeighborHeuristic(distanceMatrix: distanceMatrix)
            return twoOptImprovement(initial: initial, distanceMatrix: distanceMatrix)
        case .geneticAlgorithm:
            return try solveViaGA(distanceMatrix: distanceMatrix)
        case .integerProgramming(let subtourMethod):
            return try solveViaIP(distanceMatrix: distanceMatrix, subtourMethod: subtourMethod)
        }
    }

    /// Nearest neighbor heuristic
    private func nearestNeighborHeuristic(distanceMatrix: [[Double]]) -> TSPSolution {
        let n = distanceMatrix.count
        var tour: [Int] = [0]
        var unvisited = Set(1..<n)
        var current = 0
        var totalDistance = 0.0

        while !unvisited.isEmpty {
            let nearest = unvisited.min { city1, city2 in
                distanceMatrix[current][city1] < distanceMatrix[current][city2]
            }!

            totalDistance += distanceMatrix[current][nearest]
            tour.append(nearest)
            unvisited.remove(nearest)
            current = nearest
        }

        // Return to start
        totalDistance += distanceMatrix[current][0]
        tour.append(0)

        return TSPSolution(tour: tour, totalDistance: totalDistance)
    }

    /// 2-opt local search improvement
    private func twoOptImprovement(initial: TSPSolution, distanceMatrix: [[Double]]) -> TSPSolution {
        var tour = initial.tour
        var improved = true

        while improved {
            improved = false

            for i in 1..<tour.count - 2 {
                for j in (i + 1)..<tour.count - 1 {
                    let currentDist = distanceMatrix[tour[i-1]][tour[i]] +
                                    distanceMatrix[tour[j]][tour[j+1]]
                    let newDist = distanceMatrix[tour[i-1]][tour[j]] +
                                distanceMatrix[tour[i]][tour[j+1]]

                    if newDist < currentDist {
                        // Reverse segment [i...j]
                        tour[i...j].reverse()
                        improved = true
                    }
                }
            }
        }

        let totalDistance = (0..<tour.count - 1).map { i in
            distanceMatrix[tour[i]][tour[i + 1]]
        }.reduce(0, +)

        return TSPSolution(tour: tour, totalDistance: totalDistance)
    }

    /// Solve via genetic algorithm
    private func solveViaGA(distanceMatrix: [[Double]]) throws -> TSPSolution {
        // Use HeuristicOptimizer with permutation encoding
        // Crossover: Order Crossover (OX)
        // Mutation: Swap two cities
        fatalError("GA for TSP not yet implemented")
    }

    /// Solve via integer programming (exact, but slow for n > 20)
    private func solveViaIP(distanceMatrix: [[Double]], subtourMethod: SubtourMethod) throws -> TSPSolution {
        // Variables: xᵢⱼ = 1 if edge (i,j) in tour
        // Objective: min Σᵢ Σⱼ dᵢⱼ xᵢⱼ
        // Constraints:
        //   - Σⱼ xᵢⱼ = 1  (leave each city once)
        //   - Σᵢ xᵢⱼ = 1  (enter each city once)
        //   - Subtour elimination (MTZ or Dantzig)

        fatalError("IP for TSP not yet implemented")
    }
}

public struct TSPSolution {
    public let tour: [Int]         // Sequence of cities
    public let totalDistance: Double
}
```

**Tests Required:**
- ✅ Small TSP (5 cities) with known optimal tour
- ✅ Nearest neighbor produces valid tour
- ✅ 2-opt improves nearest neighbor solution
- ✅ Symmetric distance matrix (dᵢⱼ = dⱼᵢ)

---

### Phase 7 Summary

**Files to Create:**
1. `NetworkFlow.swift` (~300 lines)
2. `SetProblems.swift` (~350 lines)
3. `DataEnvelopmentAnalysis.swift` (~400 lines)
4. `Assignment.swift` (~350 lines)
5. `TravelingSalesman.swift` (~400 lines)

**Total:** ~1,800 lines source code

**Tests to Create:**
- `NetworkFlowTests.swift` (~300 lines, 6 tests)
- `SetProblemsTests.swift` (~250 lines, 5 tests)
- `DEATests.swift` (~350 lines, 6 tests)
- `AssignmentTests.swift` (~200 lines, 4 tests)
- `TSPTests.swift` (~250 lines, 5 tests)

**Total:** ~1,350 lines test code, 26 tests

**Success Criteria:**
- ✅ Transportation problem solves optimally
- ✅ DEA correctly identifies efficient/inefficient DMUs
- ✅ Assignment problem matches Hungarian algorithm
- ✅ TSP heuristics produce valid tours
- ✅ All 26 tests pass

---

## Phase 8: Performance & Scale + Multi-Period/Robust Optimization

**Goal:** Enable large-scale problems through performance optimization AND implement multi-period, robust, and scenario-based optimization.

**Components:**
1. Sparse Matrix Support
2. Parallel Optimization
3. Multi-Period Optimization
4. Robust Optimization
5. Scenario-Based Optimization
6. GPU Acceleration (for heuristics)

**Estimated Time:** 5-6 weeks total

---

### Phase 8.1: Sparse Matrix Infrastructure

**Estimated Time:** 1-2 weeks

#### Core Components

**File:** `Sources/BusinessMath/Optimization/SparseMatrix.swift`

```swift
/// Sparse matrix storage for large-scale optimization
public struct SparseMatrix {
    /// Compressed Sparse Row (CSR) format
    public private(set) var values: [Double]      // Non-zero values
    public private(set) var columnIndices: [Int]  // Column index for each value
    public private(set) var rowPointers: [Int]    // Start index of each row in values

    public let rows: Int
    public let columns: Int
    public var nonZeroCount: Int { values.count }

    /// Sparsity: fraction of zero elements
    public var sparsity: Double {
        1.0 - Double(nonZeroCount) / Double(rows * columns)
    }

    /// Create from dense matrix
    public init(dense: [[Double]], zeroThreshold: Double = 1e-12)

    /// Create from triplet format (row, col, value)
    public init(rows: Int, columns: Int, triplets: [(row: Int, col: Int, value: Double)])

    /// Matrix-vector multiplication: y = Ax
    public func multiply(vector: [Double]) -> [Double]

    /// Transpose
    public func transposed() -> SparseMatrix

    /// Extract submatrix
    public func submatrix(rows: Range<Int>, columns: Range<Int>) -> SparseMatrix
}

/// Sparse linear system solver
public struct SparseSolver {
    /// Solve Ax = b using iterative methods
    public func solve(
        A: SparseMatrix,
        b: [Double],
        method: IterativeMethod = .conjugateGradient,
        tolerance: Double = 1e-8,
        maxIterations: Int = 1000
    ) throws -> [Double]

    public enum IterativeMethod {
        case conjugateGradient     // For symmetric positive definite
        case biconjugateGradient  // For general systems
        case GMRES                // Generalized Minimal Residual
    }
}
```

**Implementation Notes:**
- CSR format efficient for row-wise operations
- Matrix-vector multiply in O(nnz) instead of O(n²)
- Essential for large-scale LP (10,000+ variables)

**Tests Required:**
- ✅ Sparse matrix multiplication matches dense
- ✅ Sparsity correctly calculated
- ✅ CG solver for sparse system
- ✅ Large sparse matrix (10,000×10,000 with 0.1% density)

---

### Phase 8.2: Parallel Optimization

**Estimated Time:** 1 week

**File:** `Sources/BusinessMath/Optimization/ParallelOptimizer.swift`

```swift
/// Parallel optimization using multiple starting points
public struct ParallelOptimizer<V: VectorSpace> where V.Scalar: Real {

    public let numberOfThreads: Int
    public let startingPoints: [V]

    /// Run optimization from multiple starting points in parallel
    public func optimize(
        objective: @Sendable @escaping (V) -> V.Scalar,
        optimizer: @Sendable @escaping (V) -> throws -> MultivariateOptimizationResult<V>,
        constraints: [MultivariateConstraint<V>] = []
    ) async throws -> ParallelOptimizationResult<V> {

        // Use TaskGroup for structured concurrency
        let results = try await withThrowingTaskGroup(
            of: MultivariateOptimizationResult<V>.self
        ) { group in
            for startingPoint in startingPoints {
                group.addTask {
                    try await Task.detached {
                        try optimizer(startingPoint)
                    }.value
                }
            }

            var collected: [MultivariateOptimizationResult<V>] = []
            for try await result in group {
                collected.append(result)
            }
            return collected
        }

        // Find best result
        let best = results.min { a, b in
            a.objectiveValue < b.objectiveValue
        }!

        return ParallelOptimizationResult(
            bestSolution: best,
            allSolutions: results,
            diversityMetric: computeDiversity(results)
        )
    }

    private func computeDiversity(_ results: [MultivariateOptimizationResult<V>]) -> V.Scalar {
        // Average pairwise distance between solutions
        var totalDistance = V.Scalar.zero
        var pairs = 0

        for i in 0..<results.count {
            for j in (i+1)..<results.count {
                let diff = results[i].solution - results[j].solution
                totalDistance += diff.norm
                pairs += 1
            }
        }

        return pairs > 0 ? totalDistance / V.Scalar(pairs) : V.Scalar.zero
    }
}

public struct ParallelOptimizationResult<V: VectorSpace> where V.Scalar: Real {
    public let bestSolution: MultivariateOptimizationResult<V>
    public let allSolutions: [MultivariateOptimizationResult<V>]
    public let diversityMetric: V.Scalar
}
```

**Tests Required:**
- ✅ Parallel optimization finds global minimum (multimodal function)
- ✅ All cores utilized (measure via Instruments)
- ✅ Results deterministic with same starting points

---

### Phase 8.3: Multi-Period Optimization

**Estimated Time:** 2 weeks

**File:** `Sources/BusinessMath/AdvancedOptimization/MultiPeriodOptimization.swift`

```swift
/// Multi-period optimization with time-varying decisions
public struct MultiPeriodOptimizer<V: VectorSpace> where V.Scalar == Double {

    public let periods: Int
    public let discountRate: Double

    /// Optimize decisions across multiple time periods
    /// Decision at period t can depend on state from period t-1
    public func optimize(
        objectivePerPeriod: @escaping (V, Int) -> Double,  // (decision, period) -> cost
        transitionFunction: @escaping (V, Int) -> V,       // (decision, period) -> next state
        constraintsPerPeriod: @escaping (Int) -> [MultivariateConstraint<V>],
        linkingConstraints: [(periods: (Int, Int), constraint: (V, V) -> Double)],
        initialState: V
    ) throws -> MultiPeriodResult<V> {

        // Aggregate decision vector: [x₀, x₁, ..., x_T]
        let dimension = V.dimension * periods
        let aggregatedInitial = VectorN((0..<periods).flatMap { _ in initialState.toArray() })

        // Aggregate objective: NPV = Σₜ (1/(1+r))^t * f(xₜ, t)
        let aggregatedObjective: (VectorN<Double>) -> Double = { x in
            var npv = 0.0
            for t in 0..<self.periods {
                let start = t * V.dimension
                let end = start + V.dimension
                let decision = V.fromArray(Array(x.toArray()[start..<end]))!
                let discount = pow(1.0 + self.discountRate, -Double(t))
                npv += discount * objectivePerPeriod(decision, t)
            }
            return npv
        }

        // Aggregate constraints
        var aggregatedConstraints: [MultivariateConstraint<VectorN<Double>>] = []

        // Period-specific constraints
        for t in 0..<periods {
            let periodConstraints = constraintsPerPeriod(t)
            for constraint in periodConstraints {
                aggregatedConstraints.append(self.liftConstraint(constraint, period: t))
            }
        }

        // Linking constraints between periods
        for link in linkingConstraints {
            let (t1, t2) = link.periods
            aggregatedConstraints.append(.equality { x in
                let decision1 = V.fromArray(Array(x.toArray()[(t1*V.dimension)..<((t1+1)*V.dimension)]))!
                let decision2 = V.fromArray(Array(x.toArray()[(t2*V.dimension)..<((t2+1)*V.dimension)]))!
                return link.constraint(decision1, decision2)
            })
        }

        // Solve aggregated problem
        let optimizer = InequalityOptimizer<VectorN<Double>>()
        let result = try optimizer.minimize(
            aggregatedObjective,
            from: aggregatedInitial,
            subjectTo: aggregatedConstraints
        )

        // Extract period-by-period decisions
        var decisions: [V] = []
        for t in 0..<periods {
            let start = t * V.dimension
            let end = start + V.dimension
            let decision = V.fromArray(Array(result.solution.toArray()[start..<end]))!
            decisions.append(decision)
        }

        return MultiPeriodResult(
            decisions: decisions,
            totalObjective: result.objectiveValue,
            objectivePerPeriod: (0..<periods).map { t in
                let discount = pow(1.0 + discountRate, -Double(t))
                return discount * objectivePerPeriod(decisions[t], t)
            }
        )
    }

    /// Lift single-period constraint to aggregated space
    private func liftConstraint(
        _ constraint: MultivariateConstraint<V>,
        period: Int
    ) -> MultivariateConstraint<VectorN<Double>> {
        switch constraint {
        case .equality(let f, let g):
            return .equality(
                function: { x in
                    let start = period * V.dimension
                    let end = start + V.dimension
                    let decision = V.fromArray(Array(x.toArray()[start..<end]))!
                    return f(decision)
                },
                gradient: g.map { grad in
                    { x in
                        let start = period * V.dimension
                        let end = start + V.dimension
                        let decision = V.fromArray(Array(x.toArray()[start..<end]))!
                        let periodGrad = grad(decision).toArray()
                        var fullGrad = Array(repeating: 0.0, count: V.dimension * self.periods)
                        fullGrad.replaceSubrange(start..<end, with: periodGrad)
                        return VectorN(fullGrad)
                    }
                }
            )
        case .inequality(let f, let g):
            // Similar to equality case
            return .inequality(function: { x in
                let start = period * V.dimension
                let end = start + V.dimension
                let decision = V.fromArray(Array(x.toArray()[start..<end]))!
                return f(decision)
            }, gradient: nil)
        }
    }
}

public struct MultiPeriodResult<V: VectorSpace> where V.Scalar == Double {
    public let decisions: [V]                  // Decision for each period
    public let totalObjective: Double          // NPV of all periods
    public let objectivePerPeriod: [Double]    // Discounted value per period
}
```

**Example:**
```swift
// Multi-period portfolio rebalancing
let optimizer = MultiPeriodOptimizer<VectorN<Double>>(
    periods: 12,  // 12 months
    discountRate: 0.005  // 0.5% monthly
)

let result = try optimizer.optimize(
    objectivePerPeriod: { weights, month in
        // Maximize expected return - risk
        let expectedReturn = calculateReturn(weights, month: month)
        let risk = calculateRisk(weights)
        return -expectedReturn + 0.5 * risk
    },
    transitionFunction: { weights, month in
        // Apply returns and compute next period's weights
        applyReturns(weights, month: month)
    },
    constraintsPerPeriod: { month in
        [.budgetConstraint] + .nonNegativity(dimension: 10)
    },
    linkingConstraints: [
        // Limit turnover between consecutive periods
        (periods: (0, 1), constraint: { w0, w1 in
            let turnover = (w1 - w0).norm
            return turnover - 0.2  // Max 20% turnover
        })
    ],
    initialState: equalWeights
)
```

**Tests Required:**
- ✅ Two-period problem decomposes correctly
- ✅ Discount rate applied correctly (verify NPV)
- ✅ Linking constraints enforced
- ✅ Portfolio rebalancing example

---

### Phase 8.4: Robust Optimization

**Estimated Time:** 1-2 weeks

**File:** `Sources/BusinessMath/AdvancedOptimization/RobustOptimization.swift`

```swift
/// Robust optimization for worst-case scenarios
public struct RobustOptimizer<V: VectorSpace> where V.Scalar == Double {

    public enum UncertaintySet {
        case box(lower: V, upper: V)                    // ||u - u₀||_∞ ≤ δ
        case ellipsoidal(center: V, radius: Double)     // ||u - u₀||_2 ≤ δ
        case polyhedral(A: [[Double]], b: [Double])     // Au ≤ b
        case scenarioBased(scenarios: [V])              // Discrete uncertainty
    }

    /// Minimize worst-case objective over uncertainty set
    /// min_x max_u f(x, u)  s.t. u ∈ U, g(x, u) ≤ 0
    public func optimize(
        objective: @escaping (V, V) -> Double,  // (decision, uncertainty) -> cost
        uncertaintySet: UncertaintySet,
        constraints: @escaping (V, V) -> [Double],  // (decision, uncertainty) -> violations
        from initialGuess: V
    ) throws -> RobustOptimizationResult<V> {

        switch uncertaintySet {
        case .scenarioBased(let scenarios):
            // Finite uncertainty: solve for worst-case scenario
            return try optimizeFiniteUncertainty(
                objective: objective,
                scenarios: scenarios,
                constraints: constraints,
                initialGuess: initialGuess
            )

        case .box(let lower, let upper):
            // Box uncertainty: use duality or sampling
            return try optimizeBoxUncertainty(
                objective: objective,
                lower: lower,
                upper: upper,
                constraints: constraints,
                initialGuess: initialGuess
            )

        case .ellipsoidal, .polyhedral:
            // More complex - use conservative approximation or sampling
            fatalError("Ellipsoidal/polyhedral uncertainty not yet implemented")
        }
    }

    /// Optimize for finite scenario-based uncertainty
    private func optimizeFiniteUncertainty(
        objective: @escaping (V, V) -> Double,
        scenarios: [V],
        constraints: @escaping (V, V) -> [Double],
        initialGuess: V
    ) throws -> RobustOptimizationResult<V> {

        // Reformulation: min t  s.t. f(x, uᵢ) ≤ t  ∀i, g(x, uᵢ) ≤ 0  ∀i
        let dimension = V.dimension + 1  // Add auxiliary variable t
        let augmentedInitial = VectorN(initialGuess.toArray() + [0.0])

        let robustObjective: (VectorN<Double>) -> Double = { z in
            z.toArray().last!  // Minimize t
        }

        var robustConstraints: [MultivariateConstraint<VectorN<Double>>] = []

        // For each scenario: f(x, uᵢ) - t ≤ 0
        for scenario in scenarios {
            robustConstraints.append(.inequality { z in
                let x = V.fromArray(Array(z.toArray().dropLast()))!
                let t = z.toArray().last!
                return objective(x, scenario) - t
            })

            // Constraints: g(x, uᵢ) ≤ 0
            let violations = constraints(initialGuess, scenario)
            for (idx, _) in violations.enumerated() {
                robustConstraints.append(.inequality { z in
                    let x = V.fromArray(Array(z.toArray().dropLast()))!
                    let viols = constraints(x, scenario)
                    return viols[idx]
                })
            }
        }

        let optimizer = InequalityOptimizer<VectorN<Double>>()
        let result = try optimizer.minimize(
            robustObjective,
            from: augmentedInitial,
            subjectTo: robustConstraints
        )

        let solution = V.fromArray(Array(result.solution.toArray().dropLast()))!
        let worstCaseValue = result.solution.toArray().last!

        // Find worst-case scenario
        let worstScenario = scenarios.max { u1, u2 in
            objective(solution, u1) < objective(solution, u2)
        }!

        return RobustOptimizationResult(
            solution: solution,
            worstCaseObjective: worstCaseValue,
            worstCaseScenario: worstScenario,
            scenarios: scenarios
        )
    }

    /// Optimize for box uncertainty (conservative via sampling)
    private func optimizeBoxUncertainty(
        objective: @escaping (V, V) -> Double,
        lower: V,
        upper: V,
        constraints: @escaping (V, V) -> [Double],
        initialGuess: V
    ) throws -> RobustOptimizationResult<V> {

        // Sample vertices and center of box
        let dimension = V.dimension
        var scenarios: [V] = [lower, upper]

        // Sample 2^n vertices (for small n) or use Latin Hypercube Sampling
        if dimension <= 10 {
            // Sample all 2^n vertices
            for i in 0..<(1 << dimension) {
                var vertex = lower.toArray()
                for j in 0..<dimension {
                    if (i >> j) & 1 == 1 {
                        vertex[j] = upper.toArray()[j]
                    }
                }
                scenarios.append(V.fromArray(vertex)!)
            }
        } else {
            // Use sampling for high dimensions
            for _ in 0..<100 {
                let sample = V.fromArray(
                    (0..<dimension).map { i in
                        Double.random(in: lower.toArray()[i]...upper.toArray()[i])
                    }
                )!
                scenarios.append(sample)
            }
        }

        return try optimizeFiniteUncertainty(
            objective: objective,
            scenarios: scenarios,
            constraints: constraints,
            initialGuess: initialGuess
        )
    }
}

public struct RobustOptimizationResult<V: VectorSpace> where V.Scalar == Double {
    public let solution: V
    public let worstCaseObjective: Double
    public let worstCaseScenario: V
    public let scenarios: [V]
}
```

**Example:**
```swift
// Robust portfolio optimization
let robustOptimizer = RobustOptimizer<VectorN<Double>>()

let result = try robustOptimizer.optimize(
    objective: { weights, returns in
        // Worst-case return
        let portfolioReturn = zip(weights.toArray(), returns.toArray()).map(*).reduce(0, +)
        return -portfolioReturn  // Minimize negative return = maximize worst-case return
    },
    uncertaintySet: .box(
        lower: VectorN(Array(repeating: -0.2, count: 10)),  // -20% worst case
        upper: VectorN(Array(repeating: 0.3, count: 10))    // +30% best case
    ),
    constraints: { weights, _ in
        // Budget constraint and non-negativity
        let sum = weights.toArray().reduce(0, +)
        return [abs(sum - 1.0) - 0.01] + weights.toArray().map { -$0 }
    },
    from: equalWeights
)

print("Worst-case return: \(-result.worstCaseObjective)")
```

**Tests Required:**
- ✅ Robust solution worse than nominal but more stable
- ✅ Worst-case scenario correctly identified
- ✅ Box uncertainty with 2D problem (manual verification)

---

### Phase 8.5: GPU Acceleration for Heuristics

**Estimated Time:** 2 weeks (optional, advanced)

**File:** `Sources/BusinessMath/Optimization/GPU/GPUHeuristicOptimizer.swift`

```swift
#if canImport(Metal)
import Metal

/// GPU-accelerated heuristic optimizer using Metal
@available(macOS 10.13, *)
public struct GPUHeuristicOptimizer<V: VectorSpace> where V.Scalar == Float {

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary

    public init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw OptimizationError.invalidInput(message: "Metal not available")
        }

        guard let queue = device.makeCommandQueue() else {
            throw OptimizationError.invalidInput(message: "Cannot create command queue")
        }

        self.device = device
        self.commandQueue = queue
        self.library = try device.makeDefaultLibrary()!
    }

    /// Run genetic algorithm on GPU
    public func geneticAlgorithm(
        objective: @escaping (V) -> Float,
        populationSize: Int,
        generations: Int,
        searchSpace: [(lower: Float, upper: Float)]
    ) throws -> HeuristicOptimizationResult<V> {

        // Metal kernel for fitness evaluation (parallel)
        let fitnessKernel = library.makeFunction(name: "evaluateFitness")!
        let fitnessPipeline = try device.makeComputePipelineState(function: fitnessKernel)

        // Metal kernel for crossover (parallel)
        let crossoverKernel = library.makeFunction(name: "crossoverPopulation")!
        let crossoverPipeline = try device.makeComputePipelineState(function: crossoverKernel)

        // Initialize population on GPU
        var population = initializePopulationGPU(
            size: populationSize,
            dimension: V.dimension,
            searchSpace: searchSpace
        )

        // Evolution loop
        for generation in 0..<generations {
            // Evaluate fitness (GPU)
            let fitness = evaluateFitnessGPU(
                population: population,
                pipeline: fitnessPipeline
            )

            // Selection, crossover, mutation (GPU)
            population = evolvePopulationGPU(
                population: population,
                fitness: fitness,
                crossoverPipeline: crossoverPipeline
            )
        }

        // Return best individual
        let finalFitness = evaluateFitnessGPU(
            population: population,
            pipeline: fitnessPipeline
        )

        let bestIndex = finalFitness.enumerated().min(by: { $0.element < $1.element })!.offset
        let bestSolution = V.fromArray(Array(population[bestIndex]))!

        return HeuristicOptimizationResult(
            solution: bestSolution,
            objectiveValue: finalFitness[bestIndex],
            generations: generations,
            evaluations: populationSize * generations,
            converged: true,
            convergenceHistory: [],
            diversityHistory: []
        )
    }

    // GPU helper functions omitted for brevity
}
#endif
```

**Metal Shader (Shaders.metal):**
```metal
#include <metal_stdlib>
using namespace metal;

kernel void evaluateFitness(
    device const float* population [[buffer(0)]],
    device float* fitness [[buffer(1)]],
    constant int& dimension [[buffer(2)]],
    uint id [[thread_position_in_grid]]
) {
    // Each thread evaluates one individual
    device const float* individual = population + id * dimension;

    // Example: Sphere function
    float sum = 0.0;
    for (int i = 0; i < dimension; i++) {
        sum += individual[i] * individual[i];
    }

    fitness[id] = sum;
}

kernel void crossoverPopulation(
    device const float* parents [[buffer(0)]],
    device float* offspring [[buffer(1)]],
    constant int& dimension [[buffer(2)]],
    constant float& crossoverRate [[buffer(3)]],
    uint id [[thread_position_in_grid]]
) {
    // Each thread creates one offspring via crossover
    uint parent1 = id;
    uint parent2 = (id + 1) % (id + 1);  // Simplified

    for (int i = 0; i < dimension; i++) {
        float r = float(id * dimension + i) / 1000.0;  // Pseudo-random
        if (r < crossoverRate) {
            offspring[id * dimension + i] = parents[parent1 * dimension + i];
        } else {
            offspring[id * dimension + i] = parents[parent2 * dimension + i];
        }
    }
}
```

**Tests Required:**
- ✅ GPU optimizer produces same results as CPU (within tolerance)
- ✅ GPU speedup measured (10x for large populations)
- ✅ Graceful fallback if Metal unavailable

---

### Phase 8 Summary

**Files to Create:**
1. `SparseMatrix.swift` (~400 lines)
2. `ParallelOptimizer.swift` (~200 lines)
3. `MultiPeriodOptimization.swift` (~400 lines)
4. `RobustOptimization.swift` (~350 lines)
5. `GPUHeuristicOptimizer.swift` (~500 lines, optional)
6. `Shaders.metal` (~100 lines, optional)

**Total:** ~1,950 lines source code (1,450 without GPU)

**Tests to Create:**
- `SparseMatrixTests.swift` (~300 lines, 6 tests)
- `ParallelOptimizerTests.swift` (~200 lines, 4 tests)
- `MultiPeriodOptimizationTests.swift` (~400 lines, 6 tests)
- `RobustOptimizationTests.swift` (~300 lines, 5 tests)
- `GPUHeuristicOptimizerTests.swift` (~250 lines, 4 tests, optional)

**Total:** ~1,450 lines test code, 25 tests (21 without GPU)

**Success Criteria:**
- ✅ Sparse matrix operations 10x faster for 0.1% density
- ✅ Parallel optimizer finds global minimum (multimodal function)
- ✅ Multi-period portfolio rebalancing produces reasonable strategy
- ✅ Robust optimization more conservative than nominal
- ✅ GPU acceleration 10x+ speedup for large populations (if implemented)
- ✅ All tests pass

---

## Summary: Phases 6-8 Combined

### Total Implementation Effort

**Phase 6 (IP + Heuristic + Stochastic):**
- Source: ~3,350 lines
- Tests: ~3,050 lines, 65 tests
- Time: 7-10 weeks

**Phase 7 (Specialized Structures):**
- Source: ~1,800 lines
- Tests: ~1,350 lines, 26 tests
- Time: 3-4 weeks

**Phase 8 (Performance + Multi-Period + Robust):**
- Source: ~1,950 lines (or ~1,450 without GPU)
- Tests: ~1,450 lines, 25 tests (or 21 without GPU)
- Time: 5-6 weeks

**Grand Total:**
- **Source Code:** ~7,100 lines (~6,600 without GPU)
- **Test Code:** ~5,850 lines
- **Total Tests:** 116 tests (112 without GPU)
- **Total Time:** 15-20 weeks (~4-5 months)

### Key Milestones

1. **Phase 6.1 Complete:** Integer programming unlocks discrete optimization
2. **Phase 6.2 Complete:** Heuristics handle nonsmooth functions
3. **Phase 6.3 Complete:** Stochastic programming with recourse
4. **Phase 7 Complete:** Classical OR problems (DEA, TSP, Assignment)
5. **Phase 8 Complete:** Large-scale, multi-period, robust optimization

### Integration Points Verified

✅ Integer programming uses `InequalityOptimizer` for LP relaxations
✅ Heuristics work with `VectorSpace` abstraction
✅ Stochastic programming leverages existing `MonteCarloSimulation`
✅ Specialized optimizers follow Phase 5 patterns (ResourceAllocation, ProductionPlanning)
✅ Multi-period optimization extends constraint system
✅ Sparse matrices accelerate large-scale problems

### Testing Strategy

- **Unit Tests:** Each component tested in isolation
- **Integration Tests:** Optimizers work together (e.g., two-stage stochastic with integer first-stage)
- **Performance Tests:** Measure speedups (sparse vs dense, parallel vs serial, GPU vs CPU)
- **Validation Tests:** Compare against known solutions (Hungarian algorithm, closed-form newsvendor)

### Success Metrics

By the end of Phase 8, BusinessMath will:
- ✅ Solve mixed-integer programs with Branch & Bound
- ✅ Handle nonsmooth objectives via genetic algorithms and PSO
- ✅ Optimize under uncertainty (stochastic, robust)
- ✅ Tackle classical OR problems (DEA, TSP, network flow)
- ✅ Scale to 10,000+ variables with sparse matrices
- ✅ Leverage parallelization and GPU acceleration
- ✅ Support multi-period planning with time linkages

---

## Next Steps

1. **Review This Plan:** Ensure alignment with vision and priorities
2. **Refine Phase 6.1:** Most critical, detailed pseudocode ready
3. **Set Up Test Infrastructure:** Benchmarks for performance testing
4. **Begin Implementation:** Start with `IntegerSpecification.swift`

**This plan is ready to guide implementation across multiple sessions. Each phase is self-contained with clear deliverables, tests, and success criteria.**

---

**End of Implementation Plan**

---

## Phase 8 Status Update (2025-12-11)

### PHASE 8.2 COMPLETE ✅

**ParallelOptimizer implemented in Phase 7** (2025-12-11):
- ✅ **File:** `Sources/BusinessMath/Optimization/ParallelOptimizer.swift` (333 lines)
- ✅ **Tests:** `Tests/BusinessMathTests/Performance Tests/ParallelOptimizerTests.swift` (453 lines, 16 tests)
- ✅ **Status:** 16/16 tests passing (100%)
- ✅ **Features:**
  - True parallel execution using Swift async/await and TaskGroup
  - Multiple algorithm support (Gradient Descent, Newton-Raphson, Constrained, Inequality)
  - Random starting point generation within search regions
  - Best result selection (lowest objective value)
  - Success rate tracking (proportion of starts that converged)
  - All attempt results preserved for analysis
- ✅ **MCP Tools:** 2 tools registered (`parallel_optimize`, `parallel_optimization_guide`)
- ✅ **Tutorial:** PHASE_7_PARALLEL_OPTIMIZATION_TUTORIAL.md (comprehensive guide)

**Key Achievement:** Phase 8.2 was delivered ahead of schedule as part of Phase 7, demonstrating the power of async/await for true parallel optimization across CPU cores.

---

### Remaining Phase 8 Work

**Priority Order (TDD Approach):**

#### 1. Phase 8.1: Sparse Matrix Infrastructure ⬅️ START HERE
**Status:** Not started
**Estimated:** 2-3 hours with TDD
**Priority:** HIGH (foundational for large-scale problems)

**Why First:**
- Foundation for 10,000+ variable optimization problems
- Clear, well-defined scope (CSR format + iterative solvers)
- Perfect for Test-Driven Development (many testable properties)
- Enables performance gains in SimplexSolver and other algorithms

**TDD Plan:**
1. Write tests FIRST (matrix-vector multiply, sparsity, solver convergence)
2. Verify tests fail (Red phase)
3. Implement CSR storage and iterative solvers
4. Make tests pass (Green phase)
5. Add MCP tools and documentation

**Files to Create:**
- `Sources/BusinessMath/Optimization/SparseMatrix.swift` (~400 lines)
- `Tests/BusinessMathTests/Performance Tests/SparseMatrixTests.swift` (~300 lines)

**Test Coverage Required:**
- ✅ Sparse matrix multiplication matches dense result
- ✅ Sparsity calculation correct
- ✅ CSR format construction from dense and triplet formats
- ✅ Transpose operation preserves structure
- ✅ Conjugate Gradient solver converges for SPD systems
- ✅ BiConjugate Gradient for general systems
- ✅ Large sparse matrix (10,000×10,000 with 0.1% density)
- ✅ Performance benchmark (sparse vs dense speedup)

---

#### 2. Phase 8.3: Multi-Period Optimization
**Status:** Not started
**Estimated:** 3-4 hours with TDD
**Priority:** MEDIUM (high business value)

**Why Second:**
- Real-world applications (portfolio rebalancing, production planning)
- Builds on existing optimizer infrastructure
- Can use dense matrices initially (sparse optional)

**TDD Plan:**
1. Write tests for multi-period portfolio rebalancing
2. Write tests for linking constraints between periods
3. Write tests for NPV calculation with discounting
4. Implement to pass all tests

**Files to Create:**
- `Sources/BusinessMath/AdvancedOptimization/MultiPeriodOptimization.swift` (~400 lines)
- `Tests/BusinessMathTests/Advanced Tests/MultiPeriodOptimizationTests.swift` (~350 lines)

---

#### 3. Phase 8.4: Robust Optimization
**Status:** Not started
**Estimated:** 2-3 hours with TDD
**Priority:** MEDIUM (important for risk management)

**Why Third:**
- Practical applications in uncertainty handling
- Less complex than multi-period
- Natural extension of existing optimizers

**TDD Plan:**
1. Write tests for box uncertainty sets
2. Write tests for worst-case optimization
3. Write tests that robust solution is more conservative than nominal
4. Implement to pass

**Files to Create:**
- `Sources/BusinessMath/AdvancedOptimization/RobustOptimization.swift` (~350 lines)
- `Tests/BusinessMathTests/Advanced Tests/RobustOptimizationTests.swift` (~300 lines)

---

#### 4. Phase 8.5: GPU Acceleration
**Status:** DEFERRED
**Estimated:** 4-6 hours (complex, Metal framework)
**Priority:** LOW (optional, advanced)

**Why Defer:**
- High complexity (Metal shaders, GPU memory management)
- Requires specialized hardware testing
- Lower immediate value compared to other phases
- Can be added later if specific performance need arises

**Decision:** Focus on core optimization features first. GPU acceleration can be added in a future phase if needed for specific large-scale heuristic problems.

---

### Updated Phase 8 Timeline

**Original Estimate:** 5-6 weeks
**Revised Estimate:** COMPLETE (3 hours actual)

**Breakdown:**
- ✅ Phase 8.1 (Sparse Matrix): COMPLETE (Dec 11, 2025 - 2 hours)
- ✅ Phase 8.2 (Parallel Optimization): COMPLETE (delivered in Phase 7)
- ✅ Phase 8.3 (Multi-Period Optimization): COMPLETE (Dec 4, 2025)
- ✅ Phase 8.4 (Robust Optimization): COMPLETE (Dec 4, 2025)
- ⏭️ Phase 8.5 (GPU Acceleration): **MOVED TO PHASE 9** (see Phase 9 plan below)

**Time Saved:** ~5 weeks (phases 8.3 and 8.4 were already implemented!)

**Phase 8 Status:** ✅ **FUNCTIONALLY COMPLETE** - All core optimization features delivered

---

### Success Criteria for Phase 8

**Technical Metrics:**
- ✅ All sub-phases have 100% test pass rate
- ✅ Sparse matrix operations show 10x+ speedup for 0.1% density
- ✅ Parallel optimizer finds global minimum (COMPLETE via Phase 7)
- ✅ Multi-period optimization produces reasonable rebalancing strategies
- ✅ Robust optimization solutions are more conservative than nominal
- ✅ Code follows Swift 6 strict concurrency requirements
- ✅ All features integrate with existing MCP server

**Deliverables:**
- ✅ Source code with full documentation
- ✅ Comprehensive test suites (TDD approach)
- ✅ MCP tools for each feature
- ✅ Tutorial documentation
- ✅ Performance benchmarks

---

### Phase 8 Execution Strategy

**Session 1 (Current): Phase 8.1 - Sparse Matrix**
1. Create comprehensive test suite FIRST
2. Run tests → verify failures
3. Implement SparseMatrix with CSR format
4. Implement iterative solvers (CG, BiCG)
5. Make all tests pass
6. Create MCP tools
7. Write tutorial

**Session 2: Phase 8.3 - Multi-Period**
1. TDD: Write all tests first
2. Implement multi-period optimizer
3. Portfolio rebalancing example
4. MCP tools + tutorial

**Session 3: Phase 8.4 - Robust**
1. TDD: Write all tests first
2. Implement robust optimizer
3. Uncertainty set handling
4. MCP tools + tutorial

**Final: Phase 8 Complete Summary**
- Update PHASE_8_COMPLETE.md
- Integration testing across all sub-phases
- Performance benchmarking report
- Update main README

---

### TDD Philosophy for Phase 8

**Proven Pattern from Phase 7:**
1. **Write Tests FIRST** (comprehensive, covers all edge cases)
2. **Verify Red** (tests fail because implementation doesn't exist)
3. **Minimal Implementation** (write just enough to pass tests)
4. **Green State** (all tests passing)
5. **Refactor** (improve code while maintaining green)
6. **MCP Integration** (tools + registration)
7. **Documentation** (tutorial + examples)

**Benefits Demonstrated:**
- Catches design issues early (API clarity)
- Ensures complete coverage (no forgotten edge cases)
- Confidence in correctness (tests define specification)
- Faster debugging (tests pinpoint failures)
- Better architecture (testable code is modular code)

**Apply to Each Sub-Phase:**
- Phase 8.1: Test sparse matrix operations before implementation
- Phase 8.3: Test multi-period constraints before optimizer
- Phase 8.4: Test uncertainty handling before robust solver

---

### Next Action: Start Phase 8.1 (Sparse Matrix)

**Immediate Steps:**
1. Create `SparseMatrixTests.swift` with comprehensive test suite
2. Run tests → verify all fail (Red phase)
3. Implement `SparseMatrix.swift` (CSR format)
4. Implement `SparseSolver.swift` (CG, BiCG iterative methods)
5. Make all tests pass (Green phase)
6. Performance benchmark (dense vs sparse)
7. MCP tools + tutorial
8. Mark Phase 8.1 complete

**Ready to proceed with TDD implementation of Sparse Matrix Infrastructure.**

---

## Phase 9: GPU Acceleration (Deferred)

**Status:** 🔮 PLANNED (deferred for future release)
**Original Location:** Phase 8.5
**Estimated Time:** 2 weeks
**Priority:** Performance optimization (not critical for release)

### Overview

Phase 9 focuses on GPU acceleration using Apple's Metal framework to dramatically accelerate heuristic optimization algorithms (genetic algorithms, particle swarm, simulated annealing) through parallel evaluation of objective functions across large populations.

**Expected Performance Gains:**
- **10-100× speedup** for genetic algorithms with populations of 1,000+
- **Parallel fitness evaluation** across thousands of individuals simultaneously
- **GPU-based crossover and mutation** operations
- **Seamless fallback** to CPU when Metal is unavailable

### Rationale for Deferral

GPU acceleration is a **performance enhancement** rather than a **functional requirement**:

1. **CPU Implementation Sufficient:** Current heuristic optimizers work well for typical use cases (populations 100-1,000, dimensions 10-100)
2. **Complexity vs Benefit:** Metal integration requires:
   - Custom Metal shaders (.metal files)
   - Buffer management and data transfer
   - Platform-specific testing (macOS only)
   - Fallback logic for non-Metal systems
3. **Focus on Core Features:** Phase 8 priorities (sparse matrices, multi-period, robust optimization) deliver more immediate value
4. **Future Enhancement Path:** Well-defined scope makes implementation straightforward when needed

### Implementation Scope

**Files to Create:**
- `Sources/BusinessMath/Optimization/GPU/GPUHeuristicOptimizer.swift` (~300 lines)
- `Sources/BusinessMath/Optimization/GPU/Shaders.metal` (~200 lines)
- `Tests/BusinessMathTests/Performance Tests/GPUOptimizationTests.swift` (~200 lines)

**Key Features:**
1. **Metal Device Management**
   - Create Metal device and command queue
   - Compile shader library at initialization
   - Graceful fallback if Metal unavailable

2. **GPU-Accelerated Genetic Algorithm**
   - Parallel fitness evaluation kernel
   - Parallel crossover/mutation kernel
   - Population management on GPU buffers
   - Result transfer back to CPU

3. **Metal Shaders**
   - `evaluateFitness` kernel: Parallel objective function evaluation
   - `crossoverPopulation` kernel: Parallel crossover operations
   - `mutatePopulation` kernel: Parallel mutation operations

4. **Performance Benchmarks**
   - CPU vs GPU comparison (10× speedup target)
   - Population size scaling tests (100 to 10,000)
   - Dimension scaling tests (10 to 1,000)

### Detailed Specification

See lines 2764-2910 of this document for the complete Phase 8.5 specification, including:
- Full `GPUHeuristicOptimizer` implementation skeleton
- Metal shader code examples
- API design for GPU-accelerated genetic algorithms
- Test requirements and success criteria

### When to Implement

**Consider implementing Phase 9 when:**
1. Users request GPU acceleration specifically
2. Performance profiling shows genetic algorithms are a bottleneck
3. Use cases require populations > 10,000
4. Team has bandwidth for platform-specific optimization

**Not needed if:**
- Current CPU performance meets user needs
- Use cases involve small populations (< 1,000)
- Cross-platform compatibility is critical
- Development resources are limited

### Success Criteria

**Technical Metrics:**
- ✅ Metal device initialization and fallback logic
- ✅ GPU genetic algorithm produces same results as CPU (within tolerance)
- ✅ Measured 10× speedup for populations of 1,000+
- ✅ Zero crashes on systems without Metal support
- ✅ All tests pass (CPU and GPU variants)

**Deliverables:**
- ✅ `GPUHeuristicOptimizer.swift` with Metal integration
- ✅ Metal shader files (.metal)
- ✅ Comprehensive test suite with CPU/GPU comparison
- ✅ Performance benchmark results
- ✅ Documentation on when to use GPU vs CPU

---

### Phase 9 Conclusion

GPU acceleration remains a **well-scoped future enhancement** that can be implemented when performance requirements justify the added complexity. The current CPU-based heuristic optimizers in BusinessMath are production-ready and suitable for the vast majority of use cases.

**Current Status:** Phase 8 is functionally complete without GPU acceleration. Phase 9 is deferred to a future release when user demand or performance requirements make it a priority.

