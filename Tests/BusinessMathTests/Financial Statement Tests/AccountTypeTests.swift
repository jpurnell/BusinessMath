//
//  AccountTypeTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Testing
@testable import BusinessMath

@Suite("Account Type Tests")
struct AccountTypeTests {

	// MARK: - Basic Enum Tests

	@Test("AccountType enum has all expected cases")
	func enumHasAllCases() {
		let types: [AccountType] = [
			.revenue, .expense,
			.asset, .liability, .equity,
			.operating, .investing, .financing
		]

		#expect(types.count == 8)
	}

	@Test("AccountType equality works")
	func equalityWorks() {
		#expect(AccountType.revenue == .revenue)
		#expect(AccountType.revenue != .expense)
		#expect(AccountType.asset == .asset)
	}

	// MARK: - Category Tests

	@Test("Revenue and Expense are income statement accounts")
	func revenueAndExpenseAreIncomeStatement() {
		#expect(AccountType.revenue.category == .incomeStatement)
		#expect(AccountType.expense.category == .incomeStatement)

		#expect(AccountType.revenue.isIncomeStatement)
		#expect(AccountType.expense.isIncomeStatement)

		#expect(!AccountType.revenue.isBalanceSheet)
		#expect(!AccountType.revenue.isCashFlow)
	}

	@Test("Asset, Liability, and Equity are balance sheet accounts")
	func assetsLiabilitiesEquityAreBalanceSheet() {
		#expect(AccountType.asset.category == .balanceSheet)
		#expect(AccountType.liability.category == .balanceSheet)
		#expect(AccountType.equity.category == .balanceSheet)

		#expect(AccountType.asset.isBalanceSheet)
		#expect(AccountType.liability.isBalanceSheet)
		#expect(AccountType.equity.isBalanceSheet)

		#expect(!AccountType.asset.isIncomeStatement)
		#expect(!AccountType.asset.isCashFlow)
	}

	@Test("Operating, Investing, and Financing are cash flow accounts")
	func operatingInvestingFinancingAreCashFlow() {
		#expect(AccountType.operating.category == .cashFlowStatement)
		#expect(AccountType.investing.category == .cashFlowStatement)
		#expect(AccountType.financing.category == .cashFlowStatement)

		#expect(AccountType.operating.isCashFlow)
		#expect(AccountType.investing.isCashFlow)
		#expect(AccountType.financing.isCashFlow)

		#expect(!AccountType.operating.isIncomeStatement)
		#expect(!AccountType.operating.isBalanceSheet)
	}

	// MARK: - Normal Balance Tests

	@Test("Assets and Expenses are debit accounts")
	func assetsAndExpensesAreDebit() {
		#expect(AccountType.asset.isDebitAccount)
		#expect(AccountType.expense.isDebitAccount)

		#expect(!AccountType.asset.isCreditAccount)
		#expect(!AccountType.expense.isCreditAccount)
	}

	@Test("Liabilities, Equity, and Revenue are credit accounts")
	func liabilitiesEquityRevenueAreCredit() {
		#expect(AccountType.liability.isCreditAccount)
		#expect(AccountType.equity.isCreditAccount)
		#expect(AccountType.revenue.isCreditAccount)

		#expect(!AccountType.liability.isDebitAccount)
		#expect(!AccountType.equity.isDebitAccount)
		#expect(!AccountType.revenue.isDebitAccount)
	}

	@Test("Cash flow accounts are treated as debit")
	func cashFlowAccountsAreDebit() {
		// Cash flows represent net changes, typically shown as debits
		#expect(AccountType.operating.isDebitAccount)
		#expect(AccountType.investing.isDebitAccount)
		#expect(AccountType.financing.isDebitAccount)
	}

	// MARK: - Codable Tests

	@Test("AccountType is Codable")
	func accountTypeIsCodable() throws {
		let types: [AccountType] = [.revenue, .expense, .asset, .liability, .equity]

		for type in types {
			let encoded = try JSONEncoder().encode(type)
			let decoded = try JSONDecoder().decode(AccountType.self, from: encoded)
			#expect(decoded == type)
		}
	}

	// MARK: - Category Enum Tests

	@Test("AccountCategory has three categories")
	func categoryHasThreeCases() {
		let categories: [AccountCategory] = [
			.incomeStatement,
			.balanceSheet,
			.cashFlowStatement
		]

		#expect(categories.count == 3)
	}

	@Test("AccountCategory is equatable")
	func categoryIsEquatable() {
		#expect(AccountCategory.incomeStatement == .incomeStatement)
		#expect(AccountCategory.incomeStatement != .balanceSheet)
	}
}
