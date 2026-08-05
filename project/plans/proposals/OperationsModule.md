# Design Proposal: Operations Module

**Author:** Justin Purnell + Claude  
**Date:** 2026-05-09  
**Status:** Approved — Implementation In Progress  
**Master Plan Reference:** Extends BusinessMath into operations management domain (inventory management, supply chain optimization)

---

## 1. Objective

### Problem Statement

BusinessMath provides robust forecasting (Holt-Winters), simulation (Monte Carlo), and statistical primitives (`normalCDF`, `inverseNormalCDF`) but has no dedicated operations management module. Downstream consumers like StockOpt must re-derive safety stock formulas, EOQ calculations, and newsvendor models ad-hoc — leading to simplified implementations that miss important factors (e.g., lead time variability, cost-optimized service levels).

### Goals

1. Provide textbook-correct, generic implementations of core inventory management models
2. Build on existing BusinessMath primitives (statistics, forecasting, simulation) rather than duplicating them
3. Enable downstream apps to upgrade from "basic z-score safety stock" to economically-optimal, simulation-validated inventory policies
4. Follow the library's established patterns: `<T: Real & Sendable & Codable>` generics, dual API (raw values + TimeSeries), DocC documentation

### Non-Goals

- Full supply chain network optimization (multi-echelon, facility location)
- ERP/MRP planning systems (those belong in application layer)
- Demand forecasting improvements (Forecasting module's responsibility)

---

## 2. Proposed Architecture

### File & Module Placement

```
Sources/BusinessMath/Operations/
├── OperationsError.swift              — Domain-specific error types
├── SafetyStockModel.swift             — Safety stock calculation (multiple methods)
├── ReorderPointModel.swift            — (Q,r) continuous-review reorder point
├── EOQModel.swift                     — Economic Order Quantity
├── NewsvendorModel.swift              — Single-period stocking (critical fractile)
└── InventorySimulator.swift           — Monte Carlo demand-during-lead-time
```

### Module Relationships

```
                 ┌──────────────┐
                 │  Statistics   │
                 │  normalCDF    │
                 │  inverseNorm  │
                 └──────┬───────┘
                        │ uses
┌──────────────┐  ┌─────┴──────────┐  ┌──────────────┐
│  Forecasting │  │   Operations   │  │  Simulation  │
│  HoltWinters │──│  SafetyStock   │──│  MonteCarlo  │
│              │  │  EOQ           │  │              │
└──────────────┘  │  Newsvendor    │  └──────────────┘
                  │  ReorderPoint  │
                  │  Simulator     │
                  └────────────────┘
```

The Operations module **depends on** existing Statistics and Simulation modules. The Forecasting module is an **optional integration** — `SafetyStockModel` can use forecast error (RMSE from Holt-Winters residuals) instead of raw demand standard deviation, but doesn't require it.

---

## 3. API Surface

### 3.1 OperationsError

```swift
public enum OperationsError: Error, Sendable {
    case insufficientData(required: Int, got: Int)
    case invalidParameter(String)
    case invalidServiceLevel
    case zeroDemand
    case negativeCost
}
```

### 3.2 SafetyStockModel

```swift
public struct SafetyStockModel<T: Real & Sendable & Codable>: Sendable {

    /// Method for computing safety stock.
    public enum Method: Sendable {
        /// Classic: SS = z × σ_d × √L (demand variability only, deterministic lead time)
        case demandOnly

        /// Full: SS = z × √(L × σ_d² + d̄² × σ_L²) (demand AND lead time variability)
        case demandAndLeadTime

        /// Forecast-error-driven: SS = z × σ_forecast_error × √L
        case forecastError
    }

    /// Calculates safety stock.
    ///
    /// - Parameters:
    ///   - method: The calculation method to use.
    ///   - serviceLevel: Desired probability of no stockout (0 < p < 1).
    ///   - averageDemand: Mean demand per period.
    ///   - demandStdDev: Standard deviation of demand per period.
    ///   - leadTime: Mean lead time in periods.
    ///   - leadTimeStdDev: Standard deviation of lead time (required for `.demandAndLeadTime`).
    ///   - forecastRMSE: Root mean squared forecast error (required for `.forecastError`).
    /// - Returns: The calculated safety stock quantity.
    /// - Throws: `OperationsError` for invalid parameters.
    public static func safetyStock(
        method: Method = .demandOnly,
        serviceLevel: T,
        averageDemand: T,
        demandStdDev: T,
        leadTime: T,
        leadTimeStdDev: T = T(0),
        forecastRMSE: T? = nil
    ) throws -> T

    /// Calculates the z-score for a given service level using the inverse normal CDF.
    ///
    /// Uses `inverseNormalCDF(p:)` from the Statistics module — continuous precision,
    /// not a discrete lookup table.
    public static func zScore(for serviceLevel: T) throws -> T
}
```

### 3.3 ReorderPointModel

```swift
public struct ReorderPointModel<T: Real & Sendable & Codable>: Sendable {

    /// Result of a reorder point calculation.
    public struct Result: Sendable {
        public let reorderPoint: T
        public let safetyStock: T
        public let demandDuringLeadTime: T
        public let averageDailyDemand: T
        public let demandStdDev: T
        public let zScore: T
        public let serviceLevel: T
        public let method: SafetyStockModel<T>.Method
    }

    /// Calculates the reorder point r = d̄ × L + SS.
    ///
    /// - Parameters:
    ///   - demandHistory: Historical demand per period.
    ///   - leadTime: Mean lead time in periods.
    ///   - serviceLevel: Desired cycle service level (0 < p < 1).
    ///   - leadTimeStdDev: Standard deviation of lead time (0 for deterministic).
    ///   - method: Safety stock calculation method.
    /// - Returns: A `Result` with reorder point, safety stock, and supporting metrics.
    /// - Throws: `OperationsError` for invalid inputs.
    public static func calculate(
        demandHistory: [T],
        leadTime: T,
        serviceLevel: T,
        leadTimeStdDev: T = T(0),
        method: SafetyStockModel<T>.Method = .demandOnly
    ) throws -> Result

    /// Calculates stockout probability for a given inventory position.
    ///
    /// P(stockout) = P(demand during lead time > inventory position)
    ///             = 1 - Φ((inventory - μ) / σ)
    ///
    /// - Parameters:
    ///   - currentStock: Current inventory on hand.
    ///   - averageDemand: Mean demand per period.
    ///   - demandStdDev: Standard deviation of demand per period.
    ///   - leadTime: Lead time in periods.
    ///   - leadTimeStdDev: Standard deviation of lead time.
    /// - Returns: Probability of stockout during the next lead time period.
    public static func stockoutProbability(
        currentStock: T,
        averageDemand: T,
        demandStdDev: T,
        leadTime: T,
        leadTimeStdDev: T = T(0)
    ) -> T
}
```

### 3.4 EOQModel

```swift
public struct EOQModel<T: Real & Sendable & Codable>: Sendable {

    /// Result of an EOQ calculation.
    public struct Result: Sendable {
        public let orderQuantity: T
        public let annualOrderingCost: T
        public let annualHoldingCost: T
        public let totalAnnualCost: T
        public let ordersPerYear: T
        public let daysBetweenOrders: T
    }

    /// Calculates the Economic Order Quantity: Q* = √(2SD/H).
    ///
    /// - Parameters:
    ///   - annualDemand: Total demand per year (D).
    ///   - orderingCost: Fixed cost per order placed (S).
    ///   - holdingCostPerUnit: Annual holding cost per unit (H).
    ///     Typically `unitCost × holdingCostRate`.
    /// - Returns: A `Result` with optimal order quantity and cost breakdown.
    /// - Throws: `OperationsError` for zero or negative inputs.
    public static func calculate(
        annualDemand: T,
        orderingCost: T,
        holdingCostPerUnit: T
    ) throws -> Result

    /// Calculates total annual inventory cost for a given order quantity.
    ///
    /// TC = (S × D / Q) + (H × Q / 2) + (c × D)
    ///
    /// - Parameters:
    ///   - orderQuantity: The order quantity to evaluate (Q).
    ///   - annualDemand: Total demand per year (D).
    ///   - orderingCost: Fixed cost per order (S).
    ///   - holdingCostPerUnit: Annual holding cost per unit (H).
    ///   - unitCost: Purchase cost per unit (c). Defaults to 0 if not needed.
    /// - Returns: Total annual cost.
    public static func totalCost(
        orderQuantity: T,
        annualDemand: T,
        orderingCost: T,
        holdingCostPerUnit: T,
        unitCost: T = T(0)
    ) -> T
}
```

### 3.5 NewsvendorModel

```swift
public struct NewsvendorModel<T: Real & Sendable & Codable>: Sendable {

    /// Result of a newsvendor calculation.
    public struct Result: Sendable {
        public let optimalQuantity: T
        public let criticalFractile: T
        public let zScore: T
        public let expectedProfit: T
        public let expectedOverstock: T
        public let expectedUnderstock: T
        public let serviceLevel: T
    }

    /// Calculates the optimal stocking quantity using the critical fractile.
    ///
    /// The critical fractile p_c = c_u / (c_u + c_o) determines the economically
    /// optimal service level. The optimal quantity is Q* = μ + z* × σ where
    /// z* = NORMSINV(p_c).
    ///
    /// - Parameters:
    ///   - meanDemand: Expected demand (μ).
    ///   - demandStdDev: Standard deviation of demand (σ).
    ///   - underageCost: Cost per unit of unmet demand (c_u = selling price - cost).
    ///   - overageCost: Cost per unit of excess inventory (c_o = cost - salvage value).
    /// - Returns: A `Result` with optimal quantity and expected outcomes.
    /// - Throws: `OperationsError` for invalid costs.
    public static func optimalQuantity(
        meanDemand: T,
        demandStdDev: T,
        underageCost: T,
        overageCost: T
    ) throws -> Result

    /// Calculates the critical fractile: p_c = c_u / (c_u + c_o).
    ///
    /// - Parameters:
    ///   - underageCost: Lost profit per unit of unmet demand.
    ///   - overageCost: Loss per unit of unsold inventory.
    /// - Returns: The critical fractile (optimal service level).
    /// - Throws: `OperationsError.negativeCost` if either cost is negative.
    public static func criticalFractile(
        underageCost: T,
        overageCost: T
    ) throws -> T

    /// Calculates expected profit for a given stocking level.
    ///
    /// Contribution = r × min(D, Q) - w × Q + s × max(0, Q - D)
    ///
    /// - Parameters:
    ///   - quantity: Number of units to stock.
    ///   - meanDemand: Expected demand.
    ///   - demandStdDev: Standard deviation of demand.
    ///   - sellingPrice: Revenue per unit sold.
    ///   - unitCost: Cost per unit purchased.
    ///   - salvageValue: Salvage value per unsold unit. Defaults to 0.
    /// - Returns: Expected profit for the given stocking level.
    public static func expectedProfit(
        quantity: T,
        meanDemand: T,
        demandStdDev: T,
        sellingPrice: T,
        unitCost: T,
        salvageValue: T = T(0)
    ) -> T
}
```

### 3.6 InventorySimulator

Composes the existing `MonteCarloSimulation` engine via custom `SimulationInput` samplers.
No new simulation infrastructure required — `MonteCarloSimulation` handles trial execution,
seeded RNG (`DeterministicRNG`), statistics, percentiles, and GPU fallback.

```swift
public struct InventorySimulator<T: Real & Sendable & Codable>: Sendable {

    /// Strategy for sampling demand in each simulation trial.
    public enum SamplingStrategy: Sendable {
        /// Bootstrap from historical demand (non-parametric).
        /// Can't extrapolate beyond observed values.
        case empirical

        /// Fit Normal(μ, σ) to demand history.
        /// Handles extrapolation, assumes symmetric demand.
        case normal

        /// Fit Poisson(λ) for low-volume/intermittent items.
        /// Good when demand is integer counts with many zeros.
        case poisson

        /// Fit Negative Binomial for over-dispersed count data (σ² > μ).
        /// Handles "bursty" demand patterns.
        case negativeBinomial

        /// Sample from forecast residuals: demand = forecast + residual.
        /// Tightest integration with ForecastEngine.
        case forecastResidual(forecasts: [T], residuals: [T])
    }

    /// Result of an inventory simulation.
    public struct Result: Sendable {
        public let safetyStock: T
        public let reorderPoint: T
        public let simulatedStockoutRate: T
        public let demandDuringLeadTimeMean: T
        public let demandDuringLeadTimeStdDev: T
        public let percentiles: [T: T]
        public let pathCount: Int
        public let samplingStrategy: String
    }

    /// Simulates demand during lead time using Monte Carlo sampling.
    ///
    /// Internally wraps the inventory-specific logic in a `SimulationInput`
    /// custom sampler and delegates trial execution to `MonteCarloSimulation`.
    ///
    /// For each trial:
    /// 1. Sample lead time from Normal(meanLeadTime, leadTimeStdDev)
    /// 2. For each day in the sampled lead time, sample daily demand per strategy
    /// 3. Sum to get total demand during lead time
    ///
    /// `MonteCarloSimulation` handles N-trial execution, seeded RNG, and
    /// result aggregation (percentiles, statistics).
    ///
    /// - Parameters:
    ///   - demandHistory: Historical daily demand values.
    ///   - meanLeadTime: Average lead time in days.
    ///   - leadTimeStdDev: Standard deviation of lead time.
    ///   - serviceLevel: Target service level (0 < p < 1).
    ///   - strategy: How to sample demand per day. Defaults to `.empirical`.
    ///   - iterations: Number of Monte Carlo trials. Defaults to 10,000.
    ///   - seed: Random seed for reproducibility.
    /// - Returns: A `Result` with simulated safety stock and percentile distribution.
    /// - Throws: `OperationsError` for invalid inputs.
    public static func simulate(
        demandHistory: [T],
        meanLeadTime: T,
        leadTimeStdDev: T = T(0),
        serviceLevel: T,
        strategy: SamplingStrategy = .empirical,
        iterations: Int = 10_000,
        seed: UInt64 = 42
    ) throws -> Result
}
```

### 3.7 InventoryAdvisor

Routes non-expert users to the right model and method based on data availability.

```swift
public struct InventoryAdvisor<T: Real & Sendable & Codable>: Sendable {

    /// Profile of available data for a SKU.
    public struct DataProfile: Sendable {
        public let demandHistoryLength: Int
        public let hasCostData: Bool
        public let hasLeadTimeVariability: Bool
        public let hasForecastModel: Bool
        public let coefficientOfVariation: T?
    }

    /// Recommendation with reasoning.
    public struct Recommendation: Sendable {
        public let model: RecommendedModel
        public let safetyStockMethod: SafetyStockModel<T>.Method
        public let samplingStrategy: InventorySimulator<T>.SamplingStrategy?
        public let reasoning: String
    }

    public enum RecommendedModel: Sendable {
        case basicReorderPoint
        case newsvendor
        case simulationBacked
    }

    /// Recommends the appropriate model based on available data.
    ///
    /// Decision logic:
    /// - < 14 days demand → reject (insufficient data)
    /// - 14-30 days, no costs → basicReorderPoint + demandOnly
    /// - 30+ days, no costs, variable LT → basicReorderPoint + demandAndLeadTime
    /// - 30+ days, has cost/margin data → newsvendor
    /// - 30+ days, has forecast model → basicReorderPoint + forecastError
    /// - 30+ days, high CV (> 1.0) or intermittent → simulationBacked
    ///
    /// - Parameter profile: Description of available data.
    /// - Returns: A recommendation with human-readable reasoning.
    public static func recommended(for profile: DataProfile) -> Recommendation
}
```

---

## 4. MCP Schema

Each model will have a corresponding MCP tool. Example schemas:

### safety_stock

```json
{
  "name": "calculate_safety_stock",
  "description": "Calculate safety stock using analytical formulas with selectable method",
  "parameters": {
    "type": "object",
    "properties": {
      "method": {
        "type": "string",
        "enum": ["demand_only", "demand_and_lead_time", "forecast_error"],
        "description": "Calculation method. demand_only: classic SS = z × σ_d × √L. demand_and_lead_time: SS = z × √(L × σ_d² + d̄² × σ_L²). forecast_error: uses forecast RMSE instead of demand σ."
      },
      "service_level": {
        "type": "number",
        "description": "Desired probability of no stockout during lead time (0-1). Example: 0.95 for 95% service level."
      },
      "average_demand": {
        "type": "number",
        "description": "Mean demand per period (e.g., units per day)."
      },
      "demand_std_dev": {
        "type": "number",
        "description": "Standard deviation of demand per period."
      },
      "lead_time": {
        "type": "number",
        "description": "Mean lead time in periods (e.g., days)."
      },
      "lead_time_std_dev": {
        "type": "number",
        "description": "Standard deviation of lead time in periods. Required for demand_and_lead_time method."
      },
      "forecast_rmse": {
        "type": "number",
        "description": "Root mean squared forecast error. Required for forecast_error method."
      }
    },
    "required": ["service_level", "average_demand", "demand_std_dev", "lead_time"]
  }
}
```

### economic_order_quantity

```json
{
  "name": "calculate_economic_order_quantity",
  "description": "Calculate optimal order quantity using the EOQ model: Q* = √(2SD/H)",
  "parameters": {
    "type": "object",
    "properties": {
      "annual_demand": {
        "type": "number",
        "description": "Total demand per year in units (D)."
      },
      "ordering_cost": {
        "type": "number",
        "description": "Fixed cost per order placed in dollars (S)."
      },
      "holding_cost_per_unit": {
        "type": "number",
        "description": "Annual holding cost per unit in dollars (H). Typically unit_cost × holding_rate."
      }
    },
    "required": ["annual_demand", "ordering_cost", "holding_cost_per_unit"]
  }
}
```

### newsvendor_optimal_quantity

```json
{
  "name": "calculate_newsvendor_optimal_quantity",
  "description": "Calculate optimal stocking quantity using the critical fractile / newsvendor model. Balances underage cost (lost profit) vs overage cost (excess inventory) to find economically optimal service level.",
  "parameters": {
    "type": "object",
    "properties": {
      "mean_demand": {
        "type": "number",
        "description": "Expected demand (μ)."
      },
      "demand_std_dev": {
        "type": "number",
        "description": "Standard deviation of demand (σ)."
      },
      "underage_cost": {
        "type": "number",
        "description": "Cost per unit of unmet demand (c_u). Typically selling_price - unit_cost."
      },
      "overage_cost": {
        "type": "number",
        "description": "Cost per unit of excess inventory (c_o). Typically unit_cost - salvage_value."
      }
    },
    "required": ["mean_demand", "demand_std_dev", "underage_cost", "overage_cost"]
  }
}
```

### simulate_inventory

```json
{
  "name": "simulate_inventory",
  "description": "Monte Carlo simulation of demand during lead time. Handles non-normal, skewed, and intermittent demand patterns.",
  "parameters": {
    "type": "object",
    "properties": {
      "demand_history": {
        "type": "array",
        "items": { "type": "number" },
        "description": "Historical daily demand values for empirical sampling."
      },
      "mean_lead_time": {
        "type": "number",
        "description": "Average lead time in days."
      },
      "lead_time_std_dev": {
        "type": "number",
        "description": "Standard deviation of lead time in days."
      },
      "service_level": {
        "type": "number",
        "description": "Target service level (0-1)."
      },
      "paths": {
        "type": "integer",
        "description": "Number of Monte Carlo paths. Default 10000."
      },
      "seed": {
        "type": "integer",
        "description": "Random seed for reproducibility. Default 42."
      }
    },
    "required": ["demand_history", "mean_lead_time", "service_level"]
  }
}
```

---

## 5. Constraints & Compliance

### Concurrency

- All types are `struct` with `Sendable` conformance
- No mutable shared state — all methods are `static` (pure functions)
- `InventorySimulator` uses seeded RNG for deterministic results; no `@Sendable` closure captures needed

### Determinism

- All calculations using `Real` protocol arithmetic are deterministic
- Monte Carlo simulation requires explicit `seed` parameter
- No floating-point-order-dependent reductions (use compensated summation where needed)

### Generics

- All types generic over `<T: Real & Sendable & Codable>` matching library convention
- Double specialization extensions with default parameters where useful
- Statistics dependencies (`normalCDF`, `inverseNormalCDF`) are already generic over `<T: Real>`

### Safety

- Division guards: all denominators checked before division (demand, std dev, costs)
- Domain validation: service level ∈ (0, 1), costs ≥ 0, quantities ≥ 0
- No force unwraps, no `try!`, no force casts
- Guard clauses for all validation; early returns over nested ifs
- Fail-silent principle: never return plausible-but-wrong results — throw `OperationsError`

---

## 6. Backend Abstraction

Not applicable for this module. All computations are scalar arithmetic and small-array operations. No vectorized/GPU paths needed. The `InventorySimulator` could theoretically benefit from SIMD path generation, but 10K paths of ~7-14 day lead times is trivially fast on CPU.

If simulation path counts grow to 1M+, we can add an Accelerate-backed variant in a future iteration.

---

## 7. Dependencies

### Internal (within BusinessMath)

| Module | Types Used | Purpose |
|--------|-----------|---------|
| Statistics | `normalCDF<T>`, `inverseNormalCDF<T>` | z-score ↔ service level conversion |
| Statistics | `percentile(zScore:)` | Percentile lookups |
| Simulation | `MonteCarloSimulation`, `SimulationInput` | Trial execution for InventorySimulator |
| Simulation | `DeterministicRNG` | Seeded reproducible RNG |
| Simulation | `SimulationResults` | Statistics, percentiles, probability queries |
| Forecasting | `HoltWintersModel<T>` | Optional: forecast RMSE for safety stock |
| Core | `standardDeviation<T>` | Demand variability from history |

### External

None. All dependencies are internal to BusinessMath.

---

## 8. Test Strategy

### 8.1 Golden Path Tests

| Test | Reference Truth | Validation |
|------|----------------|------------|
| EOQ: Q* = √(2×10×936 / 7.50) ≈ 50 | standard operations management textbook Problem 1 | Tolerance: 0.01 |
| Newsvendor: p_c = 5/7 ≈ 0.714, Q* = 2 (discrete) | standard operations management textbook Example 1 | Exact for discrete |
| Newsvendor (normal): μ=40, σ=18, c_u=1, c_o=0.5, Q*≈48 | standard operations management textbook watermelon example | Tolerance: 0.5 |
| Safety stock (demand only): SS = 1.645 × 5 × √7 ≈ 21.76 | Hand calculation | Tolerance: 0.01 |
| Safety stock (demand+LT): SS = 1.645 × √(7×25 + 100×4) ≈ 35.0 | Hand calculation | Tolerance: 0.1 |

### 8.2 Edge Cases

- Zero demand → `OperationsError.zeroDemand`
- Service level = 0, 1, or out of range → `OperationsError.invalidServiceLevel`
- Lead time std dev = 0 → `demandAndLeadTime` degenerates to `demandOnly`
- Very high service level (0.999) → large z-score, large safety stock
- Very low service level (0.5) → z ≈ 0, safety stock ≈ 0

### 8.3 Property-Based Tests

- EOQ: `totalCost(Q*)` ≤ `totalCost(Q* ± 1)` (optimality)
- Newsvendor: `criticalFractile(c_u, c_o)` ∈ (0, 1) for all positive costs
- Safety stock: monotonically increasing with service level
- Safety stock: `demandAndLeadTime` ≥ `demandOnly` (when σ_L > 0)
- Reorder point: always ≥ demand during lead time (when service level > 0.5)

### 8.4 Cross-Validation

- Simulate 100K paths → empirical stockout rate should match analytical prediction within 1%
- EOQ total cost decomposition: ordering cost ≈ holding cost at Q* (within rounding)
- Newsvendor Q* via simulation vs. analytical formula (within σ/√N tolerance)

### 8.5 Numerical Stability

- Very large demand values (1e12)
- Very small standard deviations (1e-10)
- Service levels near boundaries (0.001, 0.999)
- Float vs Double consistency (generic tests)

### 8.6 Stress Tests

- `InventorySimulator` with 100K paths completes in < 2 seconds
- EOQ with extreme inputs (demand = 1e15, cost = 1e-10)

### 8.7 Fault Injection

- Demand history with NaN values
- Negative demand in history
- Zero-length demand array
- Lead time of 0

---

## 9. Architecture Decision Review

### ADR: Static Methods vs. Instance Methods

**Decision:** Use static methods on zero-stored-property structs (namespace pattern).

**Rationale:** These models are pure functions — they take inputs, compute outputs, and store no state. Unlike `HoltWintersModel` which has a train-then-predict lifecycle requiring mutable state (`level`, `trend`, `seasonal`), inventory models are one-shot calculations. Using `static func` makes this explicit and avoids the anti-pattern of constructing an empty struct just to call a method.

**Exception:** `InventorySimulator` could potentially store configuration (path count, seed) if we want a builder pattern. For v1, keep it static — configuration is passed per-call.

### ADR: Method Enum vs. Separate Types

**Decision:** `SafetyStockModel` uses a `Method` enum to select the formula, rather than separate `DemandOnlySafetyStock`, `DemandAndLeadTimeSafetyStock` types.

**Rationale:** The three methods differ in one term of the formula. Separate types would duplicate 90% of the code and make the API surface harder to discover. The enum makes the choice explicit and the switch is exhaustive.

**Trade-off:** If methods diverge significantly in the future (e.g., Bayesian safety stock with prior distributions), a protocol-based strategy pattern may be warranted. Monitor for this.

---

## 10. Adversarial Review

### Strongest Case for Alternative Approach

**"These should be free functions, not namespacing structs."**

BusinessMath already uses free functions extensively (`normalCDF`, `inverseNormalCDF`, `standardDeviation`). Why not `func safetyStock(...)` at module scope?

**Response:** Free functions work well for single-return-value computations. These models return rich result types with multiple fields. Namespacing via struct groups the result type with its computation and keeps the module's top-level namespace clean. The existing `HoltWintersModel<T>` and `MonteCarloEngine` set this precedent.

### Where Design Is Most Likely Wrong

**The `InventorySimulator` sampling strategy.** Addressed in v1 with the `SamplingStrategy` enum (empirical, normal, poisson, negativeBinomial, forecastResidual). Remaining risk:

1. Demand auto-correlation (today's high demand may predict tomorrow's) is not modeled by any strategy
2. The `forecastResidual` strategy assumes residuals are i.i.d. — if they have serial correlation, the simulation understates tail risk
3. Strategy selection by `InventoryAdvisor` uses heuristics (coefficient of variation threshold) that may not generalize across all product categories

### What an Experienced Critic Would Say

*"You're giving people six ways to compute safety stock but no guidance on when to use which. A Shopify merchant with 30 days of sales data doesn't need a Monte Carlo simulator — they need the simplest formula that's correct for their situation, with clear defaults."*

**Response:** Valid. The implementation should include a `recommended(for:)` method or clear DocC guidance that routes users to the right method based on data availability:

- < 30 days data, no cost info → `demandOnly` with default 0.95 service level
- ≥ 30 days data, lead time varies → `demandAndLeadTime`
- Have cost/margin data → Newsvendor
- Have forecast model → `forecastError`
- Irregular/intermittent demand → `InventorySimulator`

---

## 11. Open Questions — RESOLVED

1. **InventorySimulator and MonteCarloEngine** — RESOLVED: `InventorySimulator` composes the existing `MonteCarloSimulation` (the generic N-trial runner) via custom `SimulationInput` samplers. `MonteCarloEngine` (derivative pricing) is a separate concern and stays untouched. No `SimulationRunner` protocol needed — `MonteCarloSimulation` is already the generic runner.

2. **Discrete demand for Newsvendor** — RESOLVED: Continuous normal CDF subsumes discrete cases. No lookup table — `inverseNormalCDF` handles all practical cases with rounding.

3. **TimeSeries integration** — RESOLVED: Dual API from the start. Raw `[T]` for values, `TimeSeries<T>` convenience methods where applicable.

4. **Unit system** — RESOLVED: Implicit, with clear documentation and tutorial. All inputs must use consistent time units. Tutorial covers correct and incorrect usage with worked examples.

---

## 12. Documentation Strategy

### API Documentation

All public types and methods get full DocC comments with:
- Mathematical formula (using Unicode: μ, σ, √, etc.)
- Parameter descriptions with units and valid ranges
- Real-world example (e-commerce inventory scenario)
- Excel equivalent function name where applicable (NORMSINV, etc.)
- Cross-references to related types within the module

### Narrative Article

Create a DocC article: **"Inventory Management Models"** covering:

1. When to use each model (decision tree matching `InventoryAdvisor` logic)
2. Worked example: Shopify store with seasonal demand
3. Progression from basic safety stock → newsvendor → simulation
4. Common pitfalls (mixing time units, ignoring lead time variability)
5. References to standard operations management formulas

### Tutorial Document

Create a DocC tutorial: **"Choosing the Right Inventory Model"** covering:

1. What data you need and why
2. How `InventoryAdvisor.recommended(for:)` makes its decisions
3. Unit consistency (daily vs. weekly vs. monthly) with correct/incorrect examples
4. When to graduate from basic safety stock to newsvendor to simulation
5. Interpreting results for non-technical users

### Excel Equivalents Table

| BusinessMath | Excel | Description |
|-------------|-------|-------------|
| `SafetyStockModel.zScore(for: 0.95)` | `=NORMSINV(0.95)` | Service level → z-score |
| `EOQModel.calculate(D, S, H)` | `=SQRT(2*S*D/H)` | Economic Order Quantity |
| `NewsvendorModel.criticalFractile(cu, co)` | `=cu/(cu+co)` | Critical fractile |
| `NewsvendorModel.optimalQuantity(μ, σ, cu, co)` | `=NORMINV(cu/(cu+co), μ, σ)` | Newsvendor Q* |

---

## Implementation Plan

### Phase 1: Foundation (RED → GREEN)

| Step | File | Tests | Depends On |
|------|------|-------|------------|
| 1.1 | `OperationsError.swift` | Error case tests | — |
| 1.2 | `SafetyStockModel.swift` | 3 methods × 5 test categories | 1.1, Statistics |
| 1.3 | `ReorderPointModel.swift` | Golden path + stockout probability | 1.2 |

### Phase 2: Economic Models (RED → GREEN)

| Step | File | Tests | Depends On |
|------|------|-------|------------|
| 2.1 | `EOQModel.swift` | EOQ + total cost + optimality proof | 1.1 |
| 2.2 | `NewsvendorModel.swift` | Critical fractile + optimal Q + expected profit | 1.1, Statistics |

### Phase 3: Simulation & Advisory (RED → GREEN)

| Step | File | Tests | Depends On |
|------|------|-------|------------|
| 3.1 | `InventorySimulator.swift` | SamplingStrategy, convergence, cross-validation | 1.2, MonteCarloSimulation |
| 3.2 | `InventoryAdvisor.swift` | recommended(for:) logic, all data profiles | 1.2, 2.2, 3.1 |

### Phase 4: REFACTOR → DOCUMENT → VERIFY

| Step | Activity |
|------|----------|
| 4.1 | Refactor: extract shared validation, reduce duplication |
| 4.2 | DocC comments on all public APIs |
| 4.3 | DocC narrative article: "Inventory Management Models" |
| 4.4 | DocC tutorial: "Choosing the Right Inventory Model" |
| 4.5 | Quality gate: `swift build` + `swift test` + safety checks |

### Phase 5: MCP Integration

| Step | Activity |
|------|----------|
| 5.1 | Add MCP tool handlers to businessMathMCP |
| 5.2 | MCP integration tests |

### Phase 6: StockOpt Integration

| Step | Activity |
|------|----------|
| 6.1 | Update StockOpt's `ReorderEngine` to use `BusinessMath.SafetyStockModel` |
| 6.2 | Add newsvendor endpoint to StockOpt API |
| 6.3 | Update StockOpt tests |

---

## Proposal Review Checklist

- [x] **Architecture**: File placement follows module convention, no circular dependencies
- [x] **MCP Readiness**: JSON schemas for all public models, required fields marked, descriptions complete
- [x] **Backend Abstraction**: N/A — scalar arithmetic only, no GPU path needed
- [x] **Testing**: 7 test categories planned, reference truth from standard operations management formulas (independently verifiable)
- [x] **Adversarial Review**: Alternative approaches evaluated, weakest design point identified
- [x] **Dependencies**: All internal, no new external packages
- [x] **Concurrency**: All types Sendable, no mutable shared state
- [x] **Generics**: `<T: Real & Sendable & Codable>` throughout
- [ ] **Approval**: Awaiting review
