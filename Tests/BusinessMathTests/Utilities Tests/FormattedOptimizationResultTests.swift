import Testing
import Foundation
@testable import BusinessMath

// Typealias for cleaner test code
typealias IntegerProgramResult<V: VectorSpace> = IntegerOptimizationResult<V> where V.Scalar == Double

@Suite("Formatted Optimization Result Tests")
struct FormattedOptimizationResultTests {

    // MARK: - OptimizationResult Formatting

    @Test("OptimizationResult provides formatted output")
    func testOptimizationResultFormatting() throws {
        // Create a result with floating-point noise
        let result = MultivariateOptimizationResult(
            solution: VectorN([2.9999999999999964, -1.5000000000000002]),
            value: 1.2345678901234567e-15,
            iterations: 42,
            converged: true,
            gradientNorm: 1e-10,
            history: nil
        )

        // Raw values should be unchanged
        #expect(abs(result.solution[0] - 2.9999999999999964) < 1e-10)
        #expect(abs(result.solution[1] - (-1.5)) < 1e-10)

        // Formatted values should be clean
        #expect(result.formattedSolution.contains("3"))
        #expect(result.formattedSolution.contains("-1.5"))
        #expect(result.formattedObjectiveValue == "0")  // Essentially zero

        // Description should show formatted by default
        let description = result.formattedDescription
        #expect(description.contains("3"))
        #expect(!description.contains("2.9999"))
    }

    @Test("OptimizationResult can use raw formatter")
    func testOptimizationResultRawFormatter() throws {
        var result = MultivariateOptimizationResult(
            solution: VectorN([2.9999999999999964]),
            value: 0.0,
            iterations: 10,
            converged: true,
            gradientNorm: 1e-10,
            history: nil
        )

        // With raw formatter
        result.formatter = FloatingPointFormatter.raw
        #expect(result.formattedSolution.contains("2.999"))
    }

    @Test("OptimizationResult respects custom formatter")
    func testOptimizationResultCustomFormatter() throws {
        var result = MultivariateOptimizationResult(
            solution: VectorN([123.456789]),
            value: 0.0,
            iterations: 10,
            converged: true,
            gradientNorm: 1e-10,
            history: nil
        )

        // Use significant figures
        result.formatter = FloatingPointFormatter(strategy: .significantFigures(count: 3))
        let formatted = result.formattedSolution
        #expect(formatted.contains("123"))
    }

    // MARK: - AdaptiveOptimizer.Result Formatting

    @Test("AdaptiveOptimizer.Result provides formatted output")
    func testAdaptiveOptimizerResultFormatting() throws {
        let result = AdaptiveOptimizer<VectorN<Double>>.Result(
            solution: VectorN([2.9999999999999964, 3.0000000000000004]),
            objectiveValue: 1e-15,
            algorithmUsed: "Newton-Raphson",
            selectionReason: "Test",
            iterations: 20,
            converged: true,
            constraintViolation: nil
        )

        // Should have formatted accessors
        #expect(result.formattedSolution.contains("3"))
        #expect(result.formattedObjectiveValue == "0")

        // Description should be formatted
        let description = result.formattedDescription
        #expect(description.contains("3"))
        #expect(description.contains("Newton-Raphson"))
    }

    // MARK: - Integer Program Result Formatting

    @Test("IntegerProgramResult properly rounds integers")
    func testIntegerProgramResultRounding() throws {
        // This is the CRITICAL FIX for the production scheduling bug
        let solution = VectorN([99.99999999999999, 150.0, 79.99999999999999, 120.00000000000001])
        let spec = IntegerProgramSpecification(
            integerVariables: Set([0, 1, 2, 3]),
            binaryVariables: Set()
        )

        let result = IntegerProgramResult(
            solution: solution,
            objectiveValue: 14060.0,
            bestBound: 14060.0,
            relativeGap: 0.0,
            nodesExplored: 47,
            status: .optimal,
            solveTime: 0.15,
            integerSpec: spec
        )

        // CRITICAL: Integer solution must use round(), not truncation
        let intSolution = result.integerSolution
        #expect(intSolution[0] == 100)  // NOT 99!
        #expect(intSolution[1] == 150)
        #expect(intSolution[2] == 80)   // NOT 79!
        #expect(intSolution[3] == 120)

        // Formatted solution should show clean integers
        let formatted = result.formattedSolution
        #expect(formatted.contains("100"))
        #expect(formatted.contains("80"))
        #expect(!formatted.contains("99"))
        #expect(!formatted.contains("79"))
    }

