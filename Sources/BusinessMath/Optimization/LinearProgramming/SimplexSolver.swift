import Foundation

// MARK: - Simplex Constraint

/// Constraint for linear programming in simplex method.
///
/// Represents a linear constraint of the form: a₁x₁ + a₂x₂ + ... + aₙxₙ {≤,=,≥} b
///
/// ## Example
/// ```swift
/// // Constraint: 2x + 3y ≤ 10
/// let constraint = SimplexConstraint(
///     coefficients: [2.0, 3.0],
///     relation: .lessOrEqual,
///     rhs: 10.0
/// )
/// ```
public struct SimplexConstraint: Sendable {
    /// Coefficients [a₁, a₂, ..., aₙ] for the left-hand side
    public let coefficients: [Double]

    /// Constraint relation (≤, =, or ≥)
    public let relation: ConstraintRelation

    /// Right-hand side value b
    public let rhs: Double

    /// Creates a simplex constraint.
    public init(coefficients: [Double], relation: ConstraintRelation, rhs: Double) {
        self.coefficients = coefficients
        self.relation = relation
        self.rhs = rhs
    }
}

/// Type of linear constraint relation
public enum ConstraintRelation: Sendable {
    case lessOrEqual      // ≤
    case equal            // =
    case greaterOrEqual   // ≥
}

// MARK: - Simplex Result

/// Result from simplex linear programming solver.
///
/// ## Example
/// ```swift
/// let result = try solver.maximize(
///     objective: [3.0, 2.0],
///     subjectTo: [constraint1, constraint2]
/// )
///
/// if result.status == .optimal {
///     print("Optimal value: \(result.objectiveValue)")
///     print("Solution: \(result.solution)")
/// }
/// ```
public struct SimplexResult: Sendable {
    /// Solution vector x* (original variables only, no slack/surplus/artificial)
    public let solution: [Double]

    /// Objective function value at solution
    public let objectiveValue: Double

    /// Solution status
    public let status: SimplexStatus

    /// Number of simplex iterations performed
    public let iterations: Int

    /// Creates a simplex result.
    public init(solution: [Double], objectiveValue: Double, status: SimplexStatus, iterations: Int) {
        self.solution = solution
        self.objectiveValue = objectiveValue
        self.status = status
        self.iterations = iterations
    }
}

/// Status of linear programming solution
public enum SimplexStatus: Sendable {
    case optimal      // Found optimal solution
    case unbounded    // Problem is unbounded
    case infeasible   // No feasible solution exists
}

// MARK: - Simplex Solver

/// Solver for linear programming using the simplex method.
///
/// Solves problems of the form:
/// ```
/// maximize/minimize cᵀx
/// subject to: Ax {≤,=,≥} b
///            x ≥ 0
/// ```
///
/// ## Algorithm
///
/// Uses the **two-phase simplex method**:
/// - **Phase I**: Find a basic feasible solution (or prove infeasibility)
/// - **Phase II**: Optimize from the feasible solution
///
/// The algorithm:
/// 1. Converts all constraints to standard form (equality with slack/surplus/artificial variables)
/// 2. Finds an initial basic feasible solution using Phase I
/// 3. Pivots to optimality using Phase II
///
/// ## Usage Example
/// ```swift
/// // Maximize 3x + 2y
/// // Subject to: x + y ≤ 4
/// //            2x + y ≤ 5
/// //            x, y ≥ 0
///
/// let solver = SimplexSolver()
/// let result = try solver.maximize(
///     objective: [3.0, 2.0],
///     subjectTo: [
///         SimplexConstraint(coefficients: [1.0, 1.0], relation: .lessOrEqual, rhs: 4.0),
///         SimplexConstraint(coefficients: [2.0, 1.0], relation: .lessOrEqual, rhs: 5.0)
///     ]
/// )
///
/// print("Optimal value: \(result.objectiveValue)")  // 9.0
/// print("Solution: \(result.solution)")             // [1.0, 3.0]
/// ```
///
/// ## Implementation Notes
///
/// - **Bland's rule** prevents cycling in degenerate problems
/// - **Two-phase method** handles any starting constraints
/// - **Numerical tolerance** handles floating-point arithmetic
/// - **Non-negativity** is implicit (all variables x ≥ 0)
public struct SimplexSolver: Sendable {

