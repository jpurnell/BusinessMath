# DESIGN_PRINCIPLES.md

## Core Architectural Constraints

These principles define the fundamental structure and behavior of the BusinessMath Library and all related packages (Adapters, UI, MCP Server). Adherence to these constraints is mandatory for all code generation and review.

### I. Immutability and Composability

The library must be built using functional paradigms that prioritize data integrity and flexibility.

1.  **Immutability**: All operations performed on core data structures, such as `TimeSeries` and `Period`, must return a **new value** rather than modifying the original instance [1-3]. This is enforced by preferring `structs` over classes for value semantics [4].
2.  **Composability**: Components must be designed as self-contained building blocks [5]. Complex functionality, such as operational modeling, should be achieved by **chaining operations** (e.g., `TimeSeries` operations) [1, 3].
3.  **Type Safety**: The library must leverage Swift’s robust type system and generics to prevent errors [1, 3]. Numeric functions must utilize the generic constraint **`<T: Real>`** (from `swift-numerics`) for flexibility across `Float`, `Double`, and other floating-point types [6].

### II. Quality Assurance and Mathematical Rigor

All code must adhere to strict quality standards, particularly concerning testing and mathematical correctness.

1.  **Test-Driven Development (TDD)**: Implementation must strictly follow the **Test-Driven Development approach** [7-9]. Tests must be **written first** to define the expected behavior of a function or component before implementation begins [10].
2.  **Deterministic Testing**: When testing stochastic functions (e.g., probability distributions, Monte Carlo simulations), tests must **always prioritize deterministic, seeded values** over truly random values to ensure test repeatability and eliminate flakiness in Continuous Integration (CI) [11-13].
3.  **Mathematical Correctness**: The library must never use **default values that mask mathematically undefined operations** [14-16].
    *   If an operation is mathematically undefined (e.g., division by zero, invalid degrees of freedom), the function must return **`NaN`** (Not a Number) [16-18].
    *   If the invalid input represents a programming error or prevents meaningful execution, the function must **throw a dedicated error** [16, 17].
4.  **Testability**: Functions must be designed as **pure functions** and support dependency injection (e.g., for date/time sources) to ensure testability [1, 3].

### III. Performance and Concurrency

The library must be highly performant and designed for modern, concurrent Swift execution.

1.  **Efficiency**: Code must be designed for performance, prioritizing **O(1) lookups** (using `Dictionary` storage where appropriate) [1, 3, 19]. Optimization efforts target moving complex initializations to **O(n) or better** complexity [2, 20].
2.  **Strict Concurrency**: All types exposed publicly must conform to **`Sendable`** to ensure thread safety and strict concurrency compliance under Swift 6.0 [21-24].
3.  **Performance Targets**: Optimization should be guided by measurable targets, such as maintaining **sub-millisecond financial calculations** [25-27].

### IV. Design and Compatibility

APIs should be intuitive for developers and consistent with industry standards.

1.  **Excel Compatibility**: Financial functions should **match Excel function names and behavior** where sensible (e.g., TVM functions like `NPV`, `IRR`, `XNPV`) [1, 3].
2.  **Progressive Disclosure**: The API design should make **simple cases simple** to execute, while advanced features (like correlation matrices or custom optimization constraints) remain available but not required for basic use [5, 28].
3.  **Protocol-Oriented Design**: Behavior contracts (like `Driver` or `TrendModel`) must be clearly defined using protocols, enabling flexibility and extension [29-31].
