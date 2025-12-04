//
//  TemplateRegistry.swift
//  BusinessMath
//
//  Created on December 2, 2025.
//  Phase 5: Template Sharing Infrastructure
//

import Foundation
import CryptoKit

// MARK: - Template Protocol

/// Protocol for shareable financial model templates
///
/// Templates that conform to this protocol can be registered, exported,
/// and shared with other users. The protocol defines the standard interface
/// for creating models from parameters and validating inputs.
///
/// Example:
/// ```swift
/// struct MySaaSTemplate: TemplateProtocol {
///     var identifier: String { "com.example.saas-template" }
///
///     func create(parameters: [String: Any]) throws -> FinancialModel {
///         // Create model from parameters
///     }
///
///     func schema() -> TemplateSchema {
///         // Return parameter schema
///     }
///
///     func validate(parameters: [String: Any]) throws {
///         // Validate parameters
///     }
/// }
/// ```
public protocol TemplateProtocol: Sendable {
    /// Unique identifier for this template (reverse DNS notation recommended)
    var identifier: String { get }

    /// Create a financial model from the provided parameters
    ///
    /// - Parameter parameters: Dictionary of parameter names to values
    /// - Returns: Configured financial model
    /// - Throws: ``EnhancedBusinessMathError`` if parameters are invalid
    func create(parameters: [String: Any]) throws -> Any

    /// Get the template's parameter schema
    ///
    /// - Returns: Schema describing required and optional parameters
    func schema() -> TemplateSchema

    /// Validate parameters before creating a model
    ///
    /// - Parameter parameters: Dictionary of parameter names to values
    /// - Throws: ``EnhancedBusinessMathError`` if validation fails
    func validate(parameters: [String: Any]) throws
}

// MARK: - Template Schema

/// Schema definition for template parameters
///
/// Defines what parameters a template accepts, their types,
/// validation rules, and default values.
public struct TemplateSchema: Codable, Sendable {
    /// Parameter definition
    public struct Parameter: Codable, Sendable {
        /// Parameter name
        public let name: String

        /// Parameter type
        public let type: ParameterType

        /// Human-readable description
        public let description: String

        /// Whether parameter is required
        public let required: Bool

        /// Default value (as JSON string)
        public let defaultValue: String?

        /// Validation rules
        public let validation: [ValidationRule]?

        public init(
            name: String,
            type: ParameterType,
            description: String,
            required: Bool = true,
            defaultValue: String? = nil,
            validation: [ValidationRule]? = nil
        ) {
            self.name = name
            self.type = type
            self.description = description
            self.required = required
            self.defaultValue = defaultValue
            self.validation = validation
        }
    }

    /// Parameter type enumeration
    public enum ParameterType: String, Codable, Sendable {
        case string
        case number
        case boolean
        case array
        case object
    }

    /// Validation rule
    public struct ValidationRule: Codable, Sendable {
        /// Rule type (e.g., "min", "max", "pattern")
        public let rule: String

        /// Error message if validation fails
        public let message: String

        public init(rule: String, message: String) {
            self.rule = rule
            self.message = message
        }
    }

    /// Array of parameter definitions
    public let parameters: [Parameter]

    /// Example parameter sets
    public let examples: [String: [String: String]]

    public init(
        parameters: [Parameter],
        examples: [String: [String: String]] = [:]
    ) {
        self.parameters = parameters
        self.examples = examples
    }
}

// MARK: - Template Category

/// Template category for organization and discovery
public enum TemplateCategory: String, Codable, Sendable, CaseIterable {
    case saas = "saas"
    case retail = "retail"
    case manufacturing = "manufacturing"
    case realEstate = "real_estate"
    case consulting = "consulting"
    case ecommerce = "ecommerce"
    case marketplace = "marketplace"
    case subscription = "subscription"
    case custom = "custom"

    /// Human-readable name
    public var displayName: String {
        switch self {
        case .saas: return "SaaS"
        case .retail: return "Retail"
        case .manufacturing: return "Manufacturing"
        case .realEstate: return "Real Estate"
        case .consulting: return "Consulting"
        case .ecommerce: return "E-commerce"
        case .marketplace: return "Marketplace"
        case .subscription: return "Subscription"
        case .custom: return "Custom"
        }
    }
}

// MARK: - Template Metadata

/// Metadata for a template
///
/// Contains descriptive information about the template including
/// author, version, license, and parameter requirements.
public struct TemplateMetadata: Codable, Sendable {
    /// Template name
    public let name: String

    /// Brief description
    public let description: String

