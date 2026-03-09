import Testing
import Numerics
#if canImport(OSLog)
import OSLog
#endif

@testable import BusinessMath

@Suite("Liquidity Ratios Tests")
struct LiquidityRatiosTests {
    @Test("Calculate current ratio correctly")
    func testCurrentRatio() throws {
        let currentAssets: Double = 15000.0
        let currentLiabilities: Double = 10000.0
        let result = try currentRatio(currentAssets: currentAssets, currentLiabilities: currentLiabilities)
        #expect(result == 1.5) // Expected: 1.5
    }

    @Test("Calculate quick ratio correctly")
    func testQuickRatio() throws {
        let currentAssets: Double = 20000.0
        let inventory: Double = 5000.0
        let currentLiabilities: Double = 15000.0
        let result = try quickRatio(currentAssets: currentAssets, inventory: inventory, currentLiabilities: currentLiabilities)
        #expect(result == 1.0) // Expected: 1.0
    }

    @Test("Current ratio throws on zero liabilities")
    func testCurrentRatioThrows() {
        #expect(throws: BusinessMathError.self) {
            _ = try currentRatio(currentAssets: 15000.0, currentLiabilities: 0.0)
        }
    }

    @Test("Quick ratio throws on zero liabilities")
    func testQuickRatioThrows() {
        #expect(throws: BusinessMathError.self) {
            _ = try quickRatio(currentAssets: 20000.0, inventory: 5000.0, currentLiabilities: 0.0)
        }
    }
}
