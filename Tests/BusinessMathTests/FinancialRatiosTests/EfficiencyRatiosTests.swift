import Testing
import Numerics
@testable import BusinessMath

@Suite("Efficiency Ratios Tests")
struct EfficiencyRatiosTests {

    @Test("Calculate inventory turnover ratio correctly")
    func testInventoryTurnover() {
        let costOfGoodsSold: Double = 24000.0
        let averageInventory: Double = 8000.0
        let result = inventoryTurnover(costOfGoodsSold: costOfGoodsSold, averageInventory: averageInventory)
        #expect(result == 3.0) // Expected: 3.0
    }

    @Test("Calculate asset turnover ratio correctly")
    func testAssetTurnover() {
        let netSales: Double = 100000.0
        let averageTotalAssets: Double = 50000.0
        let result = assetTurnover(netSales: netSales, averageTotalAssets: averageTotalAssets)
        #expect(result == 2.0) // Expected: 2.0
    }
}
