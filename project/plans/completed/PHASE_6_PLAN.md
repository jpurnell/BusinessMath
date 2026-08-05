# Phase 6: Advanced Optimization Features - Implementation Plan

**Created:** 2025-12-04
**Status:** Planning
**Goal:** Extend optimization framework to handle dynamic, uncertain, and multi-scenario problems

---

## Overview

Phase 6 adds sophisticated optimization capabilities that handle:
- **Time-varying decisions** (multi-period optimization)
- **Uncertainty** (stochastic optimization)
- **Worst-case scenarios** (robust optimization)
- **Multiple futures** (scenario-based optimization)

This phase transforms BusinessMath from **static** to **dynamic** optimization, enabling real-world planning under uncertainty.

---

## Implementation Order

### 1. Multi-Period Optimization (First Priority)
**Goal:** Optimize decisions that evolve over time with inter-temporal constraints

**Key Concepts:**
- Time-varying decision variables (e.g., x₁, x₂, ..., xₜ)
- Inter-temporal constraints (linking decisions across periods)
- Discount factors for time value of money
- Rolling horizon optimization

**Use Cases:**
- Portfolio rebalancing over time (with transaction costs)
- Multi-period production planning (inventory, capacity)
- Capital budgeting with staged investments
- Multi-period cash flow optimization

**API Design:**
```swift
let optimizer = MultiPeriodOptimizer<VectorN<Double>>(
    numberOfPeriods: 12,
    discountRate: 0.08
)

let result = try optimizer.optimize(
    objective: { decisions in
        // decisions[t] is the decision at period t
        // Returns sum of discounted period objectives
    },
    initialState: initialWeights,
    constraints: [
        // Constraints within each period
        .eachPeriod { t, x in x.sum() - 1.0 },  // Budget each period

        // Constraints across periods
        .transition { t, xₜ, xₜ₊₁ in
            // Transaction cost constraint
            let turnover = (xₜ₊₁ - xₜ).norm
            return turnover - 0.20  // ≤ 20% turnover
        }
    ]
)
```

**Components to Build:**
- `MultiPeriodOptimizer<V: VectorSpace>`
- `MultiPeriodConstraint<V>` enum
- `MultiPeriodResult<V>` with trajectory data
- Integration with existing optimizers for single-period problems

---

### 2. Stochastic Optimization (Second Priority)
**Goal:** Optimize expected outcomes under uncertainty using Monte Carlo methods

**Key Concepts:**
- Random variables in objective/constraints
- Expected value optimization: E[f(x, ω)]
- Monte Carlo sampling for expectation estimation
- Variance reduction techniques

**Use Cases:**
- Portfolio optimization with uncertain returns
- Production planning with demand uncertainty
- Capital budgeting with uncertain cash flows
- Risk-averse optimization (CVaR, worst-case percentile)

**API Design:**
```swift
let optimizer = StochasticOptimizer<VectorN<Double>>(
    numberOfSamples: 1000,
    randomSeed: 42
)

let result = try optimizer.optimize(
    objective: { x, scenario in
        // scenario contains random values (returns, demands, etc.)
        // Returns objective value for this scenario
    },
    scenarioGenerator: {
        // Generate random scenario
        MonteCarloScenario(
            returns: sampleReturns(),
            demands: sampleDemands()
        )
    },
    initialValue: initialWeights,
    constraints: [
        // Constraints that must hold for all scenarios
        .robust { x in x.sum() - 1.0 },

        // Constraints on expected values
        .expected { x, scenario in
            scenario.return(for: x) - 0.08  // E[return] ≥ 8%
        }
    ]
)
```

**Components to Build:**
- `StochasticOptimizer<V: VectorSpace>`
- `Scenario` protocol for random parameters
- `StochasticConstraint<V>` enum
- Sample Average Approximation (SAA) method
- Integration with existing Monte Carlo tools

---

### 3. Robust Optimization (Third Priority)
**Goal:** Optimize for worst-case outcomes across uncertainty sets

**Key Concepts:**
- Uncertainty sets (box, ellipsoidal, polyhedral)
- Min-max optimization: min_x max_ω f(x, ω)
- Worst-case constraints
- Robust counterparts of uncertain constraints

**Use Cases:**
- Worst-case portfolio optimization
- Robust production planning with demand ranges
- Risk management under model uncertainty
- Conservative capital allocation

