import XCTest
import Numerics
@testable import BusinessMath

final class BusinessMathTests: XCTestCase {
    
    func testCombinationAndPermutation() {
        func testFactorial() {
            let result = factorial(4)
            let resultZero = factorial(0)
            let resultOne = factorial(1)
            let resultExtension = 5.factorial()
            XCTAssertEqual(result, 24)
            XCTAssertEqual(resultZero, 1)
            XCTAssertEqual(resultOne, 1)
            XCTAssertEqual(resultExtension, 120)
        }
        
        func testCombination() {
            let result = combination(10, c: 3)
            XCTAssertEqual(result, 120)
        }
        
        func testPermutation() {
            let result = permutation(5, p: 3)
            XCTAssertEqual(result, 60)
        }
        
        testFactorial()
        testCombination()
        testPermutation()
    }
    
    func testSimulation() {
        
        func testTriangularZero() {
            let _ = triangularDistribution(low: 0, high: 1, base: 0.5)
            let resultZero = triangularDistribution(low: 0, high: 0, base: 0)
            let resultOne = triangularDistribution(low: 1, high: 1, base: 1)
            XCTAssertEqual(resultZero, 0)
            XCTAssertEqual(resultOne, 1)
        }
        
        func testUniformDistribution() {
            let resultZero = distributionUniform(min: 0, max: 0)
            XCTAssertEqual(resultZero, 0)
            let resultOne = distributionUniform(min: 1, max: 1)
            XCTAssertEqual(resultOne, 1)
            let min = 2.0
            let max = 40.0
            let result = distributionUniform(min: min, max: max)
            XCTAssertLessThanOrEqual(result, max, "Value must be below \(max)")
            XCTAssertGreaterThanOrEqual(result, min)
        }
        
        func testDistributionNormal() {
            var array: [Double] = []
            for _ in 0..<1000 {
                array.append(distributionNormal())
            }
            let mu = (mean(array) * 10).rounded() / 10
            let sd = (stdDev(array) * 10).rounded() / 10
            XCTAssertEqual(mu, 0)
            XCTAssertEqual(sd, 1)
        }
        
        testTriangularZero()
        testUniformDistribution()
        testDistributionNormal()
    }
    
