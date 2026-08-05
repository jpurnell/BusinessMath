## Phase 2: VectorSpace Foundation (Multi-Dimensional Optimization)

### Step 2.1: VectorSpace Protocol

**File:** `Sources/BusinessMath/Optimization/Vector/VectorSpace.swift`

```swift
//
//  VectorSpace.swift
//  BusinessMath
//
//  Created by Justin Purnell on [Date].
//

import Foundation
import Numerics

/// Protocol for types that behave like mathematical vectors.
///
/// `VectorSpace` defines the basic operations needed for multi-dimensional
/// optimization, including vector arithmetic, norms, and dot products.
///
/// ## Example Implementation
///
/// ```swift
/// struct Vector2D<T: Real>: VectorSpace {
///     var x: T
///     var y: T
///
///     static func + (lhs: Vector2D, rhs: Vector2D) -> Vector2D {
///         Vector2D(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
///     }
///
///     static func * (lhs: T, rhs: Vector2D) -> Vector2D {
///         Vector2D(x: lhs * rhs.x, y: lhs * rhs.y)
///     }
///
///     var norm: T { T.sqrt(x * x + y * y) }
///
///     func dot(_ other: Vector2D) -> T {
///         x * other.x + y * other.y
///     }
/// }
/// ```
public protocol VectorSpace: Equatable, Sendable, Codable {
    associatedtype Scalar: Real & Sendable & Codable

    /// Zero vector (additive identity).
    static var zero: Self { get }

    /// Vector addition

