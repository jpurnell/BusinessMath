# Swift 6 Concurrency Migration

**Status**: ✅ **COMPLETED** (February 6, 2026)
**Priority**: High (Required for Swift 6 compatibility)
**Impact**: Breaking changes included in v2.0
**Actual Effort**: 1 day

## Implementation Summary

All Swift 6 concurrency issues have been resolved. The code now compiles cleanly with zero critical errors, and the API is fully consistent with @Sendable requirements across all optimizers.

### Completed Work

**Phase 1: Import Fixes** ✅
- Added `import RealModule` to TestEntity.swift
- Fixed 3 conformance warnings (lines 35, 93, 173)

**Phase 2: Protocol @Sendable Consistency** ✅
- Updated `Optimizer.swift` protocol with @Sendable objective parameter
- Updated `MultivariateOptimizer.swift` protocol with @Sendable in minimize methods
- Updated all sync optimizer implementations:
  - `GradientDescentOptimizer.swift`
  - `GoalSeekOptimizer.swift`
  - `InequalityOptimizer.swift` (both minimize methods)
  - `ConstrainedOptimizer.swift` (both minimize methods)

**Phase 3: ScenarioOptimizer Sendable Constraints** ✅
- Made `ScenarioConstraint` enum Sendable with @Sendable function parameters
- Updated function accessor return type to `@Sendable (V) -> Double`
- Made `expectedObjective` closure @Sendable
- Added explicit @Sendable annotations to ternary operator closures
- Updated `optimizeWeighted` parameter signature
- Made `ScenarioOptimizer` struct Sendable
- Made `NamedScenario` struct Sendable

**Phase 4: Debounce Actor Migration** ✅
- Created `DebounceState` actor for thread-safe state management
- Refactored `AsyncDebounceSequence.Iterator` to use actor isolation
- Eliminated mutable captures in @Sendable closures
- Replaced captured state with proper actor-isolated state

**Phase 5: Code Quality Fixes** ✅
- Changed unused `var converged` to `let` in AsyncGradientDescentOptimizer.swift
- Changed unused loop variable `round` to `_` in BranchAndBound.swift
- Changed unused `var cutsPerRound` to `let` in BranchAndCutSolver.swift

**Additional Advanced Optimizers** ✅
- Added @Sendable to `AdaptiveOptimizer.swift`
- Added @Sendable to `RobustOptimizer.swift` (optimize and minimize methods)
- Added @Sendable to `StochasticOptimizer.swift` (optimize and minimize methods)
- Added @Sendable to `ParallelOptimizer.swift` (internal runSingleOptimization)

**Heuristic Optimizers** ✅
- Added @Sendable to `GeneticAlgorithm.swift` (minimize, optimizeDetailed, and internal optimize methods)
- Fixed runtime cast error: "Could not cast value to '@Sendable closure'"

**Test File Updates** ✅
- Updated 123+ test file closures with @Sendable annotations
- Fixed closure parameter type annotations

**Verification** ✅
- **Core BusinessMath library**: ✅ Builds cleanly with `-Xswiftc -strict-concurrency=complete` (0 errors)
- All optimizer protocols and implementations updated
- All heuristic optimizers (6) fully compliant
- All multivariate algorithms (3) fully compliant
- Actor-based state management in streaming operators
- Only non-critical warnings remain (unhandled README files)

**Note**: MCP-related runtime errors are out of scope as MCP is being extracted from the library.

## Overview

Swift 6 introduces strict concurrency checking that will turn many current warnings into compilation errors. This plan catalogs all concurrency-related warnings in the codebase and provides a systematic approach to achieving full Swift 6 compliance.

### Current State
- ✅ Code compiles successfully in Swift 5 mode
- ⚠️ 30+ concurrency warnings that will become errors in Swift 6
- ⚠️ Non-Sendable function types and closures
- ⚠️ Mutable state shared across concurrent contexts
- ⚠️ Missing Sendable conformances

### Target State
- 🎯 Full Swift 6 compliance with strict concurrency checking enabled
- 🎯 All closures properly marked as `@Sendable` where required
- 🎯 Thread-safe state management in concurrent contexts
- 🎯 Proper Sendable conformances for all shared types

---

## Table of Contents

