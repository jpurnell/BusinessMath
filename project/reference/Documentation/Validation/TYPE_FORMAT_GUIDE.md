# TYPE_FORMAT_GUIDE.md

This document formalizes the mandatory data types, constraints, and format requirements used throughout the BusinessMath ecosystem. All AI-generated code, documentation, and MCP tool definitions must strictly adhere to these standards to ensure type safety and interoperability.

## I. Numeric Type Constraints

### 1. Generic Real Type (`T: Real`)
The library prioritizes generic programming for flexibility across numeric types.

| Constraint | Requirement | Source Support |
| :--- | :--- | :--- |
| **Primary Constraint** | Use generic type **`<T: Real>`** for all financial and mathematical functions. | [1-4] |
| **Source** | The `Real` protocol is sourced from the **`swift-numerics`** dependency. | [1, 5, 6] |
| **Supported Types** | `Real` enables compatibility with standard floating-point types like `Double` and `Float`. | [1] |
| **Floating Point Safet** | Many distribution and statistics functions require an additional constraint: **`<T: BinaryFloatingPoint>`** to ensure safe numeric conversions, especially on 32-bit systems (Apple Watch) [7-9]. | [8, 9] |

### 2. Invalid Input Handling

Functions must handle mathematically undefined operations rigorously to avoid masking errors.

| Condition | Action | Rationale / Source Support |
| :--- | :--- | :--- |
| **Mathematically Undefined** | Must return **`NaN`** (Not a Number) [10, 11]. This allows computations to continue while signaling invalidity [10]. | [10-13] |
| **Programming Error** | Must **throw a dedicated error** (e.g., `FinancialError`, `SimulationError`) [10]. This is required when an invalid input prevents the operation from proceeding meaningfully [10]. | [10-12] |
| **Substitution Rule** | **Never silently substitute default values** that mask mathematical errors or produce incorrect results [10, 14, 15]. | [12, 14, 15] |

## II. Temporal Data Formats

The project uses the internal `Period` struct as the primary temporal container, but external integration (like MCP tools and data sources) requires explicit string formats.

### 1. Internal Period Type Values

The `PeriodType` enum is used internally for temporal definition and aggregation [16-19].

| Enum Case | Description | Source Support |
| :--- | :--- | :--- |
| **`daily`** | Daily granularity | [17, 18] |
| **`monthly`** | Monthly granularity | [17, 18] |
| **`quarterly`** | Quarterly granularity | [17, 18] |
| **`annual`** | Annual granularity | [17, 18] |

### 2. External Date Format Strings

When dates must be passed as strings (e.g., through JSON for I/O), specific formats must be enforced.

| Context | Format Standard | Example | Source Support |
| :--- | :--- | :--- | :--- |
| **Irregular Cash Flows (MCP)** | **ISO 8601 (Strict)** | `2025-01-15` or `2025-01-15T00:00:00Z` | [20, 21] |
| **FinancialAnalysis (CSV Annual)** | Plain Year | `2023` | [22, 23] |
| **FinancialAnalysis (CSV Quarterly)** | Year-Q-Quarter | `2023-Q1`, `2023-Q2` | [22, 23] |
| **FinancialAnalysis (CSV Monthly)** | Year-Month | `2023-01`, `2023-12` | [22, 23] |

## III. Concurrency and Mutability Standards

All core types must be designed for full compliance with the strict Swift concurrency model.

| Principle | Requirement | Source Support |
| :--- | :--- | :--- |
| **Concurrency** | All public types, including `Period`, `TimeSeries`, and their contained generics, must conform to **`Sendable`** for Swift 6.0 strict concurrency compliance [24-26]. | [24-27] |
| **Immutability** | Core data structures (like `Period` and `TimeSeries`) must be implemented as **`structs`** and their operations must return **new values** [4, 25, 28]. | [4, 25, 28] |

## IV. Standard Enumerations

These enumerations define acceptable categorical values for key functions and protocols, which must be listed explicitly in MCP tool documentation [21].

| Enum | Location | Acceptable Values | Source Support |
| :--- | :--- | :--- | :--- |
| **`PeriodType`** | Time Series | `daily`, `monthly`, `quarterly`, `annual` | [17, 18] |
| **`AnnuityType`** | TVM | `ordinary` (end of period), `due` (beginning of period) | [29] |
| **`CompoundingFrequency`** | Growth/TVM | `annual`, `semiannual`, `quarterly`, `monthly`, `daily`, `continuous` | [30] |
| **`DecompositionMethod`** | Seasonality | `additive`, `multiplicative` | [31] |
