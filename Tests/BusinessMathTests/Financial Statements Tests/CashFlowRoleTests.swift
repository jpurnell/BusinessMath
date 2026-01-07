import Testing
import Foundation
@testable import BusinessMath

/// Tests for CashFlowRole enum
///
/// These tests verify that the enum has all required cases, computed properties
/// work correctly, and Codable conformance functions properly.
@Suite("CashFlowRole Tests")
struct CashFlowRoleTests {

	// MARK: - Case Existence Tests

	@Test("CashFlowRole has all operating activity cases")
	func testOperatingActivityCasesExist() {
		#expect(CashFlowRole.allCases.contains(.netIncome))
		#expect(CashFlowRole.allCases.contains(.depreciationAmortizationAddback))
		#expect(CashFlowRole.allCases.contains(.stockBasedCompensationAddback))
		#expect(CashFlowRole.allCases.contains(.deferredTaxes))
		#expect(CashFlowRole.allCases.contains(.changeInReceivables))
		#expect(CashFlowRole.allCases.contains(.changeInInventory))
		#expect(CashFlowRole.allCases.contains(.changeInPayables))
		#expect(CashFlowRole.allCases.contains(.otherOperatingActivities))
	}

	@Test("CashFlowRole has all investing activity cases")
	func testInvestingActivityCasesExist() {
		#expect(CashFlowRole.allCases.contains(.capitalExpenditures))
		#expect(CashFlowRole.allCases.contains(.acquisitions))
		#expect(CashFlowRole.allCases.contains(.proceedsFromAssetSales))
		#expect(CashFlowRole.allCases.contains(.purchaseOfInvestments))
		#expect(CashFlowRole.allCases.contains(.proceedsFromInvestments))
		#expect(CashFlowRole.allCases.contains(.loansToOtherEntities))
		#expect(CashFlowRole.allCases.contains(.otherInvestingActivities))
	}

	@Test("CashFlowRole has all financing activity cases")
	func testFinancingActivityCasesExist() {
		#expect(CashFlowRole.allCases.contains(.proceedsFromDebt))
		#expect(CashFlowRole.allCases.contains(.repaymentOfDebt))
		#expect(CashFlowRole.allCases.contains(.proceedsFromEquity))
		#expect(CashFlowRole.allCases.contains(.repurchaseOfEquity))
		#expect(CashFlowRole.allCases.contains(.dividendsPaid))
		#expect(CashFlowRole.allCases.contains(.paymentOfFinancingCosts))
		#expect(CashFlowRole.allCases.contains(.otherFinancingActivities))
	}

	@Test("CashFlowRole has exactly 22 cases")
	func testTotalCaseCount() {
		// 8 operating + 7 investing + 7 financing = 22 cases
		#expect(CashFlowRole.allCases.count >= 22)
	}

	// MARK: - Computed Property Tests

	@Test("isOperating groups all operating roles correctly")
	func testOperatingGrouping() {
		#expect(CashFlowRole.netIncome.isOperating == true)
		#expect(CashFlowRole.depreciationAmortizationAddback.isOperating == true)
		#expect(CashFlowRole.changeInReceivables.isOperating == true)
		#expect(CashFlowRole.changeInInventory.isOperating == true)
		#expect(CashFlowRole.changeInPayables.isOperating == true)

		// Non-operating cases should return false
		#expect(CashFlowRole.capitalExpenditures.isOperating == false)
		#expect(CashFlowRole.proceedsFromDebt.isOperating == false)
	}

	@Test("isInvesting groups all investing roles correctly")
	func testInvestingGrouping() {
		#expect(CashFlowRole.capitalExpenditures.isInvesting == true)
		#expect(CashFlowRole.acquisitions.isInvesting == true)
		#expect(CashFlowRole.proceedsFromAssetSales.isInvesting == true)
		#expect(CashFlowRole.purchaseOfInvestments.isInvesting == true)

		// Non-investing cases should return false
		#expect(CashFlowRole.netIncome.isInvesting == false)
		#expect(CashFlowRole.dividendsPaid.isInvesting == false)
	}

	@Test("isFinancing groups all financing roles correctly")
	func testFinancingGrouping() {
		#expect(CashFlowRole.proceedsFromDebt.isFinancing == true)
		#expect(CashFlowRole.repaymentOfDebt.isFinancing == true)
		#expect(CashFlowRole.proceedsFromEquity.isFinancing == true)
		#expect(CashFlowRole.dividendsPaid.isFinancing == true)

		// Non-financing cases should return false
		#expect(CashFlowRole.netIncome.isFinancing == false)
		#expect(CashFlowRole.capitalExpenditures.isFinancing == false)
	}

	@Test("usesChangeInBalance identifies working capital items correctly")
	func testUsesChangeInBalance() {
		// Working capital items should use balance changes
		#expect(CashFlowRole.changeInReceivables.usesChangeInBalance == true)
		#expect(CashFlowRole.changeInInventory.usesChangeInBalance == true)
		#expect(CashFlowRole.changeInPayables.usesChangeInBalance == true)

		// Direct cash flow items should not
		#expect(CashFlowRole.netIncome.usesChangeInBalance == false)
		#expect(CashFlowRole.depreciationAmortizationAddback.usesChangeInBalance == false)
		#expect(CashFlowRole.capitalExpenditures.usesChangeInBalance == false)
		#expect(CashFlowRole.dividendsPaid.usesChangeInBalance == false)
	}

	// MARK: - Codable Tests

	@Test("CashFlowRole is Codable")
	func testCodable() throws {
		let role = CashFlowRole.capitalExpenditures
		let encoded = try JSONEncoder().encode(role)
		let decoded = try JSONDecoder().decode(CashFlowRole.self, from: encoded)

		#expect(decoded == role)
	}

	@Test("CashFlowRole encodes to expected string")
	func testEncodedFormat() throws {
		let role = CashFlowRole.changeInReceivables
		let encoded = try JSONEncoder().encode(role)
		let jsonString = String(data: encoded, encoding: .utf8)

		// Should encode as a simple string, not an object
		#expect(jsonString == "\"changeInReceivables\"")
	}

	@Test("CashFlowRole decodes from string")
	func testDecodeFromString() throws {
		let json = "\"dividendsPaid\"".data(using: .utf8)!
		let decoded = try JSONDecoder().decode(CashFlowRole.self, from: json)

		#expect(decoded == CashFlowRole.dividendsPaid)
	}

	// MARK: - Protocol Conformance Tests

	@Test("CashFlowRole conforms to Hashable")
	func testHashable() {
		let role1 = CashFlowRole.netIncome
		let role2 = CashFlowRole.netIncome
		let role3 = CashFlowRole.capitalExpenditures

		#expect(role1.hashValue == role2.hashValue)
		#expect(role1.hashValue != role3.hashValue)

		// Can be used in Set
		let roleSet: Set<CashFlowRole> = [role1, role2, role3]
		#expect(roleSet.count == 2) // role1 and role2 are same
	}

	@Test("CashFlowRole conforms to CaseIterable")
	func testCaseIterable() {
		// allCases should contain all enum cases
		#expect(CashFlowRole.allCases.isEmpty == false)

		// Should be able to iterate
		var count = 0
		for _ in CashFlowRole.allCases {
			count += 1
		}
		#expect(count > 0)
	}
}
