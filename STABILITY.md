# API Stability Guarantees: BusinessMath 2.x

This document outlines API stability commitments for the BusinessMath 2.x release series.

---

## Version 2.0 Commitment

BusinessMath 2.0 marks a **production-ready**, **API-stable** release suitable for long-term use in applications.

### What "Stable" Means

- **No breaking changes** within 2.x series (2.0 → 2.1 → 2.2, etc.)
- **Semantic versioning** strictly followed
- **Deprecation warnings** before removal (minimum 2 minor versions)
- **Comprehensive testing** (3,013 tests across 240 suites)
- **Extensive documentation** (52 tutorial guides + API reference)

---

## Stable APIs

The following APIs are **guaranteed stable** for all 2.x releases:

### Core Protocols

✅ **`Optimizer`** - Scalar optimization interface
```swift
func optimize(
    objective: @escaping (T) -> T,
    constraints: [Constraint<T>],
    initialGuess: T,  // Stable parameter name
    bounds: (lower: T, upper: T)?
) -> OptimizationResult<T>
```

✅ **`MultivariateOptimizer`** - Multivariate optimization interface
```swift
func minimize(
    _ objective: @escaping (V) -> V.Scalar,
    from initialGuess: V,  // Stable parameter name
    constraints: [MultivariateConstraint<V>]
) throws -> MultivariateOptimizationResult<V>
```

✅ **`VectorSpace`** - Vector operations protocol

---

### Optimization Algorithms

All optimization algorithm APIs are stable:

- **Scalar Optimizers:**
  - `GradientDescentOptimizer` - Gradient descent with momentum/Nesterov
  - `NewtonRaphsonOptimizer` - Newton-Raphson with line search
  - `GoalSeekOptimizer` - Root-finding via Newton's method

- **Multivariate Optimizers:**
  - `MultivariateGradientDescent` - First-order methods (basic, Adam, momentum)
  - `MultivariateNewtonRaphson` - Second-order methods (Newton, BFGS)
  - `ConstrainedOptimizer` - Equality-constrained optimization
  - `InequalityOptimizer` - Mixed equality/inequality constraints
  - `AdaptiveOptimizer` - Automatic algorithm selection
  - `ParallelOptimizer` - Multi-start global optimization
  - `StochasticOptimizer` - Scenario-based optimization
  - `RobustOptimizer` - Uncertainty-aware optimization

- **Specialized Optimizers:**
  - `PortfolioOptimizer` - Modern Portfolio Theory (MPT)
  - `CapitalAllocationOptimizer` - Budget allocation
  - `IntegerProgramSolver` - Branch-and-bound & branch-and-cut
  - `SimplexSolver` - Linear programming

---

### Financial Functions

All financial calculation APIs are stable:

- **Time Value of Money:** `npv()`, `irr()`, `pv()`, `fv()`, `pmt()`
- **Time Series:** `TimeSeries`, growth rates, moving averages
- **Forecasting:** Trend analysis, seasonal adjustment
- **Financial Ratios:** All 21 ratio functions
- **Valuation Models:** DDM, FCFE, bond pricing, CDS pricing
- **Investment Metrics:** PI, payback period, MIRR
- **Loan Analysis:** PPMT, IPMT, cumulative calculations

---

### Statistical Functions

All statistical APIs are stable:

- **Descriptive:** Mean, median, mode, standard deviation, variance
- **Regression:** Linear, polynomial, exponential, nonlinear
- **Hypothesis Testing:** T-tests, chi-square, F-tests
- **Distributions:** All 15 probability distributions
- **Monte Carlo:** Simulation framework and analysis tools
- **Bayesian:** Bayes' theorem and posterior calculations

---

## Versioning Policy

BusinessMath follows **Semantic Versioning 2.0** (semver.org):

### Version Format: MAJOR.MINOR.PATCH

**Example:** `2.3.1`
- **MAJOR (2)** - Breaking changes
- **MINOR (3)** - New features, backward-compatible
- **PATCH (1)** - Bug fixes, backward-compatible

### What Changes in Each Version Type

#### MAJOR (2.x → 3.0)
**Breaking changes allowed:**
- API renaming or removal
- Parameter signature changes
- Behavioral changes
- Minimum Swift version increase

**Triggers:**
- Significant architectural improvements
- Major Swift language updates
- Fundamental API redesign

**Release Frequency:** ~12-24 months

#### MINOR (2.0 → 2.1)
**Backward-compatible additions:**
- New functions and types
- New optional parameters (with defaults)
- New protocol methods (with default implementations)
- Performance improvements
- Enhanced features

**Examples:**
- Adding shadow price extraction (TODO in 2.1)
- Adding anti-dilution protection (TODO in 2.1)
- New distribution types
- Enhanced cutting plane generation

**Release Frequency:** ~2-4 months

#### PATCH (2.0.0 → 2.0.1)
**Bug fixes only:**
- Numerical accuracy improvements
- Edge case fixes
- Documentation corrections
- Performance optimizations (no API changes)

**Release Frequency:** As needed

