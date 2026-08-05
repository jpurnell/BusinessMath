# Tier 3 Implementation Plan: Numerical Robustness

## Summary

**Complexity**: Medium (3-5 days of focused work)
**Impact**: High (prevents numerical failures in production)
**Dependencies**: SimplexSolver basis tracking

---

## Feature 1: Cut Scaling and Normalization

### What It Does
Normalizes cut coefficients to prevent ill-conditioned LPs and numerical instability.

### Implementation Requirements

#### 1.1 Add Configuration Parameters
**File**: `BranchAndBound.swift`
```swift
public let normalizeCuts: Bool = true
public let cutScalingNorm: CutNorm = .euclidean  // or .infinity
public let cutCoefficientThreshold: Double = 1e-8
```

**Effort**: 5 minutes

#### 1.2 Implement Cut Normalization
**File**: `BranchAndBound.swift` (in cutting plane loop, ~line 590)
```swift
// After generating cut, before adding to constraint list
if normalizeCuts {
    let norm = cutScalingNorm == .euclidean
        ? sqrt(cut.coefficients.reduce(0.0) { $0 + $1 * $1 })
        : cut.coefficients.map(abs).max() ?? 1.0

    if norm > cutCoefficientThreshold {
        // Normalize: divide all coefficients and RHS by norm
        let normalizedCoeffs = cut.coefficients.map { $0 / norm }
        let normalizedRHS = cut.rhs / norm

        cut = CuttingPlane(
            coefficients: normalizedCoeffs,
            rhs: normalizedRHS,
            type: cut.type
        )
    } else {
        // Skip cut with tiny coefficients
        continue
    }
}
```

**Effort**: 30 minutes
**Complexity**: Low - straightforward vector normalization

#### 1.3 Filter Small Coefficients
**Already in normalization above** - coefficients below threshold are rejected

**Total Effort**: ~1 hour (including tests)

---

## Feature 2: Degeneracy and Cycling Protection

### What It Does
Detects stagnation (no bound improvement) and cycling (repeated solutions) to prevent infinite loops.

### Implementation Requirements

#### 2.1 Add Configuration Parameters
**File**: `BranchAndBound.swift`
```swift
public let detectStagnation: Bool = true
public let stagnationTolerance: Double = 1e-8
public let detectCycling: Bool = true
public let cyclingWindowSize: Int = 5  // Check last N solutions
```

**Effort**: 5 minutes

#### 2.2 Track Bound History
**File**: `BranchAndBound.swift` (in `solveRelaxation`, ~line 520)
```swift
// Inside cutting plane loop
var boundHistory: [Double] = []
var solutionHistory: [[Double]] = []

for round in 0..<maxCuttingRounds {
    // ... generate cuts ...

    // After LP re-solve
    if detectStagnation {
        boundHistory.append(resolvedResult.objectiveValue)

        // Check if bound improved
        if boundHistory.count >= 2 {
            let improvement = abs(boundHistory.last! - boundHistory[boundHistory.count - 2])
            if improvement < stagnationTolerance {
                // No meaningful improvement - terminate
                break
            }
        }
    }

    if detectCycling && resolvedResult.solution != nil {
        solutionHistory.append(resolvedResult.solution!.toArray())

        // Check for repeated solutions
        if solutionHistory.count > cyclingWindowSize {
            let current = solutionHistory.last!
            let recent = solutionHistory.suffix(cyclingWindowSize).dropLast()

            for prev in recent {
                if solutionsEqual(current, prev, tolerance: stagnationTolerance) {
                    // Cycling detected - terminate
                    break
                }
            }
        }
    }
}
```

**Effort**: 1 hour
**Complexity**: Medium - requires tracking state across iterations

#### 2.3 Add Helper Function
```swift
private func solutionsEqual(_ a: [Double], _ b: [Double], tolerance: Double) -> Bool {
    guard a.count == b.count else { return false }
    return zip(a, b).allSatisfy { abs($0 - $1) < tolerance }
}
```

**Effort**: 10 minutes

**Total Effort**: ~2 hours (including tests)

---

## Feature 3: Warm Starts and Basis Reuse

### What It Does
Reuses simplex bases when re-solving LP with added cuts, dramatically improving performance.

### Implementation Requirements

#### 3.1 Add Configuration Parameter
**File**: `BranchAndBound.swift`
```swift
public let enableWarmStart: Bool = true
```

**Effort**: 2 minutes

#### 3.2 Extend SimplexSolver API
**File**: `SimplexSolver.swift`

Currently:
```swift
public func minimize(objective: [Double], subjectTo constraints: [SimplexConstraint]) throws -> SimplexResult
```

Need to add:
```swift
public func minimize(
    objective: [Double],
    subjectTo constraints: [SimplexConstraint],
    initialBasis: [Int]? = nil  // NEW PARAMETER
) throws -> SimplexResult
```

**Implementation**:
```swift
// In solve() method, after building initial tableau
if let basis = initialBasis {
    // Validate basis is feasible for new problem
    if isValidBasis(basis, tableau: workingTableau) {
        // Use provided basis instead of artificial variables
        workingTableau.basis = basis
        skipPhaseI = true
    }
}
```

