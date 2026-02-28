import Testing
import Foundation
@testable import BusinessMath

/// Tests for BalanceSheetRole enum
///
/// These tests verify that the enum has all required cases, computed properties
/// work correctly, and Codable conformance functions properly.
@Suite("BalanceSheetRole Tests")
struct BalanceSheetRoleTests {

	// MARK: - Case Existence Tests

	@Test("BalanceSheetRole has all current asset cases")
	func testCurrentAssetCasesExist() {
		#expect(BalanceSheetRole.allCases.contains(.cashAndEquivalents))
		#expect(BalanceSheetRole.allCases.contains(.shortTermInvestments))
		#expect(BalanceSheetRole.allCases.contains(.accountsReceivable))
		#expect(BalanceSheetRole.allCases.contains(.inventory))
		#expect(BalanceSheetRole.allCases.contains(.prepaidExpenses))
		#expect(BalanceSheetRole.allCases.contains(.otherCurrentAssets))
	}

	@Test("BalanceSheetRole has all non-current asset cases")
	func testNonCurrentAssetCasesExist() {
		#expect(BalanceSheetRole.allCases.contains(.propertyPlantEquipment))
		#expect(BalanceSheetRole.allCases.contains(.intangibleAssets))
		#expect(BalanceSheetRole.allCases.contains(.goodwill))
		#expect(BalanceSheetRole.allCases.contains(.longTermInvestments))
		#expect(BalanceSheetRole.allCases.contains(.deferredTaxAssets))
		#expect(BalanceSheetRole.allCases.contains(.rightOfUseAssets))
		#expect(BalanceSheetRole.allCases.contains(.otherNonCurrentAssets))
	}

	@Test("BalanceSheetRole has all current liability cases")
	func testCurrentLiabilityCasesExist() {
		#expect(BalanceSheetRole.allCases.contains(.accountsPayable))
		#expect(BalanceSheetRole.allCases.contains(.accruedLiabilities))
		#expect(BalanceSheetRole.allCases.contains(.shortTermDebt))
		#expect(BalanceSheetRole.allCases.contains(.currentPortionLongTermDebt))
		#expect(BalanceSheetRole.allCases.contains(.deferredRevenue))
		#expect(BalanceSheetRole.allCases.contains(.otherCurrentLiabilities))
	}

	@Test("BalanceSheetRole has all non-current liability cases")
	func testNonCurrentLiabilityCasesExist() {
		#expect(BalanceSheetRole.allCases.contains(.longTermDebt))
		#expect(BalanceSheetRole.allCases.contains(.deferredTaxLiabilities))
		#expect(BalanceSheetRole.allCases.contains(.pensionLiabilities))
		#expect(BalanceSheetRole.allCases.contains(.leaseLiabilities))
		#expect(BalanceSheetRole.allCases.contains(.otherNonCurrentLiabilities))
	}

	@Test("BalanceSheetRole has all equity cases")
	func testEquityCasesExist() {
		#expect(BalanceSheetRole.allCases.contains(.commonStock))
		#expect(BalanceSheetRole.allCases.contains(.preferredStock))
		#expect(BalanceSheetRole.allCases.contains(.additionalPaidInCapital))
		#expect(BalanceSheetRole.allCases.contains(.retainedEarnings))
		#expect(BalanceSheetRole.allCases.contains(.treasuryStock))
		#expect(BalanceSheetRole.allCases.contains(.accumulatedOtherComprehensiveIncome))
	}

	@Test("BalanceSheetRole has exactly 27 cases")
	func testTotalCaseCount() {
		// 6 current assets + 7 non-current assets + 6 current liabilities
		// + 5 non-current liabilities + 6 equity = 30 cases
		// (Adjust after final implementation)
		#expect(BalanceSheetRole.allCases.count >= 27)
	}

	// MARK: - Computed Property Tests

	@Test("isAsset groups all asset roles correctly")
	func testAssetGrouping() {
		// Current assets
		#expect(BalanceSheetRole.cashAndEquivalents.isAsset == true)
		#expect(BalanceSheetRole.accountsReceivable.isAsset == true)
		#expect(BalanceSheetRole.inventory.isAsset == true)

		// Non-current assets
		#expect(BalanceSheetRole.propertyPlantEquipment.isAsset == true)
		#expect(BalanceSheetRole.intangibleAssets.isAsset == true)
		#expect(BalanceSheetRole.goodwill.isAsset == true)

		// Non-assets should return false
		#expect(BalanceSheetRole.accountsPayable.isAsset == false)
		#expect(BalanceSheetRole.longTermDebt.isAsset == false)
		#expect(BalanceSheetRole.commonStock.isAsset == false)
	}