---

## Deprecation Policy

### Deprecation Process

When an API needs to be removed or changed:

1. **Mark as deprecated** in version N
2. **Provide alternative** in documentation
3. **Compiler warnings** guide migration
4. **Keep working** for at least 2 minor versions
5. **Remove** in version N+2 or later

### Example Timeline

```
Version 2.5: Deprecate oldFunction()
             → Add newFunction()
             → Compiler warning: "oldFunction() is deprecated, use newFunction()"

Version 2.6: oldFunction() still works
             → Warning continues

Version 2.7: oldFunction() still works
             → Warning continues

Version 2.8: oldFunction() removed (earliest)
             → Compiler error if used
```

### Currently Deprecated APIs

**None** - All 2.0 APIs are stable and supported.

---

## Experimental Features

Some features may be marked as **experimental** during 2.x:

- **HTTP Mode** for MCP server (documented in HTTP_MODE_README.md)
- Result builder DSLs (if added in future)
- Async/await optimization (if added in future)

**Experimental features:**
- ⚠️ May change in minor versions
- ⚠️ May be removed without deprecation
- ⚠️ Clearly marked in documentation
- ✅ Safe to use, but API may evolve

---

## Swift Version Support

### Swift 6.0+

BusinessMath 2.x requires **Swift 6.0 or later**.

**Rationale:**
- Full strict concurrency checking (`@Sendable`, actor isolation)
- Modern Swift features (parameter packs, typed throws in future)
- Best performance and safety guarantees

### Platform Support

- **macOS 13.0+** (required for MCP server)
- **iOS 16.0+**
- **watchOS 9.0+**
- **tvOS 16.0+**
- **Linux** (where Swift 6.0 is available)

---

## Performance Guarantees

While we continuously optimize performance, **behavioral correctness takes priority** over speed.

### What's Guaranteed

- **Algorithmic complexity** won't increase within 2.x
- **Numerical accuracy** won't decrease
- **Convergence properties** remain stable

### What's Not Guaranteed

- Exact execution time (may improve in patches)
- Memory usage (may improve in patches)
- Internal implementation details

**Example:** If gradient descent converges in 100 iterations, it will continue to converge similarly. The exact number may vary slightly due to optimizations, but overall behavior is stable.

---

## Testing Commitment

BusinessMath 2.x maintains:

- ✅ **3,013+ tests** across 240 suites
- ✅ **>99% pass rate** on functional tests
- ✅ **Continuous integration** on all commits
- ✅ **Playground-validated examples** in documentation
- ✅ **Property-based tests** for critical algorithms

New features in 2.x will maintain this testing standard.

---

## Documentation Commitment

All 2.x APIs are documented with:

- **API Reference:** Complete in-code documentation
- **Tutorials:** 52+ step-by-step guides
- **Examples:** Working code in `Examples/` directory
- **Migration Guides:** Upgrade path documentation

Documentation updates are **backward-compatible** - old examples continue to work.

---

## Breaking Change Process

If a critical bug requires breaking the API within 2.x:

1. **Security/correctness issue** must be severe
2. **Community discussion** via GitHub issue
3. **Clear migration path** provided
4. **Version jump** to next major (2.x → 3.0)

**This is extremely rare.** We're committed to stability.

---

## What's NOT Stable

These aspects may change within 2.x without being considered breaking:

### Internal Implementation

- Private methods and types
- File organization
- Internal algorithms (as long as behavior is consistent)
- Test implementation details

### Performance Characteristics

- Exact iteration counts
- Exact memory usage
- Exact execution time

### Compiler Warnings

- New warnings may appear
- Existing warnings may change

### Error Messages

- Wording of error messages
- Specific error details
- Suggestion text

---

## Feedback and Stability Issues

If you encounter stability issues:

1. **Check MIGRATION.md** - Ensure you've migrated correctly
2. **Review CHANGELOG.md** - Look for documented changes
3. **Search GitHub Issues** - See if it's a known issue
4. **Open an Issue** - Report unexpected breaking changes

We take stability seriously. Unintentional breaking changes are treated as critical bugs.

---

## Future Vision (3.0 and Beyond)

Potential future changes (not committed, just ideas):

- **Swift Macros** for common patterns
- **Async/await optimization** algorithms
- **Streaming data support** for time series
- **Result builders** for financial models
- **Swift Charts integration** for visualization

These would require major version (3.0) due to breaking changes or significant architectural shifts.

---

## License Stability

BusinessMath 2.x is released under the **MIT License**, which is stable and won't change within 2.x.

---

## Summary: What You Can Rely On

✅ **All public APIs** in 2.0 will work in 2.x
✅ **Parameter names** won't change (`initialGuess` is here to stay)
✅ **Algorithm behavior** remains consistent
✅ **Semantic versioning** strictly followed
✅ **Deprecation warnings** before removal
✅ **Comprehensive testing** maintained
✅ **Documentation quality** preserved

**BusinessMath 2.0 is production-ready.**

---

**Questions about stability?** Open a discussion on GitHub!