**API Design:**
```swift
let optimizer = RobustOptimizer<VectorN<Double>>(
    uncertaintySet: .box(
        nominal: nominalReturns,
        deviations: [0.02, 0.03, 0.04, 0.01]  // ±2%, ±3%, etc.
    )
)

let result = try optimizer.optimize(
    objective: { x, uncertainReturns in
        // Returns worst-case objective over uncertainty set
        x.dot(uncertainReturns)  // Will be minimized over ω
    },
    initialValue: initialWeights,
    constraints: [
        // Constraints that must hold for all realizations
        .budgetConstraint,
        .nonNegativity(dimension: 4)
    ]
)

// Result guarantees performance even in worst case
print("Worst-case return: \(result.worstCaseObjective)")
```

**Components to Build:**
- `RobustOptimizer<V: VectorSpace>`
- `UncertaintySet` enum (box, ellipsoid, polyhedral)
- `RobustConstraint<V>` for worst-case constraints
- Inner max optimization for worst-case search
- Tractable reformulations where possible

---

### 4. Scenario-Based Optimization (Fourth Priority)
**Goal:** Optimize across multiple discrete scenarios with probabilities

**Key Concepts:**
- Discrete scenario set with probabilities
- Weighted objective across scenarios
- Conditional constraints (scenario-specific)
- Scenario tree optimization

**Use Cases:**
- Strategic planning across market scenarios (bull/bear/base)
- Contingent decision making
- Multi-stage stochastic programming
- Stress testing and scenario analysis

**API Design:**
```swift
let scenarios = [
    Scenario(name: "Bull Market", probability: 0.30, returns: [0.15, 0.20, 0.18, 0.08]),
    Scenario(name: "Base Case", probability: 0.50, returns: [0.10, 0.12, 0.11, 0.04]),
    Scenario(name: "Bear Market", probability: 0.20, returns: [0.02, -0.05, 0.03, 0.06])
]

let optimizer = ScenarioOptimizer<VectorN<Double>>(
    scenarios: scenarios
)

let result = try optimizer.optimize(
    objective: { x, scenario in
        // Objective for this scenario
        x.dot(VectorN(scenario.returns))
    },
    initialValue: initialWeights,
    constraints: [
        // Constraints that hold in all scenarios
        .all { x in x.sum() - 1.0 },

        // Conditional constraints (scenario-specific)
        .inScenario("Bear Market") { x in
            // More conservative in bear market
            let bondWeight = x[3]
            return 0.30 - bondWeight  // bonds ≥ 30%
        }
    ]
)

// Analyze results per scenario
for (scenario, value) in result.scenarioValues {
    print("\(scenario.name): \(value)")
}
```

**Components to Build:**
- `ScenarioOptimizer<V: VectorSpace>`
- `Scenario` struct with probability and parameters
- `ScenarioConstraint<V>` enum
- Weighted objective aggregation
- Per-scenario analysis tools

---

## Integration with Existing Phases

### Phase 3 Integration (Multivariate Optimization)
- Multi-period optimizer uses Phase 3 algorithms for single-period subproblems
- Stochastic optimizer wraps Phase 3 optimizers with Monte Carlo
- All Phase 6 optimizers leverage gradient descent, Newton-Raphson, BFGS

### Phase 4 Integration (Constrained Optimization)
- Multi-period constraints extend Phase 4's constraint system
- Robust optimizer uses Phase 4 for min-max inner problems
- All Phase 6 features maintain compatibility with equality/inequality constraints

### Phase 5 Integration (Business Applications)
- Multi-period resource allocation (staged investments)
- Stochastic production planning (demand uncertainty)
- Robust driver optimization (model uncertainty)
- Scenario-based capital budgeting

---

## Testing Strategy

Each feature requires comprehensive tests:

### Multi-Period Optimization Tests
- [ ] Simple 2-period portfolio rebalancing
- [ ] Multi-period with transaction costs
- [ ] Production planning with inventory
- [ ] Budget constraints across periods
- [ ] Transition constraints (linking periods)

### Stochastic Optimization Tests
- [ ] Portfolio with uncertain returns
- [ ] Expected value optimization
- [ ] CVaR risk measure
- [ ] Scenario generation and sampling
- [ ] Convergence with sample size

### Robust Optimization Tests
- [ ] Box uncertainty set
- [ ] Ellipsoidal uncertainty set
- [ ] Worst-case portfolio return
- [ ] Robust production planning
- [ ] Conservative constraint satisfaction

### Scenario-Based Optimization Tests
- [ ] 3-scenario optimization (bull/base/bear)
- [ ] Weighted objective aggregation
- [ ] Conditional constraints
- [ ] Per-scenario analysis
- [ ] Probability-weighted results

**Target:** 50+ comprehensive tests for Phase 6

---

## File Structure

