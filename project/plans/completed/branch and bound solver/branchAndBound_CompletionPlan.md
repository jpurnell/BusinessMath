# Branch-and-Bound Solver: Systematic Completion Plan

**Goal**: Transform current implementation into a mathematically provable, numerically robust, production-grade solver.

**Approach**: Test-Driven Development with formal verification at each phase.

---

## Phase Classification

### 🔴 **Phase 1: Critical Correctness** (MUST FIX - Weeks 1-2)
Mathematical soundness issues that affect correctness on ALL problems.

### 🟡 **Phase 2: Numerical Robustness** (SHOULD FIX - Weeks 3-4)
Issues that cause failures on difficult/ill-conditioned problems.

### 🟢 **Phase 3: Algorithmic Completeness** (NICE TO HAVE - Weeks 5-6)
Features that improve performance but don't affect correctness.

### 🔵 **Phase 4: Production-Grade** (POLISH - Weeks 7-8)
Performance, memory, and diagnostics for production deployment.

---

## 🔴 PHASE 1: Critical Correctness (Priority 1 - MUST FIX)

**Estimated Time**: 10-14 days
**Risk Level**: HIGH - affects correctness

### 1.1 Bound Semantics & Sign Conventions
**File**: `BranchAndBound.swift`
**Estimated Time**: 2 days

#### Issues
- Minimization/maximization bound direction not enforced
- `relativeGap` assumes minimization
- `bestBound` updates use raw comparisons

#### Implementation
```swift
// Add helper functions
private func isBetterBound(_ a: Double, _ b: Double, minimize: Bool) -> Bool {
    return minimize ? (a < b) : (a > b)
}

private func isValidBound(_ bound: Double, _ incumbent: Double, minimize: Bool) -> Bool {
    return minimize ? (bound <= incumbent) : (bound >= incumbent)
}

private func computeGap(incumbent: Double, bound: Double, minimize: Bool) -> Double {
    let gap = minimize ? (incumbent - bound) : (bound - incumbent)
    return max(0.0, gap)  // Gap should never be negative
}
```

#### Tests
- [x] Minimization: relaxation bound < incumbent
- [x] Maximization: relaxation bound > incumbent
- [x] Gap always non-negative
- [x] Gap computation correct for both directions
- [x] Bound comparisons use helpers everywhere

#### Files to Modify
- `BranchAndBound.swift`: Add helpers, replace all bound comparisons
- Create `Tests/.../BoundSemanticsTests.swift`: 10-12 tests

**Effort**: 8-12 hours (including comprehensive tests)

---

### 1.2 LP Status Handling (Infeasible vs Unbounded)
**File**: `BranchAndBound.swift`
**Estimated Time**: 1 day

#### Issues
- Currently: `status != .optimal` → prune node
- Problem: Unbounded LP may have bounded integer solution

#### Implementation
```swift
// In solveRelaxation()
guard result.status == .optimal else {
    switch result.status {
    case .infeasible:
        // Prune - no integer solution possible
        return BranchNode(/* infeasible */)

    case .unbounded:
        // Continue branching with safeguards
        // Use large but finite bound
        let safeBound = minimize ? -1e20 : 1e20
        return BranchNode(bound: safeBound, /* ... */)

    case .numericalFailure:
        // Log warning, try alternate solver or prune
        return BranchNode(/* infeasible with warning */)
    }
}
```

#### Tests
- [x] Infeasible LP → infeasible IP
- [x] Unbounded LP with integer constraints → bounded IP
- [x] Numerical failure handling
- [x] Status propagation to result

**Effort**: 4-6 hours

---

### 1.3 Integer Feasibility Validation
**File**: `BranchAndBound.swift`
**Estimated Time**: 2 days

#### Issues
- No constraint re-check after rounding
- Implicit integrality from tight bounds not detected
- Tolerance inconsistency

