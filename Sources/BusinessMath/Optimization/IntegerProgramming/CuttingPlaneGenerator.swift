import Foundation

// MARK: - Simplex Row Representation

/// Represents a simplex tableau row with explicit mapping to original variable space.
///
/// The row is provided in **solved form** as returned by SimplexSolver:
/// ```
/// x_B = b + Σ c_j x_j
/// ```
///
/// where:
/// - `x_B` is the basic variable
/// - `x_j` are non-basic variables
/// - `c_j` are the coefficients from the tableau
/// - `b` is the RHS value
///
/// The Gomory cut generator will internally convert to canonical form for correct derivation.
///
/// ## Example
/// ```swift
/// // Simplex solved form: x0 = 2.5 + 0.25*s0 - 0.5*s1
///
/// let row = SimplexRow(
///     rhs: 2.5,
///     coefficients: [0.25, -0.5],       // solved form coefficients
///     nonBasicVariableIndices: [2, 3],  // s0=var 2, s1=var 3
///     basicVariableIndex: 0              // x0=var 0
/// )
/// ```
public struct SimplexRow: Sendable {
    /// RHS value of the canonical equation
    public let rhs: Double

    /// Canonical coefficients of non-basic variables (LEFT-HAND SIDE)
    ///
    /// These are the `a_j` coefficients in: `x_B + Σ a_j x_j = b`
    public let coefficients: [Double]

    /// Original variable indices corresponding to `coefficients`
    ///
    /// Maps tableau column positions to original variable indices.
    /// Example: if `coefficients[0]` is for slack s2, then `nonBasicVariableIndices[0] = 5`
    public let nonBasicVariableIndices: [Int]

    /// Original variable index of the basic variable
    public let basicVariableIndex: Int

    /// Creates a simplex row with explicit variable mapping.
    ///
    /// - Important: `coefficients` must be in canonical form (LHS of `x_B + Σ a_j x_j = b`)
    public init(
        rhs: Double,
        coefficients: [Double],
        nonBasicVariableIndices: [Int],
        basicVariableIndex: Int
    ) {
        self.rhs = rhs
        self.coefficients = coefficients
        self.nonBasicVariableIndices = nonBasicVariableIndices
        self.basicVariableIndex = basicVariableIndex
    }
}

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

    /// Generates a Gomory fractional cut expressed in original variable space.
    ///
    /// Given a simplex tableau row in the form:
    /// ```
    /// x_B = b + Σ a_j x_j  (over non-basic variables)
    /// ```
    ///
    /// The Gomory cut is:
    /// ```
    /// Σ frac(a_j) x_j ≥ frac(b)
    /// ```
    ///
    /// Converted to ≤ form:
    /// ```
    /// -Σ frac(a_j) x_j ≤ -frac(b)
    /// ```
    ///
    /// **Critical**: The returned cut is expressed over ALL original variables,
    /// with proper mapping from tableau columns to original variable indices.
    ///
    /// - Parameters:
    ///   - row: Simplex row with variable index mapping
    ///   - totalVariableCount: Total number of variables in original problem space
    /// - Returns: Cutting plane in original variable space, or nil if no valid cut
    /// - Throws: `CuttingPlaneError.invalidTableau` if row structure is invalid
    public func generateGomoryCut(
        from row: SimplexRow,
        totalVariableCount: Int
    ) throws -> CuttingPlane? {
        // Check if RHS is fractional
        let rhsFractional = fractionalPart(row.rhs)

        if rhsFractional < fractionalTolerance {
            return nil  // No cut needed for integer RHS
        }

        // Validate row structure
        guard row.coefficients.count == row.nonBasicVariableIndices.count else {
            throw CuttingPlaneError.invalidTableau
        }

        // Build coefficient vector in ORIGINAL VARIABLE SPACE
        var fullCoefficients = Array(repeating: 0.0, count: totalVariableCount)

        for (colIndex, originalIndex) in row.nonBasicVariableIndices.enumerated() {
            guard originalIndex < totalVariableCount else {
                throw CuttingPlaneError.invalidTableau
            }

            // SimplexSolver already returns canonical form: x_B + a_j x_j = b
            let canonicalCoeff = row.coefficients[colIndex]
            let frac = fractionalPart(canonicalCoeff)
            fullCoefficients[originalIndex] = -frac
        }

        let cut = CuttingPlane(
            coefficients: fullCoefficients,
            rhs: -rhsFractional,
            type: .gomory,
            sourceIndex: row.basicVariableIndex
        )

        return cut.isWeak ? nil : cut
    }

    // MARK: - Mixed-Integer Rounding Cuts

    /// Generate a mixed-integer rounding (MIR) cut (DEPRECATED).
    ///
    /// - Warning: This method uses the old tableau-space API and is deprecated.
    ///   MIR cuts require proper variable mapping to original space.
    ///
    /// - Parameters:
    ///   - tableauRow: Coefficients of non-basic variables
    ///   - rhs: Right-hand side value
    ///   - integerIndices: Indices of variables that must be integer
    ///   - basicVariableIndex: Index of the basic variable
    /// - Returns: Generated MIR cut, or nil if no valid cut exists
    @available(*, deprecated, message: "MIR cuts require SimplexRow with variable mapping")
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

    /// Generate Gomory cuts from multiple simplex rows.
    ///
    /// Generates cuts from all fractional basic variables, filtering out
    /// rows with integer RHS values.
    ///
    /// - Parameters:
    ///   - rows: Array of simplex rows with variable mappings
    ///   - currentSolution: Current LP solution in original variable space
    ///   - totalVariableCount: Total number of variables in problem
    /// - Returns: Array of generated cutting planes in original variable space
    /// - Throws: `CuttingPlaneError` if row structures are invalid
    public func generateCuts(
        from rows: [SimplexRow],
        currentSolution: [Double],
        totalVariableCount: Int
    ) throws -> [CuttingPlane] {
        var cuts: [CuttingPlane] = []

        for row in rows {
            // Verify basic variable index is valid
            guard row.basicVariableIndex < currentSolution.count else {
                continue
            }

            let basicValue = currentSolution[row.basicVariableIndex]
            let frac = fractionalPart(basicValue)

            // Only generate cut if basic value is fractional
            guard frac >= fractionalTolerance else {
                continue
            }

            // Create adjusted row with actual basic value as RHS
            let adjustedRow = SimplexRow(
                rhs: basicValue,
                coefficients: row.coefficients,
                nonBasicVariableIndices: row.nonBasicVariableIndices,
                basicVariableIndex: row.basicVariableIndex
            )

            if let cut = try generateGomoryCut(
                from: adjustedRow,
                totalVariableCount: totalVariableCount
            ) {
                cuts.append(cut)
            }
        }

        return cuts
    }

    /// Generate cuts from all fractional basic variables in a tableau (DEPRECATED).
    ///
    /// - Warning: This method uses the old tableau-space API and is deprecated.
    ///   Use `generateCuts(from:currentSolution:totalVariableCount:)` instead.
    ///
    /// - Parameters:
    ///   - tableau: Complete simplex tableau (rows for basic variables)
    ///   - solution: Current LP solution values
    ///   - isBasic: Indicates which variables are basic
    /// - Returns: Array of generated cutting planes
    @available(*, deprecated, message: "Use generateCuts(from:currentSolution:totalVariableCount:) with SimplexRow instead")
    public func generateCutsFromTableau(
        tableau: [[Double]],
        solution: [Double],
        isBasic: [Bool]
    ) throws -> [CuttingPlane] {
        // This old API cannot correctly map to original variable space
        // Return empty array to avoid generating incorrect cuts
        return []
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
