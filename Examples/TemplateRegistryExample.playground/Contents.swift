//
//  TemplateRegistryExample.swift
//  BusinessMath Examples
//
//  Created on December 2, 2025.
//
//  This example demonstrates how to use the TemplateRegistry system
//  to register, share, and use financial model templates.

import Foundation
import BusinessMath

	/// Example: Using the Template Registry System
	///
	/// This example shows how to:
	/// 1. Register standard templates
	/// 2. Create models from templates using parameters
	/// 3. Export templates to shareable packages
	/// 4. Import templates from packages
	/// 5. Discover templates by category and tags
//	@main
	struct TemplateRegistryExample {

		static func main() async throws {
			print("=== BusinessMath Template Registry Example ===\n")

			// MARK: - Step 1: Create Registry and Register Templates
			print("Step 1: Creating template registry...")
			let registry = TemplateRegistry()

			// Register SaaS template
			let saasTemplate = SaaSTemplate()
			let saasMetadata = TemplateMetadata(
				name: "SaaS Business Model",
				description: "Template for Software-as-a-Service businesses with MRR, churn, and unit economics",
				author: "BusinessMath",
				version: "1.0.0",
				category: .saas,
				requiredParameters: ["initialMRR", "churnRate", "newCustomersPerMonth", "averageRevenuePerUser"],
				tags: ["saas", "recurring", "subscription", "mrr"]
			)
			try await registry.register(saasTemplate, metadata: saasMetadata)
			print("✓ Registered SaaS template")

			// Register Retail template
			let retailTemplate = RetailTemplate()
			let retailMetadata = TemplateMetadata(
				name: "Retail Business Model",
				description: "Template for retail businesses with inventory and operating expenses",
				author: "BusinessMath",
				version: "1.0.0",
				category: .retail,
				requiredParameters: ["initialInventoryValue", "monthlyRevenue", "costOfGoodsSoldPercentage", "operatingExpenses"],
				tags: ["retail", "inventory", "cogs"]
			)
			try await registry.register(retailTemplate, metadata: retailMetadata)
			print("✓ Registered Retail template")

			print("Total templates: \(await registry.count)\n")

			// MARK: - Step 2: Create a Model from a Template
			print("Step 2: Creating a SaaS model from template...")

			let saasParams: [String: Any] = [
				"initialMRR": 50_000.0,
				"churnRate": 0.05,
				"newCustomersPerMonth": 200.0,
				"averageRevenuePerUser": 99.0,
				"grossMargin": 0.85,
				"customerAcquisitionCost": 350.0
			]

			let saasModel = try saasTemplate.create(parameters: saasParams) as! SaaSModel

			// Use the model
			let projection = saasModel.project(months: 12)
			let ltv = saasModel.calculateLTV()
			let ltvToCAC = saasModel.calculateLTVtoCAC()

			print("SaaS Model Metrics:")
			print("  Initial MRR: \(saasModel.initialMRR.currency())")
			print("  Customer LTV: \(ltv.currency())")
			print("  LTV:CAC Ratio: \(ltvToCAC.number())")
			print("  MRR after 12 months: \(projection.revenue.valuesArray[11].currency())\n")

			// MARK: - Step 3: Export Template to Package
			print("Step 3: Exporting SaaS template to package...")

			let package = try await registry.export("SaaS Business Model")

			print("Package details:")
			print("  Name: \(package.metadata.name)")
			print("  Version: \(package.metadata.version)")
			print("  Author: \(package.metadata.author)")
			print("  Checksum: \(package.checksum.prefix(16))...")
			print("  Integrity verified: \(package.verifyIntegrity() ? "✓" : "✗")\n")

			// Save to JSON file
			let encoder = JSONEncoder()
			encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
			let jsonData = try encoder.encode(package)

			let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
			let packageFile = documentsPath.appendingPathComponent("SaaSTemplate.json")
			try jsonData.write(to: packageFile)

			print("✓ Package saved to: \(packageFile.path)\n")

			// MARK: - Step 4: Import Template from Package
			print("Step 4: Importing template from package into new registry...")

			let newRegistry = TemplateRegistry()

			// Simulate loading from file
			let loadedData = try Data(contentsOf: packageFile)
			let decoder = JSONDecoder()
			let loadedPackage = try decoder.decode(TemplatePackage.self, from: loadedData)

			_ = try await newRegistry.import(loadedPackage)

			print("✓ Template imported successfully")
			print("New registry has \(await newRegistry.count) template(s)\n")

			// MARK: - Step 5: Discover Templates
			print("Step 5: Discovering templates...")

			// Find by name
			if let foundTemplate = await registry.template(named: "SaaS Business Model") {
				print("✓ Found template by name: SaaS Business Model")
			}

			// Find by category
			let saasTemplates = await registry.templates(in: .saas)
			print("✓ Found \(saasTemplates.count) SaaS template(s)")

			// Find by tag
			let recurringTemplates = await registry.templates(withTag: "recurring")
			print("✓ Found \(recurringTemplates.count) template(s) with tag 'recurring'")

			// List all templates
			let allTemplates = await registry.allTemplates()
			print("\nAll registered templates:")
			for template in allTemplates {
				if let metadata = await registry.metadata(for: template.identifier) {
					print("  • \(metadata.name) v\(metadata.version)")
					print("    Category: \(metadata.category.displayName)")
					print("    Tags: \(metadata.tags.joined(separator: ", "))")
				}
			}

			// MARK: - Step 6: Validate Template
			print("\nStep 6: Validating template...")

			let validation = try await registry.validate("SaaS Business Model")
			print("Validation result: \(validation.isValid ? "✓ Valid" : "✗ Invalid")")
			print(validation.formatted())

			print("\n=== Example Complete ===")
		}
	}

Task {
	try await TemplateRegistryExample.main()
}
