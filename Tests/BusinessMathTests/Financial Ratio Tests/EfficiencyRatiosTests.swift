import Testing
import Numerics
@testable import BusinessMath

@Suite("Efficiency Ratios Tests")
struct EfficiencyRatiosTests {

    @Test("Calculate inventory turnover ratio correctly")
    func testInventoryTurnover() throws {
        let costOfGoodsSold: Double = 24000.0
        let averageInventory: Double = 8000.0
        let result = try inventoryTurnover(costOfGoodsSold: costOfGoodsSold, averageInventory: averageInventory)
        #expect(result == 3.0) // Expected: 3.0
    }

    @Test("Calculate asset turnover ratio correctly")
    func testAssetTurnover() throws {
        let netSales: Double = 100000.0
        let averageTotalAssets: Double = 50000.0
        let result = try assetTurnover(netSales: netSales, averageTotalAssets: averageTotalAssets)
        #expect(result == 2.0) // Expected: 2.0
    }

    @Test("Inventory turnover throws on zero inventory")
    func testInventoryTurnoverThrows() {
        #expect(throws: BusinessMathError.self) {
            _ = try inventoryTurnover(costOfGoodsSold: 24000.0, averageInventory: 0.0)
        }
    }

    @Test("Asset turnover throws on zero assets")
    func testAssetTurnoverThrows() {
        #expect(throws: BusinessMathError.self) {
            _ = try assetTurnover(netSales: 100000.0, averageTotalAssets: 0.0)
        }
    }
}