    /// Author name or organization
    public let author: String

    /// Semantic version (e.g., "1.0.0")
    public let version: String

    /// Template category
    public let category: TemplateCategory

    /// Required parameter names
    public let requiredParameters: [String]

    /// Optional parameter names
    public let optionalParameters: [String]

    /// Searchable tags
    public let tags: [String]

    /// License identifier (e.g., "MIT", "Apache-2.0")
    public let license: String?

    /// Documentation URL
    public let documentation: URL?

    public init(
        name: String,
        description: String,
        author: String,
        version: String,
        category: TemplateCategory,
        requiredParameters: [String] = [],
        optionalParameters: [String] = [],
        tags: [String] = [],
        license: String? = nil,
        documentation: URL? = nil
    ) {
        self.name = name
        self.description = description
        self.author = author
        self.version = version
        self.category = category
        self.requiredParameters = requiredParameters
        self.optionalParameters = optionalParameters
        self.tags = tags
        self.license = license
        self.documentation = documentation
    }
}

// MARK: - Template Package

/// Shareable template package in JSON format
///
/// Templates are exported as JSON packages that can be:
/// - Inspected in any text editor
/// - Verified for security
/// - Tracked in version control (git-friendly)
/// - Shared via file, URL, or package manager
public struct TemplatePackage: Codable, Sendable {
    /// Template metadata
    public let metadata: TemplateMetadata

    /// Template definition as JSON string
    public let templateJSON: String

    /// SHA-256 checksum for integrity verification
    public let checksum: String

    /// Package creation timestamp
    public let createdAt: Date

    public init(
        metadata: TemplateMetadata,
        templateJSON: String,
        checksum: String,
        createdAt: Date = Date()
    ) {
        self.metadata = metadata
        self.templateJSON = templateJSON
        self.checksum = checksum
        self.createdAt = createdAt
    }

    /// Verify package integrity
    ///
    /// - Returns: True if checksum matches template data
    public func verifyIntegrity() -> Bool {
        let calculatedChecksum = Self.calculateChecksum(templateJSON)
        return calculatedChecksum == checksum
    }

