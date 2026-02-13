//
//  TemplateRegistryTests.swift
//  BusinessMath
//
//  Created on December 2, 2025.
//  Phase 5: Template Sharing Infrastructure Tests
//

import Testing
import Foundation
@testable import BusinessMath

/// Tests for the TemplateRegistry system
///
/// Verifies that:
/// - Templates can be registered and discovered
/// - Export/import works correctly
/// - JSON format is valid and human-readable
/// - Validation catches errors
/// - Checksums ensure integrity
@Suite("TemplateRegistry Tests")
struct TemplateRegistryTests {

    // MARK: - Test Template

    /// Simple test template for validation
    struct TestTemplate: TemplateProtocol {
        var identifier: String { "com.test.simple-template" }

        func create(parameters: [String: Any]) throws -> Any {
            guard let value = parameters["testValue"] as? Double else {
                throw BusinessMathError.missingData(
                    account: "testValue",
                    period: "parameters"
                )
            }

            return value
        }

        func schema() -> TemplateSchema {
            TemplateSchema(
                parameters: [
                    TemplateSchema.Parameter(
                        name: "testValue",
                        type: .number,
                        description: "Test value parameter",
                        required: true
                    ),
                    TemplateSchema.Parameter(
                        name: "optionalValue",
                        type: .string,
                        description: "Optional test parameter",
                        required: false,
                        defaultValue: "default"
                    )
                ],
                examples: [
                    "basic": ["testValue": "100.0", "optionalValue": "test"]
                ]
            )
        }

        func validate(parameters: [String: Any]) throws {
            guard parameters["testValue"] != nil else {
                throw BusinessMathError.missingData(
                    account: "testValue",
                    period: "parameters"
                )
            }
        }
    }

    // MARK: - Registration Tests

    @Test("Register template successfully")
    func registerTemplate() async throws {
        let registry = TemplateRegistry()
        let template = TestTemplate()

        let metadata = TemplateMetadata(
            name: "Test Template",
            description: "A simple test template",
            author: "Test Author",
            version: "1.0.0",
            category: .custom,
            requiredParameters: ["testValue"],
            optionalParameters: ["optionalValue"],
            tags: ["test", "example"]
        )

        try await registry.register(template, metadata: metadata)

        #expect(await registry.count == 1)
        #expect(await registry.contains("Test Template"))
    }

    @Test("Register multiple templates")
    func registerMultipleTemplates() async throws {
        let registry = TemplateRegistry()

        let template1 = TestTemplate()
        let metadata1 = TemplateMetadata(
            name: "Template 1",
            description: "First template",
            author: "Author",
            version: "1.0.0",
            category: .saas,
            requiredParameters: ["testValue"]
        )

        let template2 = TestTemplate()
        let metadata2 = TemplateMetadata(
            name: "Template 2",
            description: "Second template",
            author: "Author",
            version: "1.0.0",
            category: .retail,
            requiredParameters: ["testValue"]
        )

        try await registry.register(template1, metadata: metadata1)
        try await registry.register(template2, metadata: metadata2)

        #expect(await registry.count == 2)
    }

    @Test("Cannot register template with empty name")
    func registerWithEmptyName() async {
        let registry = TemplateRegistry()
        let template = TestTemplate()

        let metadata = TemplateMetadata(
            name: "",  // Empty name
            description: "Test",
            author: "Author",
            version: "1.0.0",
            category: .custom,
            requiredParameters: ["testValue"]
        )

        var caughtError: Error?
        do {
            try await registry.register(template, metadata: metadata)
        } catch {
            caughtError = error
        }

        #expect(caughtError is BusinessMathError)
    }

    @Test("Cannot register template with empty version")
    func registerWithEmptyVersion() async {
        let registry = TemplateRegistry()
        let template = TestTemplate()

        let metadata = TemplateMetadata(
            name: "Test",
            description: "Test",
            author: "Author",
            version: "",  // Empty version
            category: .custom,
            requiredParameters: ["testValue"]
        )

        var caughtError: Error?
        do {
            try await registry.register(template, metadata: metadata)
        } catch {
            caughtError = error
        }

        #expect(caughtError is BusinessMathError)
    }

    // MARK: - Discovery Tests

