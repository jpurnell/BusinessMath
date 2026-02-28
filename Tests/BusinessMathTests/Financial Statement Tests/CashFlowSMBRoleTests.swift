import Testing
import Foundation
@testable import BusinessMath

/// Tests for SMB-specific CashFlowRole enhancements (v2.0.0)
///
/// Verifies that new cash flow enum cases added for small business
/// accounting work correctly and maintain backward compatibility.
@Suite("CashFlow Role - SMB Specific (v2.0.0)")
struct CashFlowSMBRoleTests {

    // ═══════════════════════════════════════════════════════════
    // MARK: - SMB Operating Activities
    // ═══════════════════════════════════════════════════════════

    @Test("Change in sales tax payable is operating activity")
    func changeInSalesTaxPayableClassification() {
        #expect(CashFlowRole.changeInSalesTaxPayable.isOperating == true)
        #expect(CashFlowRole.changeInSalesTaxPayable.isOperatingActivity == true)
        #expect(CashFlowRole.changeInSalesTaxPayable.isInvesting == false)
        #expect(CashFlowRole.changeInSalesTaxPayable.isFinancing == false)
    }

    @Test("Change in sales tax payable uses balance change")
    func changeInSalesTaxPayableUsesChangeInBalance() {
        #expect(CashFlowRole.changeInSalesTaxPayable.usesChangeInBalance == true)
    }

    @Test("Change in payroll liabilities is operating activity")
    func changeInPayrollLiabilitiesClassification() {
        #expect(CashFlowRole.changeInPayrollLiabilities.isOperating == true)
        #expect(CashFlowRole.changeInPayrollLiabilities.isOperatingActivity == true)
        #expect(CashFlowRole.changeInPayrollLiabilities.isInvesting == false)
        #expect(CashFlowRole.changeInPayrollLiabilities.isFinancing == false)
    }

    @Test("Change in payroll liabilities uses balance change")
    func changeInPayrollLiabilitiesUsesChangeInBalance() {
        #expect(CashFlowRole.changeInPayrollLiabilities.usesChangeInBalance == true)
    }

    @Test("Change in customer deposits is operating activity")
    func changeInCustomerDepositsClassification() {
        #expect(CashFlowRole.changeInCustomerDeposits.isOperating == true)
        #expect(CashFlowRole.changeInCustomerDeposits.isOperatingActivity == true)
        #expect(CashFlowRole.changeInCustomerDeposits.isInvesting == false)
        #expect(CashFlowRole.changeInCustomerDeposits.isFinancing == false)
    }

    @Test("Change in customer deposits uses balance change")
    func changeInCustomerDepositsUsesChangeInBalance() {
        #expect(CashFlowRole.changeInCustomerDeposits.usesChangeInBalance == true)
    }

    @Test("Change in accrued expenses is operating activity")
    func changeInAccruedExpensesClassification() {
        #expect(CashFlowRole.changeInAccruedExpenses.isOperating == true)
        #expect(CashFlowRole.changeInAccruedExpenses.isOperatingActivity == true)
        #expect(CashFlowRole.changeInAccruedExpenses.isInvesting == false)
        #expect(CashFlowRole.changeInAccruedExpenses.isFinancing == false)
    }

