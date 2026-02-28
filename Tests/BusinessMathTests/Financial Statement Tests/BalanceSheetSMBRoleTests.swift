import Testing
import Foundation
@testable import BusinessMath

/// Tests for SMB-specific BalanceSheetRole enhancements (v2.0.0)
///
/// Verifies that new enum cases added for small business accounting
/// work correctly and maintain backward compatibility.
@Suite("BalanceSheet Role - SMB Specific (v2.0.0)")
struct BalanceSheetSMBRoleTests {

    // ═══════════════════════════════════════════════════════════
    // MARK: - Sales Tax Payable
    // ═══════════════════════════════════════════════════════════

    @Test("Sales tax payable is current liability")
    func salesTaxPayableIsCurrentLiability() {
        #expect(BalanceSheetRole.salesTaxPayable.isCurrentLiability == true)
        #expect(BalanceSheetRole.salesTaxPayable.isLiability == true)
        #expect(BalanceSheetRole.salesTaxPayable.isCurrent == true)
    }

    @Test("Sales tax payable is working capital")
    func salesTaxPayableIsWorkingCapital() {
        #expect(BalanceSheetRole.salesTaxPayable.isWorkingCapital == true)
    }

    @Test("Sales tax payable is NOT debt")
    func salesTaxPayableIsNotDebt() {
        #expect(BalanceSheetRole.salesTaxPayable.isDebt == false)
    }

