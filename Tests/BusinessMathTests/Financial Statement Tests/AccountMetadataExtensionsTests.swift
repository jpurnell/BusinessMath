import Testing
import Foundation
@testable import BusinessMath

/// Tests for AccountMetadata enhancements (v2.0.0)
///
/// Verifies that new external system integration fields and cost classification
/// fields work correctly and maintain backward compatibility.
@Suite("AccountMetadata Extensions (v2.0.0)")
struct AccountMetadataExtensionsTests {

    // ═══════════════════════════════════════════════════════════
    // MARK: - External System Integration Fields
    // ═══════════════════════════════════════════════════════════

    @Test("External system fields default to nil")
    func externalFieldsDefaultToNil() {
        let metadata = AccountMetadata()

        #expect(metadata.externalAccountType == nil)
        #expect(metadata.externalDetailType == nil)
        #expect(metadata.externalSourceSystem == nil)
    }

    @Test("External system fields can be set individually")
    func externalFieldsCanBeSet() {
        var metadata = AccountMetadata()

        metadata.externalSourceSystem = "Xero"
        metadata.externalAccountType = "Current Liability"
        metadata.externalDetailType = "Sales Tax Payable"

        #expect(metadata.externalSourceSystem == "Xero")
        #expect(metadata.externalAccountType == "Current Liability")
        #expect(metadata.externalDetailType == "Sales Tax Payable")
    }

    @Test("External system fields can be set via initializer")
    func externalFieldsViaInitializer() {
        let metadata = AccountMetadata(
            externalAccountType: "Operating Expense",
            externalDetailType: "Payroll",
            externalSourceSystem: "NetSuite"
        )

        #expect(metadata.externalAccountType == "Operating Expense")
        #expect(metadata.externalDetailType == "Payroll")
        #expect(metadata.externalSourceSystem == "NetSuite")
    }