    @Test("Change in accrued expenses uses balance change")
    func changeInAccruedExpensesUsesChangeInBalance() {
        #expect(CashFlowRole.changeInAccruedExpenses.usesChangeInBalance == true)
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - SMB Financing Activities
    // ═══════════════════════════════════════════════════════════

    @Test("Owner distributions is financing activity")
    func ownerDistributionsClassification() {
        #expect(CashFlowRole.ownerDistributions.isFinancing == true)
        #expect(CashFlowRole.ownerDistributions.isFinancingActivity == true)
        #expect(CashFlowRole.ownerDistributions.isOperating == false)
        #expect(CashFlowRole.ownerDistributions.isInvesting == false)
    }

    @Test("Owner distributions does NOT use balance change")
    func ownerDistributionsDoesNotUseBalanceChange() {
        #expect(CashFlowRole.ownerDistributions.usesChangeInBalance == false)
    }

    @Test("Owner contributions is financing activity")
    func ownerContributionsClassification() {
        #expect(CashFlowRole.ownerContributions.isFinancing == true)
        #expect(CashFlowRole.ownerContributions.isFinancingActivity == true)
        #expect(CashFlowRole.ownerContributions.isOperating == false)
        #expect(CashFlowRole.ownerContributions.isInvesting == false)
    }

    @Test("Owner contributions does NOT use balance change")
    func ownerContributionsDoesNotUseBalanceChange() {
        #expect(CashFlowRole.ownerContributions.usesChangeInBalance == false)
    }

    @Test("Draw on line of credit is financing activity")
    func drawOnLineOfCreditClassification() {
        #expect(CashFlowRole.drawOnLineOfCredit.isFinancing == true)
        #expect(CashFlowRole.drawOnLineOfCredit.isFinancingActivity == true)
        #expect(CashFlowRole.drawOnLineOfCredit.isOperating == false)
        #expect(CashFlowRole.drawOnLineOfCredit.isInvesting == false)
    }

    @Test("Draw on line of credit does NOT use balance change")
    func drawOnLineOfCreditDoesNotUseBalanceChange() {
        #expect(CashFlowRole.drawOnLineOfCredit.usesChangeInBalance == false)
    }

    @Test("Repayment of line of credit is financing activity")
    func repaymentOfLineOfCreditClassification() {
        #expect(CashFlowRole.repaymentOfLineOfCredit.isFinancing == true)
        #expect(CashFlowRole.repaymentOfLineOfCredit.isFinancingActivity == true)
        #expect(CashFlowRole.repaymentOfLineOfCredit.isOperating == false)
        #expect(CashFlowRole.repaymentOfLineOfCredit.isInvesting == false)
    }

    @Test("Repayment of line of credit does NOT use balance change")
    func repaymentOfLineOfCreditDoesNotUseBalanceChange() {
        #expect(CashFlowRole.repaymentOfLineOfCredit.usesChangeInBalance == false)
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - Integration Tests
    // ═══════════════════════════════════════════════════════════

    @Test("All SMB roles are in CaseIterable")
    func allSMBRolesIncluded() {
        let allRoles = CashFlowRole.allCases

        // Verify new SMB operating activity cases
        #expect(allRoles.contains(.changeInSalesTaxPayable))
        #expect(allRoles.contains(.changeInPayrollLiabilities))
        #expect(allRoles.contains(.changeInCustomerDeposits))
        #expect(allRoles.contains(.changeInAccruedExpenses))

        // Verify new SMB financing activity cases
        #expect(allRoles.contains(.ownerDistributions))
        #expect(allRoles.contains(.ownerContributions))
        #expect(allRoles.contains(.drawOnLineOfCredit))
        #expect(allRoles.contains(.repaymentOfLineOfCredit))
    }

    @Test("All SMB roles are Codable")
    func smbRolesCodable() throws {
        let roles: [CashFlowRole] = [
            .changeInSalesTaxPayable,
            .changeInPayrollLiabilities,
            .changeInCustomerDeposits,
            .changeInAccruedExpenses,
            .ownerDistributions,
            .ownerContributions,
            .drawOnLineOfCredit,
            .repaymentOfLineOfCredit
        ]

        for role in roles {
            // Encode
            let encoder = JSONEncoder()
            let data = try encoder.encode(role)

            // Decode
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(CashFlowRole.self, from: data)

            // Verify round-trip
            #expect(decoded == role)
        }
    }

    @Test("All SMB roles are Hashable")
    func smbRolesHashable() {
        let roles: Set<CashFlowRole> = [
            .changeInSalesTaxPayable,
            .changeInPayrollLiabilities,
            .changeInCustomerDeposits,
            .changeInAccruedExpenses,
            .ownerDistributions,
            .ownerContributions,
            .drawOnLineOfCredit,
            .repaymentOfLineOfCredit
        ]

        // Verify Set contains all unique roles
        #expect(roles.count == 8)

        // Verify can be used as dictionary keys
        var roleDict: [CashFlowRole: String] = [:]
        roleDict[.ownerDistributions] = "Distributions"
        roleDict[.ownerContributions] = "Contributions"

        #expect(roleDict[.ownerDistributions] == "Distributions")
        #expect(roleDict[.ownerContributions] == "Contributions")
    }

    @Test("SMB operating activities aggregate correctly")
    func smbOperatingActivitiesAggregate() {
        let operating = CashFlowRole.allCases.filter { $0.isOperating }

        // Verify SMB operating activities included
        #expect(operating.contains(.changeInSalesTaxPayable))
        #expect(operating.contains(.changeInPayrollLiabilities))
        #expect(operating.contains(.changeInCustomerDeposits))
        #expect(operating.contains(.changeInAccruedExpenses))

        // Verify existing operating activities still included (backward compatibility)
        #expect(operating.contains(.netIncome))
        #expect(operating.contains(.depreciationAmortizationAddback))
        #expect(operating.contains(.changeInReceivables))
        #expect(operating.contains(.changeInInventory))
        #expect(operating.contains(.changeInPayables))
    }

    @Test("SMB financing activities aggregate correctly")
    func smbFinancingActivitiesAggregate() {
        let financing = CashFlowRole.allCases.filter { $0.isFinancing }

        // Verify SMB financing activities included
        #expect(financing.contains(.ownerDistributions))
        #expect(financing.contains(.ownerContributions))
        #expect(financing.contains(.drawOnLineOfCredit))
        #expect(financing.contains(.repaymentOfLineOfCredit))

        // Verify existing financing activities still included (backward compatibility)
        #expect(financing.contains(.proceedsFromDebt))
        #expect(financing.contains(.repaymentOfDebt))
        #expect(financing.contains(.dividendsPaid))
    }

    @Test("SMB balance change items aggregate correctly")
    func smbBalanceChangeItemsAggregate() {
        let balanceChangeItems = CashFlowRole.allCases.filter { $0.usesChangeInBalance }

        // Verify SMB balance change items included
        #expect(balanceChangeItems.contains(.changeInSalesTaxPayable))
        #expect(balanceChangeItems.contains(.changeInPayrollLiabilities))
        #expect(balanceChangeItems.contains(.changeInCustomerDeposits))
        #expect(balanceChangeItems.contains(.changeInAccruedExpenses))

        // Verify financing activities do NOT use balance change
        #expect(!balanceChangeItems.contains(.ownerDistributions))
        #expect(!balanceChangeItems.contains(.ownerContributions))
        #expect(!balanceChangeItems.contains(.drawOnLineOfCredit))
        #expect(!balanceChangeItems.contains(.repaymentOfLineOfCredit))

        // Verify existing balance change items still work (backward compatibility)
        #expect(balanceChangeItems.contains(.changeInReceivables))
        #expect(balanceChangeItems.contains(.changeInInventory))
        #expect(balanceChangeItems.contains(.changeInPayables))
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - Backward Compatibility Tests
    // ═══════════════════════════════════════════════════════════

    @Test("Existing operating roles unchanged after SMB additions")
    func existingOperatingRolesUnchanged() {
        #expect(CashFlowRole.netIncome.isOperating == true)
        #expect(CashFlowRole.depreciationAmortizationAddback.isOperating == true)
        #expect(CashFlowRole.changeInReceivables.isOperating == true)
        #expect(CashFlowRole.changeInInventory.isOperating == true)
        #expect(CashFlowRole.changeInPayables.isOperating == true)
    }

    @Test("Existing investing roles unchanged after SMB additions")
    func existingInvestingRolesUnchanged() {
        #expect(CashFlowRole.capitalExpenditures.isInvesting == true)
        #expect(CashFlowRole.acquisitions.isInvesting == true)
        #expect(CashFlowRole.proceedsFromAssetSales.isInvesting == true)
    }

    @Test("Existing financing roles unchanged after SMB additions")
    func existingFinancingRolesUnchanged() {
        #expect(CashFlowRole.proceedsFromDebt.isFinancing == true)
        #expect(CashFlowRole.repaymentOfDebt.isFinancing == true)
        #expect(CashFlowRole.dividendsPaid.isFinancing == true)
    }

    @Test("Existing balance change items unchanged")
    func existingBalanceChangeItemsUnchanged() {
        #expect(CashFlowRole.changeInReceivables.usesChangeInBalance == true)
        #expect(CashFlowRole.changeInInventory.usesChangeInBalance == true)
        #expect(CashFlowRole.changeInPayables.usesChangeInBalance == true)

        // Non-working-capital items should NOT use balance change
        #expect(CashFlowRole.netIncome.usesChangeInBalance == false)
        #expect(CashFlowRole.capitalExpenditures.usesChangeInBalance == false)
        #expect(CashFlowRole.proceedsFromDebt.usesChangeInBalance == false)
    }

    @Test("Activity alias properties work correctly")
    func activityAliasesWork() {
        // Verify alias properties match original properties
        #expect(CashFlowRole.netIncome.isOperatingActivity == CashFlowRole.netIncome.isOperating)
        #expect(CashFlowRole.capitalExpenditures.isInvestingActivity == CashFlowRole.capitalExpenditures.isInvesting)
        #expect(CashFlowRole.proceedsFromDebt.isFinancingActivity == CashFlowRole.proceedsFromDebt.isFinancing)

        // Test with SMB roles
        #expect(CashFlowRole.ownerDistributions.isFinancingActivity == CashFlowRole.ownerDistributions.isFinancing)
        #expect(CashFlowRole.changeInSalesTaxPayable.isOperatingActivity == CashFlowRole.changeInSalesTaxPayable.isOperating)
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - Cross-Reference Tests (Balance Sheet ↔ Cash Flow)
    // ═══════════════════════════════════════════════════════════

    @Test("Sales tax payable has corresponding cash flow role")
    func salesTaxCrossReference() {
        // Balance sheet role
        let bsRole = BalanceSheetRole.salesTaxPayable
        #expect(bsRole.isCurrentLiability == true)

        // Corresponding cash flow role
        let cfRole = CashFlowRole.changeInSalesTaxPayable
        #expect(cfRole.isOperating == true)
        #expect(cfRole.usesChangeInBalance == true)
    }

    @Test("Payroll liabilities has corresponding cash flow role")
    func payrollCrossReference() {
        let bsRole = BalanceSheetRole.payrollLiabilities
        #expect(bsRole.isCurrentLiability == true)

        let cfRole = CashFlowRole.changeInPayrollLiabilities
        #expect(cfRole.isOperating == true)
        #expect(cfRole.usesChangeInBalance == true)
    }

    @Test("Customer deposits has corresponding cash flow role")
    func customerDepositsCrossReference() {
        let bsRole = BalanceSheetRole.customerDeposits
        #expect(bsRole.isCurrentLiability == true)

        let cfRole = CashFlowRole.changeInCustomerDeposits
        #expect(cfRole.isOperating == true)
        #expect(cfRole.usesChangeInBalance == true)
    }

    @Test("Line of credit has corresponding cash flow roles")
    func lineOfCreditCrossReference() {
        let bsRole = BalanceSheetRole.lineOfCredit
        #expect(bsRole.isDebt == true)
        #expect(bsRole.isCurrentLiability == true)

        // LOC has TWO cash flow roles (draw and repayment)
        let drawRole = CashFlowRole.drawOnLineOfCredit
        let repayRole = CashFlowRole.repaymentOfLineOfCredit

        #expect(drawRole.isFinancing == true)
        #expect(repayRole.isFinancing == true)
        #expect(drawRole.usesChangeInBalance == false)
        #expect(repayRole.usesChangeInBalance == false)
    }
}