    func testStatistics() {
        
        func testDescriptives() {
            
            func testCentralTendency() {
                func testMean() {
                    let doubleArray: [Double] = [0.0, 1.0, 2.0, 3.0, 4.0]
                    let result = mean(doubleArray)
                    XCTAssertEqual(result, 2.0)
                }
                
                func testMedian() {
                    let result = median([0.0, 1.0, 2.0, 3.0, 4.0, 5.0])
                    let resultOdd = median([0.0, 1.0, 2.0, 3.0, 4.0])
                    let resultOne = median([1.0, 1, 1, 1, 1, 1, 2])
                    print(result)
                    print(resultOne)
                    XCTAssertEqual(result, 2.5)
                    XCTAssertEqual(resultOdd, 2.0)
                    XCTAssertEqual(resultOne, 1)
                }

                func testMode() {
                    let doubleArray: [Float] = [0.0, 2.0, 2.0, 3.0, 2.0]
                    let result = mode(doubleArray)
                    XCTAssertEqual(result, 2)
                }
                
                testMean()
                testMedian()
                testMode()
            }
            
            func testCovarianceAndCorrelation() {
                func testCovarianceS() {
                    // Test from https://www.educba.com/covariance-formula/
                    let xVar = [1.8, 1.5, 2.1, 2.4, 0.2]
                    let yVar = [2.5, 4.3, 4.5, 4.1, 2.2]
                    let result = ((covarianceS(xVar, yVar) * 1000).rounded()) / 1000
                    XCTAssertEqual(result, 0.63)
                }
                
                func testCovarianceP() {
                    // Test from https://www.educba.com/covariance-formula/
                    let xVar = [2, 2.8, 4, 3.2]
                    let yVar = [8.0, 11, 12, 8]
                    let result = ((covarianceP(xVar, yVar) * 100).rounded()) / 100
                    XCTAssertEqual(result, 0.85)
                }
                
                func testCovariance() {
                    // Test from https://www.educba.com/covariance-formula/
                    let xVar = [1.8, 1.5, 2.1, 2.4, 0.2]
                    let yVar = [2.5, 4.3, 4.5, 4.1, 2.2]
                    let result = ((covariance(xVar, yVar) * 100).rounded()) / 100
                    let resultS = ((covarianceS(xVar, yVar) * 100).rounded()) / 100
                    let resultP = ((covarianceP(xVar, yVar) * 100).rounded()) / 100
                    XCTAssertNotEqual(result, resultP)
                    XCTAssertEqual(result, resultS)
                }
                
                func testCorrelationCoefficient() {
                    let x = [20.0, 23, 45, 78, 21]
                    let y = [200.0, 300, 500, 700, 100]
                    let result = correlationCoefficient(x, y, .sample)
                    let s = (result * 10000).rounded() / 10000
                    XCTAssertEqual(s, 0.9487)
                    let resultP = correlationCoefficient(x, y, .population)
                    let sP = (resultP * 10000).rounded() / 10000
                    XCTAssertEqual(sP, 0.9487)
                }
                
                testCovarianceS()
                testCovarianceP()
                testCovariance()
                testCorrelationCoefficient()
            }
            
            func testDispersionAroundTheMean() {
                func testSumOfSquaredAvgDiff() {
                    let doubleArray: [Double] = [0.0, 1.0, 2.0, 3.0, 4.0]
                    let result = sumOfSquaredAvgDiff(doubleArray)
                    XCTAssertEqual(result, 10)
                }
                
                func testVarianceP() {
                    let doubleArray: [Double] = [0.0, 1.0, 2.0, 3.0, 4.0]
                    let result = varianceP(doubleArray)
                    XCTAssertEqual(result, 2)
                }
                
                func testVarianceS() {
                    let doubleArray: [Double] = [0.0, 1.0, 2.0, 3.0, 4.0]
                    let result = varianceS(doubleArray)
                    XCTAssertEqual(result, 2.5)
                }
                
                func testStdDevP() {
                    let result = stdDevP([0, 1, 2, 3, 4])
                    XCTAssertEqual(result, Double.sqrt(2))
                }
                
                func testStdDevS() {
                    let result = (stdDevS([96, 13, 84, 59, 92, 24, 68, 80, 89, 88, 37, 27, 44, 66, 14, 15, 87, 34, 36, 48, 64, 26, 79, 53]) * 10000.0).rounded(.up) / 10000
                    XCTAssertEqual(result, 27.7243)
                }
                
                func testStdDev() {
                    let result = stdDev([0, 1, 2, 3, 4])
                    XCTAssertEqual(result, Double.sqrt(2.5))
                }
                
                func testCoefficientOfVariation() {
                    let array: [Double] = [0, 1, 2, 3, 4]
                    let stdDev = stdDev(array)
                    let mean = mean(array)
                    let result = coefficientOfVariation(stdDev, mean: mean)
                    XCTAssertEqual(result, (Double.sqrt(2.5) / 2) * 100)
                }
                
                func testTStatistic() {
                    let result = tStatistic(x: 1)
                    XCTAssertEqual(result, 1)
                }

                testSumOfSquaredAvgDiff()
                testVarianceP()
                testVarianceS()
                testStdDev()
                testStdDevP()
                testStdDevS()
                testCoefficientOfVariation()
                testTStatistic()
            }
            
            func testSkewness() {
                func testSkewS() {
                    let values: [Double] = [96, 13, 84, 59, 92, 24, 68, 80, 89, 88, 37, 27, 44, 66, 14, 15, 87, 34, 36, 48, 64, 26, 79, 53]
                    let result = (skewS(values) * 100000000.0).rounded(.up) / 100000000
                    XCTAssertEqual(result, -0.06157035)
                }
                
                func testCoefficientOfSkew() {
                    let result = coefficientOfSkew(mean: 1, median: 0, stdDev: 3)
                    XCTAssertEqual(result, 1)
                }
                
                testSkewS()
                testCoefficientOfSkew()

            }
            
            testCentralTendency()
            testCovarianceAndCorrelation()
            testDispersionAroundTheMean()
            testSkewness()
        }
        
        testDescriptives()
    }

//    func testVarianceTDist() {
//        let doubleArray: [Double] = [0.0, 1.0, 2.0, 3.0, 4.0]
//        let result = varianceTDist(doubleArray)
//        XCTAssertEqual(result, 2)
//    }
//
//    func testStdDevTDist() {
//        let result = stdDevTDist([0, 1, 2, 3, 4])
//        XCTAssertEqual(result, Double.sqrt(2))
//    }
    
    
    func testMeanDiscrete() {
        let prob: Double = 1/6
        let distribution = [(1.0, prob), (2, prob), (3, prob), (4, prob), (5, prob), (6, prob)]
        let result = meanDiscrete(distribution)
        XCTAssertEqual(result, 3.5)
    }
    