    @Test("External system fields are optional in initializer")
    func externalFieldsOptionalInInitializer() {
        let metadata = AccountMetadata(
            description: "Test account",
            externalSourceSystem: "Xero"
            // Other external fields omitted
        )

        #expect(metadata.description == "Test account")
        #expect(metadata.externalSourceSystem == "Xero")
        #expect(metadata.externalAccountType == nil)
        #expect(metadata.externalDetailType == nil)
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - Cost Classification Fields
    // ═══════════════════════════════════════════════════════════

    @Test("Cost classification fields default to nil")
    func costFieldsDefaultToNil() {
        let metadata = AccountMetadata()

        #expect(metadata.isFixedCost == nil)
        #expect(metadata.isVariableCost == nil)
    }

    @Test("Fixed cost can be set to true")
    func fixedCostCanBeTrue() {
        var metadata = AccountMetadata()
        metadata.isFixedCost = true

        #expect(metadata.isFixedCost == true)
        #expect(metadata.isVariableCost == false)
    }

    @Test("Variable cost can be set to true")
    func variableCostCanBeTrue() {
        var metadata = AccountMetadata()
        metadata.isVariableCost = true

        #expect(metadata.isVariableCost == true)
        #expect(metadata.isFixedCost == false)
    }

    @Test("Setting fixed cost to true sets variable cost to false")
    func fixedCostMutualExclusivity() {
        var metadata = AccountMetadata()

        // First set variable cost to true
        metadata.isVariableCost = true
        #expect(metadata.isVariableCost == true)
        #expect(metadata.isFixedCost == false)

        // Then set fixed cost to true - should flip variable cost to false
        metadata.isFixedCost = true
        #expect(metadata.isFixedCost == true)
        #expect(metadata.isVariableCost == false)
    }

    @Test("Setting variable cost to true sets fixed cost to false")
    func variableCostMutualExclusivity() {
        var metadata = AccountMetadata()

        // First set fixed cost to true
        metadata.isFixedCost = true
        #expect(metadata.isFixedCost == true)
        #expect(metadata.isVariableCost == false)

        // Then set variable cost to true - should flip fixed cost to false
        metadata.isVariableCost = true
        #expect(metadata.isVariableCost == true)
        #expect(metadata.isFixedCost == false)
    }

    @Test("Setting cost fields to false or nil doesn't flip the other")
    func costFieldsFalseDoesNotFlip() {
        var metadata = AccountMetadata()

        metadata.isFixedCost = true
        #expect(metadata.isFixedCost == true)
        #expect(metadata.isVariableCost == false)

        // Setting variable cost to false explicitly should not change fixed cost
        metadata.isVariableCost = false
        #expect(metadata.isFixedCost == true)
        #expect(metadata.isVariableCost == false)

        // Setting variable cost to nil should not change fixed cost
        metadata.isVariableCost = nil
        #expect(metadata.isFixedCost == true)
        #expect(metadata.isVariableCost == nil)
    }

    @Test("Initializer with both cost fields true prefers fixed cost")
    func initializerMutualExclusivity() {
        // This shouldn't happen in practice, but test the behavior
        let metadata = AccountMetadata(
            isFixedCost: true,
            isVariableCost: true
        )

        // Should prefer fixed cost when both are true
        #expect(metadata.isFixedCost == true)
        #expect(metadata.isVariableCost == false)
    }

    @Test("Cost classification via initializer")
    func costClassificationViaInitializer() {
        let fixedMetadata = AccountMetadata(isFixedCost: true)
        #expect(fixedMetadata.isFixedCost == true)
        #expect(fixedMetadata.isVariableCost == false)

        let variableMetadata = AccountMetadata(isVariableCost: true)
        #expect(variableMetadata.isVariableCost == true)
        #expect(variableMetadata.isFixedCost == false)

        let unclassifiedMetadata = AccountMetadata()
        #expect(unclassifiedMetadata.isFixedCost == nil)
        #expect(unclassifiedMetadata.isVariableCost == nil)
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - Codable Tests
    // ═══════════════════════════════════════════════════════════

    @Test("New fields are Codable")
    func newFieldsCodable() throws {
        let original = AccountMetadata(
            description: "Test account",
            externalAccountType: "Current Liability",
            externalDetailType: "Sales Tax Payable",
            externalSourceSystem: "Xero",
            isFixedCost: nil,
            isVariableCost: true
        )

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AccountMetadata.self, from: data)

        // Verify round-trip
        #expect(decoded.description == original.description)
        #expect(decoded.externalAccountType == original.externalAccountType)
        #expect(decoded.externalDetailType == original.externalDetailType)
        #expect(decoded.externalSourceSystem == original.externalSourceSystem)
        #expect(decoded.isFixedCost == original.isFixedCost)
        #expect(decoded.isVariableCost == original.isVariableCost)
    }

    @Test("Backward compatibility: Old JSON without new fields decodes correctly")
    func backwardCompatibilityOldJSON() throws {
        // Simulate JSON from v2.0 RC (without new fields)
        let oldJSON = """
        {
            "description": "Revenue account",
            "category": "Revenue",
            "tags": ["recurring"],
            "externalId": "ACCT-1001"
        }
        """

        let decoder = JSONDecoder()
        let data = oldJSON.data(using: .utf8)!
        let metadata = try decoder.decode(AccountMetadata.self, from: data)

        // Existing fields should work
        #expect(metadata.description == "Revenue account")
        #expect(metadata.category == "Revenue")
        #expect(metadata.tags == ["recurring"])
        #expect(metadata.externalId == "ACCT-1001")

        // New fields should default to nil
        #expect(metadata.externalAccountType == nil)
        #expect(metadata.externalDetailType == nil)
        #expect(metadata.externalSourceSystem == nil)
        #expect(metadata.isFixedCost == nil)
        #expect(metadata.isVariableCost == nil)
    }

    @Test("Backward compatibility: New metadata encodes/decodes with old parsers")
    func backwardCompatibilityNewJSON() throws {
        let metadata = AccountMetadata(
            description: "Test",
            externalSourceSystem: "Xero",
            isVariableCost: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(metadata)

        // Decode it back
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AccountMetadata.self, from: data)

        #expect(decoded.description == "Test")
        #expect(decoded.externalSourceSystem == "Xero")
        #expect(decoded.isVariableCost == true)
    }

    @Test("All fields in initializer roundtrip through Codable")
    func completeRoundtrip() throws {
        let original = AccountMetadata(
            description: "Comprehensive test",
            category: "Expenses",
            subCategory: "COGS",
            tags: ["variable", "direct"],
            externalId: "EXT-123",
            externalAccountType: "Cost of Goods Sold",
            externalDetailType: "Materials",
            externalSourceSystem: "NetSuite",
            isFixedCost: false,
            isVariableCost: true
        )

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AccountMetadata.self, from: data)

        // Verify everything
        #expect(decoded.description == original.description)
        #expect(decoded.category == original.category)
        #expect(decoded.subCategory == original.subCategory)
        #expect(decoded.tags == original.tags)
        #expect(decoded.externalId == original.externalId)
        #expect(decoded.externalAccountType == original.externalAccountType)
        #expect(decoded.externalDetailType == original.externalDetailType)
        #expect(decoded.externalSourceSystem == original.externalSourceSystem)
        #expect(decoded.isFixedCost == original.isFixedCost)
        #expect(decoded.isVariableCost == original.isVariableCost)
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - Integration Tests
    // ═══════════════════════════════════════════════════════════

    @Test("Real-world scenario: External system import")
    func externalSystemImportScenario() {
        var metadata = AccountMetadata()

        // Simulate importing from an external system
        metadata.externalSourceSystem = "Xero"
        metadata.externalAccountType = "Current Liability"
        metadata.externalDetailType = "Sales Tax Payable"
        metadata.description = "State sales tax collected from customers"
        metadata.tags = ["liability", "current", "tax"]

        // Verify all fields set correctly
        #expect(metadata.externalSourceSystem == "Xero")
        #expect(metadata.externalAccountType == "Current Liability")
        #expect(metadata.externalDetailType == "Sales Tax Payable")
        #expect(metadata.tags.contains("tax"))
    }

    @Test("Real-world scenario: Cost classification for contribution margin")
    func costClassificationScenario() {
        // Variable cost example (COGS)
        var cogsMetadata = AccountMetadata()
        cogsMetadata.description = "Raw materials cost"
        cogsMetadata.category = "COGS"
        cogsMetadata.isVariableCost = true

        #expect(cogsMetadata.isVariableCost == true)
        #expect(cogsMetadata.isFixedCost == false)

        // Fixed cost example (Rent)
        var rentMetadata = AccountMetadata()
        rentMetadata.description = "Office rent"
        rentMetadata.category = "Operating Expenses"
        rentMetadata.subCategory = "Occupancy"
        rentMetadata.isFixedCost = true

        #expect(rentMetadata.isFixedCost == true)
        #expect(rentMetadata.isVariableCost == false)

        // Unclassified cost (needs review)
        var uncategorized = AccountMetadata()
        uncategorized.description = "Marketing expense"

        #expect(uncategorized.isFixedCost == nil)
        #expect(uncategorized.isVariableCost == nil)
    }

    @Test("Real-world scenario: Complete imported account")
    func completeImportedAccount() {
        let metadata = AccountMetadata(
            description: "Sales tax collected from customers",
            category: "Current Liabilities",
            subCategory: "Tax Liabilities",
            tags: ["tax", "regulatory", "current"],
            externalId: "ACCT-2150",
            externalAccountType: "Other Current Liability",
            externalDetailType: "SalesTaxPayable",
            externalSourceSystem: "Xero",
            isFixedCost: false,
            isVariableCost: false  // Neither fixed nor variable (it's a liability)
        )

        // Verify complete metadata
        #expect(metadata.description != nil)
        #expect(metadata.externalSourceSystem == "Xero")
        #expect(metadata.externalDetailType == "SalesTaxPayable")
        #expect(metadata.tags.count == 3)
        #expect(metadata.isFixedCost == false)
        #expect(metadata.isVariableCost == false)
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - Equatable Tests
    // ═══════════════════════════════════════════════════════════

    @Test("Metadata with same values are equal")
    func metadataEquality() {
        let metadata1 = AccountMetadata(
            externalSourceSystem: "Xero",
            isVariableCost: true
        )

        let metadata2 = AccountMetadata(
            externalSourceSystem: "Xero",
            isVariableCost: true
        )

        #expect(metadata1 == metadata2)
    }

    @Test("Metadata with different values are not equal")
    func metadataInequality() {
        let metadata1 = AccountMetadata(
            externalSourceSystem: "Xero",
            isVariableCost: true
        )

        let metadata2 = AccountMetadata(
            externalSourceSystem: "NetSuite",
            isVariableCost: true
        )

        #expect(metadata1 != metadata2)
    }

    @Test("Metadata with different cost classification are not equal")
    func costClassificationInequality() {
        let fixed = AccountMetadata(isFixedCost: true)
        let variable = AccountMetadata(isVariableCost: true)

        #expect(fixed != variable)
    }
}