#### Implementation
```swift
/// Centralized integer feasibility checker
private func isIntegerFeasible(
    solution: V,
    constraints: [MultivariateConstraint<V>],
    integerSpec: IntegerProgramSpecification,
    tolerance: Double
) -> Bool {
    let arr = solution.toArray()

    // 1. Check integrality
    for i in integerSpec.allIntegerIndices {
        let value = arr[i]
        let fractionalPart = abs(value - round(value))
        if fractionalPart > tolerance {
            return false
        }
    }

    // 2. Check constraint satisfaction
    for constraint in constraints {
        let violation = constraint.violation(at: solution)
        if violation > tolerance {
            return false
        }
    }

    return true
}
```

#### Tests
- [x] Integer variables within tolerance
- [x] Binary variables ∈ {0,1}
- [x] Rounded solution satisfies constraints
- [x] Solution near boundary is validated
- [x] Solution that violates constraint is rejected

**Effort**: 8-10 hours

---

### 1.4 Objective Value Consistency with Shifting
**File**: `BranchAndBound.swift`, `VariableShift.swift`
**Estimated Time**: 1 day

#### Issues
- Objective computed in shifted space
- Solution unshifted but objective value reused
- Incorrect if objective depends on absolute values

#### Implementation
```swift
// Store both values
struct IncumbentSolution {
    let solution: V                  // Unshifted
    let shiftedSolution: V           // Shifted
    let objectiveValue: Double       // In original space
    let shiftedObjectiveValue: Double
}

// After finding incumbent:
let shiftedValue = objective(shiftedSolution)
let unshiftedSolution = variableShift.unshift(shiftedSolution)
let trueValue = objective(unshiftedSolution)  // Recompute!

incumbent = IncumbentSolution(
    solution: unshiftedSolution,
    shiftedSolution: shiftedSolution,
    objectiveValue: trueValue,
    shiftedObjectiveValue: shiftedValue
)
```

#### Tests
- [x] Objective value matches unshifted solution
- [x] Shifted/unshifted values tracked separately
- [x] Linear objective → values equal
- [x] Absolute-value objective → values may differ

**Effort**: 4-6 hours

---

## 🔴 PHASE 2: Cutting Plane Mathematical Validity

### 2.1 Gomory Cut Validity Guards
**File**: `CuttingPlaneGenerator.swift`
**Estimated Time**: 1.5 days

#### Issues
- No check that basis variable is original (not slack)
- No check that basis variable is integer-constrained
- No check that RHS is truly fractional

#### Implementation
```swift
func generateGomoryCut(...) -> CuttingPlane? {
    // Guard 1: Basic variable must be integer-constrained
    guard integerSpec.isInteger(basicVariableIndex) else {
        return nil  // Skip continuous basic variables
    }

    // Guard 2: RHS must be fractional
    let fractionalPart = rhs - floor(rhs)
    guard fractionalPart > fractionalTolerance &&
          fractionalPart < 1.0 - fractionalTolerance else {
        return nil  // Skip nearly-integer RHS
    }

    // Guard 3: Basic variable must be original (not slack)
    guard basicVariableIndex < numOriginalVariables else {
        return nil  // Skip slack/artificial variables
    }

    // ... generate cut ...
}
```

#### Tests
- [x] Cut not generated for continuous basic variable
- [x] Cut not generated for nearly-integer RHS
- [x] Cut not generated for slack variables
- [x] Cut generated for valid fractional integer variable

**Effort**: 6-8 hours

---

### 2.2 Cut Violation Validation
**File**: `BranchAndBound.swift`
**Estimated Time**: 1 day

#### Issues
- Cuts added without checking if they actually cut off current solution
- Leads to useless/harmful cuts

#### Implementation
```swift
// Before adding cut:
let violation = cut.evaluate(at: currentSolution) - cut.rhs
guard violation > cutTolerance else {
    // Cut doesn't violate current solution - skip
    continue
}

// Only add violating cuts
cutsThisRound.append(cut)
```

#### Tests
- [x] Non-violating cuts rejected
- [x] Violating cuts accepted
- [x] Tolerance respected
- [x] Cut violation measured correctly

**Effort**: 4-5 hours

---

### 2.3 Cut Deduplication (Replace String Hashing)
**File**: `BranchAndBound.swift`
**Estimated Time**: 1 day

