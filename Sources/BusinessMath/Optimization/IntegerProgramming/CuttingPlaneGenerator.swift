import Foundation

// MARK: - Simplex Row Representation

/// Represents a simplex tableau row with explicit mapping to original variable space.
///
/// The row is provided in **canonical form**, as `SimplexSolver`'s tableau stores it:
/// ```
/// x_B + Σ a_j y_j = b
/// ```
///
/// where:
/// - `x_B` is the basic variable
/// - `y_j` are the non-basic variables, each `≥ 0`
/// - `a_j` are the coefficients read straight from the tableau row
/// - `b` is the right-hand side
///
/// - Important: This header used to describe the **solved** form, `x_B = b + Σ c_j y_j`, and
///   give an example labelled as such — while the doc on ``coefficients`` said canonical and
///   every generator in this file read the values as canonical. The two differ by a sign on
///   every coefficient, which is the difference between a valid cut and one that excludes
///   feasible points, so the contradiction was worth more than a typo. The tableau is canonical;
///   the pivot in `SimplexSolver` maintains it that way.
///
/// ## Example
/// ```swift
/// // Canonical tableau row: x0 + 0.25*s0 - 0.5*s1 = 2.5
///
/// let row = SimplexRow(
///     rhs: 2.5,
///     coefficients: [0.25, -0.5],       // canonical coefficients, read from the tableau
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

    // MARK: - Gomory Mixed-Integer Cuts

    /// Generates a Gomory mixed-integer cut from a simplex row.
    ///
    /// The cut this package should reach for by default, and the only one of the Gomory family
    /// that stays valid once the tableau contains rows the cutting loop itself added.
    ///
    /// ## Why not the fractional cut
    ///
    /// ``generateGomoryCut(from:totalVariableCount:)`` rounds every coefficient, and that step
    /// is sound only if every non-basic variable in the row is integral at every
    /// integer-feasible point. The original rows of a problem with integer coefficients and
    /// integer right-hand sides satisfy this — their slacks are integral — so the first round
    /// of cutting is safe. A cut row does not: its coefficients and right-hand side are
    /// fractional, so its slack is fractional too. Deriving a fractional cut from a tableau
    /// containing one produces an inequality that can exclude optimal integer points, which is
    /// what branch-and-cut was doing from its second round onward.
    ///
    /// ## The derivation
    ///
    /// The row arrives in canonical form, `x_B + Σ a_j y_j = b`, with every `y_j ≥ 0` and `x_B`
    /// integer-constrained. Writing `f₀ = frac(b)`, integrality of `x_B` forces
    /// `Σ a_j y_j ≡ f₀ (mod 1)`, and the cut is `Σ α_j y_j ≥ f₀` with
    ///
    /// | column `j` | `α_j` |
    /// |---|---|
    /// | integer, `f_j ≤ f₀` | `f_j` |
    /// | integer, `f_j > f₀` | `f₀(1 − f_j) / (1 − f₀)` |
    /// | continuous, `a_j ≥ 0` | `a_j` |
    /// | continuous, `a_j < 0` | `−f₀ a_j / (1 − f₀)` |
    ///
    /// where `f_j = frac(a_j)`. Both continuous rules give a non-negative `α_j`, which is what
    /// makes the inequality a restriction on non-negative variables rather than a licence.
    ///
    /// Note what the continuous rule does *not* require: nothing about `y_j` being integral.
    /// That absence is the whole point — it is why this cut may be derived from a tableau
    /// holding earlier cuts, and the fractional cut may not.
    ///
    /// ## On classifying columns
    ///
    /// A column not named in `integerVariables` is treated as continuous. Slack columns are
    /// never named there, so every slack takes the continuous rule — including the slacks of
    /// rows that happen to have integer data and are therefore integral. That is deliberate:
    /// treating an integral variable as continuous **weakens** the cut and never invalidates
    /// it, so the conservative classification is the safe direction to be wrong in, and it
    /// needs no bookkeeping about which rows carry integer data.
    ///
    /// - Parameters:
    ///   - row: The tableau row, in canonical form, whose basic variable is integer-constrained
    ///     and currently fractional.
    ///   - totalVariableCount: Width of the space the returned cut is expressed over.
    ///   - integerVariables: Original indices of the integer-constrained variables. Anything
    ///     absent is treated as continuous.
    ///
    /// - Returns: The cut in `Σ c_j x_j ≤ rhs` form over `totalVariableCount` columns, or `nil`
    ///   when the right-hand side is integral — there is nothing to cut off — or when the
    ///   result would be too weak to be worth adding.
    ///
    /// - Throws: ``CuttingPlaneError/invalidTableau`` when the row's coefficients and index map
    ///   disagree in length, or an index falls outside `totalVariableCount`.
    ///
    /// - Complexity: O(n) in the number of non-basic columns.
    public func generateGomoryMixedIntegerCut(
        from row: SimplexRow,
        totalVariableCount: Int,
        integerVariables: Set<Int>
    ) throws -> CuttingPlane? {
        let f0 = fractionalPart(row.rhs)

        // Both ends matter. Below the tolerance the basic variable is already integral and
        // there is nothing to separate; above `1 - tolerance` it is integral from the other
        // side, and dividing by `1 - f0` there would amplify rounding without bound.
        guard f0 >= fractionalTolerance, f0 <= 1.0 - fractionalTolerance else {
            return nil
        }

        guard row.coefficients.count == row.nonBasicVariableIndices.count else {
            throw CuttingPlaneError.invalidTableau
        }

        var fullCoefficients = Array(repeating: 0.0, count: totalVariableCount)

        for (position, originalIndex) in row.nonBasicVariableIndices.enumerated() {
            guard originalIndex < totalVariableCount else {
                throw CuttingPlaneError.invalidTableau
            }

            let alpha = gomoryMixedIntegerCoefficient(
                row.coefficients[position],
                f0: f0,
                isInteger: integerVariables.contains(originalIndex)
            )

            // Stored negated because `CuttingPlane` is a `≤` inequality and the derivation
            // produces a `≥` one. A column appearing twice in the map would overwrite rather
            // than accumulate, but the simplex basis names each non-basic column once.
            fullCoefficients[originalIndex] = -alpha
        }

        let cut = CuttingPlane(
            coefficients: fullCoefficients,
            rhs: -f0,
            type: .gomory,
            sourceIndex: row.basicVariableIndex
        )

        return cut.isWeak ? nil : cut
    }

    /// One column's coefficient in the Gomory mixed-integer cut `Σ α_j y_j ≥ f₀`.
    ///
    /// Split out because three entry points need the same four-case rule and previously had two
    /// different answers for it. The result is always non-negative, which is the property that
    /// makes the assembled inequality a restriction on non-negative variables; a derivation
    /// that returns a negative `α_j` has inverted that column's meaning.
    ///
    /// - Parameters:
    ///   - a: The column's coefficient in the canonical row `x_B + Σ a_j y_j = b`.
    ///   - f0: `frac(b)`, strictly between zero and one — the caller checks this, because a
    ///     value at either end means there is no cut to make and division by `1 - f0` would be
    ///     unbounded.
    ///   - isInteger: Whether this column is integer-constrained. Passing `false` for a column
    ///     that is in fact integral weakens the cut and never invalidates it, so this is the
    ///     safe direction to be uncertain in.
    /// - Returns: `α_j ≥ 0`.
    private func gomoryMixedIntegerCoefficient(_ a: Double, f0: Double, isInteger: Bool) -> Double {
        let complement: Double = 1.0 - f0
        if isInteger {
            let fj: Double = fractionalPart(a)
            if fj <= f0 { return fj }
            let numerator: Double = f0 * (1.0 - fj)
            return numerator / complement // fp-safety:disable — caller guarantees f0 <= 1 - fractionalTolerance
        }
        if a >= 0.0 { return a }
        let numerator: Double = -f0 * a
        return numerator / complement // fp-safety:disable — caller guarantees f0 <= 1 - fractionalTolerance
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

        // Deprecated, but not left computing a wrong answer: this now applies the same
        // Gomory mixed-integer rule as every other entry point. It cannot delegate, because it
        // takes tableau column positions with no map to original variable space — which is the
        // reason it is deprecated.
        guard rhsFractional <= 1.0 - fractionalTolerance else {
            return nil
        }

        var cutCoefficients: [Double] = []

        for (index, coeff) in tableauRow.enumerated() {
            let alpha = gomoryMixedIntegerCoefficient(
                coeff,
                f0: rhsFractional,
                isInteger: integerIndices.contains(index)
            )
            cutCoefficients.append(-alpha)
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

    /// Generate a mixed-integer rounding (MIR) cut from a simplex row.
    ///
    /// ## This is the Gomory mixed-integer cut
    ///
    /// Mixed-integer rounding applied to a **single** tableau row and the Gomory mixed-integer
    /// cut are the same inequality. MIR becomes a distinct family only when it is applied to an
    /// aggregation of several rows, which nothing in this package does. So this delegates to
    /// ``generateGomoryMixedIntegerCut(from:totalVariableCount:integerVariables:)`` and differs
    /// from it in one respect: the returned cut is tagged ``CutType/mixedIntegerRounding``, so
    /// callers that separate the two in their statistics still can.
    ///
    /// ## What it used to compute
    ///
    /// A different rule, and an invalid one. For a continuous column it produced
    /// `a_j / (1 - f₀)` when `a_j ≥ 0` and `a_j / f₀` when `a_j < 0` — the second of which is
    /// **negative**, where the derivation requires every coefficient to be non-negative. A
    /// negative coefficient on a non-negative variable inverts what that column contributes, and
    /// the resulting inequality excluded feasible points. Checked against enumeration over six
    /// rows: three were invalid, the worst excluding a feasible point by 41.
    ///
    /// The integer branch was wrong too, though less visibly: it used `frac(a_j)` unconditionally
    /// where the derivation uses `f₀(1 - f_j)/(1 - f₀)` once `f_j` exceeds `f₀`.
    ///
    /// Nothing called this outside the generator, and no test covered it.
    ///
    /// - Parameters:
    ///   - row: Simplex row with variable index mapping, in canonical form.
    ///   - totalVariableCount: Total number of variables in original problem space.
    ///   - integerVariables: Set of variable indices that must be integer.
    /// - Returns: The cut in original variable space, or `nil` if there is none to make.
    /// - Throws: ``CuttingPlaneError/invalidTableau`` if the row structure is invalid.
    /// - Complexity: O(n) in the number of non-basic columns.
    public func generateMIRCut(
        from row: SimplexRow,
        totalVariableCount: Int,
        integerVariables: Set<Int>
    ) throws -> CuttingPlane? {
        let cut = try generateGomoryMixedIntegerCut(
            from: row,
            totalVariableCount: totalVariableCount,
            integerVariables: integerVariables
        )
        guard let cut else { return nil }

        return CuttingPlane(
            coefficients: cut.coefficients,
            rhs: cut.rhs,
            type: .mixedIntegerRounding,
            sourceIndex: cut.sourceIndex
        )
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

    /// Generate cuts from multiple simplex rows with configurable cut types.
    ///
    /// Generates different types of cuts based on configuration, including Gomory,
    /// MIR (mixed-integer rounding), and cover cuts.
    ///
    /// - Parameters:
    ///   - rows: Array of simplex rows with variable mappings
    ///   - currentSolution: Current LP solution in original variable space
    ///   - totalVariableCount: Total number of variables in problem
    ///   - integerVariables: Set of variable indices that must be integer
    ///   - enableGomory: Whether to generate Gomory fractional cuts (default: true)
    ///   - enableMIR: Whether to generate mixed-integer rounding cuts (default: false)
    /// - Returns: Array of generated cutting planes in original variable space
    /// - Throws: `CuttingPlaneError` if row structures are invalid
    public func generateCuts(
        from rows: [SimplexRow],
        currentSolution: [Double],
        totalVariableCount: Int,
        integerVariables: Set<Int>,
        enableGomory: Bool = true,
        enableMIR: Bool = false
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

            // Generate Gomory cuts.
            //
            // The **mixed-integer** form, not the fractional one this used to call. The
            // fractional cut's rounding step assumes every non-basic column is integral at
            // integer-feasible points, which the caller cannot promise: from the second cutting
            // round onward the tableau contains the rounds before it, whose slacks are
            // fractional. Deriving a fractional cut there produced inequalities that excluded
            // optimal integer points, and branch-and-cut returned whatever survived and called
            // it optimal. See ``generateGomoryMixedIntegerCut(from:totalVariableCount:integerVariables:)``.
            if enableGomory {
                if let cut = try generateGomoryMixedIntegerCut(
                    from: adjustedRow,
                    totalVariableCount: totalVariableCount,
                    integerVariables: integerVariables
                ) {
                    cuts.append(cut)
                }
            }

            // Generate MIR cuts if enabled
            if enableMIR {
                if let cut = try generateMIRCut(
                    from: adjustedRow,
                    totalVariableCount: totalVariableCount,
                    integerVariables: integerVariables
                ) {
                    cuts.append(cut)
                }
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