```
Sources/BusinessMath/
├── AdvancedOptimization/
│   ├── MultiPeriodOptimizer.swift        # Feature 1
│   ├── MultiPeriodConstraint.swift
│   ├── StochasticOptimizer.swift         # Feature 2
│   ├── Scenario.swift
│   ├── RobustOptimizer.swift             # Feature 3
│   ├── UncertaintySet.swift
│   ├── ScenarioOptimizer.swift           # Feature 4
│   └── ScenarioConstraint.swift

Tests/BusinessMathTests/
├── Advanced Optimization Tests/
│   ├── MultiPeriodOptimizationTests.swift
│   ├── StochasticOptimizationTests.swift
│   ├── RobustOptimizationTests.swift
│   └── ScenarioOptimizationTests.swift

Examples/
├── MultiPeriodOptimizationExample.swift
├── StochasticOptimizationExample.swift
├── RobustOptimizationExample.swift
└── ScenarioOptimizationExample.swift
```

---

## Success Criteria

### Feature Completeness
- ✅ All 4 features implemented with clean APIs
- ✅ Comprehensive test coverage (50+ tests)
- ✅ Integration with existing phases
- ✅ Real-world examples for each feature

### Code Quality
- ✅ Clean compilation with no warnings
- ✅ Consistent with existing code style
- ✅ Generic over `VectorSpace` where applicable
- ✅ Comprehensive documentation

### Performance
- ✅ Multi-period optimization scales to 50+ periods
- ✅ Stochastic optimization converges with 1000+ samples
- ✅ Robust optimization completes in reasonable time
- ✅ Scenario optimization handles 10+ scenarios

### Documentation
- ✅ PHASE_6_TUTORIAL.md with theory and examples
- ✅ PHASE_6_SUMMARY.md tracking completion
- ✅ Example files demonstrating each feature
- ✅ Examples/README.md updated with Phase 6 section
- ✅ DocC documentation for all public APIs

---

## Timeline Estimate

**Feature 1: Multi-Period Optimization** (~2-3 hours)
- Design API and data structures
- Implement optimizer and constraint system
- Write 12-15 comprehensive tests
- Create examples

**Feature 2: Stochastic Optimization** (~2-3 hours)
- Design scenario generation system
- Implement Monte Carlo optimization
- Write 12-15 comprehensive tests
- Create examples

**Feature 3: Robust Optimization** (~2-3 hours)
- Design uncertainty set representation
- Implement min-max optimization
- Write 12-15 comprehensive tests
- Create examples

**Feature 4: Scenario-Based Optimization** (~1-2 hours)
- Design scenario API
- Implement weighted optimization
- Write 12-15 comprehensive tests
- Create examples

**Documentation** (~2 hours)
- Tutorial covering all 4 features
- Summary and completion tracking
- Examples README updates

**Total Estimated Time: 9-13 hours**

---

## Key Design Decisions

### 1. Genericity
All optimizers will be generic over `VectorSpace` to maintain consistency with Phases 3-5.

### 2. Composability
Phase 6 features should compose with each other:
- Multi-period + stochastic = multi-stage stochastic programming
- Robust + scenario-based = worst-case across scenarios
- All features work with existing constraints

### 3. Integration
Phase 6 features are built **on top of** existing optimizers, not separate implementations.

### 4. Practical Focus
Emphasize real business applications over pure mathematical generality.

---

## Next Steps

1. **Start with Multi-Period Optimization** (this session)
   - Design `MultiPeriodOptimizer<V: VectorSpace>`
   - Implement inter-temporal constraints
   - Write portfolio rebalancing example
   - Create 12-15 comprehensive tests

2. **Move to Stochastic Optimization**
   - Design `StochasticOptimizer<V: VectorSpace>`
   - Implement scenario generation
   - Write uncertain portfolio example
   - Create 12-15 comprehensive tests

3. **Then Robust Optimization**
   - Design `RobustOptimizer<V: VectorSpace>`
   - Implement uncertainty sets
   - Write worst-case portfolio example
   - Create 12-15 comprehensive tests

4. **Finally Scenario-Based Optimization**
   - Design `ScenarioOptimizer<V: VectorSpace>`
   - Implement weighted aggregation
   - Write multi-scenario planning example
   - Create 12-15 comprehensive tests

5. **Complete Documentation**
   - PHASE_6_TUTORIAL.md
   - PHASE_6_SUMMARY.md
   - Update Examples/README.md

---

## Open Questions

1. **Multi-Period:** Should we support rolling horizon optimization?
2. **Stochastic:** Should we implement variance reduction techniques (antithetic variates, control variates)?
3. **Robust:** Should we support affine decision rules for tractability?
4. **Scenario:** Should we support scenario trees (multi-stage with branching)?

These can be addressed during implementation based on practical needs.

---

## Let's Begin!

Starting with **Multi-Period Optimization** in next file...