#### Issues
- String formatting to 6 decimals is numerically unsound
- Different cuts may collide
- Identical cuts may differ in low bits

#### Implementation
```swift
struct CutSignature: Hashable {
    let quantizedCoefficients: [Int64]  // Quantize to fixed precision
    let quantizedRHS: Int64

    init(cut: CuttingPlane, precision: Double = 1e-9) {
        self.quantizedCoefficients = cut.coefficients.map { coeff in
            Int64(round(coeff / precision))
        }
        self.quantizedRHS = Int64(round(cut.rhs / precision))
    }
}

// Usage:
var generatedCuts: Set<CutSignature> = []
let signature = CutSignature(cut)
if !generatedCuts.contains(signature) {
    cutsThisRound.append(cut)
    generatedCuts.insert(signature)
}
```

#### Tests
- [x] Identical cuts deduplicated
- [x] Nearly-identical cuts (within precision) deduplicated
- [x] Different cuts not collided
- [x] Normalized vs unnormalized cuts handled

**Effort**: 4-6 hours

---

## 🟡 PHASE 3: Numerical Robustness

### 3.1 Tolerance Hierarchy & Validation
**File**: `BranchAndBound.swift`
**Estimated Time**: 0.5 days

#### Issues
- No documented relationship between tolerances
- Can lead to contradictory checks

#### Implementation
```swift
public init(...) {
    // Validate tolerance hierarchy
    precondition(lpTolerance <= integralityTolerance,
        "lpTolerance must be ≤ integralityTolerance")
    precondition(integralityTolerance <= cutTolerance,
        "integralityTolerance must be ≤ cutTolerance")

    // Auto-adjust if needed
    if lpTolerance > integralityTolerance {
        print("Warning: Adjusting lpTolerance to match integralityTolerance")
        self.lpTolerance = integralityTolerance
    }

    // ... rest of init ...
}
```

#### Tests
- [x] Tolerance hierarchy enforced
- [x] Invalid tolerances rejected
- [x] Auto-adjustment works
- [x] Warning messages emitted

**Effort**: 2-3 hours

---

### 3.2 Post-Solve Verification
**File**: `BranchAndBound.swift`
**Estimated Time**: 1 day

#### Issues
- No final validation of solution
- Constraint violations may go undetected
- Objective value not rechecked

#### Implementation
```swift
private func verifySolution(
    solution: V,
    objective: @Sendable (V) -> Double,
    constraints: [MultivariateConstraint<V>],
    integerSpec: IntegerProgramSpecification,
    expectedObjective: Double
) -> SolutionVerification {
    var violations: [String] = []

    // Check integrality
    let arr = solution.toArray()
    for i in integerSpec.allIntegerIndices {
        let frac = abs(arr[i] - round(arr[i]))
        if frac > integralityTolerance {
            violations.append("Variable \(i) not integer: \(arr[i])")
        }
    }

    // Check constraints
    for (idx, constraint) in constraints.enumerated() {
        let viol = constraint.violation(at: solution)
        if viol > lpTolerance {
            violations.append("Constraint \(idx) violated by \(viol)")
        }
    }

    // Check objective
    let actualObjective = objective(solution)
    if abs(actualObjective - expectedObjective) > lpTolerance {
        violations.append("Objective mismatch: expected \(expectedObjective), got \(actualObjective)")
    }

    return SolutionVerification(
        isValid: violations.isEmpty,
        violations: violations
    )
}
```

#### Tests
- [x] Valid solution passes verification
- [x] Invalid integrality detected
- [x] Constraint violations detected
- [x] Objective mismatches detected

**Effort**: 4-6 hours

---

## 🟢 PHASE 4: Algorithmic Completeness

### 4.1 Pseudo-Cost Branching
**File**: `BranchAndBound.swift`
**Estimated Time**: 2 days

#### Issues
- Currently falls back to mostFractional
- Loses significant performance

