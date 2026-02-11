import Foundation

// MARK: - Cutting Plane Types

/// Represents a cutting plane (valid inequality) for integer programming
public struct CuttingPlane: Sendable {
    /// Coefficients of the cutting plane (left-hand side)
    public let coefficients: [Double]

    /// Right-hand side constant
    public let rhs: Double

    /// Type of cut generated
    public let type: CutType

    /// Source variable index (for tracking)
    public let sourceIndex: Int?

    /// Creates a cutting plane with specified characteristics.
    ///
    /// - Parameters:
    ///   - coefficients: Coefficients for the left-hand side of the inequality
    ///   - rhs: Right-hand side constant
    ///   - type: Type of cut (Gomory, MIR, cover, or clique)
    ///   - sourceIndex: Optional index of the source variable for tracking
    public init(coefficients: [Double], rhs: Double, type: CutType, sourceIndex: Int? = nil) {
        self.coefficients = coefficients
        self.rhs = rhs
        self.type = type
        self.sourceIndex = sourceIndex
    }

    /// A cut is "weak" if it provides negligible strengthening
    public var isWeak: Bool {
        return coefficients.allSatisfy { abs($0) < 1e-6 } || abs(rhs) < 1e-6
    }

    /// Calculate violation of this cut for a given solution
    /// Positive violation means the cut is violated (should exclude this point)
    public func violation(at solution: [Double]) -> Double {
        guard solution.count == coefficients.count else { return 0.0 }
        let lhs = zip(coefficients, solution).map(*).reduce(0, +)
        return lhs - rhs
    }
}

/// Type of cutting plane
public enum CutType: Sendable {
    case gomory              // Standard Gomory fractional cut
    case mixedIntegerRounding // Mixed-integer rounding cut
    case cover               // Cover inequality for knapsack
    case clique              // Clique inequality
}

// MARK: - Cutting Plane Generator

/// Generates cutting planes from LP relaxation solutions to strengthen integer programs
public struct CuttingPlaneGenerator: Sendable {

    /// Tolerance for considering a value fractional
    public let fractionalTolerance: Double

    /// Tolerance for considering a cut weak
    public let weakCutTolerance: Double

    /// Creates a cutting plane generator with specified tolerances.
    ///
    /// - Parameters:
    ///   - fractionalTolerance: Tolerance for considering a value fractional (default: 1e-6)
    ///   - weakCutTolerance: Tolerance for considering a cut weak (default: 1e-6)
    public init(
        fractionalTolerance: Double = 1e-6,
        weakCutTolerance: Double = 1e-6
    ) {
        self.fractionalTolerance = fractionalTolerance
        self.weakCutTolerance = weakCutTolerance
    }

    // MARK: - Gomory Fractional Cuts

    /// Generate a Gomory fractional cut from a simplex tableau row
    ///
    /// Given a basic variable with fractional value in the optimal LP solution,
    /// this generates a cutting plane that cuts off the fractional point while
    /// remaining valid for all integer-feasible points.
    ///
    /// The Gomory cut is derived from: x_i = b_i + Σ a_ij * x_j
    /// Taking fractional parts: f_0 = Σ f_j * x_j  where f = fractionalPart
    /// The cut is: Σ f_j * x_j ≥ f_0
    ///
    /// - Parameters:
    ///   - tableauRow: Coefficients of non-basic variables in the tableau row
    ///   - rhs: Right-hand side (current value of basic variable)
    ///   - basicVariableIndex: Index of the basic variable for tracking
    /// - Returns: Generated cutting plane, or nil if no valid cut exists
    public func generateGomoryCut(
        tableauRow: [Double],
        rhs: Double,
        basicVariableIndex: Int
    ) throws -> CuttingPlane? {
        // Check if RHS is fractional
        let rhsFractional = fractionalPart(rhs)

        // If RHS is integer (or very close), no cut needed
        if rhsFractional < fractionalTolerance {
            return nil
        }

        // Generate cut coefficients by taking fractional parts
        var cutCoefficients: [Double] = []

        for coeff in tableauRow {
            let frac = fractionalPart(coeff)
            // For Gomory cut: if fractional part exists, use it
            // The cut is: Σ f_j * x_j ≥ f_0
            // In standard form (≤): -Σ f_j * x_j ≤ -f_0
            cutCoefficients.append(-frac)
        }

        let cutRhs = -rhsFractional

        // Check if cut is weak (all coefficients near zero)
        let cut = CuttingPlane(
            coefficients: cutCoefficients,
            rhs: cutRhs,
            type: .gomory,
            sourceIndex: basicVariableIndex
        )

        return cut.isWeak ? nil : cut
    }

