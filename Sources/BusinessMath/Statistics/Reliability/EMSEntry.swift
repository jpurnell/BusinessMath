import Numerics

/// An entry in an Expected Mean Squares (EMS) table.
///
/// Each entry pairs a variance component (identified by its set of facet names)
/// with the coefficient that multiplies it in the EMS equation for a given effect.
///
/// Example:
/// ```swift
/// // In a p × r design, EMS({p}) = n_r * sigma^2_p + sigma^2_{p,r}
/// // The entry for sigma^2_p in EMS({p}) has coefficient n_r.
/// let entry = EMSEntry<Double>(component: Set(["p"]), coefficient: 3.0)
/// ```
public struct EMSEntry<T: Real & Sendable>: Sendable, Equatable {

    /// The variance component, identified by the set of facet names it involves.
    public let component: Set<String>

    /// The coefficient multiplying this variance component in the EMS equation.
    public let coefficient: T

    /// Creates an EMS entry.
    ///
    /// - Parameters:
    ///   - component: The set of facet names identifying the variance component.
    ///   - coefficient: The multiplier for this component in the EMS equation.
    public init(component: Set<String>, coefficient: T) {
        self.component = component
        self.coefficient = coefficient
    }
}