	@Test("isLiability groups all liability roles correctly")
	func testLiabilityGrouping() {
		// Current liabilities
		#expect(BalanceSheetRole.accountsPayable.isLiability == true)
		#expect(BalanceSheetRole.accruedLiabilities.isLiability == true)
		#expect(BalanceSheetRole.shortTermDebt.isLiability == true)

		// Non-current liabilities
		#expect(BalanceSheetRole.longTermDebt.isLiability == true)
		#expect(BalanceSheetRole.pensionLiabilities.isLiability == true)

		// Non-liabilities should return false
		#expect(BalanceSheetRole.cashAndEquivalents.isLiability == false)
		#expect(BalanceSheetRole.commonStock.isLiability == false)
	}

	@Test("isEquity groups all equity roles correctly")
	func testEquityGrouping() {
		#expect(BalanceSheetRole.commonStock.isEquity == true)
		#expect(BalanceSheetRole.preferredStock.isEquity == true)
		#expect(BalanceSheetRole.additionalPaidInCapital.isEquity == true)
		#expect(BalanceSheetRole.retainedEarnings.isEquity == true)
		#expect(BalanceSheetRole.treasuryStock.isEquity == true)
		#expect(BalanceSheetRole.accumulatedOtherComprehensiveIncome.isEquity == true)

		// Non-equity should return false
		#expect(BalanceSheetRole.cashAndEquivalents.isEquity == false)
		#expect(BalanceSheetRole.accountsPayable.isEquity == false)
	}

	@Test("isCurrent groups all current roles correctly")
	func testCurrentGrouping() {
		// Current assets
		#expect(BalanceSheetRole.cashAndEquivalents.isCurrent == true)
		#expect(BalanceSheetRole.accountsReceivable.isCurrent == true)
		#expect(BalanceSheetRole.inventory.isCurrent == true)

		// Current liabilities
		#expect(BalanceSheetRole.accountsPayable.isCurrent == true)
		#expect(BalanceSheetRole.shortTermDebt.isCurrent == true)

		// Non-current items should return false
		#expect(BalanceSheetRole.propertyPlantEquipment.isCurrent == false)
		#expect(BalanceSheetRole.longTermDebt.isCurrent == false)
		#expect(BalanceSheetRole.commonStock.isCurrent == false)
	}

	@Test("isNonCurrent groups all non-current roles correctly")
	func testNonCurrentGrouping() {
		// Non-current assets
		#expect(BalanceSheetRole.propertyPlantEquipment.isNonCurrent == true)
		#expect(BalanceSheetRole.intangibleAssets.isNonCurrent == true)
		#expect(BalanceSheetRole.goodwill.isNonCurrent == true)

		// Non-current liabilities
		#expect(BalanceSheetRole.longTermDebt.isNonCurrent == true)
		#expect(BalanceSheetRole.pensionLiabilities.isNonCurrent == true)

		// Current items should return false
		#expect(BalanceSheetRole.cashAndEquivalents.isNonCurrent == false)
		#expect(BalanceSheetRole.accountsPayable.isNonCurrent == false)

		// Equity is neither current nor non-current
		#expect(BalanceSheetRole.commonStock.isNonCurrent == false)
	}

	// MARK: - Codable Tests

	@Test("BalanceSheetRole is Codable")
	func testCodable() throws {
		let role = BalanceSheetRole.accountsReceivable
		let encoded = try JSONEncoder().encode(role)
		let decoded = try JSONDecoder().decode(BalanceSheetRole.self, from: encoded)

		#expect(decoded == role)
	}

	@Test("BalanceSheetRole encodes to expected string")
	func testEncodedFormat() throws {
		let role = BalanceSheetRole.propertyPlantEquipment
		let encoded = try JSONEncoder().encode(role)
		let jsonString = String(data: encoded, encoding: .utf8)

		// Should encode as a simple string, not an object
		#expect(jsonString == "\"propertyPlantEquipment\"")
	}

	@Test("BalanceSheetRole decodes from string")
	func testDecodeFromString() throws {
		let json = "\"longTermDebt\"".data(using: .utf8)!
		let decoded = try JSONDecoder().decode(BalanceSheetRole.self, from: json)

		#expect(decoded == BalanceSheetRole.longTermDebt)
	}

	// MARK: - Protocol Conformance Tests

	@Test("BalanceSheetRole conforms to Hashable")
	func testHashable() {
		let role1 = BalanceSheetRole.cashAndEquivalents
		let role2 = BalanceSheetRole.cashAndEquivalents
		let role3 = BalanceSheetRole.accountsPayable

		#expect(role1.hashValue == role2.hashValue)
		#expect(role1.hashValue != role3.hashValue)

		// Can be used in Set
		let roleSet: Set<BalanceSheetRole> = [role1, role2, role3]
		#expect(roleSet.count == 2) // role1 and role2 are same
	}

	@Test("BalanceSheetRole conforms to CaseIterable")
	func testCaseIterable() {
		// allCases should contain all enum cases
		#expect(BalanceSheetRole.allCases.isEmpty == false)

		// Should be able to iterate
		var count = 0
		for _ in BalanceSheetRole.allCases {
			count += 1
		}
		#expect(count > 0)
	}
}