    @Test("IntegerProgramResult handles binary variables")
    func testIntegerProgramResultBinary() throws {
        // Binary variables at exactly 0 or 1
        let solution = VectorN([0.0, 1.0, 0.9999999999999999, 0.0000000000000001])
        let spec = IntegerProgramSpecification(
            integerVariables: Set(),
            binaryVariables: Set([0, 1, 2, 3])
        )

        let result = IntegerProgramResult(
            solution: solution,
            objectiveValue: 0.0,
            bestBound: 0.0,
            relativeGap: 0.0,
            nodesExplored: 10,
            status: .optimal,
            solveTime: 0.01,
            integerSpec: spec
        )

        let intSolution = result.integerSolution
        #expect(intSolution[0] == 0)
        #expect(intSolution[1] == 1)
        #expect(intSolution[2] == 1)  // Rounds to 1
        #expect(intSolution[3] == 0)  // Rounds to 0
    }

    // MARK: - VectorN Formatting

    @Test("VectorN provides formatted output")
    func testVectorNFormatting() throws {
        let vector = VectorN([2.9999999999999964, 0.7500000000000002, 1e-15])

        let formatted = vector.formattedDescription()
        #expect(formatted.contains("3"))
        #expect(formatted.contains("0.75"))
        #expect(formatted.contains("0"))
        #expect(!formatted.contains("2.999"))
    }

    @Test("VectorN supports custom formatter")
    func testVectorNCustomFormatter() throws {
        let vector = VectorN([123.456, 789.012])

        let formatter = FloatingPointFormatter(strategy: .significantFigures(count: 2))
        let formatted = vector.formattedDescription(with: formatter)

        #expect(formatted.contains("120"))  // 123 with 2 sig figs
        #expect(formatted.contains("790"))  // 789 with 2 sig figs
    }

    // MARK: - End-to-End Integration Test

    @Test("Production scheduling example with formatted output")
    func testProductionSchedulingIntegration() throws {
        // This tests the exact scenario from the tutorial that was failing

        let productionCosts = [25.0, 30.0, 20.0, 28.0]
        let setupCosts = [500.0, 600.0, 450.0, 550.0]
        let demands = [100.0, 150.0, 80.0, 120.0]
        let capacities = [200.0, 250.0, 150.0, 200.0]

        let dimension = 8
        let spec = IntegerProgramSpecification(
            integerVariables: Set([0, 1, 2, 3]),
            binaryVariables: Set([4, 5, 6, 7])
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { x in
            let vars = x.toArray()
            var variableCost = 0.0
            for i in 0..<4 {
                variableCost += productionCosts[i] * vars[i]
            }
            var fixedCost = 0.0
            for i in 0..<4 {
                fixedCost += setupCosts[i] * vars[4 + i]
            }
            return variableCost + fixedCost
        }

        var constraints: [MultivariateConstraint<VectorN<Double>>] = []

        // Demand constraints
        for i in 0..<4 {
            constraints.append(.inequality { x in
                demands[i] - x.toArray()[i]
            })
        }

        // Linking constraints
        for i in 0..<4 {
            constraints.append(.inequality { x in
                let vars = x.toArray()
                return vars[i] - capacities[i] * vars[4 + i]
            })
        }

        // Capacity constraints
        for i in 0..<4 {
            constraints.append(.inequality { x in
                x.toArray()[i] - capacities[i]
            })
        }

        // Bounds
        for i in 0..<dimension {
            constraints.append(.inequality { x in -x.toArray()[i] })
            if i >= 4 {
                constraints.append(.inequality { x in x.toArray()[i] - 1.0 })
            }
        }

        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 3000,
            timeLimit: 30.0
        )

        let result = try solver.solve(
            objective: objective,
            from: VectorN(Array(repeating: 0.0, count: dimension)),
            subjectTo: constraints,
            integerSpec: spec,
            minimize: true
        )

        // CRITICAL TEST: Integer solution must match demands exactly
        let intSolution = result.integerSolution
        #expect(intSolution[0] == 100, "Product 0 production should be 100, not 99")
        #expect(intSolution[1] == 150, "Product 1 production should be 150")
        #expect(intSolution[2] == 80, "Product 2 production should be 80, not 79")
        #expect(intSolution[3] == 120, "Product 3 production should be 120")

        // Formatted output should be clean
        let formatted = result.formattedSolution
        #expect(formatted.contains("100"))
        #expect(formatted.contains("150"))
        #expect(formatted.contains("80"))
        #expect(formatted.contains("120"))
    }
}
