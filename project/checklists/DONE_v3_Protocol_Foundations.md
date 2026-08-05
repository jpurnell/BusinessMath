# BusinessMath v3.0 Protocol Foundations — Implementation Checklist

**Purpose:** Track implementation of the public protocol foundation that BusinessMathPro depends on.
**Status:** ✅ COMPLETE
**Last Updated:** 2026-04-15
**Design Proposal:** See BusinessMathPro `SIMULATION_INFRASTRUCTURE_AND_MARKET_INTEGRITY.md` and `DERIVATIVES_AND_HEDGING.md`
**Commit:** `20f9d61`

---

## Quick Reference

| Phase | Status | Files | Tests |
|-------|--------|-------|-------|
| Phase 0: Design | ✅ Complete | — | — |
| Phase 1a: MeasureTag + ProcessState protocols | ✅ Complete | 2 | 8 |
| Phase 1b: StochasticProcess protocol | ✅ Complete | 1 | 6 |
| Phase 1c: GeometricBrownianMotion | ✅ Complete | 1 | 13 |
| Phase 1d: OrnsteinUhlenbeck | ✅ Complete | 1 | 13 |
| Phase 1e: ArithmeticBrownianMotion | ✅ Complete | 1 | 6 |
| Phase 1f: JumpDiffusion | ✅ Complete | 1 | 7 |
| Phase 1g: PeriodSequence | ✅ Complete | 1 | 9 |
| Phase 2: Quality Gate + Commit | ✅ Complete | — | — |

**Totals:** 8 source files, 8 test files (+ 1 helper), 62 new tests, 4,944 total tests passing

**Legend:**
- ⬜ Not Started
- 🔄 In Progress
- ✅ Complete
- ⚠️ Blocked
- 🔴 Issues Found

---

## Phase 0: Design ✅

Design approved through 9 audit passes in BusinessMathPro proposal suite.

- [x] `StochasticProcess` protocol with `ProcessState` associatedtype
- [x] `MeasureTag` protocol with `RiskNeutral` and `Physical` concrete types
- [x] Four stochastic process implementations (GBM, OU, ABM, JumpDiffusion)
- [x] `PeriodSequence` with factory methods and aggregation
- [x] Public/private split defined — these types are the public API

---

## Phase 1a: MeasureTag + ProcessState Protocols

### RED — Write failing tests first

**Test File:** `Tests/BusinessMathTests/Stochastic/MeasureTagTests.swift`

- [ ] `RiskNeutral` has static name "risk-neutral"
- [ ] `Physical` has static name "physical"
- [ ] Both conform to `MeasureTag` and `Sendable`
- [ ] `MeasureTag` has `name` requirement

**Test File:** `Tests/BusinessMathTests/Stochastic/ProcessStateTests.swift`

- [ ] `Double` conforms to `ProcessState` with `Scalar == Double`
- [ ] `Double.dimension == 1`
- [ ] `ProcessState` requires `Scalar`, `NormalDraws`, `dimension`

### GREEN — Minimum implementation

**File:** `Sources/BusinessMath/Stochastic/MeasureTag.swift`

- [ ] `MeasureTag` protocol — `Sendable`, requires `static var name: String`
- [ ] `RiskNeutral` struct conforming to `MeasureTag`
- [ ] `Physical` struct conforming to `MeasureTag`

**File:** `Sources/BusinessMath/Stochastic/ProcessState.swift`

- [ ] `ProcessState` protocol — `Sendable`, requires `Scalar`, `NormalDraws`, `dimension`
- [ ] `Double` extension conforming to `ProcessState`

### REFACTOR

- [ ] Verify naming consistency with proposal
- [ ] Ensure DocC documentation on all public types

---

## Phase 1b: StochasticProcess Protocol

### RED — Write failing tests first

**Test File:** `Tests/BusinessMathTests/Stochastic/StochasticProcessTests.swift`

- [ ] Protocol requires `name: String`
- [ ] Protocol requires `step(from:dt:normalDraws:) -> State`
- [ ] Protocol requires `allowsNegativeValues: Bool`
- [ ] Protocol requires `factors: Int`
- [ ] Protocol has `State: ProcessState` associated type
- [ ] Verify a mock process can conform and produce expected output