1. [Issue Categories](#issue-categories)
2. [Sendable Function Type Issues](#sendable-function-type-issues)
3. [Concurrent State Capture Issues](#concurrent-state-capture-issues)
4. [Missing Module Imports](#missing-module-imports)
5. [Code Quality Improvements](#code-quality-improvements)
6. [Migration Strategy](#migration-strategy)
7. [Testing Plan](#testing-plan)
8. [Rollout Plan](#rollout-plan)

---

## Issue Categories

### Priority 1: Critical (Blocks Swift 6 Adoption)

| File | Issue | Lines | Severity |
|------|-------|-------|----------|
| `ScenarioOptimizer.swift` | Non-Sendable function types | 347, 349, 409 | 🔴 High |
| `StreamingComposition.swift` | Non-Sendable type captures | 169, 171, 183-197 | 🔴 High |
| `StreamingComposition.swift` | Concurrent mutable state | 185, 192, 197, 290, 291, 349, 359, 365 | 🔴 High |

### Priority 2: Important (Warnings)

| File | Issue | Lines | Severity |
|------|-------|-------|----------|
| `TestEntity.swift` | Missing RealModule import | 35, 93, 173 | 🟡 Medium |
| `ExpressionFunction.swift` | Type mismatches | 203, 222 | 🟢 Fixed |
| `ExpressionArray.swift` | Ambiguous initializers | 387-401 | 🟢 Fixed |

### Priority 3: Code Quality

| File | Issue | Lines | Severity |
|------|-------|-------|----------|
| `AsyncGradientDescentOptimizer.swift` | Unused variable mutation | 192 | 🔵 Low |
| `BranchAndBound.swift` | Unused loop variable | 730 | 🔵 Low |
| `BranchAndCutSolver.swift` | Unused array mutation | 106 | 🔵 Low |

---

## Sendable Function Type Issues

### Problem: ScenarioOptimizer.swift

**Location**: Lines 347, 349, 409

**Current Code**:
```swift
// Line 347
standardConstraints.append(.equality(function: function, gradient: nil))

// Line 349
standardConstraints.append(.inequality(function: function, gradient: nil))

// Line 409
let objective: @Sendable (V, NamedScenario) -> Double = { x, scenario in
    let index = Int(scenario["index"] ?? 0)
    return scenarioValues[index].objective(x)  // scenarioValues contains non-Sendable functions
}
```

**Issue**:
- Function types `(V) -> Double` are not marked as `@Sendable`
- Array of tuples contains non-Sendable closures
- Captures non-Sendable function types in `@Sendable` closure

**Solution**:

#### Option 1: Mark Functions as Sendable (Preferred)
```swift
// Update constraint types to require Sendable functions
public enum Constraint<T: VectorSpace> where T.Scalar: Real {
    case equality(function: @Sendable (T) -> T.Scalar, gradient: (@Sendable (T) -> T)?)
    case inequality(function: @Sendable (T) -> T.Scalar, gradient: (@Sendable (T) -> T)?)
}

// Update scenario values structure
private var scenarioValues: [(
    name: String,
    probability: Double,
    objective: @Sendable (V) -> Double
)] = []
```

**Pros**: Type-safe, enforces thread safety at compile time
**Cons**: Breaking API change, requires caller updates

#### Option 2: Use Unchecked Sendable (Temporary)
```swift
struct UncheckedSendableFunction<Input, Output>: @unchecked Sendable {
    let function: (Input) -> Output

    init(_ function: @escaping (Input) -> Output) {
        self.function = function
    }

    func callAsFunction(_ input: Input) -> Output {
        function(input)
    }
}
```

**Pros**: Non-breaking, gradual migration
**Cons**: Removes compile-time safety guarantees

#### Recommendation:
Use **Option 1** - This is a major version opportunity to get concurrency right. Most optimization functions are already thread-safe (pure mathematical operations).

---

## Concurrent State Capture Issues

### Problem: StreamingComposition.swift

**Location**: Lines 169-197, 290-293, 349-365

**Current Code**:
```swift
// Lines 169-197: AsyncMergeSequence
var continuationBox: ContinuationBox<Element>!
channel = AsyncStream { cont in
    continuationBox = ContinuationBox(cont)  // ⚠️ Type doesn't conform to Sendable
}

await withTaskGroup(of: Void.self) { group in
    group.addTask { @Sendable in
        var iter = firstIterator  // ⚠️ Non-Sendable capture
        while let value = try? await iter.next() {
            continuationBox.yield(value)  // ⚠️ Concurrent access
        }
    }
}
```

**Issue**:
- `ContinuationBox<Element>` not marked as Sendable
- Concurrent access to mutable `continuationBox` variable
- Captures of non-Sendable iterator types
- Reference to captured var in concurrently-executing code

**Solution**:

#### Step 1: Make ContinuationBox Sendable
```swift
actor ContinuationBox<Element> {
    private var continuation: AsyncStream<Element>.Continuation?
    private var isFinished = false

    init(_ continuation: AsyncStream<Element>.Continuation) {
        self.continuation = continuation
    }

    func yield(_ value: Element) {
        guard !isFinished else { return }
        continuation?.yield(value)
    }

    func finish() {
        guard !isFinished else { return }
        isFinished = true
        continuation?.finish()
        continuation = nil
    }
}
```

**Why Actor?**: Actors provide automatic synchronization for mutable state accessed from multiple concurrent contexts.

#### Step 2: Add Sendable Constraints to Generic Types
```swift
public struct AsyncMergeSequence<First: AsyncSequence, Second: AsyncSequence>: AsyncSequence
where First.Element == Second.Element,
      First.Element: Sendable,  // Add this constraint
      First.AsyncIterator: Sendable,  // Add this constraint
      Second.AsyncIterator: Sendable  // Add this constraint
{
    // Implementation...
}
```

#### Step 3: Use Isolated Variables Pattern
```swift
let continuationBox = ContinuationBox(continuation)  // Change from var to let

await withTaskGroup(of: Void.self) { group in
    group.addTask { @Sendable in
        let iter = firstIterator  // Capture is now isolated to this task
        // Process iterator...
    }
}
```

### Problem: Debounce and CombineLatest

**Location**: Lines 290-293 (debounce), 349-365 (combineLatest)

**Current Code**:
```swift
// Debounce
var lastValue: Element? = nil
debounceTask = Task { @Sendable in
    try? await Task.sleep(for: interval)
    if !Task.isCancelled, let val = lastValue {  // ⚠️ Concurrent access
        continuationBox.yield(val)
    }
}

// CombineLatest
continuationBox.yield((value, second))  // ⚠️ Concurrent access
```

**Solution**: Use actor-isolated state

```swift
actor DebounceState<Element> {
    private var lastValue: Element?
    private var debounceTask: Task<Void, Never>?

    func updateValue(_ value: Element, interval: Duration,
                    onEmit: @Sendable @escaping (Element) async -> Void) {
        lastValue = value
        debounceTask?.cancel()

        let valueToDebounce = value
        debounceTask = Task {
            try? await Task.sleep(for: interval)
            if !Task.isCancelled {
                await onEmit(valueToDebounce)
            }
        }
    }
}
```

---

## Missing Module Imports

### Problem: TestEntity.swift

**Location**: Lines 35, 93, 173

**Current Code**:
```swift
public func createTestIncomeStatement() throws -> IncomeStatement<Double> {
    // ⚠️ Cannot use conformance of 'Double' to 'Real' here
    // ⚠️ 'RealModule' was not imported by this file
}
```

**Issue**: Swift 6 requires explicit imports for protocol conformances used in signatures.

**Solution**:
```swift
// Add at top of file
import RealModule

public func createTestIncomeStatement() throws -> IncomeStatement<Double> {
    let entity = createTestEntity()
    let periods = createTestPeriods()
    // ...
}
```

**Impact**: None - this is a simple import addition.

---

## Code Quality Improvements

### 1. AsyncGradientDescentOptimizer.swift (Line 192)

**Current**:
```swift
var converged = false  // ⚠️ Never mutated
```

**Fix**:
```swift
let converged = false
```

### 2. BranchAndBound.swift (Line 730)

**Current**:
```swift
for round in 0..<maxCuttingRounds {  // ⚠️ 'round' never used
    // Check if solution is fractional...
}
```

**Fix**:
```swift
for _ in 0..<maxCuttingRounds {
    // Check if solution is fractional...
}
```

### 3. BranchAndCutSolver.swift (Line 106)

**Current**:
```swift
var cutsPerRound: [Int] = []  // ⚠️ Never mutated
```

**Fix**: Either remove if unused, or use if it was intended for metrics:
```swift
let cutsPerRound: [Int] = []  // If keeping for future use
// OR remove entirely if not needed
```

---

## Migration Strategy

### Phase 1: Preparation (Week 1)
**Goal**: Understand impact and set up testing infrastructure

- [ ] Enable strict concurrency checking on test targets first
- [ ] Create Swift 6 compatibility feature branch
- [ ] Audit all `@Sendable` requirements across public APIs
- [ ] Document breaking changes for release notes

### Phase 2: Low-Hanging Fruit (Week 1)
**Goal**: Fix simple issues with no API changes

- [ ] Add missing `import RealModule` to TestEntity.swift
- [ ] Fix unused variable warnings (Priority 3 issues)
- [ ] Update internal closures to be `@Sendable` where possible
- [ ] Run test suite to establish baseline

### Phase 3: Sendable Function Types (Week 2)
**Goal**: Make optimization functions Sendable

**Files to Update**:
- [ ] `ScenarioOptimizer.swift` - Add `@Sendable` to function types
- [ ] `Constraint.swift` - Update constraint function signatures
- [ ] `Optimizer.swift` protocol - Update objective function requirements
- [ ] All optimizer implementations - Update to use Sendable functions

**Breaking Changes**:
```swift
// Before
func optimize(objective: (T) -> Double) -> Result

// After
func optimize(objective: @Sendable (T) -> Double) -> Result
```

**Migration Path for Users**:
- Most mathematical functions are already thread-safe
- Capture semantics remain the same
- Compiler will enforce thread safety
- Add migration guide to documentation

### Phase 4: Concurrent State Management (Week 2-3)
**Goal**: Fix StreamingComposition concurrency issues

**Subtasks**:
- [ ] Convert `ContinuationBox` to actor
- [ ] Add Sendable constraints to AsyncSequence types
- [ ] Refactor debounce implementation with actor isolation
- [ ] Refactor combineLatest with actor isolation
- [ ] Update all streaming operators for Sendable conformance

**Testing Focus**:
- Concurrent iteration from multiple tasks
- Stress testing with high-frequency streams
- Memory leak testing with cancellation
- Race condition testing

### Phase 5: Generic Constraints (Week 3)
**Goal**: Add Sendable constraints to generic types

**Strategy**:
```swift
// Add conditional Sendable conformances where possible
extension OptimizationResult: Sendable where T: Sendable {}
extension SimulationResults: Sendable where T: Sendable {}
extension Matrix: Sendable where T: Sendable {}

// Add where clauses to algorithms that need Sendable
func parallelOptimize<T: Real & Sendable>(...) async throws -> Result<T>
```

### Phase 6: Documentation & Release (Week 3)
**Goal**: Document changes and release Swift 6 compatible version

- [ ] Update all API documentation with Sendable requirements
- [ ] Create migration guide (similar to ASYNC_MIGRATION_GUIDE.md)
- [ ] Update README with Swift 6 support
- [ ] Create GitHub release with detailed breaking changes
- [ ] Bump major version (indicates breaking changes)

---

## Testing Plan

### Unit Tests
- [ ] All existing tests pass in Swift 6 mode
- [ ] Add tests for concurrent access patterns
- [ ] Test Sendable conformance with TaskGroup
- [ ] Test actor isolation in StreamingComposition

### Integration Tests
- [ ] Parallel optimization with Sendable functions
- [ ] Concurrent streaming operations
- [ ] Task cancellation across boundaries
- [ ] Memory safety under high concurrency

### Performance Tests
- [ ] Benchmark actor overhead in streaming operations
- [ ] Compare Swift 5 vs Swift 6 performance
- [ ] Stress test with 1000+ concurrent operations
- [ ] Profile memory usage patterns

### Compatibility Tests
- [ ] Test on macOS 13+, iOS 16+
- [ ] Test with Xcode 15 (Swift 5.9)
- [ ] Test with Xcode 16+ (Swift 6.0)
- [ ] Verify backward compatibility where possible

---

## Rollout Plan

### Version Strategy

**v3.0.0 - Full Swift 6 Compliance** (Recommended)
- Breaking changes for Sendable requirements
- All concurrency warnings resolved
- Strict concurrency checking enabled
- Target: Q2 2024

**Migration Path**:
1. v2.x - Current version (Swift 5 mode, warnings)
2. v2.9.x - Pre-release with deprecation warnings
3. v3.0.0 - Swift 6 compliant with breaking changes

### Communication Plan

**For Users**:
1. **Blog Post**: "Preparing for Swift 6" (2 weeks before)
   - Explain upcoming changes
   - Show migration examples
   - Announce timeline

2. **Migration Guide**: Detailed document with:
   - All breaking changes
   - Before/after code examples
   - Common migration patterns
   - FAQ section

3. **GitHub Discussions**: Q&A thread for migration help

4. **Release Notes**: Comprehensive changelog with:
   - Breaking changes highlighted
   - Migration steps for each change
   - New features enabled by Swift 6

---

## Risk Assessment

### High Risk
⚠️ **API Breaking Changes**: Sendable requirements may break existing code
- **Mitigation**: Comprehensive migration guide, deprecated transitional APIs

⚠️ **Performance Impact**: Actor isolation may add overhead
- **Mitigation**: Benchmark before/after, optimize hot paths

### Medium Risk
⚠️ **Third-party Dependencies**: May not be Swift 6 compatible yet
- **Mitigation**: Audit dependencies, contribute fixes upstream

⚠️ **Generic Constraint Complexity**: Sendable constraints may complicate APIs
- **Mitigation**: Use conditional conformance, clear documentation

### Low Risk
✅ **Most Code Already Thread-Safe**: Mathematical operations are pure functions
✅ **Strong Type System**: Compiler catches issues at build time
✅ **Async Already Adopted**: Concurrency patterns already in place

---

## Success Metrics

- [ ] Zero concurrency warnings in Swift 6 mode
- [ ] All unit tests pass in strict concurrency mode
- [ ] No performance regression >5% on key benchmarks
- [ ] Migration guide completed with 10+ examples
- [ ] At least 3 beta users successfully migrate

---

## Resources

### Documentation
- [Swift 6 Concurrency Migration Guide](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/)
- [SE-0302: Sendable and @Sendable closures](https://github.com/apple/swift-evolution/blob/main/proposals/0302-concurrent-value-and-concurrent-closures.md)
- [Actors and Actor Isolation](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Actors)

### Related Plans
- `ASYNC_MIGRATION_GUIDE.md` - Async/await patterns already established
- `MIGRATION_GUIDE_v2.0.md` - Previous major version migration

### Tools
- Swift 6 compiler warnings as guidelines
- Thread Sanitizer for race condition detection
- Instruments for performance profiling

---

## Next Steps

1. **Immediate** (This Week):
   - [ ] Review and approve this plan
   - [ ] Create GitHub project board for tracking
   - [ ] Set up Swift 6 CI workflow
   - [ ] Schedule kickoff meeting

2. **Short Term** (Next 2 Weeks):
   - [ ] Create feature branch
   - [ ] Begin Phase 1 & 2 work
   - [ ] Start drafting migration guide
   - [ ] Reach out to beta testers

3. **Medium Term** (Next Month):
   - [ ] Complete Phase 3-5
   - [ ] Comprehensive testing
   - [ ] Documentation review
   - [ ] Beta release for feedback

4. **Long Term** (Q2 2024):
   - [ ] Final v3.0.0 release
   - [ ] Monitor adoption and feedback
   - [ ] Continue to refine based on real-world usage

---

## Approval

**Prepared By**: Claude (Claude Code)
**Date**: 2024-02-06
**Review Status**: Pending

**Stakeholder Sign-off**:
- [ ] Lead Developer
- [ ] Architecture Review
- [ ] QA Team

---

## Appendix A: Full Warning List

```
File: ScenarioOptimizer.swift
- Line 347: converting non-sendable function value to '@Sendable (V) -> Double'
- Line 349: converting non-sendable function value to '@Sendable (V) -> Double'
- Line 409: capture of 'scenarioValues' with non-sendable type

File: TestEntity.swift
- Line 35: cannot use conformance of 'Double' to 'Real' (missing RealModule import)
- Line 93: cannot use conformance of 'Double' to 'Real' (missing RealModule import)
- Line 173: cannot use conformance of 'Double' to 'Real' (missing RealModule import)

File: AsyncGradientDescentOptimizer.swift
- Line 192: variable 'converged' was never mutated

File: BranchAndBound.swift
- Line 730: immutable value 'round' was never used

File: BranchAndCutSolver.swift
- Line 106: variable 'cutsPerRound' was never mutated

File: StreamingComposition.swift
- Line 169: type 'Element' does not conform to 'Sendable'
- Line 171: type 'First.Element' does not conform to 'Sendable' (ContinuationBox init)
- Line 183: capture of 'firstIterator' with non-sendable type 'First.AsyncIterator'
- Line 185: capture of 'continuationBox' with non-sendable type 'ContinuationBox<Element>?'
- Line 185: reference to captured var 'continuationBox' in concurrently-executing code
- Line 190: capture of 'secondIterator' with non-sendable type 'Second.AsyncIterator'
- Line 197: reference to captured var 'continuationBox' in concurrently-executing code
- Line 290: reference to captured var 'lastValue' in concurrently-executing code
- Line 291: reference to captured var 'continuationBox' in concurrently-executing code
- Line 349: reference to captured var 'continuationBox' in concurrently-executing code
- Line 359: reference to captured var 'continuationBox' in concurrently-executing code
- Line 365: reference to captured var 'continuationBox' in concurrently-executing code
```

---

**Total Warnings**: 30+
**Critical Issues**: 3 files
**Estimated LOC Impact**: ~500 lines
**API Breaking Changes**: Medium (Sendable constraints)
