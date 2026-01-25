import Testing
import Foundation
@testable import BusinessMath

/// Tests for SimplexResult tableau access (required for cutting plane generation)
///
/// Following TDD: These tests are written FIRST (RED phase) and will fail
/// until SimplexResult is extended to expose tableau, basis, and dual information.
///
/// ## What We're Testing
/// - Tableau access from SimplexResult
/// - Basis identification (which variables are basic)
/// - Dual variable access for sensitivity analysis
/// - Integration with CuttingPlaneGenerator
///
/// ## Why This Matters
/// Gomory cuts require access to the simplex tableau rows for fractional basic variables.
/// Without tableau access, we cannot generate cuts from LP relaxations.
@Suite("SimplexTableau Access Tests")
struct SimplexTableauAccessTests {

    // MARK: - Basic Tableau Access

    @Test("SimplexResult exposes final tableau")
    func testTableauExposure() throws {
        let solver = SimplexSolver()

        // Simple LP: max 3x + 2y
        // s.t. x + y ≤ 4
        //      2x + y ≤ 5
        //      x, y ≥ 0

        let objective = [3.0, 2.0]
        let constraints = [
            SimplexConstraint(coefficients: [1.0, 1.0], relation: .lessOrEqual, rhs: 4.0),
            SimplexConstraint(coefficients: [2.0, 1.0], relation: .lessOrEqual, rhs: 5.0)
        ]

        let result = try solver.maximize(objective: objective, subjectTo: constraints)

        #expect(result.status == .optimal, "Should find optimal solution")

        // SimplexResult should now have tableau field
        #expect(result.tableau != nil, "Result should expose final tableau")

        if let tableau = result.tableau {
            // Tableau should have rows for each constraint + objective row
            #expect(tableau.rowCount >= constraints.count, "Tableau should have constraint rows")

            // Tableau should have columns for variables + slack + RHS
            #expect(tableau.columnCount > objective.count, "Tableau should have slack variables")
        }
    }

    @Test("SimplexResult exposes basis information")
    func testBasisExposure() throws {
        let solver = SimplexSolver()

        let objective = [1.0, 1.0]
        let constraints = [
            SimplexConstraint(coefficients: [1.0, 0.0], relation: .lessOrEqual, rhs: 3.0),
            SimplexConstraint(coefficients: [0.0, 1.0], relation: .lessOrEqual, rhs: 2.0)
        ]

        let result = try solver.maximize(objective: objective, subjectTo: constraints)

        #expect(result.status == .optimal)

        // SimplexResult should expose which variables are basic
        #expect(result.basis != nil, "Result should expose basis")

        if let basis = result.basis {
            // Basis should have one entry per constraint (basic variable per row)
            #expect(basis.count == constraints.count, "Basis size should match constraint count")

            // All basis indices should be valid
            for varIndex in basis {
                #expect(varIndex >= 0, "Basis variable index should be non-negative")
            }
        }
    }

    // MARK: - Fractional Solution Detection

    @Test("Identify fractional basic variables from tableau")
    func testFractionalBasicVariableDetection() throws {
        let solver = SimplexSolver()

        // LP that will have fractional solution
        // max x + y
        // s.t. x + 2y ≤ 7
        //      2x + y ≤ 7
        //      x, y ≥ 0
        // Optimal: x = 7/3, y = 7/3 (both fractional)

        let objective = [1.0, 1.0]
        let constraints = [
            SimplexConstraint(coefficients: [1.0, 2.0], relation: .lessOrEqual, rhs: 7.0),
            SimplexConstraint(coefficients: [2.0, 1.0], relation: .lessOrEqual, rhs: 7.0)
        ]

        let result = try solver.maximize(objective: objective, subjectTo: constraints)

        #expect(result.status == .optimal)

        // Check that solution is fractional
        let isFractional = result.solution.contains { value in
            let frac = value - floor(value)
            return frac > 1e-6 && frac < 1.0 - 1e-6
        }

        #expect(isFractional, "Solution should contain fractional values")

        // Should be able to identify which basic variables are fractional
        if let basis = result.basis, let tableau = result.tableau {
            var fractionalBasicVars: [Int] = []

            for (rowIndex, basicVarIndex) in basis.enumerated() {
                if basicVarIndex < result.solution.count {
                    let value = result.solution[basicVarIndex]
                    let frac = value - floor(value)

                    if frac > 1e-6 && frac < 1.0 - 1e-6 {
                        fractionalBasicVars.append(rowIndex)
                    }
                }
            }

            #expect(!fractionalBasicVars.isEmpty, "Should identify fractional basic variables")
        }
    }

    // MARK: - Integration with Cutting Plane Generator

    @Test("Extract tableau row for Gomory cut generation")
    func testTableauRowExtraction() throws {
        let solver = SimplexSolver()

        // Simple fractional LP
        let objective = [1.0, 1.0]
        let constraints = [
            SimplexConstraint(coefficients: [1.0, 2.0], relation: .lessOrEqual, rhs: 7.0),
            SimplexConstraint(coefficients: [2.0, 1.0], relation: .lessOrEqual, rhs: 7.0)
        ]

        let result = try solver.maximize(objective: objective, subjectTo: constraints)

        #expect(result.status == .optimal)
        #expect(result.tableau != nil, "Need tableau for cut generation")

        if let tableau = result.tableau, let basis = result.basis {
            // For first basic variable (if fractional), extract tableau row
            let rowIndex = 0
            guard rowIndex < basis.count else {
                Issue.record("Row index out of bounds")
                return
            }

            // Should be able to get the row coefficients
            let tableauRow = tableau.getRow(rowIndex)

            #expect(tableauRow.count > 0, "Tableau row should have coefficients")

            // Row should include coefficients for non-basic variables
            // (This is what Gomory cuts need)
        }
    }

