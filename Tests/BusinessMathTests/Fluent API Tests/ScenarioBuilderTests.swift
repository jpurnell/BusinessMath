//
//  ScenarioBuilderTests.swift
//  BusinessMath
//
//  Created on December 1, 2025.
//

import Testing
import Foundation
@testable import BusinessMath

/// Comprehensive tests for the ScenarioBuilder fluent API
///
/// Tests cover:
/// - Basic scenario creation (Baseline, Pessimistic, Optimistic, Custom)
/// - Parameter setting (revenue, growth, costs, margin, etc.)
/// - Adjustments (percentage-based modifications)
/// - ScenarioSet operations and queries
/// - Probability weighting and expected values
/// - Standard templates (three-way, five-way)
/// - Integration with scenario analysis
/// - Edge cases and validation
@Suite("ScenarioBuilder DSL Tests")
struct ScenarioBuilderTests {

    // MARK: - Basic Scenario Creation

    @Test("Baseline scenario creation")
    func baselineScenario() {
        let scenario = Baseline {
            revenue(1_000_000)
            growth(0.10)
        }

        #expect(scenario.name == "Baseline")
        #expect(scenario.parameters["revenue"] == 1_000_000)
        #expect(scenario.parameters["growth"] == 0.10)
    }

    @Test("Pessimistic scenario creation")
    func pessimisticScenario() {
        let scenario = Pessimistic {
            revenue(800_000)
            growth(0.05)
        }

        #expect(scenario.name == "Pessimistic")
        #expect(scenario.parameters["revenue"] == 800_000)
        #expect(scenario.parameters["growth"] == 0.05)
    }

    @Test("Optimistic scenario creation")
    func optimisticScenario() {
        let scenario = Optimistic {
            revenue(1_200_000)
            growth(0.15)
        }

        #expect(scenario.name == "Optimistic")
        #expect(scenario.parameters["revenue"] == 1_200_000)
        #expect(scenario.parameters["growth"] == 0.15)
    }

    @Test("Custom named scenario")
    func customNamedScenario() {
        let scenario = ScenarioNamed("Conservative Growth") {
            revenue(900_000)
            growth(0.07)
            costs(600_000)
        }

        #expect(scenario.name == "Conservative Growth")
        #expect(scenario.parameters["revenue"] == 900_000)
        #expect(scenario.parameters["growth"] == 0.07)
        #expect(scenario.parameters["costs"] == 600_000)
    }

    @Test("Empty scenario")
    func emptyScenario() {
        let scenario = Baseline {
            // Empty scenario
        }

        #expect(scenario.name == "Baseline")
        #expect(scenario.parameters.isEmpty)
        #expect(scenario.adjustments.isEmpty)
    }

    // MARK: - Parameter Setting

    @Test("All parameter types")
    func allParameterTypes() {
        let scenario = Baseline {
            revenue(1_000_000)
            growth(0.10)
            costs(700_000)
            margin(0.30)
            discountRate(0.08)
        }

        #expect(scenario.parameters["revenue"] == 1_000_000)
        #expect(scenario.parameters["growth"] == 0.10)
        #expect(scenario.parameters["costs"] == 700_000)
        #expect(scenario.parameters["margin"] == 0.30)
        #expect(scenario.parameters["discountRate"] == 0.08)
    }

    @Test("Custom parameter")
    func customParameter() {
        let scenario = Baseline {
            parameter("churnRate", value: 0.05)
            parameter("customerCount", value: 10_000)
            parameter("averageRevenue", value: 99.99)
        }

        #expect(scenario.parameters["churnRate"] == 0.05)
        #expect(scenario.parameters["customerCount"] == 10_000)
        #expect(scenario.parameters["averageRevenue"] == 99.99)
    }

    // MARK: - Adjustments

    @Test("Revenue adjustments")
    func revenueAdjustments() {
        let scenario = Pessimistic {
            adjustRevenue(by: -0.20)
        }

        #expect(scenario.adjustments["revenue"] == -0.20)
    }

    @Test("Cost adjustments")
    func costAdjustments() {
        let scenario = Pessimistic {
            adjustCosts(by: 0.15)
        }

        #expect(scenario.adjustments["costs"] == 0.15)
    }

    @Test("Multiple adjustments")
    func multipleAdjustments() {
        let scenario = Pessimistic {
            adjustRevenue(by: -0.20)
            adjustCosts(by: 0.10)
            adjustGrowth(by: -0.30)
        }

        #expect(scenario.adjustments["revenue"] == -0.20)
        #expect(scenario.adjustments["costs"] == 0.10)
        #expect(scenario.adjustments["growth"] == -0.30)
    }