#### Implementation
```swift
class PseudoCostTracker {
    var upCosts: [Int: (sum: Double, count: Int)] = [:]
    var downCosts: [Int: (sum: Double, count: Int)] = [:]

    func updateCost(variable: Int, direction: BranchDirection,
                   boundImprovement: Double, fractionalChange: Double) {
        let cost = boundImprovement / fractionalChange

        switch direction {
        case .up:
            let current = upCosts[variable] ?? (0, 0)
            upCosts[variable] = (current.sum + cost, current.count + 1)
        case .down:
            let current = downCosts[variable] ?? (0, 0)
            downCosts[variable] = (current.sum + cost, current.count + 1)
        }
    }

    func getScore(variable: Int) -> Double {
        let upCost = upCosts[variable]?.sum ?? 0.0
        let downCost = downCosts[variable]?.sum ?? 0.0
        return min(upCost, downCost)  // Pessimistic estimate
    }
}
```

#### Tests
- [x] Costs tracked correctly
- [x] Scores computed correctly
- [x] Variable selection improves over mostFractional
- [x] Fallback to mostFractional when no history

**Effort**: 8-12 hours

---

### 4.2 Strong Branching
**File**: `BranchAndBound.swift`
**Estimated Time**: 3 days

#### Issues
- Not implemented
- Significant performance benefit

#### Implementation
```swift
func strongBranching(
    candidates: [Int],
    node: BranchNode<V>
) -> Int {
    var bestVariable = candidates[0]
    var bestScore = -Double.infinity

    for variable in candidates {
        // Solve temporary LPs with up/down branches
        let upBound = solveTemporaryLP(variable: variable, direction: .up)
        let downBound = solveTemporaryLP(variable: variable, direction: .down)

        // Score: product of improvements
        let score = (upBound - node.relaxationBound) *
                   (downBound - node.relaxationBound)

        if score > bestScore {
            bestScore = score
            bestVariable = variable
        }
    }

    return bestVariable
}
```

#### Tests
- [x] Strong branching selects correct variable
- [x] Temporary LPs solved correctly
- [x] Performance better than mostFractional
- [x] Limit on number of strong branch candidates

**Effort**: 12-16 hours

---

### 4.3 Rounding Heuristic
**File**: `BranchAndBound.swift`
**Estimated Time**: 1.5 days

#### Issues
- No primal heuristics
- Misses easy incumbents

#### Implementation
```swift
func roundingHeuristic(solution: V) -> V? {
    var rounded = solution.toArray()

    // Round all integer variables
    for i in integerSpec.allIntegerIndices {
        rounded[i] = round(rounded[i])
    }

    let roundedSolution = V.fromArray(rounded)

    // Check feasibility
    if isIntegerFeasible(roundedSolution, ...) {
        return roundedSolution
    }

    // Try feasibility repair
    return repairFeasibility(roundedSolution)
}
```

#### Tests
- [x] Rounding produces integer solution
- [x] Infeasible rounded solution repaired
- [x] Incumbent found earlier than branching
- [x] Performance improvement

**Effort**: 6-8 hours

---

## 🔵 PHASE 5: Production-Grade Features

### 5.1 Efficient Node Queue (Binary Heap)
**File**: `BranchAndBound.swift`
**Estimated Time**: 2 days

#### Issues
- O(n log n) sorting per insert
- Collapses at scale

#### Implementation
- Use Swift Collections `Heap` type
- Custom comparator for node priorities
- Stable ordering for determinism

**Effort**: 8-10 hours

---

### 5.2 Constraint Memory Optimization
**File**: `BranchAndBound.swift`
**Estimated Time**: 3 days

#### Issues
- Each node copies full constraint array
- Wasteful for deep trees

#### Implementation
- Persistent constraint tree
- Copy-on-write semantics
- Delta encoding per node

**Effort**: 12-16 hours

---

### 5.3 Cut Aging & Pool Management
**File**: `BranchAndBound.swift`, new `CutPool.swift`
**Estimated Time**: 2 days

#### Issues
- Cuts never removed
- Memory grows unbounded