    /// Numerical tolerance for zero comparisons
    public let tolerance: Double

    /// Maximum iterations to prevent infinite loops
    public let maxIterations: Int

    /// Creates a simplex solver.
    ///
    /// - Parameters:
    ///   - tolerance: Numerical tolerance (default: 1e-10)
    ///   - maxIterations: Maximum iterations (default: 10,000)
    public init(tolerance: Double = 1e-10, maxIterations: Int = 10_000) {
        self.tolerance = tolerance
        self.maxIterations = maxIterations
    }

    // MARK: - Public API

    /// Maximize a linear objective function.
    ///
    /// Solves: maximize cᵀx subject to constraints
    ///
    /// - Parameters:
    ///   - objective: Objective coefficients c = [c₁, c₂, ..., cₙ]
    ///   - constraints: Linear constraints Ax {≤,=,≥} b
    /// - Returns: Optimal solution with status
    /// - Throws: `OptimizationError` if inputs are invalid
    public func maximize(
        objective: [Double],
        subjectTo constraints: [SimplexConstraint]
    ) throws -> SimplexResult {
        return try solve(objective: objective, constraints: constraints, maximize: true)
    }

    /// Minimize a linear objective function.
    ///
    /// Solves: minimize cᵀx subject to constraints
    ///
    /// - Parameters:
    ///   - objective: Objective coefficients c = [c₁, c₂, ..., cₙ]
    ///   - constraints: Linear constraints Ax {≤,=,≥} b
    /// - Returns: Optimal solution with status
    /// - Throws: `OptimizationError` if inputs are invalid
    public func minimize(
        objective: [Double],
        subjectTo constraints: [SimplexConstraint]
    ) throws -> SimplexResult {
        // Minimize c^T x = Maximize -c^T x
        let negatedObjective = objective.map { -$0 }
        var result = try solve(objective: negatedObjective, constraints: constraints, maximize: true)
        result = SimplexResult(
            solution: result.solution,
            objectiveValue: -result.objectiveValue,  // Negate back
            status: result.status,
            iterations: result.iterations
        )
        return result
    }

    // MARK: - Core Solver

    private func solve(
        objective: [Double],
        constraints: [SimplexConstraint],
        maximize: Bool
    ) throws -> SimplexResult {

        guard !objective.isEmpty else {
            throw OptimizationError.invalidInput(message: "Objective function is empty")
        }

        guard !constraints.isEmpty else {
            throw OptimizationError.invalidInput(message: "No constraints provided")
        }

        let numVars = objective.count

        // Validate constraint dimensions
        for (i, constraint) in constraints.enumerated() {
            guard constraint.coefficients.count == numVars else {
                throw OptimizationError.invalidInput(
                    message: "Constraint \(i) has \(constraint.coefficients.count) coefficients, expected \(numVars)"
                )
            }
        }

        // Convert to standard form and solve
        let tableau = try convertToStandardForm(
            objective: objective,
            constraints: constraints,
            maximize: maximize
        )

        return try solveSimplex(tableau: tableau, numOriginalVars: numVars)
    }

    // MARK: - Standard Form Conversion