    func testVarDiscrete() {
        let prob: Double = 1/6
        let distribution = [(1.0, prob), (2, prob), (3, prob), (4, prob), (5, prob), (6, prob)]
        let result = varianceDiscrete(distribution)
        XCTAssertEqual(result, (35 / 12))
    }
    
    func testSpearmansRho() {
        let result = spearmansRho([1, 2, 2, 2, 5], vs: [1, 2, 3, 4, 5])
        XCTAssertEqual(result, 0.8944271909999159)
    }
    
    func testZStatistic() {
        let array: [Double] = [0, 1, 2, 3, 4]
        let mean = mean(array)
        let stdDev = stdDev(array)
        let result = (zStatistic(x: 1, mean: mean, stdDev: stdDev) * 1000000).rounded() / 1000000
        XCTAssertEqual(result, -0.632456)
    }
    
    func testStandardize() {
        let result = (standardize(x: 11.96, mean: 10, stdev: 1) * 1000).rounded() / 1000
        XCTAssertEqual(result, 1.96)
    }
    
    func testNormSDist() {
        let result = (normSDist(zScore: 1.95996398454) * 1000).rounded(.up) / 1000
        let resultNeg = (normSDist(zScore: -1.95996398454) * 1000).rounded() / 1000
        let resultZero = (normSDist(zScore: 0.0) * 1000).rounded() / 1000
        XCTAssertEqual(result, 0.975)
        XCTAssertEqual(resultNeg, 0.025)
        XCTAssertEqual(resultZero, 0.5)
    }
    
    func testNormDist() {
        let result = normDist(x: 0, mean: 0, stdev: 1)
        let resultNotes = (normDist(x: 10, mean: 10.1, stdev: 0.04) * 1000000).rounded(.up) / 1000000
        XCTAssertEqual(result, 0.5)
        XCTAssertEqual(resultNotes, 0.00621)
    }
    
    func testNormInv() {
        let resultZero = normInv(probability: 0.5, mean: 0, stdev: 1)
        XCTAssertEqual(resultZero, 0)
        let result = (normInv(probability: 0.975, mean: 10, stdev: 1) * 1000).rounded(.up) / 1000
        XCTAssertEqual(result, 11.96)
    }
    
    func testNormSInv() {
        let result = (normSInv(probability: 0.975) * 1000000).rounded(.up) / 1000000
        XCTAssertEqual(result, 1.959964)
    }
    
    func testPercentile() {
        let result = (percentile(zScore: 1.95996398454) * 1000).rounded() / 1000
        XCTAssertEqual(result, 0.975)
    }
    
    func testErfInv() {
        let result = (erfInv(y: 0.95) * 1000000000000000).rounded() / 1000000000000000
        XCTAssertEqual(result, 1.385903824349678)
    }
    