    @Test("Custom parameter adjustments")
    func customParameterAdjustments() {
        let scenario = Optimistic {
            adjust("customerAcquisition", by: 0.25)
            adjust("conversionRate", by: 0.10)
        }

        #expect(scenario.adjustments["customerAcquisition"] == 0.25)
        #expect(scenario.adjustments["conversionRate"] == 0.10)
    }

    @Test("Mixed parameters and adjustments")
    func mixedParametersAndAdjustments() {
        let scenario = Baseline {
            revenue(1_000_000)
            adjustCosts(by: -0.05)
            growth(0.10)
            adjustRevenue(by: 0.15)
        }

        #expect(scenario.parameters["revenue"] == 1_000_000)
        #expect(scenario.parameters["growth"] == 0.10)
        #expect(scenario.adjustments["costs"] == -0.05)
        #expect(scenario.adjustments["revenue"] == 0.15)
    }

    // MARK: - ScenarioSet Builder

    @Test("ScenarioSet with multiple scenarios")
    func scenarioSetBuilder() {
        let scenarios = ScenarioSet {
            Baseline {
                revenue(1_000_000)
                growth(0.10)
            }

            Pessimistic {
                revenue(800_000)
                growth(0.05)
            }

            Optimistic {
                revenue(1_200_000)
                growth(0.15)
            }
        }

        #expect(scenarios.scenarios.count == 3)
        #expect(scenarios.scenarios[0].name == "Baseline")
        #expect(scenarios.scenarios[1].name == "Pessimistic")
        #expect(scenarios.scenarios[2].name == "Optimistic")
    }

    @Test("ScenarioSet scenario lookup")
    func scenarioSetLookup() {
        let scenarios = ScenarioSet {
            Baseline {
                revenue(1_000_000)
            }

            Pessimistic {
                revenue(800_000)
            }
        }

        let baseline = scenarios.scenario(named: "Baseline")
        #expect(baseline != nil)
        #expect(baseline?.parameters["revenue"] == 1_000_000)

        let pessimistic = scenarios.scenario(named: "Pessimistic")
        #expect(pessimistic != nil)
        #expect(pessimistic?.parameters["revenue"] == 800_000)

        let missing = scenarios.scenario(named: "NonExistent")
        #expect(missing == nil)
    }

    @Test("Empty ScenarioSet")
    func emptyScenarioSet() {
        let scenarios = ScenarioSet()

        #expect(scenarios.scenarios.isEmpty)
        #expect(scenarios.scenario(named: "Any") == nil)
    }

    // MARK: - Scenario Application

    @Test("Apply scenario with direct value")
    func applyScenarioDirectValue() {
        let scenarios = ScenarioSet {
            Baseline {
                revenue(1_000_000)
            }
        }

        let result = scenarios.apply("Baseline", to: 500_000, for: "revenue")
        #expect(result == 1_000_000) // Uses override value
    }

    @Test("Apply scenario with adjustment")
    func applyScenarioAdjustment() {
        let scenarios = ScenarioSet {
            Pessimistic {
                adjustRevenue(by: -0.20)
            }
        }

        let result = scenarios.apply("Pessimistic", to: 1_000_000, for: "revenue")
        #expect(result == 800_000) // 1M * (1 - 0.20)
    }

    @Test("Apply scenario with no matching parameter")
    func applyScenarioNoMatch() {
        let scenarios = ScenarioSet {
            Baseline {
                revenue(1_000_000)
            }
        }

        let result = scenarios.apply("Baseline", to: 500_000, for: "costs")
        #expect(result == 500_000) // Returns base value unchanged
    }

    @Test("Apply non-existent scenario")
    func applyNonExistentScenario() {
        let scenarios = ScenarioSet {
            Baseline {
                revenue(1_000_000)
            }
        }

        let result = scenarios.apply("NonExistent", to: 500_000, for: "revenue")
        #expect(result == 500_000) // Returns base value unchanged
    }

    // MARK: - Probability and Description

    @Test("Scenario with probability")
    func scenarioWithProbability() {
        let scenario = Baseline {
            revenue(1_000_000)
        }
        .withProbability(0.50)

        #expect(scenario.probability == 0.50)
    }

    @Test("Scenario with description")
    func scenarioWithDescription() {
        let scenario = Baseline {
            revenue(1_000_000)
        }
        .withDescription("Base case assumptions with moderate growth")

        #expect(scenario.description == "Base case assumptions with moderate growth")
    }

    @Test("Scenario with probability and description")
    func scenarioWithProbabilityAndDescription() {
        let scenario = Pessimistic {
            revenue(800_000)
            growth(0.05)
        }
        .withProbability(0.25)
        .withDescription("Economic downturn scenario")

        #expect(scenario.probability == 0.25)
        #expect(scenario.description == "Economic downturn scenario")
    }

    // MARK: - Expected Value and Statistics