#### Implementation
```swift
class CutPool {
    struct ManagedCut {
        let cut: CuttingPlane
        var age: Int
        var activity: Double
        var efficacy: Double
    }

    var cuts: [ManagedCut] = []
    let maxSize: Int
    let maxAge: Int

    func ageCuts() {
        cuts = cuts.map { cut in
            var aged = cut
            aged.age += 1
            return aged
        }

        // Remove old inactive cuts
        cuts.removeAll { $0.age > maxAge && $0.activity < 1e-6 }
    }
}
```

**Effort**: 8-10 hours

---

## Implementation Timeline

### Week 1-2: Critical Correctness
**Days 1-2**: Bound semantics
**Days 3-4**: Integer feasibility validation
**Day 5**: LP status handling
**Day 6**: Objective consistency
**Days 7-8**: Gomory validity guards
**Days 9-10**: Cut violation & deduplication

**Deliverable**: All Phase 1 & 2 issues resolved, proven correct

---

### Week 3-4: Numerical Robustness
**Days 11-12**: Tolerance hierarchy
**Days 13-14**: Post-solve verification
**Day 15**: Cycling detection improvements
**Day 16**: Constraint scaling (optional)
**Days 17-20**: Comprehensive testing & stress tests

**Deliverable**: Solver robust on ill-conditioned problems

---

### Week 5-6: Algorithmic Completeness (Optional)
**Days 21-23**: Pseudo-cost branching
**Days 24-27**: Strong branching
**Days 28-30**: Rounding heuristic

**Deliverable**: Performance competitive with commercial solvers

---

### Week 7-8: Production Grade (Optional)
**Days 31-33**: Binary heap node queue
**Days 34-37**: Constraint memory optimization
**Days 38-40**: Cut aging & pool management

**Deliverable**: Production-ready, scalable solver

---

## Testing Strategy

### Unit Tests (Per Feature)
- Each feature gets 5-10 targeted unit tests
- Test both success and failure cases
- Test boundary conditions

### Property Tests
- Gap is always non-negative
- Bounds are always valid for min/max direction
- Integer solutions satisfy all constraints
- Objective value matches solution

### Adversarial Tests
- Ill-conditioned constraints
- Degenerate problems
- Nearly-integer fractional values
- Extreme coefficient ranges

### Regression Tests
- Known B&B failure cases from literature
- User-reported bugs
- Edge cases from prior testing

---

## Verification Checklist

After each phase:
- [ ] All unit tests pass
- [ ] Property tests pass 1000+ iterations
- [ ] Adversarial tests don't crash
- [ ] Performance within 2x of baseline
- [ ] Memory usage reasonable
- [ ] Documentation updated
- [ ] Code review completed

---

## Risk Assessment

### High Risk (Likely to encounter issues)
- Strong branching (complex, many edge cases)
- Constraint memory optimization (tricky to get right)
- Cut normalization vs integrality (numerical subtleties)

### Medium Risk
- Pseudo-cost tracking (bookkeeping complexity)
- LP status handling (depends on SimplexSolver behavior)
- Tolerance hierarchy (may break existing tests)

### Low Risk
- Bound semantics (straightforward)
- Post-solve verification (self-contained)
- Cut deduplication (isolated change)

---

## Success Criteria

### Minimal (Phase 1-2)
- ✅ Mathematically provable correctness
- ✅ Passes all property tests
- ✅ No failures on standard test suite
- ✅ Documented guarantees

### Target (Phase 1-3)
- ✅ Above + algorithmic completeness
- ✅ Performance competitive with open-source solvers
- ✅ Robust on difficult problems

### Stretch (Phase 1-4)
- ✅ Production-ready
- ✅ Scales to 1000+ nodes
- ✅ Memory-efficient
- ✅ Industry-grade robustness

---

## Next Steps

1. **Review this plan** - Adjust priorities based on your needs
2. **Choose phases** - Decide which phases to implement
3. **Start with Phase 1.1** - Bound semantics (highest impact)
4. **Test-driven** - Write tests first for each feature
5. **Iterate** - Complete one feature at a time, verify, move on

**Recommended Starting Point**: Phase 1.1 (Bound Semantics)
- Highest impact on correctness
- Affects all other features
- Relatively straightforward
- Clear testing criteria