    /// Converts LP to standard form: max cᵀx s.t. Ax = b, x ≥ 0
    ///
    /// Adds slack variables for ≤ constraints, surplus + artificial for ≥,
    /// and artificial for = constraints.
    private func convertToStandardForm(
        objective: [Double],
        constraints: [SimplexConstraint],
        maximize: Bool
    ) throws -> SimplexTableau {

        let numVars = objective.count
        let numConstraints = constraints.count

        var slackCount = 0
        var surplusCount = 0
        var artificialCount = 0

        // Count additional variables needed
        // Must account for relation flipping when RHS < 0
        for constraint in constraints {
            let effectiveRelation = constraint.rhs < 0 ? flipRelation(constraint.relation) : constraint.relation
            switch effectiveRelation {
            case .lessOrEqual:
                slackCount += 1
            case .greaterOrEqual:
                surplusCount += 1
                artificialCount += 1
            case .equal:
                artificialCount += 1
            }
        }

        let totalVars = numVars + slackCount + surplusCount + artificialCount

        // Build tableau: each row is [a₁, a₂, ..., aₙ, slack..., surplus..., artificial..., rhs]
        var tableau = Array(repeating: Array(repeating: 0.0, count: totalVars + 1), count: numConstraints + 1)

        var slackIndex = numVars
        var surplusIndex = numVars + slackCount
        var artificialIndex = numVars + slackCount + surplusCount

        var basis: [Int] = []  // Which variable is basic in each row
        var artificialVars: [Int] = []
        var surplusVars: [(row: Int, surplusCol: Int, coefficients: [Double], rhs: Double)] = []  // Track surplus variables

        // Fill constraint rows
        for (row, constraint) in constraints.enumerated() {
            // Original variables
            for (col, coef) in constraint.coefficients.enumerated() {
                tableau[row][col] = coef
            }

            // RHS
            tableau[row][totalVars] = constraint.rhs

            // Handle negative RHS (multiply row by -1)
            if constraint.rhs < 0 {
                for col in 0...totalVars {
                    tableau[row][col] = -tableau[row][col]
                }
            }

            // Add slack/surplus/artificial variables
            let effectiveRelation = constraint.rhs < 0 ? flipRelation(constraint.relation) : constraint.relation
            switch effectiveRelation {
            case .lessOrEqual:
                tableau[row][slackIndex] = 1.0
                basis.append(slackIndex)
                slackIndex += 1

            case .greaterOrEqual:
                tableau[row][surplusIndex] = -1.0
                tableau[row][artificialIndex] = 1.0
                basis.append(artificialIndex)
                artificialVars.append(artificialIndex)

                // Capture the preprocessed constraint (after flipping if RHS was negative)
                let preprocessedCoeffs = Array(tableau[row][0..<numVars])
                let preprocessedRHS = tableau[row][totalVars]
                surplusVars.append((
                    row: row,
                    surplusCol: surplusIndex,
                    coefficients: preprocessedCoeffs,
                    rhs: preprocessedRHS
                ))

                surplusIndex += 1
                artificialIndex += 1

            case .equal:
                tableau[row][artificialIndex] = 1.0
                basis.append(artificialIndex)
                artificialVars.append(artificialIndex)
                artificialIndex += 1
            }
        }

        // Objective row (last row of tableau)
        // Simplex minimizes by default. For maximization, negate objective coefficients
        // Tableau stores "reduced costs" which should be negative of objective for entering variable test
        for col in 0..<numVars {
            tableau[numConstraints][col] = maximize ? -objective[col] : objective[col]
        }

        // Save original objective row for Phase II restoration
        let originalObjectiveRow = tableau[numConstraints]

        // Debug: print tableau for small problems with negative RHS constraints
        // let hasNegativeRHS = constraints.contains { $0.rhs < 0 }
        // if hasNegativeRHS && numVars <= 4 {
        //     print("=== SimplexSolver Initial Tableau ===")
        //     print("Variables: \(numVars) original, \(slackCount) slack, \(surplusCount) surplus, \(artificialCount) artificial")
        //     print("Basis: \(basis)")
        //     for (row, constraint) in constraints.enumerated() {
        //         let rowStr = tableau[row].map { String(format: "%.2f", $0) }.joined(separator: ", ")
        //         print("Row \(row): [\(rowStr)] (original: \(constraint.coefficients), rhs: \(constraint.rhs))")
        //     }
        // }

        return SimplexTableau(
            table: tableau,
            basis: basis,
            numOriginalVars: numVars,
            artificialVars: artificialVars,
            originalObjective: originalObjectiveRow,
            surplusVars: surplusVars
        )
    }