    @Test("Expected value calculation")
    func expectedValueCalculation() {
        let scenarios = ScenarioSet {
            Pessimistic {
                revenue(800_000)
            }
            .withProbability(0.25)

            Baseline {
                revenue(1_000_000)
            }
            .withProbability(0.50)

            Optimistic {
                revenue(1_200_000)
            }
            .withProbability(0.25)
        }

        let expectedRevenue = scenarios.expectedValue { scenario in
            scenario.parameters["revenue"] ?? 0
        }

        #expect(expectedRevenue != nil)
        // (0.25 * 800k) + (0.50 * 1M) + (0.25 * 1.2M) = 200k + 500k + 300k = 1M
        #expect(abs(expectedRevenue! - 1_000_000) < 1.0)
    }

    @Test("Expected value with missing probabilities")
    func expectedValueMissingProbabilities() {
        let scenarios = ScenarioSet {
            Baseline {
                revenue(1_000_000)
            }
            // Missing probability

            Pessimistic {
                revenue(800_000)
            }
            .withProbability(0.50)
        }

        let expectedRevenue = scenarios.expectedValue { $0.parameters["revenue"] ?? 0 }
        #expect(expectedRevenue == nil) // Should return nil if any probability is missing
    }

    @Test("Variance calculation")
    func varianceCalculation() {
        let scenarios = ScenarioSet {
            Pessimistic {
                revenue(800_000)
            }
            .withProbability(0.25)

            Baseline {
                revenue(1_000_000)
            }
            .withProbability(0.50)

            Optimistic {
                revenue(1_200_000)
            }
            .withProbability(0.25)
        }

        let variance = scenarios.variance { $0.parameters["revenue"] ?? 0 }
        #expect(variance != nil)
        #expect(variance! > 0) // Should have positive variance
    }

    @Test("Standard deviation calculation")
    func standardDeviationCalculation() {
        let scenarios = ScenarioSet {
            Pessimistic {
                revenue(800_000)
            }
            .withProbability(0.25)

            Baseline {
                revenue(1_000_000)
            }
            .withProbability(0.50)

            Optimistic {
                revenue(1_200_000)
            }
            .withProbability(0.25)
        }

        let stdDev = scenarios.standardDeviation { $0.parameters["revenue"] ?? 0 }
        #expect(stdDev != nil)
        #expect(stdDev! > 0)

        // Verify it's the square root of variance
        let variance = scenarios.variance { $0.parameters["revenue"] ?? 0 }
        if let v = variance, let sd = stdDev {
            #expect(abs(sd * sd - v) < 0.01)
        }
    }

    @Test("Range calculation")
    func rangeCalculation() {
        let scenarios = ScenarioSet {
            Pessimistic {
                revenue(800_000)
            }

            Baseline {
                revenue(1_000_000)
            }

            Optimistic {
                revenue(1_200_000)
            }
        }

        let range = scenarios.range { $0.parameters["revenue"] ?? 0 }
        #expect(range != nil)
        #expect(range?.min == 800_000)
        #expect(range?.max == 1_200_000)
    }

    @Test("Range with single scenario")
    func rangeSingleScenario() {
        let scenarios = ScenarioSet {
            Baseline {
                revenue(1_000_000)
            }
        }

        let range = scenarios.range { $0.parameters["revenue"] ?? 0 }
        #expect(range != nil)
        #expect(range?.min == 1_000_000)
        #expect(range?.max == 1_000_000)
    }

    // MARK: - Standard Templates

    @Test("Standard three-way template")
    func standardThreeWayTemplate() {
        let scenarios = ScenarioSet.standardThreeWay(
            baseRevenue: 1_000_000,
            baseGrowth: 0.10
        )

        #expect(scenarios.scenarios.count == 3)

        // Check scenario names
        #expect(scenarios.scenario(named: "Pessimistic") != nil)
        #expect(scenarios.scenario(named: "Baseline") != nil)
        #expect(scenarios.scenario(named: "Optimistic") != nil)

        // Check probabilities sum to 1.0
        let totalProb = scenarios.scenarios.compactMap(\.probability).reduce(0, +)
        #expect(abs(totalProb - 1.0) < 0.001)

        // Check baseline values
        let baseline = scenarios.scenario(named: "Baseline")!
        #expect(baseline.parameters["revenue"] == 1_000_000)
        #expect(baseline.parameters["growth"] == 0.10)
        #expect(baseline.probability == 0.50)
    }

    @Test("Standard three-way with custom variability")
    func standardThreeWayCustomVariability() {
        let scenarios = ScenarioSet.standardThreeWay(
            baseRevenue: 1_000_000,
            baseGrowth: 0.10,
            variability: 0.30
        )

        let pessimistic = scenarios.scenario(named: "Pessimistic")!
        let optimistic = scenarios.scenario(named: "Optimistic")!

        // Pessimistic: 1M * (1 - 0.30) = 700k
        #expect(pessimistic.parameters["revenue"] == 700_000)

        // Optimistic: 1M * (1 + 0.30) = 1.3M
        #expect(optimistic.parameters["revenue"] == 1_300_000)
    }

