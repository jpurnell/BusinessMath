## 4. **No Support for Multi-Dimensional Optimization**

The current design is strictly 1D. Many business/financial problems are multivariate (portfolio optimization, regression, etc.).

**Proposal**: Consider a separate `MultivariateOptimizer` protocol or extend the current design with vector support:
```swift
protocol MultivariateOptimizer {
    associatedtype Vector: RealVector
    
    func optimize(
        objective: @escaping (Vector) -> T,
        constraints: [Constraint<Vector>],
        initialValue: Vector,
        bounds: (lower: Vector, upper: Vector)?
    ) -> OptimizationResult<Vector>
}
```
