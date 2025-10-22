import Testing
import Numerics
import OSLog
@testable import BusinessMath

@Suite("Solvency Ratios Tests")
struct SolvencyRatiosTests {
	let logger = Logger(subsystem: "com.justinpurnell.businessMath", category: "\(#function)")
    @Test("Calculate debt to equity ratio correctly")
    func testDebtToEquityRatio() {
//		logger.warning("Not yet implemented:\t\(#function) in:\n\(#file):\(#line)")
        let totalLiabilities: Double = 40000.0
        let shareholderEquity: Double = 100000.0
        let result = debtToEquity(totalLiabilities: totalLiabilities, shareholderEquity: shareholderEquity)
        #expect(result == 0.4) // Expected: 0.4
    }

    @Test("Calculate interest coverage ratio correctly")
    func testInterestCoverageRatio() {
//		logger.warning("Not yet implemented:\t\(#function) in:\n\(#file):\(#line)")
        let earningsBeforeInterestAndTax: Double = 6000.0
        let interestExpense: Double = 2000.0
        let result = interestCoverage(earningsBeforeInterestAndTax: earningsBeforeInterestAndTax, interestExpense: interestExpense)
        #expect(result == 3.0) // Expected: 3.0
    }
}
