import Foundation

/// Specifies which variables in an optimization problem must take integer or binary values
public struct IntegerProgramSpecification: Sendable {
    /// Variables that must take integer values (can be any integer)
    public let integerVariables: Set<Int>

    /// Variables that must be binary (0 or 1)
    public let binaryVariables: Set<Int>

    /// Special Ordered Sets Type 1: At most one variable in each set can be nonzero
    public let sosType1: [[Int]]

    /// Special Ordered Sets Type 2: At most two adjacent variables in each set can be nonzero
    public let sosType2: [[Int]]

    /// Create an integer program specification
    /// - Parameters:
    ///   - integerVariables: Indices of variables that must be integers
    ///   - binaryVariables: Indices of variables that must be binary (0 or 1)
    ///   - sosType1: Special ordered sets type 1 constraints
    ///   - sosType2: Special ordered sets type 2 constraints
    public init(
        integerVariables: Set<Int> = [],
        binaryVariables: Set<Int> = [],
        sosType1: [[Int]] = [],
        sosType2: [[Int]] = []
    ) {
        self.integerVariables = integerVariables
        self.binaryVariables = binaryVariables
        self.sosType1 = sosType1
        self.sosType2 = sosType2
    }

    /// All variables that have integer restrictions (general integer + binary)
    public var allIntegerVariables: Set<Int> {
        integerVariables.union(binaryVariables)
    }

    /// Check if a solution satisfies all integer requirements
    /// - Parameters:
    ///   - solution: The solution vector to check
    ///   - tolerance: Maximum deviation from integer value to consider feasible
    /// - Returns: True if the solution is integer-feasible
    public func isIntegerFeasible<V: VectorSpace>(
        _ solution: V,
        tolerance: V.Scalar = 1e-6
    ) -> Bool where V.Scalar == Double {
        let values = solution.toArray()

        // Check general integer variables
        for i in integerVariables {
            guard i < values.count else { return false }
            let value = values[i]
            let rounded = round(value)
            if abs(value - rounded) > tolerance {
                return false
            }
        }

        // Check binary variables
        for i in binaryVariables {
            guard i < values.count else { return false }
            let value = values[i]
            if abs(value) > tolerance && abs(value - 1.0) > tolerance {
                return false
            }
        }

        // Check SOS1 constraints
        for sosSet in sosType1 {
            var nonzeroCount = 0
            for i in sosSet {
                guard i < values.count else { return false }
                if abs(values[i]) > tolerance {
                    nonzeroCount += 1
                }
            }
            if nonzeroCount > 1 {
                return false
            }
        }

        // Check SOS2 constraints
        for sosSet in sosType2 {
            var nonzeroIndices: [Int] = []
            for (idx, i) in sosSet.enumerated() {
                guard i < values.count else { return false }
                if abs(values[i]) > tolerance {
                    nonzeroIndices.append(idx)
                }
            }
            if nonzeroIndices.count > 2 {
                return false
            }
            if nonzeroIndices.count == 2 {
                // Check if adjacent
                let diff = abs(nonzeroIndices[0] - nonzeroIndices[1])
                if diff != 1 {
                    return false
                }
            }
        }

        return true
    }

    /// Round a solution to nearest integer values for integer-constrained variables
    /// - Parameter solution: The solution vector to round
    /// - Returns: A new vector with integer variables rounded
    public func rounded<V: VectorSpace>(_ solution: V) -> V where V.Scalar == Double {
        var values = solution.toArray()

        // Round general integer variables
        for i in integerVariables {
            guard i < values.count else { continue }
            values[i] = round(values[i])
        }

        // Round binary variables to 0 or 1
        for i in binaryVariables {
            guard i < values.count else { continue }
            values[i] = round(values[i])
            values[i] = max(0.0, min(1.0, values[i])) // Clamp to [0, 1]
        }

        return V.fromArray(values)!
    }

    /// Find the variable with the most fractional value (furthest from integer)
    /// This is used for branching decisions in branch-and-bound
    /// - Parameter solution: The solution vector to analyze
    /// - Returns: Index of the most fractional variable, or nil if all are integer-feasible
    public func mostFractionalVariable<V: VectorSpace>(
        _ solution: V
    ) -> Int? where V.Scalar == Double {
        let values = solution.toArray()
        var maxFractional = 0.0
        var maxIndex: Int? = nil

        // Check all integer-restricted variables
        for i in allIntegerVariables {
            guard i < values.count else { continue }
            let value = values[i]
            let fractionalPart = abs(value - round(value))

            // Most fractional is closest to 0.5
            // (furthest from both floor and ceiling)
            let fractionalDistance = abs(fractionalPart - 0.5)
            let actualFractional = 0.5 - fractionalDistance

            if actualFractional > maxFractional {
                maxFractional = actualFractional
                maxIndex = i
            }
        }

        // Only return if significantly fractional
        if maxFractional > 1e-6 {
            return maxIndex
        }

        return nil
    }

    /// Get the fractional part of a variable's value (distance from integer)
    /// - Parameters:
    ///   - solution: The solution vector
    ///   - index: Variable index
    /// - Returns: Fractional part (0 means integer, 0.5 is maximally fractional)
    public func fractionality<V: VectorSpace>(
        _ solution: V,
        at index: Int
    ) -> Double where V.Scalar == Double {
        let values = solution.toArray()
        guard index < values.count else { return 0.0 }
        let value = values[index]
        let fractionalPart = abs(value - round(value))
        return min(fractionalPart, 1.0 - fractionalPart)
    }
}

// MARK: - Convenience Initializers

extension IntegerProgramSpecification {
    /// Create a specification where all variables are binary
    /// - Parameter dimension: Number of variables
    /// - Returns: Specification with all binary variables
    public static func allBinary(dimension: Int) -> IntegerProgramSpecification {
        IntegerProgramSpecification(
            binaryVariables: Set(0..<dimension)
        )
    }

    /// Create a specification where all variables are general integers
    /// - Parameter dimension: Number of variables
    /// - Returns: Specification with all integer variables
    public static func allInteger(dimension: Int) -> IntegerProgramSpecification {
        IntegerProgramSpecification(
            integerVariables: Set(0..<dimension)
        )
    }
}
