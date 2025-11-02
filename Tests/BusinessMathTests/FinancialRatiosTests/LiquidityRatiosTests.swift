import Testing
import Numerics
import OSLog

@testable import BusinessMath

@Suite("Liquidity Ratios Tests")
struct LiquidityRatiosTests {
	let logger = Logger(subsystem: "com.justinpurnell.businessMath  > LiquidityRatiosTests", category: #function)
    @Test("Calculate current ratio correctly")
    func testCurrentRatio() {
        let currentAssets: Double = 15000.0
        let currentLiabilities: Double = 10000.0
        let result = currentRatio(currentAssets: currentAssets, currentLiabilities: currentLiabilities)
        #expect(result == 1.5) // Expected: 1.5
    }

    @Test("Calculate quick ratio correctly")
    func testQuickRatio() {
        let currentAssets: Double = 20000.0
        let inventory: Double = 5000.0
        let currentLiabilities: Double = 15000.0
        let result = quickRatio(currentAssets: currentAssets, inventory: inventory, currentLiabilities: currentLiabilities)
        #expect(result == 1.0) // Expected: 1.0
    }
}