    private func flipRelation(_ relation: ConstraintRelation) -> ConstraintRelation {
        switch relation {
        case .lessOrEqual: return .greaterOrEqual
        case .greaterOrEqual: return .lessOrEqual
        case .equal: return .equal
        }
    }

    // MARK: - Two-Phase Simplex

    private func solveSimplex(tableau: SimplexTableau, numOriginalVars: Int) throws -> SimplexResult {
        var currentTableau = tableau
        var totalIterations = 0

        // Phase I: Find basic feasible solution (if artificial variables present)
        if !currentTableau.artificialVars.isEmpty {
            let phaseIResult = try phaseI(tableau: currentTableau)
            currentTableau = phaseIResult.tableau
            totalIterations += phaseIResult.iterations

            if phaseIResult.status == .infeasible {
                return SimplexResult(
                    solution: Array(repeating: 0.0, count: numOriginalVars),
                    objectiveValue: 0.0,
                    status: .infeasible,
                    iterations: totalIterations
                )
            }
        }

        // Phase II: Optimize
        let phaseIIResult = try phaseII(tableau: currentTableau)
        totalIterations += phaseIIResult.iterations

        // Extract solution (only original variables)
        let solution = extractSolution(from: phaseIIResult.tableau, numVars: numOriginalVars)
        // Objective value is in RHS of objective row (already correct sign)
        let objectiveValue = phaseIIResult.tableau.table.last![phaseIIResult.tableau.table[0].count - 1]

        return SimplexResult(
            solution: solution,
            objectiveValue: objectiveValue,
            status: phaseIIResult.status,
            iterations: totalIterations
        )
    }

    /// Phase I: Find a basic feasible solution
    private func phaseI(tableau: SimplexTableau) throws -> (tableau: SimplexTableau, status: SimplexStatus, iterations: Int) {
        var workingTableau = tableau
        let numRows = workingTableau.table.count - 1
        let numCols = workingTableau.table[0].count

        // Set up Phase I objective: minimize sum of artificial variables
        // We want to minimize Σ artificial variables
        // In tableau form: maximize -Σ artificial = minimize Σ artificial
        // So objective row should have +1 for artificial vars (for minimization tableau)

        // Clear objective row
        for col in 0..<numCols {
            workingTableau.table[numRows][col] = 0.0
        }

        // Set coefficient to 1 for each artificial variable (we're minimizing their sum)
        for artificialVar in workingTableau.artificialVars {
            workingTableau.table[numRows][artificialVar] = 1.0
        }

        // Make objective row compatible with basic variables
        // For each basic artificial variable, subtract its row from objective
        // This ensures the reduced costs are correct
        for (rowIndex, basicVar) in workingTableau.basis.enumerated() {
            if workingTableau.artificialVars.contains(basicVar) {
                for col in 0..<numCols {
                    workingTableau.table[numRows][col] -= workingTableau.table[rowIndex][col]
                }
            }
        }

        // Run simplex iterations
        let result = try simplexIterations(tableau: workingTableau)

        // Check if we found a feasible solution
        // Objective value is in RHS of objective row
        let objectiveValue = result.tableau.table[numRows][numCols - 1]

        // Debug Phase I completion (commented out for production)
        // if result.tableau.numOriginalVars <= 5 {
        //     print("DEBUG Phase I complete: objectiveValue=\(objectiveValue)")
        //     print("DEBUG Phase I basis: \(result.tableau.basis)")
        //     for (rowIdx, basicVar) in result.tableau.basis.enumerated() {
        //         let rhsVal = result.tableau.table[rowIdx][numCols - 1]
        //         let isArtificial = result.tableau.artificialVars.contains(basicVar)
        //         print("DEBUG Phase I row \(rowIdx): basicVar=\(basicVar) (artificial=\(isArtificial)), RHS=\(rhsVal)")
        //     }
        // }

        if abs(objectiveValue) > tolerance {
            // Artificial variables are still in basis with nonzero value = infeasible
            return (result.tableau, .infeasible, result.iterations)
        }

        return (result.tableau, .optimal, result.iterations)
    }