### GREEN — Minimum implementation

**File:** `Sources/BusinessMath/Stochastic/StochasticProcess.swift`

- [ ] `StochasticProcess` protocol with all requirements
- [ ] DocC documentation with usage examples

### REFACTOR

- [ ] Ensure protocol is minimal — no default implementations that could constrain BusinessMathPro

---

## Phase 1c: GeometricBrownianMotion

### RED — Write failing tests first

**Test File:** `Tests/BusinessMathTests/Stochastic/GeometricBrownianMotionTests.swift`

Golden path:
- [ ] Known step: S₀=72.50, μ=0.05, σ=0.25, dt=1/12, dW=0.5 → S₁=75.28 (from proposal validation trace)
- [ ] Zero drift, zero vol: step returns current value unchanged
- [ ] `name` returns the assigned name
- [ ] `factors == 1`
- [ ] `allowsNegativeValues == false`

Statistical (deterministic seed):
- [ ] 10,000 steps: mean converges to S₀·e^(μT) within tolerance
- [ ] Positivity: no step ever produces negative value with high vol (σ=1.0)

Edge cases:
- [ ] dt=0: returns current value
- [ ] dW=0: returns deterministic drift-only step
- [ ] Very small S₀ (1e-10): still positive after step

Property-based:
- [ ] Output is always positive for positive input
- [ ] Larger σ produces larger variance across steps

### GREEN — Minimum implementation

**File:** `Sources/BusinessMath/Stochastic/GeometricBrownianMotion.swift`

