//
//  ExpressionArray.swift
//  BusinessMath
//
//  Fixed-size array operations for GPU-accelerated Monte Carlo
//
//  Provides compile-time fixed-size arrays that can be compiled to GPU bytecode.
//  Unlike dynamic Swift arrays, these arrays have known sizes at compile time,
//  enabling GPU shader compilation.
//

import Foundation

// MARK: - Expression Array

/// A fixed-size array of expressions that can be compiled to GPU bytecode
///
/// ExpressionArray provides array operations with compile-time known sizes,
/// enabling GPU acceleration. Unlike dynamic Swift arrays, the size is fixed
/// at creation and all operations are unrolled at compile time.
///
/// ## Usage
///
/// ```swift
/// let model = MonteCarloExpressionModel { builder in
///     // Create fixed-size array from inputs
///     let weights = builder.array([0, 1, 2])  // 3 portfolio weights
///     let returns = builder.array([
///         0.08,  // Asset 1: 8% return
///         0.10,  // Asset 2: 10% return
///         0.12   // Asset 3: 12% return
///     ])
///
///     // Array operations (all compile to GPU)
///     let portfolioReturn = weights.dot(returns)
///     let totalWeight = weights.sum()
///     let maxWeight = weights.max()
///
///     return portfolioReturn
/// }
/// ```
///
/// ## Supported Operations
///
/// - Reduction: `sum()`, `product()`, `min()`, `max()`, `mean()`
/// - Element-wise: `map()`, `zipWith()`
/// - Linear algebra: `dot()`, `norm()`, `normalize()`
/// - Statistical: `variance()`, `stdDev()`
public struct ExpressionArray: Sendable {

    /// The fixed-size array of expressions
    public let elements: [ExpressionProxy]

    /// The compile-time known size of this array
    public var count: Int { elements.count }

    /// Create an array from expression elements
    ///
    /// - Parameter elements: Array of expression proxies
    internal init(elements: [ExpressionProxy]) {
        self.elements = elements
    }

    // MARK: - Reduction Operations

    /// Sum all elements
    ///
    /// ## Example
    /// ```swift
    /// let weights = builder.array([0, 1, 2])
    /// let totalWeight = weights.sum()  // weights[0] + weights[1] + weights[2]
    /// ```
    public func sum() -> ExpressionProxy {
        guard !elements.isEmpty else {
            return ExpressionProxy(.constant(0.0))
        }

        return elements.dropFirst().reduce(elements[0]) { partial, element in
            partial + element
        }
    }

    /// Multiply all elements
    ///
    /// ## Example
    /// ```swift
    /// let factors = builder.array([1.1, 1.2, 1.05])
    /// let compound = factors.product()  // 1.1 * 1.2 * 1.05
    /// ```
    public func product() -> ExpressionProxy {
        guard !elements.isEmpty else {
            return ExpressionProxy(.constant(1.0))
        }

        return elements.dropFirst().reduce(elements[0]) { partial, element in
            partial * element
        }
    }

    /// Find maximum element
    ///
    /// ## Example
    /// ```swift
    /// let weights = builder.array([0, 1, 2])
    /// let maxWeight = weights.max()
    /// ```
    public func max() -> ExpressionProxy {
        guard !elements.isEmpty else {
            return ExpressionProxy(.constant(-.infinity))
        }

        return elements.dropFirst().reduce(elements[0]) { partial, element in
            partial.max(element)
        }
    }

    /// Find minimum element
    ///
    /// ## Example
    /// ```swift
    /// let prices = builder.array([0, 1, 2])
    /// let minPrice = prices.min()
    /// ```
    public func min() -> ExpressionProxy {
        guard !elements.isEmpty else {
            return ExpressionProxy(.constant(.infinity))
        }

        return elements.dropFirst().reduce(elements[0]) { partial, element in
            partial.min(element)
        }
    }

    /// Calculate arithmetic mean
    ///
    /// ## Example
    /// ```swift
    /// let returns = builder.array([0, 1, 2])
    /// let avgReturn = returns.mean()
    /// ```
    public func mean() -> ExpressionProxy {
        let total = sum()
        return total / Double(count)
    }