    func testZScore() {
        let result = (zScore(percentile: 0.975) * 1000000).rounded(.up) / 1000000
        XCTAssertEqual(result, 1.959964)
    }

    func testZScoreCI() {
        let result = (zScore(ci: 0.95) * 1000000).rounded(.up) / 1000000
        XCTAssertEqual(result, 1.959964)
    }
    
    func testPercentileFormal() {
        let result = percentile(x: 1.959963984540054, mean: 0, stdDev: 1)
//        print(percentile(x: 16.357, mean: 16, stdDev: (0.866 / sqrt(50))))
//        print(percentile(x: 31366, mean: 31000, stdDev: (1894/sqrt(100))))
        XCTAssertEqual(result, 0.975)
    }
    
    func testInverseNormalCDF() {
        let result = inverseNormalCDF(p: 0.5, mean: 0, stdDev: 1)
        XCTAssertEqual(result, 0)
    }
    
    func testUniformCDF() {
        let resultNeg = uniformCDF(x: -1)
        let resultSub1 = uniformCDF(x: 0.5)
        let resultPos = uniformCDF(x: 5)
        
        XCTAssertEqual(resultNeg, 0)
        XCTAssertEqual(resultSub1, 0.5)
        XCTAssertEqual(resultPos, 1)
    }
    
    func testBernoulliTrial() {
        let result = bernoulliTrial(p: 0.5)
        var goodResult: Bool = false
        if result == 0 || result == 1 {
            goodResult = true
        }
        XCTAssertEqual(goodResult, true)
    }

    func testConfidenceInterval() {
        let result = confidenceInterval(mean: 0, stdDev: 1, z: 1, popSize: 10_000_000)
        XCTAssertEqual(result.low, -0.00031622776601683794)
        XCTAssertEqual(result.high, 0.00031622776601683794)
    }
    
    func testConfidence() {
        let result = (confidence(alpha: 0.05, stdev: 2.5, sampleSize: 50).high * 1000000.0).rounded(.up) / 1000000.0
        XCTAssertEqual(result, 0.692952)
    }
    
    func testConfidenceIntervalCI() {
        let result = confidenceInterval(ci: 0, values: [0])
        print(result)
    }
    
    func testNormalPDF() {
        let result = (normalPDF(x: 1.96, mean: 0, stdDev: 1) * 100).rounded(.down) / 100
        let resultOne = (normalPDF(x: 1.64, mean: 0, stdDev: 1) * 100).rounded() / 100
        XCTAssertEqual(result, 0.05)
        XCTAssertEqual(resultOne, 0.10)
    }
    
    func testNormalCDF() {
        let result = (normalCDF(x: 1.96, mean: 0, stdDev: 1) * 1000.0).rounded(.down) / 1000
        XCTAssertEqual(result, 0.975)
    }
    
    func testBinomial() {}
    func testChi2cdf() {}
    func testConfidenceIntervalProbabilistic() {
        let result = confidenceIntervalProbabilistic(0.05, observations: 50, ci: 0.95)
        print(result)
    }
    func testCorrectedStandardError() {}
    func testCorrelationBreakpoint() {}
    func testDerivativeOf() {}
    func testErfInverse() {}
    func testEstMean() {}
    func testFisherR(){}
    func testHyperGeometric() {}
    func testInterestingObservation() {}
    func testPoissonDistribution() {}
    func testProbabilityDistributionFunction() {}
    func testPValue() {}
    func testPValueStudent() {}
    func testRequiredSampleSize() {}
    func testRho() {}
    func testSampleCorrelationCoefficient() {}
    func testStandardError() {}
    func testStandardErrorProbabilistic() {}
    func testTStatisticRho() {}
    func testVarianceDiscrete() {}
    func testMeanBinomial() {}
    func testStdDevBinomial() {}
    func testVarianceBinomial() {}
    func testPercentileLocation() {
        
    }
    func testPercentileMeanStdDev() {}
    func testZScoreRho() {}
    func testZScorePercentile() {}
    func testZScoreFisherR() {}
}