- [ ] Struct conforming to `StochasticProcess` with `State = Double`
- [ ] Properties: `name`, `drift`, `volatility`
- [ ] `step()`: `current * exp((drift - volatility²/2) * dt + volatility * sqrt(dt) * normalDraws)`
- [ ] Guard: if current ≤ 0, return current (don't crash)

### REFACTOR

- [ ] DocC with formula, when-to-use, example
- [ ] Verify no force unwraps, no division safety issues

---

## Phase 1d: OrnsteinUhlenbeck

### RED — Write failing tests first

**Test File:** `Tests/BusinessMathTests/Stochastic/OrnsteinUhlenbeckTests.swift`

Golden path:
- [ ] Known step with specific inputs matches manual calculation
- [ ] `allowsNegativeValues == true`
- [ ] `factors == 1`

Analytical:
- [ ] `expectedValue(from: x₀, at: t)` matches θ + (x₀ - θ)·e^(-κt) for t=0.5, 1.0, 5.0, 100.0
- [ ] `variance(at: t)` matches σ²/(2κ)·(1 - e^(-2κt))

Statistical:
- [ ] 10,000 steps from x₀ far from θ: mean converges toward θ

Edge cases:
- [ ] κ=0 (no mean reversion): behaves like ABM
- [ ] Very large κ: snaps immediately to θ
- [ ] Negative values produced when θ=0 and high vol

Property-based:
- [ ] `expectedValue` at t=0 equals x₀
- [ ] `expectedValue` at t=∞ equals θ
- [ ] `variance` at t=0 equals 0
- [ ] `variance` at t=∞ equals σ²/(2κ)

### GREEN — Minimum implementation

**File:** `Sources/BusinessMath/Stochastic/OrnsteinUhlenbeck.swift`

- [ ] Struct conforming to `StochasticProcess` with `State = Double`
- [ ] Properties: `name`, `speed` (κ), `longRunMean` (θ), `volatility` (σ)
- [ ] `step()`: exact discretization `current·e^(-κ·dt) + θ·(1 - e^(-κ·dt)) + σ·√((1 - e^(-2κdt))/(2κ))·dW`
- [ ] `expectedValue(from:at:)` — analytical
- [ ] `variance(at:)` — analytical
- [ ] Guard: κ=0 falls back to drift + σ·√dt·dW

### REFACTOR

- [ ] DocC with formula, when-to-use (commodity prices, spreads, rates)

---

## Phase 1e: ArithmeticBrownianMotion

### RED — Write failing tests first

**Test File:** `Tests/BusinessMathTests/Stochastic/ArithmeticBrownianMotionTests.swift`

Golden path:
- [ ] Known step: S₀=72.50, μ=0.5, σ=5.0, dt=1/12, dW=0.5 → manual calculation
- [ ] `allowsNegativeValues == true`
- [ ] `factors == 1`

Statistical:
- [ ] Mean after many steps converges to S₀ + μ·T
- [ ] Can produce negative values (verify with high vol, low starting value)

Edge cases:
- [ ] dt=0: returns current
- [ ] σ=0: deterministic, returns current + μ·dt

### GREEN — Minimum implementation

**File:** `Sources/BusinessMath/Stochastic/ArithmeticBrownianMotion.swift`

- [ ] Struct conforming to `StochasticProcess` with `State = Double`
- [ ] Properties: `name`, `drift`, `volatility`
- [ ] `step()`: `current + drift * dt + volatility * sqrt(dt) * normalDraws`

### REFACTOR

- [ ] DocC explaining when to use ABM vs GBM (negative prices, financial futures)

---

## Phase 1f: JumpDiffusion

### RED — Write failing tests first

**Test File:** `Tests/BusinessMathTests/Stochastic/JumpDiffusionTests.swift`

Golden path:
- [ ] With λ=0 (no jumps): output matches GBM exactly
- [ ] `allowsNegativeValues == false`
- [ ] `factors == 1`

Statistical:
- [ ] Average jump count across 10,000 paths ≈ λ·T within 3σ (Poisson)

Edge cases:
- [ ] jumpIntensity=0: pure GBM
- [ ] jumpVolatility=0: fixed jump size
- [ ] Very high jumpIntensity: many jumps, still positive

### GREEN — Minimum implementation

**File:** `Sources/BusinessMath/Stochastic/JumpDiffusion.swift`

- [ ] Struct conforming to `StochasticProcess` with `State = Double`
- [ ] Properties: `name`, `drift`, `volatility`, `jumpIntensity` (λ), `jumpMean`, `jumpVolatility`
- [ ] `step()`: GBM step + Poisson-distributed jump component
- [ ] Jump: draw Poisson(λ·dt) count, each jump is exp(jumpMean + jumpVol·Z)

### REFACTOR

- [ ] DocC explaining commodity shocks, credit events use case

---

## Phase 1g: PeriodSequence

### RED — Write failing tests first

**Test File:** `Tests/BusinessMathTests/Time Series Tests/PeriodSequenceTests.swift`

Golden path:
- [ ] `monthly(from: .month(year: 2026, month: 1), through: .month(year: 2026, month: 12))` → 12 periods
- [ ] `quarterly(from: 2026, startQuarter: 1, through: 2026, endQuarter: 4)` → 4 periods
- [ ] `annual(from: 2024, through: 2026)` → 3 periods

Aggregation:
- [ ] Sum 12 monthly values → equals quarterly aggregated sum (3 quarters × 4 months each)
- [ ] `endOfPeriod` picks last month of quarter
- [ ] `average` computes mean of months in quarter

Edge cases:
- [ ] Start == end → single period
- [ ] Start > end → throws error
- [ ] Conforms to `Sequence` — can `for period in sequence`
- [ ] Works with `Array(sequence)` for materialization

Integration with existing `PeriodRange`:
- [ ] Can construct `PeriodSequence` from an existing `PeriodRange`

### GREEN — Minimum implementation

**File:** `Sources/BusinessMath/Time Series/PeriodSequence.swift`

- [ ] Struct conforming to `Sequence` and `Sendable`
- [ ] Static factory methods: `monthly(from:through:)`, `quarterly(...)`, `annual(...)`
- [ ] `AggregationMethod` enum: `.sum`, `.average`, `.endOfPeriod`
- [ ] `aggregate(_:from:to:method:)` static method on `PeriodSequence`
- [ ] Initializer from `PeriodRange`

### REFACTOR

- [ ] DocC with financial examples (quarterly revenue from monthly, year-end balance)

---

## Phase 2: Quality Gate + Commit

- [ ] `swift build` — zero warnings, zero errors
- [ ] `swift test` — all new tests pass, all existing 4,882 tests still pass
- [ ] Strict concurrency — no Sendable warnings
- [ ] No force unwraps, no `try!`, no force casts
- [ ] All public APIs have DocC comments
- [ ] Commit with message: `feat: add StochasticProcess protocol foundations for v3.0`
- [ ] Tag: do NOT tag v3.0.0 yet — that happens when BusinessMathPro is ready

---

## File Summary

### New Source Files (7)

| File | Purpose |
|------|---------|
| `Sources/BusinessMath/Stochastic/MeasureTag.swift` | P vs Q measure markers |
| `Sources/BusinessMath/Stochastic/ProcessState.swift` | Scalar/vector state bridge |
| `Sources/BusinessMath/Stochastic/StochasticProcess.swift` | Core protocol |
| `Sources/BusinessMath/Stochastic/GeometricBrownianMotion.swift` | dS = μSdt + σSdW |
| `Sources/BusinessMath/Stochastic/OrnsteinUhlenbeck.swift` | dX = κ(θ-X)dt + σdW |
| `Sources/BusinessMath/Stochastic/ArithmeticBrownianMotion.swift` | dS = μdt + σdW |
| `Sources/BusinessMath/Stochastic/JumpDiffusion.swift` | GBM + Poisson jumps |

### New Source File (1)

| File | Purpose |
|------|---------|
| `Sources/BusinessMath/Time Series/PeriodSequence.swift` | Multi-period generation + aggregation |

### New Test Files (7)

| File | Estimated Tests |
|------|----------------|
| `Tests/BusinessMathTests/Stochastic/MeasureTagTests.swift` | ~4 |
| `Tests/BusinessMathTests/Stochastic/ProcessStateTests.swift` | ~4 |
| `Tests/BusinessMathTests/Stochastic/StochasticProcessTests.swift` | ~6 |
| `Tests/BusinessMathTests/Stochastic/GeometricBrownianMotionTests.swift` | ~15 |
| `Tests/BusinessMathTests/Stochastic/OrnsteinUhlenbeckTests.swift` | ~15 |
| `Tests/BusinessMathTests/Stochastic/ArithmeticBrownianMotionTests.swift` | ~8 |
| `Tests/BusinessMathTests/Stochastic/JumpDiffusionTests.swift` | ~10 |
| `Tests/BusinessMathTests/Time Series Tests/PeriodSequenceTests.swift` | ~15 |

**Estimated total new tests:** ~77

---

## Reference Truth

| Calculation | Reference |
|------------|-----------|
| GBM step | Hull, J.C. (2018) Ch. 14. S₁ = S₀·exp((μ - σ²/2)·dt + σ·√dt·dW) |
| OU exact discretization | Uhlenbeck & Ornstein (1930). X(t+dt) = X(t)·e^(-κdt) + θ(1-e^(-κdt)) + σ√((1-e^(-2κdt))/(2κ))·Z |
| OU analytical moments | E[X(t)] = θ + (x₀-θ)e^(-κt), Var[X(t)] = σ²/(2κ)(1-e^(-2κt)) |
| Jump-diffusion | Merton, R.C. (1976) "Option pricing when underlying stock returns are discontinuous" |
| ABM step | Standard: X(t+dt) = X(t) + μ·dt + σ·√dt·Z |

---

## Validation Traces

**GBM Golden Path:**
- S₀ = 72.50, μ = 0.05, σ = 0.25, dt = 1/12, dW = 0.5
- S₁ = 72.50 · exp((0.05 - 0.25²/2) · (1/12) + 0.25 · √(1/12) · 0.5)
- S₁ = 72.50 · exp(0.001563 + 0.03608)
- S₁ = 72.50 · exp(0.03764)
- S₁ = 72.50 · 1.03836 = **75.28**

**OU Analytical:**
- x₀ = 72.50, θ = 70.0, κ = 0.5, σ = 5.0
- E[X(1.0)] = 70.0 + (72.50 - 70.0)·e^(-0.5) = 70.0 + 2.5·0.6065 = **71.52**
- Var[X(1.0)] = 25/(2·0.5)·(1 - e^(-1.0)) = 25·(1 - 0.3679) = **15.80**