    // MARK: - Element-wise Operations

    /// Apply function to each element
    ///
    /// ## Example
    /// ```swift
    /// let prices = builder.array([0, 1, 2])
    /// let logPrices = prices.map { $0.log() }
    /// ```
    public func map(_ transform: (ExpressionProxy) -> ExpressionProxy) -> ExpressionArray {
        return ExpressionArray(elements: elements.map(transform))
    }

    /// Combine two arrays element-wise
    ///
    /// ## Example
    /// ```swift
    /// let weights = builder.array([0, 1, 2])
    /// let returns = builder.array([0.08, 0.10, 0.12])
    /// let products = weights.zipWith(returns) { w, r in w * r }
    /// ```
    public func zipWith(
        _ other: ExpressionArray,
        _ combine: (ExpressionProxy, ExpressionProxy) -> ExpressionProxy
    ) -> ExpressionArray {
        guard count == other.count else {
            fatalError("ExpressionArray.zipWith requires arrays of same size")
        }

        let zipped = zip(elements, other.elements).map { combine($0, $1) }
        return ExpressionArray(elements: zipped)
    }

    // MARK: - Linear Algebra

    /// Dot product with another array
    ///
    /// ## Example - Portfolio Return
    /// ```swift
    /// let weights = builder.array([0, 1, 2])
    /// let returns = builder.array([0.08, 0.10, 0.12])
    /// let portfolioReturn = weights.dot(returns)
    /// ```
    public func dot(_ other: ExpressionArray) -> ExpressionProxy {
        guard count == other.count else {
            fatalError("ExpressionArray.dot requires arrays of same size")
        }

        let products = zipWith(other) { $0 * $1 }
        return products.sum()
    }

    /// Euclidean norm (L2 norm)
    ///
    /// ## Example
    /// ```swift
    /// let vector = builder.array([0, 1, 2])
    /// let length = vector.norm()  // sqrt(x[0]² + x[1]² + x[2]²)
    /// ```
    public func norm() -> ExpressionProxy {
        let squares = map { $0 * $0 }
        let sumSquares = squares.sum()
        return sumSquares.sqrt()
    }

    /// Normalize to unit length
    ///
    /// ## Example
    /// ```swift
    /// let weights = builder.array([0, 1, 2])
    /// let normalized = weights.normalize()  // Sum to 1
    /// ```
    public func normalize() -> ExpressionArray {
        let total = sum()
        return map { $0 / total }
    }

    // MARK: - Statistical Operations

    /// Calculate variance
    ///
    /// ## Example
    /// ```swift
    /// let returns = builder.array([0, 1, 2, 3, 4])
    /// let variance = returns.variance()
    /// ```
    public func variance() -> ExpressionProxy {
        let avg = mean()
        let deviations = map { ($0 - avg) * ($0 - avg) }
        return deviations.sum() / Double(count)
    }

    /// Calculate standard deviation
    ///
    /// ## Example
    /// ```swift
    /// let returns = builder.array([0, 1, 2, 3, 4])
    /// let stdDev = returns.stdDev()
    /// ```
    public func stdDev() -> ExpressionProxy {
        return variance().sqrt()
    }

    // MARK: - Subscript

    /// Access element by index
    ///
    /// ## Example
    /// ```swift
    /// let weights = builder.array([0, 1, 2])
    /// let firstWeight = weights[0]
    /// ```
    public subscript(index: Int) -> ExpressionProxy {
        return elements[index]
    }
}

// MARK: - ExpressionBuilder Array Extension

extension ExpressionBuilder {

    /// Create fixed-size array from input indices
    ///
    /// ## Example
    /// ```swift
    /// let builder = ExpressionBuilder()
    /// let weights = builder.array([0, 1, 2])  // inputs[0], inputs[1], inputs[2]
    /// ```
    public func array(_ indices: [Int]) -> ExpressionArray {
        return ExpressionArray(elements: indices.map { self[$0] })
    }

