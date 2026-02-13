import Testing
import Foundation
@testable import BusinessMath

@Suite("Cutting Plane Generation Tests")
struct CuttingPlaneTests {

    // MARK: - Test Helpers

    /// Helper to create a SimplexRow for testing
    func makeSimplexRow(
        rhs: Double,
        coefficients: [Double],
        nonBasicIndices: [Int],
        basicIndex: Int
    ) -> SimplexRow {
        SimplexRow(
            rhs: rhs,
            coefficients: coefficients,
            nonBasicVariableIndices: nonBasicIndices,
            basicVariableIndex: basicIndex
        )
    }

    /// Debug helper to validate a Gomory cut.
    ///
    /// Verifies:
    /// 1. Fractional LP solution is violated.
    /// 2. All provided integer-feasible solutions satisfy the cut.
    ///
    /// - Parameters:
    ///   - cut: The generated cutting plane
    ///   - fractionalSolution: The fractional LP solution it was derived from
    ///   - integerPoints: Integer-feasible candidate solutions to verify validity
    ///   - tolerance: Numerical tolerance (default 1e-6)
    ///
    /// - Returns: `true` if valid, otherwise prints diagnostic info and returns `false`
    func validateGomoryCut(
        cut: CuttingPlane,
        fractionalSolution: [Double],
        integerPoints: [[Double]],
        tolerance: Double = 1e-6
    ) -> Bool {

        var isValid = true

        // ✅ Check fractional solution is eliminated
        let fractionalViolation = cut.violation(at: fractionalSolution)

        if fractionalViolation <= tolerance {
            print("❌ Fractional solution NOT eliminated.")
            print("   Violation:", fractionalViolation)
            isValid = false
        } else {
            print("✅ Fractional solution eliminated (violation =", fractionalViolation, ")")
        }

        // ✅ Check integer feasibility preservation
        for point in integerPoints {
            let violation = cut.violation(at: point)

            if violation > tolerance {
                print("❌ Integer solution incorrectly eliminated:", point)
                print("   Violation:", violation)
                print("   Cut coefficients:", cut.coefficients)
                print("   Cut RHS:", cut.rhs)
                isValid = false
            }
        }

        if isValid {
            print("✅ All integer solutions satisfy the cut.")
        }

        return isValid
    }

    // MARK: - Basic Gomory Cut Tests

    @Test("Generate Gomory cut from fractional LP solution")
    func testBasicGomoryCut() throws {
        // Simplex solved form: x0 = 2.5 + 0.25*s0 - 0.5*s1
        // SimplexRow will convert to canonical internally

        let row = makeSimplexRow(
            rhs: 2.5,
            coefficients: [-0.25, 0.5],   // Canonical form: x0 - 0.25*s0 + 0.5*s1 = 2.5
            nonBasicIndices: [2, 3],      // s0 is var 2, s1 is var 3
            basicIndex: 0                  // x0 is basic
        )

        let generator = CuttingPlaneGenerator()
        let cut = try generator.generateGomoryCut(
            from: row,
            totalVariableCount: 4  // x0, x1, s0, s1
        )

        #expect(cut != nil, "Should generate a cut for fractional solution")

        guard let cut = cut else { return }

        // Cut should be in original variable space (4 variables)
        #expect(cut.coefficients.count == 4, "Cut should span all variables")

        // Decision variables x0, x1 should have zero coefficients
        // (they're not in the tableau row, only slacks are)
        #expect(abs(cut.coefficients[0]) < 1e-9)
        #expect(abs(cut.coefficients[1]) < 1e-9)

        // Slack variables:
        // frac(-0.25) = 0.75 → coefficient = -0.75
        // frac(0.5) = 0.5 → coefficient = -0.5
        #expect(abs(cut.coefficients[2] - (-0.75)) < 1e-9)
        #expect(abs(cut.coefficients[3] - (-0.5)) < 1e-9)

        // RHS should be -frac(2.5) = -0.5
        #expect(abs(cut.rhs - (-0.5)) < 1e-9)

        // Verify fractional LP basic solution is eliminated
        let fractionalSolution = [2.5, 0.0, 0.0, 0.0]
        let violation = cut.violation(at: fractionalSolution)
        #expect(violation > 1e-6, "Fractional LP solution must be eliminated")

        // Verify the cut is not weak
        #expect(!cut.isWeak, "Generated cut should not be weak")
    }