    /// Phase II: Optimize from feasible solution
    private func phaseII(tableau: SimplexTableau) throws -> (tableau: SimplexTableau, status: SimplexStatus, iterations: Int) {
        var workingTableau = tableau
        let numRows = workingTableau.table.count - 1
        let numCols = workingTableau.table[0].count

        // Check if any artificial variables are in the basis before zeroing (debug commented out)
        // if workingTableau.numOriginalVars <= 5 {
        //     print("DEBUG Phase II start: basis=\(workingTableau.basis)")
        //     for artificialVar in workingTableau.artificialVars {
        //         if workingTableau.basis.contains(artificialVar) {
        //             let rowIdx = workingTableau.basis.firstIndex(of: artificialVar)!
        //             let rhsVal = workingTableau.table[rowIdx][numCols - 1]
        //             print("DEBUG Phase II: WARNING - artificial var \(artificialVar) is in basis at row \(rowIdx) with RHS=\(rhsVal)")
        //         }
        //     }
        // }

        // IMPORTANT: Pivot artificial variables out of the basis before zeroing their columns
        // If an artificial is still basic (with value 0, degenerate), we need to pivot it out
        // to maintain tableau consistency when we zero its column
        for artificialVar in workingTableau.artificialVars {
            if let rowIdx = workingTableau.basis.firstIndex(of: artificialVar) {
                // Find a non-basic variable to pivot in (prefer original variables, then slack/surplus)
                var pivotCol: Int? = nil

                // Try to find a non-zero entry in this row (excluding RHS and artificial columns)
                for col in 0..<numCols-1 {
                    if !workingTableau.artificialVars.contains(col) &&
                       abs(workingTableau.table[rowIdx][col]) > tolerance &&
                       !workingTableau.basis.contains(col) {
                        pivotCol = col
                        break
                    }
                }

                if let pivotCol = pivotCol {
                    // Perform pivot to replace artificial with this variable
                    pivot(tableau: &workingTableau, pivotRow: rowIdx, pivotCol: pivotCol)
                    // Update the basis to reflect the pivot
                    workingTableau.basis[rowIdx] = pivotCol
                    // print("DEBUG Phase II: Pivoted artificial var \(artificialVar) out of basis at row \(rowIdx), replaced with var \(pivotCol)")
                }
            }
        }

        // Remove artificial variable columns from ALL rows (including objective)
        for artificialVar in workingTableau.artificialVars {
            for row in 0...numRows {
                workingTableau.table[row][artificialVar] = 0.0
            }
        }

        // Restore original objective row coefficients for ALL variables
        // (originalObjective includes zeros for slack/surplus/artificial)
        for col in 0..<numCols {
            // Skip artificial variable columns (already zeroed)
            if !workingTableau.artificialVars.contains(col) {
                workingTableau.table[numRows][col] = workingTableau.originalObjective[col]
            }
        }

        // Compute reduced costs for the current basis
        // For each basic variable in the current basis, we need to ensure its
        // reduced cost is zero by subtracting the appropriate linear combination
        // of constraint rows from the objective row.
        //
        // The reduced cost formula is: c_j - c_B * B^{-1} * A_j
        // Where c_j is the original objective coefficient for variable j,
        // c_B are the objective coefficients of basic variables,
        // and B^{-1} * A_j is the j-th column in the current tableau.

        // For each basic variable, zero out its coefficient in objective row
        for (rowIndex, basicVar) in workingTableau.basis.enumerated() {
            // Skip artificial variables (already removed)
            if workingTableau.artificialVars.contains(basicVar) {
                continue
            }

            // Get the objective coefficient for this basic variable
            let objectiveCoeff = workingTableau.table[numRows][basicVar]

            if abs(objectiveCoeff) > tolerance {
                // Subtract objectiveCoeff times this row from the objective row
                // This zeros out the coefficient for the basic variable
                for col in 0..<numCols {
                    workingTableau.table[numRows][col] -= objectiveCoeff * workingTableau.table[rowIndex][col]
                }
            }
        }

        return try simplexIterations(tableau: workingTableau)
    }