    // MARK: - Mixed-Integer Rounding Cuts

    /// Generate a mixed-integer rounding (MIR) cut
    ///
    /// For problems with both integer and continuous variables,
    /// MIR cuts provide tighter bounds than standard Gomory cuts.
    ///
    /// - Parameters:
    ///   - tableauRow: Coefficients of non-basic variables
    ///   - rhs: Right-hand side value
    ///   - integerIndices: Indices of variables that must be integer
    ///   - basicVariableIndex: Index of the basic variable
    /// - Returns: Generated MIR cut, or nil if no valid cut exists
    public func generateMixedIntegerGomoryCut(
        tableauRow: [Double],
        rhs: Double,
        integerIndices: Set<Int>,
        basicVariableIndex: Int
    ) throws -> CuttingPlane? {
        // Check if RHS is fractional
        let rhsFractional = fractionalPart(rhs)

        if rhsFractional < fractionalTolerance {
            return nil
        }

        var cutCoefficients: [Double] = []

        for (index, coeff) in tableauRow.enumerated() {
            if integerIndices.contains(index) {
                // For integer variables, use fractional part
                let frac = fractionalPart(coeff)
                cutCoefficients.append(-frac)
            } else {
                // For continuous variables, use different formula
                // MIR: continuous variables get modified coefficient
                if coeff >= 0 {
                    cutCoefficients.append(-coeff / (1.0 - rhsFractional))
                } else {
                    cutCoefficients.append(-coeff / rhsFractional)
                }
            }
        }

        let cutRhs = -rhsFractional

        let cut = CuttingPlane(
            coefficients: cutCoefficients,
            rhs: cutRhs,
            type: .mixedIntegerRounding,
            sourceIndex: basicVariableIndex
        )

        return cut.isWeak ? nil : cut
    }

    // MARK: - Multiple Cut Generation

    /// Generate cuts from all fractional basic variables in a tableau
    ///
    /// - Parameters:
    ///   - tableau: Complete simplex tableau (rows for basic variables)
    ///   - solution: Current LP solution values
    ///   - isBasic: Indicates which variables are basic
    /// - Returns: Array of generated cutting planes
    public func generateCutsFromTableau(
        tableau: [[Double]],
        solution: [Double],
        isBasic: [Bool]
    ) throws -> [CuttingPlane] {
        var cuts: [CuttingPlane] = []

        for (index, row) in tableau.enumerated() {
            // Only generate cuts for basic variables
            guard index < isBasic.count && isBasic[index] else { continue }
            guard index < solution.count else { continue }

            let value = solution[index]

            // Only generate cut if solution is fractional
            let frac = fractionalPart(value)
            guard frac >= fractionalTolerance else { continue }

            // Generate Gomory cut for this row
            if let cut = try generateGomoryCut(
                tableauRow: row,
                rhs: value,
                basicVariableIndex: index
            ) {
                cuts.append(cut)
            }
        }

        return cuts
    }

    // MARK: - Cut Selection

    /// Select the most violated cut from a collection of cuts
    ///
    /// The most violated cut is the one with maximum positive violation
    /// at the current solution point.
    ///
    /// - Parameters:
    ///   - cuts: Available cutting planes
    ///   - currentSolution: Current LP solution
    /// - Returns: The most violated cut, or nil if no cuts violate the solution
    public func selectMostViolatedCut(
        cuts: [CuttingPlane],
        currentSolution: [Double]
    ) -> CuttingPlane? {
        var maxViolation = 0.0
        var selectedCut: CuttingPlane?

        for cut in cuts {
            let violation = cut.violation(at: currentSolution)
            if violation > maxViolation {
                maxViolation = violation
                selectedCut = cut
            }
        }

        return selectedCut
    }

