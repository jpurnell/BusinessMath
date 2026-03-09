import Testing
import Numerics
#if canImport(OSLog)
import OSLog
#endif
@testable import BusinessMath

@Suite("Profitability Ratios Tests")
struct ProfitabilityRatiosTests {
    @Test("Calculate ROE correctly")
    func testROE() throws {
        let netIncome: Double = 1000.0
        let shareholderEquity: Double = 5000.0
        let result = try roe(netIncome: netIncome, shareholderEquity: shareholderEquity)
        #expect(result == 0.20) // Expected: 20%
    }

    @Test("Calculate ROI correctly with investment")
    func testROIWithInvestment() throws {
        let gainFromInvestment: Double = 500.0
        let costOfInvestment: Double = 1000.0
        let result = try roi(gainFromInvestment: gainFromInvestment, costOfInvestment: costOfInvestment)
        #expect(result == 0.50) // Expected: 50%
    }

    @Test("Calculate profit margin correctly")
    func testProfitMargin() throws {
        let netIncome: Double = 300.0
        let revenue: Double = 1200.0
        let result = try profitMargin(netIncome: netIncome, revenue: revenue)
        #expect(result == 0.25) // Expected: 25%
    }

    @Test("ROE throws on zero equity")
    func testROEThrows() {
        #expect(throws: BusinessMathError.self) {
            _ = try roe(netIncome: 1000.0, shareholderEquity: 0.0)
        }
    }

    @Test("ROI throws on zero cost")
    func testROIThrows() {
        #expect(throws: BusinessMathError.self) {
            _ = try roi(gainFromInvestment: 500.0, costOfInvestment: 0.0)
        }
    }

    @Test("Profit margin throws on zero revenue")
    func testProfitMarginThrows() {
        #expect(throws: BusinessMathError.self) {
            _ = try profitMargin(netIncome: 300.0, revenue: 0.0)
        }
    }
}