    @Test("Find template by name")
    func findTemplateByName() async throws {
        let registry = TemplateRegistry()
        let template = TestTemplate()

        let metadata = TemplateMetadata(
            name: "Findable Template",
            description: "Test",
            author: "Author",
            version: "1.0.0",
            category: .custom,
            requiredParameters: ["testValue"]
        )

        try await registry.register(template, metadata: metadata)

        let found = await registry.template(named: "Findable Template")
        #expect(found != nil)
        #expect(found?.identifier == "com.test.simple-template")
    }

    @Test("Get all templates")
    func getAllTemplates() async throws {
        let registry = TemplateRegistry()

        for i in 1...3 {
            let template = TestTemplate()
            let metadata = TemplateMetadata(
                name: "Template \(i)",
                description: "Test",
                author: "Author",
                version: "1.0.0",
                category: .custom,
                requiredParameters: ["testValue"]
            )
            try await registry.register(template, metadata: metadata)
        }

        let all = await registry.allTemplates()
        #expect(all.count == 3)
    }

    @Test("Find templates by category")
    func findByCategory() async throws {
        let registry = TemplateRegistry()

        // SaaS templates
        for i in 1...2 {
            let template = TestTemplate()
            let metadata = TemplateMetadata(
                name: "SaaS \(i)",
                description: "Test",
                author: "Author",
                version: "1.0.0",
                category: .saas,
                requiredParameters: ["testValue"]
            )
            try await registry.register(template, metadata: metadata)
        }

        // Retail template
        let retailTemplate = TestTemplate()
        let retailMetadata = TemplateMetadata(
            name: "Retail 1",
            description: "Test",
            author: "Author",
            version: "1.0.0",
            category: .retail,
            requiredParameters: ["testValue"]
        )
        try await registry.register(retailTemplate, metadata: retailMetadata)

        let saasTemplates = await registry.templates(in: .saas)
        #expect(saasTemplates.count == 2)

        let retailTemplates = await registry.templates(in: .retail)
        #expect(retailTemplates.count == 1)
    }

    @Test("Find templates by tag")
    func findByTag() async throws {
        let registry = TemplateRegistry()

        let template1 = TestTemplate()
        let metadata1 = TemplateMetadata(
            name: "Template 1",
            description: "Test",
            author: "Author",
            version: "1.0.0",
            category: .custom,
            requiredParameters: ["testValue"],
            tags: ["enterprise", "b2b"]
        )
        try await registry.register(template1, metadata: metadata1)

        let template2 = TestTemplate()
        let metadata2 = TemplateMetadata(
            name: "Template 2",
            description: "Test",
            author: "Author",
            version: "1.0.0",
            category: .custom,
            requiredParameters: ["testValue"],
            tags: ["enterprise", "smb"]
        )
        try await registry.register(template2, metadata: metadata2)

        let enterpriseTemplates = await registry.templates(withTag: "enterprise")
        #expect(enterpriseTemplates.count == 2)

        let b2bTemplates = await registry.templates(withTag: "b2b")
        #expect(b2bTemplates.count == 1)
    }

    @Test("Get template metadata")
    func getMetadata() async throws {
        let registry = TemplateRegistry()
        let template = TestTemplate()

        let metadata = TemplateMetadata(
            name: "Metadata Test",
            description: "Testing metadata retrieval",
            author: "Test Author",
            version: "2.0.0",
            category: .saas,
            requiredParameters: ["testValue"]
        )

        try await registry.register(template, metadata: metadata)

        let retrieved = await registry.metadata(for: "Metadata Test")
        #expect(retrieved != nil)
        #expect(retrieved?.name == "Metadata Test")
        #expect(retrieved?.version == "2.0.0")
        #expect(retrieved?.author == "Test Author")
    }

    // MARK: - Export/Import Tests

    @Test("Export template to package")
    func exportTemplate() async throws {
        let registry = TemplateRegistry()
        let template = TestTemplate()

        let metadata = TemplateMetadata(
            name: "Exportable Template",
            description: "Test export",
            author: "Author",
            version: "1.0.0",
            category: .custom,
            requiredParameters: ["testValue"],
            optionalParameters: ["optionalValue"],
            tags: ["test"],
            license: "MIT"
        )

        try await registry.register(template, metadata: metadata)

        let package = try await registry.export("Exportable Template")

        #expect(package.metadata.name == "Exportable Template")
        #expect(!package.templateJSON.isEmpty)
        #expect(!package.checksum.isEmpty)
        #expect(package.metadata.license == "MIT")
    }