    /// Calculate SHA-256 checksum for template data
    static func calculateChecksum(_ data: String) -> String {
        let hash = SHA256.hash(data: Data(data.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Registered Template

/// Template registered in the registry
public struct RegisteredTemplate: Sendable {
    /// Template unique identifier
    public let identifier: String

    /// Template metadata
    public let metadata: TemplateMetadata

    /// Registration timestamp
    public let registeredAt: Date

    /// Template schema
    public let schema: TemplateSchema

    public init(
        identifier: String,
        metadata: TemplateMetadata,
        registeredAt: Date = Date(),
        schema: TemplateSchema
    ) {
        self.identifier = identifier
        self.metadata = metadata
        self.registeredAt = registeredAt
        self.schema = schema
    }
}

// MARK: - Template Registry

/// Registry for shareable financial model templates
///
/// The TemplateRegistry provides centralized management of templates:
/// - Register custom templates
/// - Discover available templates
/// - Export templates for sharing (as JSON)
/// - Import shared templates
/// - Validate template integrity
///
/// Example:
/// ```swift
/// let registry = TemplateRegistry()
///
/// // Register a template
/// await registry.register(
///     MySaaSTemplate(),
///     metadata: TemplateMetadata(
///         name: "Enterprise SaaS",
///         description: "SaaS model with enterprise features",
///         author: "Your Name",
///         version: "1.0.0",
///         category: .saas,
///         tags: ["saas", "enterprise"]
///     )
/// )
///
/// // Export for sharing
/// let package = try await registry.export("Enterprise SaaS")
/// let jsonData = try JSONEncoder().encode(package)
/// try jsonData.write(to: fileURL)
///
/// // Import shared template
/// let packageData = try Data(contentsOf: sharedTemplateURL)
/// let package = try JSONDecoder().decode(TemplatePackage.self, from: packageData)
/// try await registry.import(package)
/// ```
public actor TemplateRegistry {
    /// Storage for registered templates
    private var templates: [String: (template: any TemplateProtocol, metadata: TemplateMetadata, registeredAt: Date)] = [:]

    /// Shared singleton instance
    public static let shared = TemplateRegistry()

    /// Initialize a new registry
    public init() {}

    // MARK: - Registration

    /// Register a template for use
    ///
    /// - Parameters:
    ///   - template: Template conforming to TemplateProtocol
    ///   - metadata: Template metadata
    /// - Throws: ``EnhancedBusinessMathError`` if validation fails
    public func register(
        _ template: any TemplateProtocol,
        metadata: TemplateMetadata
    ) throws {
        // Validate metadata
        guard !metadata.name.isEmpty else {
            throw EnhancedBusinessMathError.invalidInput(
                message: "Template name cannot be empty"
            )
        }

        guard !metadata.version.isEmpty else {
            throw EnhancedBusinessMathError.invalidInput(
                message: "Template version cannot be empty"
            )
        }

        // Validate schema
        let schema = template.schema()
        guard !schema.parameters.isEmpty else {
            throw EnhancedBusinessMathError.invalidInput(
                message: "Template must define at least one parameter"
            )
        }

        // Store template
        templates[metadata.name] = (template, metadata, Date())
    }

    /// Unregister a template
    ///
    /// - Parameter name: Template name
    public func unregister(_ name: String) {
        templates.removeValue(forKey: name)
    }

    // MARK: - Discovery

    /// Get all registered templates
    ///
    /// - Returns: Array of registered template information
    public func allTemplates() -> [RegisteredTemplate] {
        templates.map { name, value in
            RegisteredTemplate(
                identifier: value.template.identifier,
                metadata: value.metadata,
                registeredAt: value.registeredAt,
                schema: value.template.schema()
            )
        }
    }

    /// Find template by name
    ///
    /// - Parameter name: Template name
    /// - Returns: Template if found, nil otherwise
    public func template(named name: String) -> (any TemplateProtocol)? {
        templates[name]?.template
    }

    /// Find templates by category
    ///
    /// - Parameter category: Template category
    /// - Returns: Array of templates in the category
    public func templates(in category: TemplateCategory) -> [RegisteredTemplate] {
        allTemplates().filter { $0.metadata.category == category }
    }

    /// Search templates by tag
    ///
    /// - Parameter tag: Tag to search for
    /// - Returns: Array of templates with the tag
    public func templates(withTag tag: String) -> [RegisteredTemplate] {
        allTemplates().filter { $0.metadata.tags.contains(tag) }
    }

    /// Get template metadata
    ///
    /// - Parameter name: Template name
    /// - Returns: Metadata if template exists
    public func metadata(for name: String) -> TemplateMetadata? {
        templates[name]?.metadata
    }

    // MARK: - Export/Import

    /// Export template to shareable JSON format
    ///
    /// Creates a TemplatePackage that can be:
    /// - Saved as a .json file
    /// - Inspected in any text editor
    /// - Shared with others
    /// - Verified for integrity
    ///
    /// - Parameter templateName: Name of template to export
    /// - Returns: Template package ready for encoding
    /// - Throws: ``EnhancedBusinessMathError`` if template not found
    public func export(_ templateName: String) throws -> TemplatePackage {
        guard let (template, metadata, _) = templates[templateName] else {
            throw EnhancedBusinessMathError.missingData(
                account: "Template",
                period: templateName
            )
        }

        // Serialize template schema to JSON
        let schema = template.schema()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let schemaData = try encoder.encode(schema)
        guard let templateJSON = String(data: schemaData, encoding: .utf8) else {
            throw EnhancedBusinessMathError.calculationFailed(
                operation: "Export Template",
                reason: "Failed to encode template schema",
                suggestions: ["Check template schema is valid"]
            )
        }

        // Calculate checksum
        let checksum = TemplatePackage.calculateChecksum(templateJSON)

        return TemplatePackage(
            metadata: metadata,
            templateJSON: templateJSON,
            checksum: checksum,
            createdAt: Date()
        )
    }

    /// Import template from shareable package
    ///
    /// Validates package integrity before importing.
    ///
    /// - Parameter package: Template package to import
    /// - Returns: Registered template information
    /// - Throws: ``EnhancedBusinessMathError`` if validation fails
    public func `import`(_ package: TemplatePackage) throws -> RegisteredTemplate {
        // Verify integrity
        guard package.verifyIntegrity() else {
            throw EnhancedBusinessMathError.dataQuality(
                message: "Template package checksum mismatch",
                context: [
                    "expected": package.checksum,
                    "template": package.metadata.name
                ]
            )
        }

        // Decode schema
        let decoder = JSONDecoder()
        guard let schemaData = package.templateJSON.data(using: .utf8) else {
            throw EnhancedBusinessMathError.dataQuality(
                message: "Invalid template JSON encoding"
            )
        }

        let schema = try decoder.decode(TemplateSchema.self, from: schemaData)

        // Create imported template wrapper
        let importedTemplate = ImportedTemplate(
            identifier: package.metadata.name,
            templateSchema: schema,
            metadata: package.metadata
        )

        // Register
        try register(importedTemplate, metadata: package.metadata)

        return RegisteredTemplate(
            identifier: importedTemplate.identifier,
            metadata: package.metadata,
            registeredAt: Date(),
            schema: schema
        )
    }

    // MARK: - Validation

    /// Validate template integrity and correctness
    ///
    /// - Parameter templateName: Name of template to validate
    /// - Returns: Validation report
    /// - Throws: ``EnhancedBusinessMathError`` if template not found
    public func validate(_ templateName: String) throws -> TemplateValidationReport {
        guard let (template, metadata, _) = templates[templateName] else {
            throw EnhancedBusinessMathError.missingData(
                account: "Template",
                period: templateName
            )
        }

        var issues: [String] = []

        // Validate metadata
        if metadata.name.isEmpty {
            issues.append("Template name is empty")
        }

        if metadata.version.isEmpty {
            issues.append("Template version is empty")
        }

        if metadata.description.isEmpty {
            issues.append("Template description is empty (recommended)")
        }

        // Validate schema
        let schema = template.schema()

        if schema.parameters.isEmpty {
            issues.append("Template has no parameters defined")
        }

        // Check for required parameters
        let requiredParams = schema.parameters.filter { $0.required }
        if requiredParams.isEmpty {
            issues.append("Template has no required parameters (may be intentional)")
        }

        // Validate parameter names
        let paramNames = schema.parameters.map { $0.name }
        let uniqueNames = Set(paramNames)
        if paramNames.count != uniqueNames.count {
            issues.append("Template has duplicate parameter names")
        }

        // Check metadata matches schema
        let metadataRequired = Set(metadata.requiredParameters)
        let schemaRequired = Set(requiredParams.map { $0.name })

        if metadataRequired != schemaRequired {
            issues.append("Metadata required parameters don't match schema")
        }

        return TemplateValidationReport(
            templateName: metadata.name,
            isValid: issues.isEmpty,
            issues: issues,
            validatedAt: Date()
        )
    }

    // MARK: - Utility

    /// Get template count
    public var count: Int {
        templates.count
    }

    /// Check if template exists
    ///
    /// - Parameter name: Template name
    /// - Returns: True if template is registered
    public func contains(_ name: String) -> Bool {
        templates[name] != nil
    }

    /// Clear all templates
    public func clear() {
        templates.removeAll()
    }
}

// MARK: - Template Validation Report

/// Report from template validation
public struct TemplateValidationReport: Sendable {
    /// Template name
    public let templateName: String

    /// Whether template is valid
    public let isValid: Bool

    /// List of validation issues
    public let issues: [String]

    /// Validation timestamp
    public let validatedAt: Date

    public init(
        templateName: String,
        isValid: Bool,
        issues: [String],
        validatedAt: Date = Date()
    ) {
        self.templateName = templateName
        self.isValid = isValid
        self.issues = issues
        self.validatedAt = validatedAt
    }

    /// Format as readable string
    public func formatted() -> String {
        var output = "Template Validation: \(templateName)\n"
        output += "Status: \(isValid ? "✅ Valid" : "❌ Invalid")\n"
        output += "Validated: \(validatedAt)\n"

        if !issues.isEmpty {
            output += "\nIssues:\n"
            for issue in issues {
                output += "  • \(issue)\n"
            }
        }

        return output
    }
}

// MARK: - Imported Template

/// Wrapper for templates imported from packages
private struct ImportedTemplate: TemplateProtocol {
    let identifier: String
    let templateSchema: TemplateSchema
    let metadata: TemplateMetadata

    func schema() -> TemplateSchema {
        return templateSchema
    }

    func create(parameters: [String: Any]) throws -> Any {
        // Imported templates store schema only, not creation logic
        // They serve as metadata containers for discovery
        throw EnhancedBusinessMathError.calculationFailed(
            operation: "Create Model",
            reason: "Imported templates are metadata-only. Use a native template implementation.",
            suggestions: [
                "Recreate template as a native TemplateProtocol implementation",
                "Use imported template as a reference for parameters"
            ]
        )
    }

    func validate(parameters: [String: Any]) throws {
        // Validate that all required parameters are present
        let requiredParams = templateSchema.parameters.filter { $0.required }

        for param in requiredParams {
            guard parameters[param.name] != nil else {
                throw EnhancedBusinessMathError.missingData(
                    account: param.name,
                    period: "template parameters"
                )
            }
        }
    }
}