    /// Create fixed-size array from constants
    ///
    /// ## Example
    /// ```swift
    /// let builder = ExpressionBuilder()
    /// let returns = builder.array([0.08, 0.10, 0.12])
    /// ```
    public func array(_ constants: [Double]) -> ExpressionArray {
        return ExpressionArray(elements: constants.map { ExpressionProxy(.constant($0)) })
    }

    /// Create fixed-size array from expressions
    ///
    /// ## Example
    /// ```swift
    /// let builder = ExpressionBuilder()
    /// let a = builder[0]
    /// let b = builder[1]
    /// let arr = builder.array([a, b, a + b])
    /// ```
    public func array(_ expressions: [ExpressionProxy]) -> ExpressionArray {
        return ExpressionArray(elements: expressions)
    }
}

// MARK: - Loop Unrolling

extension ExpressionBuilder {

    /// Unroll a fixed-size loop at compile time
    ///
    /// Generates explicit expressions for each iteration, enabling GPU compilation.
    /// The loop is completely unrolled - no runtime iteration occurs.
    ///
    /// ## Example - Multi-Period Compounding
    ///
    /// ```swift
    /// let model = MonteCarloExpressionModel { builder in
    ///     let principal = builder[0]
    ///     let rate = builder[1]
    ///
    ///     // Compound for 10 periods (unrolled at compile time)
    ///     let finalValue = builder.forEach(0..<10, initial: principal) { iteration, value in
    ///         return value * (1.0 + rate)  // Executed for iteration 0, 1, 2, ..., 9
    ///     }
    ///
    ///     return finalValue
    /// }
    /// ```
    ///
    /// ## Example - NPV Calculation
    ///
    /// ```swift
    /// let model = MonteCarloExpressionModel { builder in
    ///     let cashFlow = builder[0]
    ///     let discountRate = builder[1]
    ///
    ///     // Calculate NPV for 5 years (unrolled)
    ///     let npv = builder.forEach(1...5, initial: 0.0) { year, accumulated in
    ///         let cf = cashFlow
    ///         let pv = cf / (1.0 + discountRate).power(Double(year))
    ///         return accumulated + pv
    ///     }
    ///
    ///     return npv
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - range: Fixed range to iterate over (e.g., `0..<10` or `1...5`)
    ///   - initial: Initial value (can be constant or expression)
    ///   - body: Closure executed for each iteration (unrolled at compile time)
    /// - Returns: Final accumulated value after all iterations
    public func forEach<R: RangeExpression>(
        _ range: R,
        initial: ExpressionProxy,
        body: (Int, ExpressionProxy) -> ExpressionProxy
    ) -> ExpressionProxy where R.Bound == Int {

        let bounds = Array(range)

        return bounds.reduce(initial) { accumulated, iteration in
            body(iteration, accumulated)
        }
    }

    /// Unroll loop with constant initial value
    ///
    /// ## Example
    /// ```swift
    /// let finalValue = builder.forEach(0..<5, initial: 100_000.0) { year, value in
    ///     value * (1.0 + builder[0])
    /// }
    /// ```
    public func forEach<R: RangeExpression>(
        _ range: R,
        initial: Double,
        body: (Int, ExpressionProxy) -> ExpressionProxy
    ) -> ExpressionProxy where R.Bound == Int {

        return forEach(range, initial: ExpressionProxy(.constant(initial)), body: body)
    }
}

// MARK: - Range Helper

extension RangeExpression where Bound == Int {
    fileprivate func toArray() -> [Int] {
        if let range = self as? Range<Int> {
            return Array(range)
        } else if let range = self as? ClosedRange<Int> {
            return Array(range)
        } else {
            return Array(0..<0)  // Fallback
        }
    }
}

private extension Array where Element == Int {
    init<R: RangeExpression>(_ range: R) where R.Bound == Int {
        if let r = range as? Range<Int> {
            self = Array(r)
        } else if let r = range as? ClosedRange<Int> {
            self = Array(r)
        } else {
            self = []
        }
    }
}