    @Test("Exported package has valid checksum")
    func exportedPackageChecksum() async throws {
        let registry = TemplateRegistry()
        let template = TestTemplate()

        let metadata = TemplateMetadata(
            name: "Checksum Test",
            description: "Test",
            author: "Author",
            version: "1.0.0",
            category: .custom,
            requiredParameters: ["testValue"]
        )

        try await registry.register(template, metadata: metadata)

        let package = try await registry.export("Checksum Test")

        // Verify integrity
        #expect(package.verifyIntegrity())

        // Checksum should be consistent
        let expectedChecksum = TemplatePackage.calculateChecksum(package.templateJSON)
        #expect(package.checksum == expectedChecksum)
    }

    @Test("Package can be encoded to JSON")
    func packageJSONEncoding() async throws {
        let registry = TemplateRegistry()
        let template = TestTemplate()

        let metadata = TemplateMetadata(
            name: "JSON Test",
            description: "Test JSON encoding",
            author: "Author",
            version: "1.0.0",
            category: .saas,
            requiredParameters: ["testValue"]
        )

        try await registry.register(template, metadata: metadata)

        let package = try await registry.export("JSON Test")

        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(package)

        // Verify it's valid JSON
        #expect(!jsonData.isEmpty)

        // Should be able to decode back
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TemplatePackage.self, from: jsonData)