    /// Main simplex pivot iterations
    private func simplexIterations(tableau: SimplexTableau) throws -> (tableau: SimplexTableau, status: SimplexStatus, iterations: Int) {
        var workingTableau = tableau
        let numRows = workingTableau.table.count - 1
        let numCols = workingTableau.table[0].count - 1  // Exclude RHS

        for iteration in 0..<maxIterations {
            // Find entering variable (most negative coefficient in objective row)
            let enteringVar = selectEnteringVariable(tableau: workingTableau)

            if enteringVar == -1 {
                // Optimal solution found
                return (workingTableau, .optimal, iteration)
            }

            // Find leaving variable (minimum ratio test)
            let leavingRow = selectLeavingVariable(tableau: workingTableau, enteringVar: enteringVar)

            if leavingRow == -1 {
                // Problem is unbounded
                return (workingTableau, .unbounded, iteration)
            }

            // Perform pivot
            pivot(tableau: &workingTableau, pivotRow: leavingRow, pivotCol: enteringVar)
            workingTableau.basis[leavingRow] = enteringVar
        }

        throw OptimizationError.failedToConverge(
            message: "Simplex method did not converge within \(maxIterations) iterations"
        )
    }

    /// Select entering variable using Bland's rule (smallest index with negative cost)
    private func selectEnteringVariable(tableau: SimplexTableau) -> Int {
        let objectiveRow = tableau.table.last!
        let numCols = objectiveRow.count - 1

        for col in 0..<numCols {
            if objectiveRow[col] < -tolerance {
                return col
            }
        }

        return -1  // Optimal
    }

    /// Select leaving variable using minimum ratio test
    private func selectLeavingVariable(tableau: SimplexTableau, enteringVar: Int) -> Int {
        let numRows = tableau.table.count - 1
        let rhsCol = tableau.table[0].count - 1

        var minRatio = Double.infinity
        var leavingRow = -1

        for row in 0..<numRows {
            let coefficient = tableau.table[row][enteringVar]

            if coefficient > tolerance {
                let ratio = tableau.table[row][rhsCol] / coefficient

                if ratio < minRatio - tolerance {
                    minRatio = ratio
                    leavingRow = row
                } else if abs(ratio - minRatio) <= tolerance {
                    // Bland's rule for tie-breaking: choose row with smallest basic variable index
                    if tableau.basis[row] < tableau.basis[leavingRow] {
                        leavingRow = row
                    }
                }
            }
        }

        return leavingRow
    }

    /// Perform pivot operation
    private func pivot(tableau: inout SimplexTableau, pivotRow: Int, pivotCol: Int) {
        let numRows = tableau.table.count
        let numCols = tableau.table[0].count
        let pivotElement = tableau.table[pivotRow][pivotCol]

        // Divide pivot row by pivot element
        for col in 0..<numCols {
            tableau.table[pivotRow][col] /= pivotElement
        }

        // Eliminate pivot column in other rows
        for row in 0..<numRows {
            if row != pivotRow {
                let factor = tableau.table[row][pivotCol]
                for col in 0..<numCols {
                    tableau.table[row][col] -= factor * tableau.table[pivotRow][col]
                }
            }
        }
    }

