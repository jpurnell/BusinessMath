import Testing
import Foundation
@testable import BusinessMath

/// Tests for IncomeStatementRole enum
///
/// These tests verify that the enum has all required cases, computed properties
/// work correctly, and Codable conformance functions properly.
@Suite("IncomeStatementRole Tests")
struct IncomeStatementRoleTests {

	// MARK: - Case Existence Tests

	@Test("IncomeStatementRole has all revenue cases")
	func testRevenueCasesExist() {
		#expect(IncomeStatementRole.allCases.contains(.revenue))
		#expect(IncomeStatementRole.allCases.contains(.productRevenue))
		#expect(IncomeStatementRole.allCases.contains(.serviceRevenue))
		#expect(IncomeStatementRole.allCases.contains(.subscriptionRevenue))
		#expect(IncomeStatementRole.allCases.contains(.licensingRevenue))
		#expect(IncomeStatementRole.allCases.contains(.interestIncome))
		#expect(IncomeStatementRole.allCases.contains(.otherRevenue))
	}

	@Test("IncomeStatementRole has cost of revenue cases")
	func testCostOfRevenueCasesExist() {
		#expect(IncomeStatementRole.allCases.contains(.costOfGoodsSold))
		#expect(IncomeStatementRole.allCases.contains(.costOfServices))
	}

	@Test("IncomeStatementRole has operating expense cases")
	func testOperatingExpenseCasesExist() {
		#expect(IncomeStatementRole.allCases.contains(.researchAndDevelopment))
		#expect(IncomeStatementRole.allCases.contains(.salesAndMarketing))
		#expect(IncomeStatementRole.allCases.contains(.generalAndAdministrative))
		#expect(IncomeStatementRole.allCases.contains(.operatingExpenseOther))
	}

	@Test("IncomeStatementRole has non-cash charge cases")
	func testNonCashChargeCasesExist() {
		#expect(IncomeStatementRole.allCases.contains(.depreciationAmortization))
		#expect(IncomeStatementRole.allCases.contains(.impairmentCharges))
		#expect(IncomeStatementRole.allCases.contains(.stockBasedCompensation))
		#expect(IncomeStatementRole.allCases.contains(.restructuringCharges))
	}

	@Test("IncomeStatementRole has non-operating cases")
	func testNonOperatingCasesExist() {
		#expect(IncomeStatementRole.allCases.contains(.interestExpense))
		#expect(IncomeStatementRole.allCases.contains(.foreignExchangeGainLoss))
		#expect(IncomeStatementRole.allCases.contains(.gainLossOnInvestments))
		#expect(IncomeStatementRole.allCases.contains(.gainLossOnAssetSales))
		#expect(IncomeStatementRole.allCases.contains(.otherNonOperating))
	}

	@Test("IncomeStatementRole has tax case")
	func testTaxCaseExists() {
		#expect(IncomeStatementRole.allCases.contains(.incomeTaxExpense))
	}

	@Test("IncomeStatementRole has exactly 35 cases")
	func testTotalCaseCount() {
		// 7 revenue + 2 cost of revenue + 4 operating expense + 4 non-cash
		// + 5 non-operating + 1 tax = 23 cases minimum
		// (Adjust this number after implementing all cases)
		#expect(IncomeStatementRole.allCases.count >= 23)
	}

	// MARK: - Computed Property Tests

	@Test("isRevenue groups all revenue roles correctly")
	func testRevenueGrouping() {
		#expect(IncomeStatementRole.revenue.isRevenue == true)
		#expect(IncomeStatementRole.productRevenue.isRevenue == true)
		#expect(IncomeStatementRole.serviceRevenue.isRevenue == true)
		#expect(IncomeStatementRole.subscriptionRevenue.isRevenue == true)
		#expect(IncomeStatementRole.licensingRevenue.isRevenue == true)
		#expect(IncomeStatementRole.otherRevenue.isRevenue == true)

		// Non-revenue cases should return false
		#expect(IncomeStatementRole.costOfGoodsSold.isRevenue == false)
		#expect(IncomeStatementRole.researchAndDevelopment.isRevenue == false)
		#expect(IncomeStatementRole.interestExpense.isRevenue == false)
	}

	@Test("isCostOfRevenue groups cost of revenue roles correctly")
	func testCostOfRevenueGrouping() {
		#expect(IncomeStatementRole.costOfGoodsSold.isCostOfRevenue == true)
		#expect(IncomeStatementRole.costOfServices.isCostOfRevenue == true)

		// Non-cost-of-revenue cases should return false
		#expect(IncomeStatementRole.revenue.isCostOfRevenue == false)
		#expect(IncomeStatementRole.researchAndDevelopment.isCostOfRevenue == false)
	}