    @Test("Sales tax payable is NOT asset or equity")
    func salesTaxPayableClassification() {
        #expect(BalanceSheetRole.salesTaxPayable.isAsset == false)
        #expect(BalanceSheetRole.salesTaxPayable.isEquity == false)
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - Payroll Liabilities
    // ═══════════════════════════════════════════════════════════

    @Test("Payroll liabilities is current liability")
    func payrollLiabilitiesIsCurrentLiability() {
        #expect(BalanceSheetRole.payrollLiabilities.isCurrentLiability == true)
        #expect(BalanceSheetRole.payrollLiabilities.isLiability == true)
        #expect(BalanceSheetRole.payrollLiabilities.isCurrent == true)
    }

    @Test("Payroll liabilities is working capital")
    func payrollLiabilitiesIsWorkingCapital() {
        // Payroll liabilities ARE working capital - they're operating current liabilities
        // similar to accrued liabilities
        #expect(BalanceSheetRole.payrollLiabilities.isWorkingCapital == true)
    }

    @Test("Payroll liabilities is NOT debt")
    func payrollLiabilitiesIsNotDebt() {
        #expect(BalanceSheetRole.payrollLiabilities.isDebt == false)
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - Line of Credit
    // ═══════════════════════════════════════════════════════════

    @Test("Line of credit is current liability and debt")
    func lineOfCreditClassification() {
        #expect(BalanceSheetRole.lineOfCredit.isCurrentLiability == true)
        #expect(BalanceSheetRole.lineOfCredit.isLiability == true)
        #expect(BalanceSheetRole.lineOfCredit.isCurrent == true)
        #expect(BalanceSheetRole.lineOfCredit.isDebt == true)
    }

    @Test("Line of credit is NOT working capital")
    func lineOfCreditIsNotWorkingCapital() {
        // LOC is debt financing, not working capital
        #expect(BalanceSheetRole.lineOfCredit.isWorkingCapital == false)
    }

    @Test("Line of credit is NOT asset or equity")
    func lineOfCreditIsNotAssetOrEquity() {
        #expect(BalanceSheetRole.lineOfCredit.isAsset == false)
        #expect(BalanceSheetRole.lineOfCredit.isEquity == false)
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - Customer Deposits
    // ═══════════════════════════════════════════════════════════

    @Test("Customer deposits is current liability")
    func customerDepositsIsCurrentLiability() {
        #expect(BalanceSheetRole.customerDeposits.isCurrentLiability == true)
        #expect(BalanceSheetRole.customerDeposits.isLiability == true)
        #expect(BalanceSheetRole.customerDeposits.isCurrent == true)
    }

    @Test("Customer deposits is working capital")
    func customerDepositsIsWorkingCapital() {
        #expect(BalanceSheetRole.customerDeposits.isWorkingCapital == true)
    }

    @Test("Customer deposits is NOT debt")
    func customerDepositsIsNotDebt() {
        #expect(BalanceSheetRole.customerDeposits.isDebt == false)
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - Owner Loans
    // ═══════════════════════════════════════════════════════════

    @Test("Owner loans is current liability")
    func ownerLoansIsCurrentLiability() {
        #expect(BalanceSheetRole.ownerLoans.isCurrentLiability == true)
        #expect(BalanceSheetRole.ownerLoans.isLiability == true)
        #expect(BalanceSheetRole.ownerLoans.isCurrent == true)
    }

    @Test("Owner loans is NOT working capital")
    func ownerLoansIsNotWorkingCapital() {
        // Owner loans are financing, not working capital
        #expect(BalanceSheetRole.ownerLoans.isWorkingCapital == false)
    }

    @Test("Owner loans is NOT debt (for covenant purposes)")
    func ownerLoansIsNotDebt() {
        // Owner loans are typically excluded from debt calculations for covenants
        #expect(BalanceSheetRole.ownerLoans.isDebt == false)
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - Integration Tests
    // ═══════════════════════════════════════════════════════════

    @Test("All SMB roles are in CaseIterable")
    func allSMBRolesIncluded() {
        let allRoles = BalanceSheetRole.allCases

        // Verify new SMB cases are present
        #expect(allRoles.contains(.salesTaxPayable))
        #expect(allRoles.contains(.payrollLiabilities))
        #expect(allRoles.contains(.lineOfCredit))
        #expect(allRoles.contains(.customerDeposits))
        #expect(allRoles.contains(.ownerLoans))
    }

    @Test("All SMB roles are Codable")
    func smbRolesCodable() throws {
        let roles: [BalanceSheetRole] = [
            .salesTaxPayable,
            .payrollLiabilities,
            .lineOfCredit,
            .customerDeposits,
            .ownerLoans
        ]

        for role in roles {
            // Encode
            let encoder = JSONEncoder()
            let data = try encoder.encode(role)

            // Decode
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(BalanceSheetRole.self, from: data)

            // Verify round-trip
            #expect(decoded == role)
        }
    }

    @Test("All SMB roles are Hashable")
    func smbRolesHashable() {
        let roles: Set<BalanceSheetRole> = [
            .salesTaxPayable,
            .payrollLiabilities,
            .lineOfCredit,
            .customerDeposits,
            .ownerLoans
        ]

        // Verify Set contains all unique roles
        #expect(roles.count == 5)

        // Verify can be used as dictionary keys
        var roleDict: [BalanceSheetRole: String] = [:]
        roleDict[.salesTaxPayable] = "Sales Tax"
        roleDict[.payrollLiabilities] = "Payroll"

        #expect(roleDict[.salesTaxPayable] == "Sales Tax")
        #expect(roleDict[.payrollLiabilities] == "Payroll")
    }

    @Test("SMB current liabilities aggregate correctly")
    func smbCurrentLiabilitiesAggregate() {
        let currentLiabilities = BalanceSheetRole.allCases.filter { $0.isCurrentLiability }

        // Verify all SMB current liabilities are included
        #expect(currentLiabilities.contains(.salesTaxPayable))
        #expect(currentLiabilities.contains(.payrollLiabilities))
        #expect(currentLiabilities.contains(.lineOfCredit))
        #expect(currentLiabilities.contains(.customerDeposits))
        #expect(currentLiabilities.contains(.ownerLoans))

        // Verify existing current liabilities still included (backward compatibility)
        #expect(currentLiabilities.contains(.accountsPayable))
        #expect(currentLiabilities.contains(.shortTermDebt))
        #expect(currentLiabilities.contains(.deferredRevenue))
    }

    @Test("SMB working capital accounts aggregate correctly")
    func smbWorkingCapitalAggregate() {
        let workingCapital = BalanceSheetRole.allCases.filter { $0.isWorkingCapital }

        // Verify SMB working capital accounts included
        #expect(workingCapital.contains(.salesTaxPayable))
        #expect(workingCapital.contains(.customerDeposits))

        // Verify SMB NON-working capital excluded
        #expect(!workingCapital.contains(.lineOfCredit))  // Debt
        #expect(!workingCapital.contains(.ownerLoans))    // Financing

        // Verify payroll liabilities IS working capital (operating current liability)
        #expect(workingCapital.contains(.payrollLiabilities))

        // Verify existing working capital still works (backward compatibility)
        #expect(workingCapital.contains(.accountsReceivable))
        #expect(workingCapital.contains(.inventory))
        #expect(workingCapital.contains(.accountsPayable))
    }

    @Test("SMB debt accounts aggregate correctly")
    func smbDebtAggregate() {
        let debt = BalanceSheetRole.allCases.filter { $0.isDebt }

        // Verify LOC is included in debt
        #expect(debt.contains(.lineOfCredit))

        // Verify owner loans NOT included in debt (covenant purposes)
        #expect(!debt.contains(.ownerLoans))

        // Verify existing debt still works (backward compatibility)
        #expect(debt.contains(.shortTermDebt))
        #expect(debt.contains(.longTermDebt))
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - Backward Compatibility Tests
    // ═══════════════════════════════════════════════════════════

    @Test("Existing roles unchanged after SMB additions")
    func existingRolesUnchanged() {
        // Test existing asset classification
        #expect(BalanceSheetRole.cashAndEquivalents.isCurrentAsset == true)
        #expect(BalanceSheetRole.accountsReceivable.isCurrentAsset == true)
        #expect(BalanceSheetRole.inventory.isCurrentAsset == true)

        // Test existing liability classification
        #expect(BalanceSheetRole.accountsPayable.isCurrentLiability == true)
        #expect(BalanceSheetRole.longTermDebt.isNonCurrentLiability == true)

        // Test existing equity classification
        #expect(BalanceSheetRole.commonStock.isEquity == true)
        #expect(BalanceSheetRole.retainedEarnings.isEquity == true)
    }

    @Test("Existing working capital classification unchanged")
    func existingWorkingCapitalUnchanged() {
        // Existing working capital assets
        #expect(BalanceSheetRole.accountsReceivable.isWorkingCapital == true)
        #expect(BalanceSheetRole.inventory.isWorkingCapital == true)

        // Existing working capital liabilities
        #expect(BalanceSheetRole.accountsPayable.isWorkingCapital == true)
        #expect(BalanceSheetRole.accruedLiabilities.isWorkingCapital == true)

        // Cash explicitly NOT working capital (managed separately)
        #expect(BalanceSheetRole.cashAndEquivalents.isWorkingCapital == false)

        // Debt explicitly NOT working capital
        #expect(BalanceSheetRole.shortTermDebt.isWorkingCapital == false)
        #expect(BalanceSheetRole.longTermDebt.isWorkingCapital == false)
    }

    @Test("Existing debt classification unchanged")
    func existingDebtClassificationUnchanged() {
        #expect(BalanceSheetRole.shortTermDebt.isDebt == true)
        #expect(BalanceSheetRole.currentPortionLongTermDebt.isDebt == true)
        #expect(BalanceSheetRole.longTermDebt.isDebt == true)

        // Non-debt liabilities
        #expect(BalanceSheetRole.accountsPayable.isDebt == false)
        #expect(BalanceSheetRole.deferredRevenue.isDebt == false)
    }
}