    @Test("Standard five-way template")
    func standardFiveWayTemplate() {
        let scenarios = ScenarioSet.standardFiveWay(
            baseRevenue: 1_000_000,
            baseGrowth: 0.10
        )

        #expect(scenarios.scenarios.count == 5)

        // Check scenario names
        #expect(scenarios.scenario(named: "Worst Case") != nil)
        #expect(scenarios.scenario(named: "Pessimistic") != nil)
        #expect(scenarios.scenario(named: "Baseline") != nil)
        #expect(scenarios.scenario(named: "Optimistic") != nil)
        #expect(scenarios.scenario(named: "Best Case") != nil)

        // Check probabilities sum to 1.0
        let totalProb = scenarios.scenarios.compactMap(\.probability).reduce(0, +)
        #expect(abs(totalProb - 1.0) < 0.001)

        // Check baseline is most probable
        let baseline = scenarios.scenario(named: "Baseline")!
        #expect(baseline.probability == 0.40)
    }

    @Test("Standard five-way with custom variability")
    func standardFiveWayCustomVariability() {
        let scenarios = ScenarioSet.standardFiveWay(
            baseRevenue: 1_000_000,
            baseGrowth: 0.10,
            moderateVariability: 0.20,
            extremeVariability: 0.40
        )

        let worstCase = scenarios.scenario(named: "Worst Case")!
        let bestCase = scenarios.scenario(named: "Best Case")!

        // Worst: 1M * (1 - 0.40) = 600k
        #expect(worstCase.parameters["revenue"] == 600_000)

        // Best: 1M * (1 + 0.40) = 1.4M
        #expect(bestCase.parameters["revenue"] == 1_400_000)
    }

    // MARK: - Edge Cases

    @Test("Extreme positive adjustments")
    func extremePositiveAdjustments() {
        let scenario = Optimistic {
            adjustRevenue(by: 2.0) // 200% increase
            adjustGrowth(by: 1.5)  // 150% increase
        }

        #expect(scenario.adjustments["revenue"] == 2.0)
        #expect(scenario.adjustments["growth"] == 1.5)
    }

    @Test("Extreme negative adjustments")
    func extremeNegativeAdjustments() {
        let scenario = Pessimistic {
            adjustRevenue(by: -0.90) // 90% decrease
            adjustCosts(by: -0.50)    // 50% decrease
        }

        #expect(scenario.adjustments["revenue"] == -0.90)
        #expect(scenario.adjustments["costs"] == -0.50)
    }

    @Test("Zero values")
    func zeroValues() {
        let scenario = Baseline {
            revenue(0)
            growth(0)
            costs(0)
        }

        #expect(scenario.parameters["revenue"] == 0)
        #expect(scenario.parameters["growth"] == 0)
        #expect(scenario.parameters["costs"] == 0)
    }

    @Test("Negative parameter values")
    func negativeParameterValues() {
        let scenario = Baseline {
            revenue(-100_000) // Loss scenario
            growth(-0.05)      // Negative growth
        }

        #expect(scenario.parameters["revenue"] == -100_000)
        #expect(scenario.parameters["growth"] == -0.05)
    }

    @Test("Very large numbers")
    func veryLargeNumbers() {
        let scenario = Baseline {
            revenue(1_000_000_000) // 1 trillion
            costs(999_999_999_999)
        }

        #expect(scenario.parameters["revenue"] == 1_000_000_000)
        #expect(scenario.parameters["costs"] == 999_999_999_999)
    }

    @Test("Very small fractional values")
    func verySmallFractionalValues() {
        let scenario = Baseline {
            growth(0.0001)  // 0.01%
            margin(0.0005)  // 0.05%
        }

        #expect(scenario.parameters["growth"] == 0.0001)
        #expect(scenario.parameters["margin"] == 0.0005)
    }

    @Test("Probability sum validation in expected value")
    func probabilitySumValidation() {
        let scenarios = ScenarioSet {
            Baseline {
                revenue(1_000_000)
            }
            .withProbability(0.40)

            Pessimistic {
                revenue(800_000)
            }
            .withProbability(0.30)

            Optimistic {
                revenue(1_200_000)
            }
            .withProbability(0.20)
            // Total = 0.90, not 1.0
        }

        let expected = scenarios.expectedValue { $0.parameters["revenue"] ?? 0 }
        #expect(expected == nil) // Should fail validation
    }

    @Test("Duplicate parameter overwriting")
    func duplicateParameterOverwriting() {
        let scenario = Baseline {
            revenue(1_000_000)
            revenue(1_500_000) // Should overwrite
        }

        // Last value should win
        #expect(scenario.parameters["revenue"] == 1_500_000)
    }
}