    // MARK: - Cover Cuts (for Knapsack Constraints)

    /// Generate a cover cut for a knapsack constraint
    ///
    /// Given a knapsack constraint Σ a_i * x_i ≤ b with binary x_i,
    /// a cover C is a set of items where Σ a_i > b (exceeds capacity).
    /// The cover cut is: Σ x_i ≤ |C| - 1 for i ∈ C
    ///
    /// This cuts off fractional solutions while remaining valid for all
    /// binary-feasible solutions (at least one item in cover must be 0).
    ///
    /// - Parameters:
    ///   - weights: Item weights (coefficients in knapsack)
    ///   - capacity: Knapsack capacity (RHS)
    ///   - solution: Current fractional solution
    /// - Returns: Cover cut, or nil if no violated minimal cover found
    public func generateCoverCut(
        weights: [Double],
        capacity: Double,
        solution: [Double]
    ) throws -> CuttingPlane? {
        let n = weights.count
        guard solution.count == n else {
            throw CuttingPlaneError.dimensionMismatch
        }

        // Find a minimal cover by greedy selection
        // Sort by solution value (descending) to focus on fractional variables
        let indices = (0..<n).sorted { solution[$0] > solution[$1] }

        var cover: Set<Int> = []
        var coverWeight = 0.0

        // Add items until we have a cover
        for index in indices {
            cover.insert(index)
            coverWeight += weights[index]

            if coverWeight > capacity {
                // We have a cover - check if it's minimal
                // Try removing each item to see if still a cover
                for removeIndex in cover {
                    let weightWithout = coverWeight - weights[removeIndex]
                    if weightWithout <= capacity {
                        // Still need this item for cover to be valid
                        continue
                    } else {
                        // Can remove this item and still have cover
                        cover.remove(removeIndex)
                        coverWeight = weightWithout
                    }
                }
                break
            }
        }

        // Check if we found a valid cover
        guard coverWeight > capacity else {
            return nil
        }

        // Check if current solution violates the cover cut
        let coverSum = cover.map { solution[$0] }.reduce(0, +)
        let coverSize = Double(cover.count)

        // Cut is: Σ x_i ≤ |C| - 1
        // Violation is: Σ x_i - (|C| - 1) > 0
        guard coverSum > coverSize - 1 + fractionalTolerance else {
            return nil
        }

        // Generate cut coefficients (1 for items in cover, 0 otherwise)
        var cutCoefficients = [Double](repeating: 0.0, count: n)
        for index in cover {
            cutCoefficients[index] = 1.0
        }

        return CuttingPlane(
            coefficients: cutCoefficients,
            rhs: coverSize - 1.0,
            type: .cover
        )
    }

    // MARK: - Helper Functions

    /// Extract the fractional part of a number (always positive)
    private func fractionalPart(_ value: Double) -> Double {
        let frac = value - floor(value)
        // Handle negative numbers: fractional part should be in [0, 1)
        return frac >= 0 ? frac : frac + 1.0
    }
}

// MARK: - Errors

/// Errors that can occur during cutting plane generation.
public enum CuttingPlaneError: Error, LocalizedError {
    /// Dimension mismatch between solution vector and coefficients
    case dimensionMismatch

    /// Invalid simplex tableau structure
    case invalidTableau

    /// Unable to generate a valid cutting plane
    case noCutGenerated

    /// A localized human-readable description of the error.
    public var errorDescription: String? {
        switch self {
        case .dimensionMismatch:
            return "Dimension mismatch between solution and coefficients"
        case .invalidTableau:
            return "Invalid simplex tableau structure"
        case .noCutGenerated:
            return "Unable to generate valid cutting plane"
        }
    }
}
