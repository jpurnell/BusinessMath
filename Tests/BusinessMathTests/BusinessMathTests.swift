import XCTest
@testable import BusinessMath

final class BusinessMathTests: XCTestCase {
    func testMean() {
        let doubleArray: [Float] = [0.0, 1.0, 2.0, 3.0, 4.0]
        let result = mean(doubleArray)
        XCTAssertEqual(result, 2.0)
    }

    func testMode() {
        let doubleArray: [Float] = [0.0, 2.0, 2.0, 3.0, 2.0]
        let result = mode(doubleArray)
        XCTAssertEqual(result, 2)
    }
    
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
        XCTAssertEqual(result, 2)
    }
    
    func testVarianceTDist() {
        let doubleArray: [Double] = [0.0, 1.0, 2.0, 3.0, 4.0]
        let result = varianceTDist(doubleArray)
        XCTAssertEqual(result, 2)
    }
    
    func testTStatistic() {
        let result = tStatistic(x: 1)
        XCTAssertEqual(result, 1)
    }
    
    func testStdDevP() {
        let result = stdDevP([0, 1, 2, 3, 4])
        XCTAssertEqual(result, Double.sqrt(2))
    }
    
    func testStdDevS() {
        let result = stdDevS([0, 1, 2, 3, 4])
        XCTAssertEqual(result, Double.sqrt(2))
    }
    
    func testStdDev() {
        let result = stdDev([0, 1, 2, 3, 4])
        XCTAssertEqual(result, Double.sqrt(2))
    }
    
    func testStdDevTDist() {
        let result = stdDevTDist([0, 1, 2, 3, 4])
        XCTAssertEqual(result, Double.sqrt(2))
    }
    
    func testCoefficientOfSkew() {
        let result = coefficientOfSkew(mean: 1, median: 0, stdDev: 3)
        XCTAssertEqual(result, 1)
    }
    
    func testCoefficientOfVariation() {
        let array:[Double] = [0, 1, 2, 3, 4]
        let stdDev = stdDev(array)
        let mean = mean(array)
        let result = coefficientOfVariation(stdDev, mean: mean)
        XCTAssertEqual(result, (Double.sqrt(2) / 2) * 100)
    }
    
    func testMeanDiscrete() {
        let prob: Double = 1/6
        let distribution = [(1.0, prob), (2, prob), (3, prob), (4, prob), (5, prob), (6, prob)]
        let result = meanDiscrete(distribution)
        XCTAssertEqual(result, 3.5)
    }
    
    func testVarDiscrete() {
        print("testing Variance Discrete")
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
        print(zStatistic(x: 16.357, mean: 16, stdDev: (0.866 / sqrt(50))))
        print(zStatistic(x: 201.3, mean: 212, stdDev: (45.5 / sqrt(150))))
        XCTAssertEqual(result, (-1000000 * Double.sqrt(2) / 2).rounded() / 1000000)
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
        let result = zScore(percentile: 0.975) * 1000000000000000.rounded() / 1000000000000000
        XCTAssertEqual(result, 1.959963984540054)
        
    }
    
    func testZScoreCI() {
        let result = zScore(ci: 0.95) * 1000000000000000.rounded() / 1000000000000000
        XCTAssertEqual(result, 1.959963984540054)
    }
    
    func testPercentileFormal() {
        let result = percentile(x: 1.959963984540054, mean: 0, stdDev: 1)
        print(percentile(x: 16.357, mean: 16, stdDev: (0.866 / sqrt(50))))
        print(percentile(x: 31366, mean: 31000, stdDev: (1894/sqrt(100))))
        XCTAssertEqual(result, 0.975)
    }
    
    func testTriangularZero() {
        let result = triangularDistribution(low: 0, high: 1, base: 0.5)
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
}
