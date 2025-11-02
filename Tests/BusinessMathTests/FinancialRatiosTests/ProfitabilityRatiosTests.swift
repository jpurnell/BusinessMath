import Testing
import Numerics
import OSLog
@testable import BusinessMath

@Suite("Profitability Ratios Tests")
struct ProfitabilityRatiosTests {
	let logger = Logger(subsystem: "com.justinpurnell.businessMath > \(#file)", category: "\(#function)")
    @Test("Calculate ROE correctly")
    func testROE() {
        let netIncome: Double = 1000.0
        let shareholderEquity: Double = 5000.0
        let result = roe(netIncome: netIncome, shareholderEquity: shareholderEquity)
        #expect(result == 0.20) // Expected: 20%
    }

    @Test("Calculate ROI correctly with investment")
    func testROIWithInvestment() {
        let gainFromInvestment: Double = 500.0
        let costOfInvestment: Double = 1000.0
        let result = roi(gainFromInvestment: gainFromInvestment, costOfInvestment: costOfInvestment)
        #expect(result == 0.50) // Expected: 50%
    }

    @Test("Calculate profit margin correctly")
    func testProfitMargin() {
        let netIncome: Double = 300.0
        let revenue: Double = 1200.0
        let result = profitMargin(netIncome: netIncome, revenue: revenue)
        #expect(result == 0.25) // Expected: 25%
    }
}