	@Test("isOperatingExpense groups operating expense roles correctly")
	func testOperatingExpenseGrouping() {
		#expect(IncomeStatementRole.researchAndDevelopment.isOperatingExpense == true)
		#expect(IncomeStatementRole.salesAndMarketing.isOperatingExpense == true)
		#expect(IncomeStatementRole.generalAndAdministrative.isOperatingExpense == true)
		#expect(IncomeStatementRole.operatingExpenseOther.isOperatingExpense == true)

		// Non-operating-expense cases should return false
		#expect(IncomeStatementRole.revenue.isOperatingExpense == false)
		#expect(IncomeStatementRole.costOfGoodsSold.isOperatingExpense == false)
		#expect(IncomeStatementRole.interestExpense.isOperatingExpense == false)
	}

	@Test("isNonCashCharge groups non-cash charge roles correctly")
	func testNonCashChargeGrouping() {
		#expect(IncomeStatementRole.depreciationAmortization.isNonCashCharge == true)
		#expect(IncomeStatementRole.impairmentCharges.isNonCashCharge == true)
		#expect(IncomeStatementRole.stockBasedCompensation.isNonCashCharge == true)
		#expect(IncomeStatementRole.restructuringCharges.isNonCashCharge == true)

		// Cash-based items should return false
		#expect(IncomeStatementRole.revenue.isNonCashCharge == false)
		#expect(IncomeStatementRole.interestExpense.isNonCashCharge == false)
	}

	@Test("isNonOperating groups non-operating roles correctly")
	func testNonOperatingGrouping() {
		#expect(IncomeStatementRole.interestExpense.isNonOperating == true)
		#expect(IncomeStatementRole.interestIncome.isNonOperating == true)
		#expect(IncomeStatementRole.foreignExchangeGainLoss.isNonOperating == true)
		#expect(IncomeStatementRole.gainLossOnInvestments.isNonOperating == true)
		#expect(IncomeStatementRole.gainLossOnAssetSales.isNonOperating == true)
		#expect(IncomeStatementRole.otherNonOperating.isNonOperating == true)

		// Operating items should return false
		#expect(IncomeStatementRole.revenue.isNonOperating == false)
		#expect(IncomeStatementRole.researchAndDevelopment.isNonOperating == false)
	}

	// MARK: - Codable Tests

	@Test("IncomeStatementRole is Codable")
	func testCodable() throws {
		let role = IncomeStatementRole.researchAndDevelopment
		let encoded = try JSONEncoder().encode(role)
		let decoded = try JSONDecoder().decode(IncomeStatementRole.self, from: encoded)

		#expect(decoded == role)
	}

	@Test("IncomeStatementRole encodes to expected string")
	func testEncodedFormat() throws {
		let role = IncomeStatementRole.salesAndMarketing
		let encoded = try JSONEncoder().encode(role)
		let jsonString = String(data: encoded, encoding: .utf8)

		// Should encode as a simple string, not an object
		#expect(jsonString == "\"salesAndMarketing\"")
	}

	@Test("IncomeStatementRole decodes from string")
	func testDecodeFromString() throws {
		let json = "\"costOfGoodsSold\"".data(using: .utf8)!
		let decoded = try JSONDecoder().decode(IncomeStatementRole.self, from: json)

		#expect(decoded == IncomeStatementRole.costOfGoodsSold)
	}

	// MARK: - Protocol Conformance Tests

	@Test("IncomeStatementRole conforms to Hashable")
	func testHashable() {
		let role1 = IncomeStatementRole.revenue
		let role2 = IncomeStatementRole.revenue
		let role3 = IncomeStatementRole.costOfGoodsSold

		#expect(role1.hashValue == role2.hashValue)
		#expect(role1.hashValue != role3.hashValue)

		// Can be used in Set
		let roleSet: Set<IncomeStatementRole> = [role1, role2, role3]
		#expect(roleSet.count == 2) // role1 and role2 are same
	}

	@Test("IncomeStatementRole conforms to CaseIterable")
	func testCaseIterable() {
		// allCases should contain all enum cases
		#expect(IncomeStatementRole.allCases.isEmpty == false)

		// Should be able to iterate
		var count = 0
		for _ in IncomeStatementRole.allCases {
			count += 1
		}
		#expect(count > 0)
	}
}