        #expect(decoded.metadata.name == "JSON Test")
        #expect(decoded.checksum == package.checksum)
    }

    @Test("Import template from package")
    func importTemplate() async throws {
        // Create and export
        let registry1 = TemplateRegistry()
        let template = TestTemplate()

        let metadata = TemplateMetadata(
            name: "Import Test",
            description: "Test import",
            author: "Author",
            version: "1.0.0",
            category: .custom,
            requiredParameters: ["testValue"]
        )

        try await registry1.register(template, metadata: metadata)
        let package = try await registry1.export("Import Test")

        // Import into new registry
        let registry2 = TemplateRegistry()
        let imported = try await registry2.import(package)

        #expect(imported.metadata.name == "Import Test")
        #expect(await registry2.count == 1)
        #expect(await registry2.contains("Import Test"))
    }

    @Test("Cannot import package with invalid checksum")
    func importInvalidChecksum() async throws {
        let registry = TemplateRegistry()

        // Create package with invalid checksum
        let metadata = TemplateMetadata(
            name: "Bad Checksum",
            description: "Test",
            author: "Author",
            version: "1.0.0",
            category: .custom,
            requiredParameters: ["testValue"]
        )

        let package = TemplatePackage(
            metadata: metadata,
            templateJSON: "{\"parameters\":[]}",
            checksum: "invalid_checksum",
            createdAt: Date()
        )

        var caughtError: Error?
        do {
           let _ = try await registry.import(package)
        } catch {
            caughtError = error
        }

        #expect(caughtError is BusinessMathError)
    }

    @Test("Export non-existent template throws error")
    func exportNonExistent() async {
        let registry = TemplateRegistry()

        var caughtError: Error?
        do {
           let _ = try await registry.export("Does Not Exist")
        } catch {
            caughtError = error
        }

        #expect(caughtError is BusinessMathError)
    }

    // MARK: - Validation Tests

    @Test("Validate correct template")
    func validateCorrectTemplate() async throws {
        let registry = TemplateRegistry()
        let template = TestTemplate()

        let metadata = TemplateMetadata(
            name: "Valid Template",
            description: "A valid template",
            author: "Author",
            version: "1.0.0",
            category: .custom,
            requiredParameters: ["testValue"],
            optionalParameters: ["optionalValue"]
        )

        try await registry.register(template, metadata: metadata)

        let report = try await registry.validate("Valid Template")
        #expect(report.isValid)
        #expect(report.issues.isEmpty)
    }

    @Test("Validation report formatting")
    func validationReportFormatting() async throws {
        let registry = TemplateRegistry()
        let template = TestTemplate()

        let metadata = TemplateMetadata(
            name: "Format Test",
            description: "Test",
            author: "Author",
            version: "1.0.0",
            category: .custom,
            requiredParameters: ["testValue"]
        )

        try await registry.register(template, metadata: metadata)

        let report = try await registry.validate("Format Test")
        let formatted = report.formatted()

        #expect(formatted.contains("Format Test"))
        #expect(formatted.contains("Valid") || formatted.contains("Invalid"))
    }

    // MARK: - Template Category Tests

    @Test("Template category display names")
    func categoryDisplayNames() {
        #expect(TemplateCategory.saas.displayName == "SaaS")
        #expect(TemplateCategory.realEstate.displayName == "Real Estate")
        #expect(TemplateCategory.ecommerce.displayName == "E-commerce")
    }

    @Test("All categories are defined")
    func allCategoriesDefined() {
        let categories = TemplateCategory.allCases
        #expect(categories.count == 9)
        #expect(categories.contains(.saas))
        #expect(categories.contains(.retail))
        #expect(categories.contains(.manufacturing))
        #expect(categories.contains(.realEstate))
        #expect(categories.contains(.consulting))
        #expect(categories.contains(.ecommerce))
        #expect(categories.contains(.marketplace))
        #expect(categories.contains(.subscription))
        #expect(categories.contains(.custom))
    }

    // MARK: - Template Schema Tests

    @Test("Schema parameter validation")
    func schemaParameterValidation() {
        let param = TemplateSchema.Parameter(
            name: "testParam",
            type: .number,
            description: "A test parameter",
            required: true,
            validation: [
                TemplateSchema.ValidationRule(
                    rule: "min:0",
                    message: "Value must be positive"
                )
            ]
        )

        #expect(param.name == "testParam")
        #expect(param.type == .number)
        #expect(param.required == true)
        #expect(param.validation?.count == 1)
    }

    @Test("Schema with examples")
    func schemaWithExamples() {
        let schema = TemplateSchema(
            parameters: [
                TemplateSchema.Parameter(
                    name: "revenue",
                    type: .number,
                    description: "Revenue amount",
                    required: true
                )
            ],
            examples: [
                "basic": ["revenue": "1000000"],
                "advanced": ["revenue": "5000000"]
            ]
        )

        #expect(schema.examples.count == 2)
        #expect(schema.examples["basic"] != nil)
        #expect(schema.examples["advanced"] != nil)
    }

    // MARK: - Utility Tests

    @Test("Unregister template")
    func unregisterTemplate() async throws {
        let registry = TemplateRegistry()
        let template = TestTemplate()

        let metadata = TemplateMetadata(
            name: "Removable",
            description: "Test",
            author: "Author",
            version: "1.0.0",
            category: .custom,
            requiredParameters: ["testValue"]
        )

        try await registry.register(template, metadata: metadata)
        #expect(await registry.count == 1)

        await registry.unregister("Removable")
        #expect(await registry.count == 0)
        #expect(await !registry.contains("Removable"))
    }

    @Test("Clear all templates")
    func clearAllTemplates() async throws {
        let registry = TemplateRegistry()

        for i in 1...5 {
            let template = TestTemplate()
            let metadata = TemplateMetadata(
                name: "Template \(i)",
                description: "Test",
                author: "Author",
                version: "1.0.0",
                category: .custom,
                requiredParameters: ["testValue"]
            )
            try await registry.register(template, metadata: metadata)
        }

        #expect(await registry.count == 5)

        await registry.clear()
        #expect(await registry.count == 0)
    }

    // MARK: - Integration Tests

    @Test("Complete export/import workflow")
    func completeWorkflow() async throws {
        // 1. Create and register template
        let registry1 = TemplateRegistry()
        let template = TestTemplate()

        let metadata = TemplateMetadata(
            name: "Workflow Test",
            description: "End-to-end test",
            author: "Test Author",
            version: "1.5.0",
            category: .saas,
            requiredParameters: ["testValue"],
            optionalParameters: ["optionalValue"],
            tags: ["test", "e2e"],
            license: "MIT"
        )

        try await registry1.register(template, metadata: metadata)

        // 2. Export to package
        let package = try await registry1.export("Workflow Test")

        // 3. Encode to JSON (simulate file write)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(package)

        // 4. Decode from JSON (simulate file read)
        let decoder = JSONDecoder()
        let decodedPackage = try decoder.decode(TemplatePackage.self, from: jsonData)

        // 5. Import into new registry
        let registry2 = TemplateRegistry()
        let imported = try await registry2.import(decodedPackage)

        // 6. Verify imported template
        #expect(imported.metadata.name == "Workflow Test")
        #expect(imported.metadata.version == "1.5.0")
        #expect(imported.metadata.tags.contains("test"))
        #expect(imported.metadata.license == "MIT")

        // 7. Validate imported template
        let validation = try await registry2.validate("Workflow Test")
        #expect(validation.isValid)
    }
}