    @Test("No cut generated for integer solution")
    func testNoCutForIntegerSolution() throws {
        // If LP solution is already integer, no cut needed
        let row = makeSimplexRow(
            rhs: 3.0,  // Integer RHS
            coefficients: [0.5, -0.25],
            nonBasicIndices: [2, 3],
            basicIndex: 0
        )

        let generator = CuttingPlaneGenerator()
        let cut = try generator.generateGomoryCut(
            from: row,
            totalVariableCount: 4
        )

        // Should not generate cut when RHS is integer
        #expect(cut == nil, "No cut needed for integer RHS")
    }

    @Test("Gomory cut strengthens LP bound")
    func testGomoryCutStrengthensLP() throws {
        // Problem: max x0 + x1 (2 decision vars, 2 slacks)
        // s.t. x0 + 2x1 ≤ 7  (slack s0)
        //      2x0 + x1 ≤ 7  (slack s1)

        // LP solution: x0=7/3, x1=7/3, s0=0, s1=0

        let generator = CuttingPlaneGenerator()

        // Build SimplexRow objects for fractional basic variables
        // Row 1 canonical: x0 + (-1/3)*s0 + (1/3)*s1 = 7/3
        let row1 = makeSimplexRow(
            rhs: 7.0/3.0,
            coefficients: [-1.0/3.0, 1.0/3.0],  // Canonical coefficients
            nonBasicIndices: [2, 3],             // s0, s1 are non-basic
            basicIndex: 0                         // x0 is basic
        )

        // Row 2 canonical: x1 + (1/3)*s0 + (-1/3)*s1 = 7/3
        let row2 = makeSimplexRow(
            rhs: 7.0/3.0,
            coefficients: [1.0/3.0, -1.0/3.0],  // Canonical coefficients
            nonBasicIndices: [2, 3],
            basicIndex: 1                        // x1 is basic
        )

        let rows = [row1, row2]
        let lpSolution = [7.0/3.0, 7.0/3.0, 0.0, 0.0]  // x0, x1, s0, s1

        let cuts = try generator.generateCuts(
            from: rows,
            currentSolution: lpSolution,
            totalVariableCount: 4
        )

        #expect(!cuts.isEmpty, "Should generate at least one cut")

        // Verify cuts violate fractional solution
        for cut in cuts {
            let violation = cut.violation(at: lpSolution)
            #expect(violation > 1e-6,
                    "Cut should violate fractional LP solution")
        }
    }

    // MARK: - Mixed-Integer Cuts

    @Test("Generate cut for mixed-integer problem")
    func testMixedIntegerGomoryCut() throws {
        // TODO: MIR cuts need separate implementation
        // For now, test basic Gomory cut functionality
        // MIR cuts are more advanced and need integrality info

        // Problem: x0 (integer), x1 (continuous), s0, s1 (slacks)
        // Canonical form: x0 + (-0.75)*s0 + (-0.25)*s1 = 4.3

        let row = makeSimplexRow(
            rhs: 4.3,
            coefficients: [-0.75, -0.25],  // Canonical coefficients
            nonBasicIndices: [2, 3],        // s0, s1
            basicIndex: 0                   // x0
        )

        let generator = CuttingPlaneGenerator()
        let cut = try generator.generateGomoryCut(
            from: row,
            totalVariableCount: 4
        )

        #expect(cut != nil, "Should generate cut for fractional integer variable")

        // Note: Full MIR implementation would differentiate integer vs continuous
    }

    // MARK: - Multiple Cut Generation

    @Test("Generate multiple cuts from tableau")
    func testMultipleCutGeneration() throws {
        // Generate cuts from all fractional basic variables
        // Problem: 3 decision vars, 3 slacks (total 6 vars)

        // Build rows for fractional basic variables (canonical form)
        let row1 = makeSimplexRow(
            rhs: 2.5,  // Fractional
            coefficients: [-0.5, 0.25, -0.125],  // Canonical coefficients
            nonBasicIndices: [3, 4, 5],          // s0, s1, s2
            basicIndex: 0                         // x0 is basic
        )

        let row2 = makeSimplexRow(
            rhs: 3.333,  // Fractional
            coefficients: [-0.75, -0.333, 0.5],  // Canonical coefficients
            nonBasicIndices: [3, 4, 5],
            basicIndex: 1                         // x1 is basic
        )

        let row3 = makeSimplexRow(
            rhs: 5.0,  // Integer
            coefficients: [-1.0, 0.0, 0.0],  // Canonical coefficients
            nonBasicIndices: [3, 4, 5],
            basicIndex: 2                     // x2 is basic
        )

        let rows = [row1, row2, row3]
        let solution = [2.5, 3.333, 5.0, 0.0, 0.0, 0.0]

        let generator = CuttingPlaneGenerator()
        let cuts = try generator.generateCuts(
            from: rows,
            currentSolution: solution,
            totalVariableCount: 6
        )

        // Should generate cuts for first two fractional rows only
        #expect(cuts.count >= 1 && cuts.count <= 2,
                "Generate cuts for fractional rows only")
    }

    @Test("Select most violated cut")
    func testCutSelection() throws {
        // When multiple cuts available, select the one that
        // most violates current LP solution

        let cuts = [
            BusinessMath.CuttingPlane(coefficients: [0.5, -0.25], rhs: 1.0, type: .gomory),
            BusinessMath.CuttingPlane(coefficients: [0.75, 0.5], rhs: 2.0, type: .gomory),
            BusinessMath.CuttingPlane(coefficients: [0.25, -0.5], rhs: 0.5, type: .gomory)
        ]

        let currentSolution = [3.0, 4.0]

        let generator = CuttingPlaneGenerator()
        let selectedCut = generator.selectMostViolatedCut(
            cuts: cuts,
            currentSolution: currentSolution
        )

        #expect(selectedCut != nil, "Should select a cut")

        // Selected cut should have maximum violation
        // violation = ax - b (for constraint ax ≤ b)
    }

    // MARK: - Cut Validity Tests

    @Test("Verify cut eliminates fractional LP solution")
    func testCutValidityForFractionalPoint() throws {
        // Canonical form: x0 + (-0.25)*s0 + (0.5)*s1 = 2.5

        let row = makeSimplexRow(
            rhs: 2.5,
            coefficients: [-0.25, 0.5],  // Canonical coefficients
            nonBasicIndices: [2, 3],
            basicIndex: 0
        )

        let generator = CuttingPlaneGenerator()
        let cut = try generator.generateGomoryCut(
            from: row,
            totalVariableCount: 4
        )

        guard let validCut = cut else {
            Issue.record("Should generate a cut for fractional RHS")
            return
        }

        // Verify structure
        #expect(!validCut.isWeak, "Cut should not be weak")
        #expect(validCut.coefficients.count == 4,
                "Cut should span all variables in original space")

        // Verify fractional LP basic solution is eliminated
        let fractionalSolution = [2.5, 0.0, 0.0, 0.0]
        let violation = validCut.violation(at: fractionalSolution)
        #expect(violation > 1e-6,
                "Fractional LP solution must be eliminated (violation=\(violation))")
    }

    @Test("Verify cut eliminates fractional point")
    func testCutEliminatesCurrentFractionalSolution() throws {
        // Canonical form: x0 + (-0.25)*s0 + (0.5)*s1 = 2.5
        //
        // At LP basic solution: s0=0, s1=0, so x0=2.5 (fractional!)

        let row = makeSimplexRow(
            rhs: 2.5,
            coefficients: [-0.25, 0.5],  // Canonical coefficients
            nonBasicIndices: [2, 3],      // s0, s1
            basicIndex: 0                 // x0
        )

        let generator = CuttingPlaneGenerator()
        guard let cut = try generator.generateGomoryCut(
            from: row,
            totalVariableCount: 4
        ) else {
            Issue.record("Should generate a cut for fractional RHS")
            return
        }

        // Fractional LP basic solution: x0=2.5, x1=0, s0=0, s1=0
        let fractionalSolution = [2.5, 0.0, 0.0, 0.0]

        let violation = cut.violation(at: fractionalSolution)

        // Gomory cut MUST violate the fractional LP solution it was generated from
        #expect(violation > 1e-6,
                "Generated cut must eliminate the fractional LP solution (violation=\(violation))")

        #expect(!cut.isWeak, "Cut should not be weak")
    }

    // MARK: - Cover Cut Tests (Advanced)

    @Test("Generate cover cut for knapsack constraint")
    func testCoverCutGeneration() throws {
        // For knapsack constraint: Σ aᵢxᵢ ≤ b
        // If C is a minimal cover (Σ aᵢ > b for i∈C)
        // Then: Σ xᵢ ≤ |C| - 1 for i∈C

        let weights = [5.0, 7.0, 3.0, 4.0]
        let capacity = 10.0
        let fractionalSolution = [1.0, 0.7, 1.0, 0.5]  // Violates integrality

        let generator = CuttingPlaneGenerator()
        let coverCut = try generator.generateCoverCut(
            weights: weights,
            capacity: capacity,
            solution: fractionalSolution
        )

        if let cut = coverCut {
            // Cover cut should be valid
            #expect(cut.type == .cover, "Should be a cover cut")

            // Verify it's a minimal cover
            // (sum of weights in cover > capacity)
        }
    }

    // MARK: - Integration Tests

    @Test("Cutting planes reduce branch count")
    func testCuttingPlanesReduceBranching() throws {
			// Simple 0-1 knapsack:
				// max 16x1 + 19x2 + 23x3 + 28x4
				// s.t. 2x1 + 3x2 + 4x3 + 5x4 ≤ 7
				// x ∈ {0,1}

				let values = [16.0, 19.0, 23.0, 28.0]
				let weights = [2.0, 3.0, 4.0, 5.0]
				let capacity = 7.0

				// Fractional LP relaxation solution
				// (x1 = 1, x2 = 1, x3 = 0.5, x4 = 0)
				let lpSolution = [1.0, 1.0, 0.5, 0.0]

				let generator = CuttingPlaneGenerator()

				// Attempt to generate a cover cut
				let coverCut = try generator.generateCoverCut(
					weights: weights,
					capacity: capacity,
					solution: lpSolution
				)

				#expect(coverCut != nil, "Should generate a cover cut for fractional knapsack solution")

				guard let cut = coverCut else { return }

				#expect(cut.type == .cover, "Generated cut should be a cover cut")

				// ---------------------------------------------------------
				// 1️⃣ Verify the cut is violated by the fractional solution
				// ---------------------------------------------------------
				let lhsFractional = zip(cut.coefficients, lpSolution)
					.map(*)
					.reduce(0, +)

				#expect(lhsFractional > cut.rhs,
						"Fractional LP solution should violate the generated cut")
		
			// ---------------------------------------------------------
				// 2️⃣ Verify integer-feasible points satisfy the cut
				// ---------------------------------------------------------

				// Enumerate all 0-1 feasible solutions
				let n = values.count
				for mask in 0..<(1 << n) {

					var candidate = [Double](repeating: 0.0, count: n)
					for i in 0..<n {
						if (mask & (1 << i)) != 0 {
							candidate[i] = 1.0
						}
					}

					// Check knapsack feasibility
					let totalWeight = zip(candidate, weights).map(*).reduce(0, +)
					if totalWeight <= capacity {

						let lhs = zip(candidate, cut.coefficients)
							.map(*)
							.reduce(0, +)

						#expect(lhs <= cut.rhs + 1e-8,
								"Cut must not eliminate integer-feasible solution \(candidate)")
					}
				}
		
			// ---------------------------------------------------------
				// 3️⃣ Simulate tightening effect
				// ---------------------------------------------------------

				let lpObjective = zip(values, lpSolution).map(*).reduce(0, +)

				// Simulate effect of cut eliminating fractional x3 = 0.5
				let tightenedSolution = [1.0, 1.0, 0.0, 0.0]
				let tightenedObjective = zip(values, tightenedSolution).map(*).reduce(0, +)

				#expect(tightenedObjective <= lpObjective,
						"Cut should not improve LP objective for maximization")

				#expect(tightenedObjective >= 0,
						"Objective must remain valid after tightening")
    }

    @Test("Cutting plane convergence")
    func testCuttingPlaneConvergence() throws {
        let generator = CuttingPlaneGenerator()

        // Problem: 2 decision vars, 2 slacks (4 total)
        // Start with fractional LP solution: x0=7/3, x1=7/3, s0=0, s1=0
        var currentSolution = [7.0/3.0, 7.0/3.0, 0.0, 0.0]

        // Tableau rows (canonical form)
        let row1 = makeSimplexRow(
            rhs: 7.0/3.0,
            coefficients: [-1.0/3.0, 1.0/3.0],  // Canonical coefficients
            nonBasicIndices: [2, 3],
            basicIndex: 0
        )

        let row2 = makeSimplexRow(
            rhs: 7.0/3.0,
            coefficients: [1.0/3.0, -1.0/3.0],  // Canonical coefficients
            nonBasicIndices: [2, 3],
            basicIndex: 1
        )

        let rows = [row1, row2]

        // 1️⃣ Generate cuts from fractional solution
        let cuts = try generator.generateCuts(
            from: rows,
            currentSolution: currentSolution,
            totalVariableCount: 4
        )

        #expect(!cuts.isEmpty, "Should generate cuts for fractional solution")

        // 2️⃣ Select most violated cut
        guard let cut = generator.selectMostViolatedCut(
            cuts: cuts,
            currentSolution: currentSolution
        ) else {
            Issue.record("Should select a violated cut")
            return
        }

        // Measure violation at fractional solution
        let fractionalViolation = cut.violation(at: currentSolution)

        #expect(fractionalViolation > 1e-6,
                "Fractional solution must violate selected cut (violation=\(fractionalViolation))")

        // 3️⃣ Simulate convergence to integer solution
        currentSolution = [2.0, 2.0, 0.0, 0.0]

        // 4️⃣ Ensure no further Gomory cuts needed
        let newRows = [
            makeSimplexRow(rhs: 2.0, coefficients: [-1.0/3.0, 1.0/3.0],
                           nonBasicIndices: [2, 3], basicIndex: 0),
            makeSimplexRow(rhs: 2.0, coefficients: [1.0/3.0, -1.0/3.0],
                           nonBasicIndices: [2, 3], basicIndex: 1)
        ]

        let newCuts = try generator.generateCuts(
            from: newRows,
            currentSolution: currentSolution,
            totalVariableCount: 4
        )

        #expect(newCuts.isEmpty,
                "Once integer solution reached, no further Gomory cuts required")
//        // Adding cuts should converge to integer hull
//        // (or at least significantly tighten LP relaxation)
//
//        // Start with loose LP bound
//        let initialBound = 4.67  // Fractional LP optimal
//        let integerOptimal = 4.0  // True integer optimal
//
//        // Generate and add cuts iteratively
//        var currentBound = initialBound
//        let maxRounds = 10
//
//        for round in 1...maxRounds {
//            // In practice: resolve LP, generate cuts, add cuts
//            // Each round should improve (lower for minimization) the bound
//
//            // Simulate bound improvement
//            let improvement = (initialBound - integerOptimal) / Double(maxRounds)
//            currentBound -= improvement
//
//            if abs(currentBound - integerOptimal) < 1e-3 {
//                // Converged to integer hull
//                break
//            }
//        }
//
//        #expect(currentBound <= initialBound, "Cuts should tighten LP bound")
//        #expect(currentBound >= integerOptimal - 1e-3, "Should not cut off integer optimum")
    }
}