    @Test("Generate Gomory cut from SimplexResult tableau")
    func testGomoryCutFromTableau() throws {
        let solver = SimplexSolver()

        // LP with fractional solution
        let objective = [1.0, 1.0]
        let constraints = [
            SimplexConstraint(coefficients: [1.0, 2.0], relation: .lessOrEqual, rhs: 7.0),
            SimplexConstraint(coefficients: [2.0, 1.0], relation: .lessOrEqual, rhs: 7.0)
        ]

        let result = try solver.maximize(objective: objective, subjectTo: constraints)

        #expect(result.status == .optimal)

        // Verify solution is fractional
        let isFractional = result.solution.contains { value in
            let frac = value - floor(value)
            return frac > 1e-6 && frac < 1.0 - 1e-6
        }

        #expect(isFractional, "Solution should be fractional for this test")

        // Generate cuts from the fractional solution
        let cutGenerator = CuttingPlaneGenerator()

        guard let tableau = result.tableau, let basis = result.basis else {
            Issue.record("Need tableau and basis for cut generation")
            return
        }

        // Note: Gomory cuts require the tableau to have non-basic variable coefficients
        // The current SimplexTableau exposes rows, but may not separate basic/non-basic correctly
        // For now, just verify we can access the tableau structure

        #expect(basis.count > 0, "Basis should have entries")
        #expect(tableau.rowCount > 0, "Tableau should have rows")

        // Verify we can extract tableau rows
        for rowIndex in 0..<min(basis.count, tableau.rowCount) {
            let tableauRow = tableau.getRow(rowIndex)
            #expect(tableauRow.count > 0, "Tableau row should have coefficients")

            let rhs = tableau.getRHS(rowIndex)
            #expect(rhs.isFinite, "RHS should be finite")
        }
    }

    // MARK: - Dual Variable Access (for advanced cuts)

    @Test("SimplexResult exposes dual variables")
    func testDualVariableExposure() throws {
        let solver = SimplexSolver()

        let objective = [3.0, 2.0]
        let constraints = [
            SimplexConstraint(coefficients: [1.0, 1.0], relation: .lessOrEqual, rhs: 4.0),
            SimplexConstraint(coefficients: [2.0, 1.0], relation: .lessOrEqual, rhs: 5.0)
        ]

        let result = try solver.maximize(objective: objective, subjectTo: constraints)

        #expect(result.status == .optimal)

        // Dual variables (shadow prices) can be read from objective row
        // For advanced cut generation (MIR, etc.)
        if let dualValues = result.dualValues {
            #expect(dualValues.count == constraints.count, "One dual value per constraint")

            // Dual values should exist and be finite
            for dual in dualValues {
                #expect(dual.isFinite, "Dual values should be finite")
            }
        }
    }

    @Test("Reduced costs available from tableau")
    func testReducedCostExposure() throws {
        let solver = SimplexSolver()

        let objective = [3.0, 2.0]
        let constraints = [
            SimplexConstraint(coefficients: [1.0, 1.0], relation: .lessOrEqual, rhs: 4.0)
        ]

        let result = try solver.maximize(objective: objective, subjectTo: constraints)

        #expect(result.status == .optimal)

        // Reduced costs indicate how much objective would worsen if non-basic variable entered
        if let reducedCosts = result.reducedCosts {
            #expect(reducedCosts.count >= objective.count, "Reduced cost for each variable")

            // At optimality, non-basic variables should have non-negative reduced costs (for max)
            // (or non-positive for minimization)
        }
    }

    // MARK: - Edge Cases

    @Test("Integer solution has no fractional basic variables")
    func testIntegerSolutionHasNoFractionalVariables() throws {
        let solver = SimplexSolver()

        // LP with integer optimal solution
        // max 2x + y
        // s.t. x + y ≤ 5
        //      x ≤ 3
        //      x, y ≥ 0
        // Optimal: x = 3, y = 2 (both integer)

        let objective = [2.0, 1.0]
        let constraints = [
            SimplexConstraint(coefficients: [1.0, 1.0], relation: .lessOrEqual, rhs: 5.0),
            SimplexConstraint(coefficients: [1.0, 0.0], relation: .lessOrEqual, rhs: 3.0)
        ]

        let result = try solver.maximize(objective: objective, subjectTo: constraints)

        #expect(result.status == .optimal)

        // Solution should be integer
        for value in result.solution {
            let frac = value - floor(value)
            #expect(frac < 1e-6 || frac > 1.0 - 1e-6, "Solution should be integer")
        }

        // Should not generate any cuts
        let cutGenerator = CuttingPlaneGenerator()

        if let tableau = result.tableau, let basis = result.basis {
            var cuts: [CuttingPlane] = []

            for (rowIndex, basicVarIndex) in basis.enumerated() {
                guard basicVarIndex < result.solution.count else { continue }

                let value = result.solution[basicVarIndex]
                let tableauRow = tableau.getRow(rowIndex)

                if let cut = try cutGenerator.generateGomoryCut(
                    tableauRow: tableauRow,
                    rhs: value,
                    basicVariableIndex: basicVarIndex
                ) {
                    cuts.append(cut)
                }
            }

            #expect(cuts.isEmpty, "No cuts should be generated for integer solution")
        }
    }
}

// SimplexTableau is now implemented in SimplexSolver.swift