**Effort**: 2-3 hours
**Complexity**: High - requires understanding simplex implementation, basis validation

#### 3.3 Use Warm Start in BranchAndBound
**File**: `BranchAndBound.swift` (cutting plane loop, ~line 635)
```swift
// Track previous basis
var previousBasis: [Int]? = result.simplexResult?.basis

for round in 0..<maxCuttingRounds {
    // ... generate cuts ...

    // Re-solve with warm start
    if enableWarmStart && previousBasis != nil {
        // Extend basis for new slack variables from cuts
        let extendedBasis = extendBasis(previousBasis!, newConstraints: cutsThisRound.count)

        let resolvedResult = try relaxationSolver.solveRelaxation(
            objective: objective,
            constraints: currentConstraints,
            initialGuess: initialGuess,
            minimize: minimize,
            initialBasis: extendedBasis  // Pass basis
        )

        previousBasis = resolvedResult.simplexResult?.basis
    } else {
        // Cold start
        let resolvedResult = try relaxationSolver.solveRelaxation(...)
    }
}
```

**Effort**: 1 hour
**Complexity**: Medium - integrating with existing flow

#### 3.4 Basis Extension Helper
```swift
private func extendBasis(_ basis: [Int], newConstraints: Int) -> [Int] {
    // When adding constraints, new slack variables are initially basic
    // Extend basis: original basis + new slack indices
    let numOriginalSlacks = basis.count
    let newSlackIndices = (numOriginalSlacks..<(numOriginalSlacks + newConstraints))
    return basis + Array(newSlackIndices)
}
```

**Effort**: 30 minutes

**Total Effort**: ~5 hours (including SimplexSolver changes and tests)

---

## Overall Implementation Plan

### Phase 1: Cut Scaling (Day 1, 3-4 hours)
1. ✅ Write tests (done above)
2. Add configuration parameters
3. Implement normalization logic
4. Add coefficient filtering
5. Run tests, verify GREEN

### Phase 2: Degeneracy Protection (Day 2, 3-4 hours)
1. Add configuration parameters
2. Implement bound tracking
3. Implement stagnation detection
4. Implement cycling detection
5. Add helper functions
6. Run tests, verify GREEN

### Phase 3: Warm Start (Days 3-5, 8-12 hours)
1. Design SimplexSolver basis API extension
2. Implement basis validation in SimplexSolver
3. Extend SimplexSolver.minimize() signature
4. Modify solve() to use initial basis
5. Implement basis extension logic in BranchAndBound
6. Integrate warm start into cutting loop
7. Test with/without warm start for performance
8. Run tests, verify GREEN

### Total Effort Estimate
- **Minimum**: 14 hours (~2 days focused work)
- **Expected**: 20 hours (~3 days with testing/debugging)
- **Maximum**: 32 hours (~4-5 days with unexpected issues)

---

## Risks and Challenges

### High Risk: Warm Start Basis Validation
**Challenge**: Validating that a basis from problem P is valid for problem P+cuts

**Mitigation**:
- Start with simple validation (basis size matches problem)
- Fall back to cold start if basis is invalid
- Extensive testing with various cut types

### Medium Risk: Numerical Precision
**Challenge**: Normalization might introduce rounding errors

**Mitigation**:
- Use double precision throughout
- Add tests with known problematic cases
- Compare normalized vs non-normalized results

### Low Risk: Stagnation False Positives
**Challenge**: Might terminate prematurely on legitimately slow improvement

**Mitigation**:
- Tunable tolerance parameter
- Require multiple consecutive rounds of stagnation
- Statistics tracking to monitor false positives

---

## Expected Performance Improvements

### Cut Scaling
- **Impact**: Prevents numerical failures (crashes → success)
- **Overhead**: ~5% slowdown from normalization
- **Net**: Huge win on ill-conditioned problems

### Degeneracy Protection
- **Impact**: Prevents infinite loops (timeout → fast termination)
- **Overhead**: Negligible (~1% from history tracking)
- **Net**: Prevents worst-case behavior

### Warm Start
- **Impact**: 30-70% reduction in simplex iterations per re-solve
- **Overhead**: Minimal (basis bookkeeping)
- **Net**: Massive speedup on problems with many cuts

**Combined**: Could see 2-10x performance improvement on difficult instances while preventing numerical failures.

---

## Testing Strategy

### Unit Tests (Already Written)
- ✅ 11 tests in BranchAndCutTier3Tests.swift

### Integration Tests
- Large-scale problems with many cuts
- Ill-conditioned coefficient matrices
- Near-degenerate constraint sets

### Performance Benchmarks
- Before/after comparisons
- Warm start vs cold start
- Normalized vs raw cuts

### Regression Tests
- Ensure all existing tests still pass
- No degradation on well-conditioned problems

---

## Recommendation

**Start with Phase 1 (Cut Scaling)** - lowest effort, high impact, no dependencies.

**Then Phase 2 (Degeneracy Protection)** - prevents infinite loops, clean implementation.

**Finally Phase 3 (Warm Start)** - highest complexity but biggest performance win.

All three features are **independent** and can be implemented incrementally without breaking existing functionality.