    /// Extract solution values for original variables
    private func extractSolution(from tableau: SimplexTableau, numVars: Int) -> [Double] {
        var solution = Array(repeating: 0.0, count: numVars)
        let rhsCol = tableau.table[0].count - 1

        // First pass: extract values for basic original variables
        for (rowIndex, basicVar) in tableau.basis.enumerated() {
            if basicVar < numVars {
                solution[basicVar] = tableau.table[rowIndex][rhsCol]
            }
        }

        // Debug: print solution before lower bound enforcement (commented out)
        // if !tableau.surplusVars.isEmpty && numVars <= 5 {
        //     print("DEBUG extractSolution BEFORE lower bound fix: \(solution)")
        //     print("DEBUG basis: \(tableau.basis)")
        //     for (idx, surplusInfo) in tableau.surplusVars.enumerated() {
        //         let basicVar = tableau.basis[surplusInfo.row]
        //         let rhsValue = tableau.table[surplusInfo.row][rhsCol]
        //         print("DEBUG surplus[\(idx)]: row=\(surplusInfo.row), surplusCol=\(surplusInfo.surplusCol), basicVar=\(basicVar), rhs=\(rhsValue), coeffs=\(surplusInfo.coefficients), constraintRHS=\(surplusInfo.rhs)")
        //     }
        // }

        // Second pass: enforce lower bounds from surplus variable constraints
        // When we have a constraint like x[i] ≥ k (stored as coeffs[i]*x[i] - surplus = k),
        // and the surplus variable is basic (meaning the constraint is not tight),
        // the original variable may be non-basic (defaulting to 0), violating the lower bound.
        // We need to set such variables to their lower bound value.
        for surplusInfo in tableau.surplusVars {
            let basicVarInRow = tableau.basis[surplusInfo.row]

            // Check if this is a single-variable lower bound constraint (like x[i] ≥ k)
            var singleVarIndex: Int? = nil
            var singleVarCoeff: Double = 0.0
            var nonZeroCount = 0

            for (varIndex, coeff) in surplusInfo.coefficients.enumerated() {
                if abs(coeff) > 1e-10 {
                    nonZeroCount += 1
                    singleVarIndex = varIndex
                    singleVarCoeff = coeff
                }
            }

            // If this is a single-variable constraint and the variable is currently non-basic (value ≈ 0)
            if nonZeroCount == 1, let varIdx = singleVarIndex, abs(solution[varIdx]) < 1e-10 {
                // Original constraint: coeff * x[varIdx] - surplus = rhs
                // Therefore: x[varIdx] = (rhs + surplus) / coeff
                // At optimum, if surplus is basic, the constraint may not be tight
                // But x[varIdx] must still satisfy x[varIdx] ≥ rhs / coeff
                // Since x is non-basic (= 0) and the constraint is x ≥ k, set x = k

                let lowerBound = surplusInfo.rhs / abs(singleVarCoeff)
                // print("DEBUG enforcing lower bound: var[\(varIdx)] = \(lowerBound) (was \(solution[varIdx]))")
                solution[varIdx] = max(0.0, lowerBound)
            }
        }

        // if !tableau.surplusVars.isEmpty && numVars <= 5 {
        //     print("DEBUG extractSolution AFTER lower bound fix: \(solution)")
        // }

        return solution
    }
}

// MARK: - Internal Tableau Structure

/// Internal simplex tableau structure
private struct SimplexTableau {
    var table: [[Double]]          // Augmented matrix [A | b]
    var basis: [Int]               // Basic variable for each row
    let numOriginalVars: Int       // Number of original decision variables
    let artificialVars: [Int]      // Indices of artificial variables
    let originalObjective: [Double] // Original objective row (before Phase I)
    let surplusVars: [(row: Int, surplusCol: Int, coefficients: [Double], rhs: Double)] // Surplus constraint metadata
}
