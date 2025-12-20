//
//  StandardTemplatesTests.swift
//  BusinessMath Tests
//
//  Created on December 2, 2025.
//

import Testing
import Foundation
@testable import BusinessMath

/// Tests for standard template wrappers
@Suite("Standard Templates Tests")
struct StandardTemplatesTests {

    // MARK: - SaaS Template Tests

    @Test("SaaS template registration")
    func saasTemplateRegistration() async throws {
        let registry = TemplateRegistry()
        let template = SaaSTemplate()

        let metadata = TemplateMetadata(
            name: "SaaS Template",
            description: "Template for SaaS businesses",
            author: "BusinessMath",
            version: "1.0.0",
            category: .saas,
            requiredParameters: ["initialMRR", "churnRate", "newCustomersPerMonth", "averageRevenuePerUser"]
        )

        try await registry.register(template, metadata: metadata)

        let found = await registry.template(named: "SaaS Template")
        #expect(found != nil)
    }

    @Test("SaaS template creates valid model")
    func saasTemplateCreatesModel() throws {
        let template = SaaSTemplate()

        let parameters: [String: Any] = [
            "initialMRR": 10_000.0,
            "churnRate": 0.05,
            "newCustomersPerMonth": 100.0,
            "averageRevenuePerUser": 100.0,
            "grossMargin": 0.85,
            "customerAcquisitionCost": 500.0
        ]

        let model = try template.create(parameters: parameters)

        #expect(model is SaaSModel)
        let saasModel = model as! SaaSModel
        #expect(saasModel.initialMRR == 10_000.0)
        #expect(saasModel.churnRate == 0.05)
    }

    @Test("SaaS template validates parameters")
    func saasTemplateValidation() {
        let template = SaaSTemplate()

        // Invalid: negative MRR
        var caughtError: Error?
        do {
            try template.validate(parameters: ["initialMRR": -1000.0])
        } catch {
            caughtError = error
        }
        #expect(caughtError is BusinessMathError)

        // Valid parameters
        let validParams: [String: Any] = [
            "initialMRR": 10_000.0,
            "churnRate": 0.05,
            "newCustomersPerMonth": 100.0,
            "averageRevenuePerUser": 100.0
        ]

        caughtError = nil
        do {
            try template.validate(parameters: validParams)
        } catch {
            caughtError = error
        }
        #expect(caughtError == nil)
    }

    @Test("SaaS template export and import")
    func saasTemplateExportImport() async throws {
        let registry1 = TemplateRegistry()
        let registry2 = TemplateRegistry()
        let template = SaaSTemplate()

        let metadata = TemplateMetadata(
            name: "SaaS Template",
            description: "Template for SaaS businesses",
            author: "BusinessMath",
            version: "1.0.0",
            category: .saas,
            requiredParameters: ["initialMRR", "churnRate", "newCustomersPerMonth", "averageRevenuePerUser"]
        )

        // Register and export
        try await registry1.register(template, metadata: metadata)
        let package = try await registry1.export("SaaS Template")

        // Verify checksum
        #expect(package.verifyIntegrity())

        // Import into new registry
        _ = try await registry2.import(package)

        // Verify imported
        let found = await registry2.template(named: "SaaS Template")
        #expect(found != nil)
    }

    // MARK: - Retail Template Tests

    @Test("Retail template creates valid model")
    func retailTemplateCreatesModel() throws {
        let template = RetailTemplate()

        let parameters: [String: Any] = [
            "initialInventoryValue": 50_000.0,
            "monthlyRevenue": 100_000.0,
            "costOfGoodsSoldPercentage": 0.60,
            "operatingExpenses": 20_000.0
        ]

        let model = try template.create(parameters: parameters)

        #expect(model is RetailModel)
        let retailModel = model as! RetailModel
        #expect(retailModel.initialInventoryValue == 50_000.0)
        #expect(retailModel.monthlyRevenue == 100_000.0)
    }

    @Test("Retail template validation")
    func retailTemplateValidation() {
        let template = RetailTemplate()

        // Invalid: COGS > 1
        var caughtError: Error?
        do {
            let params: [String: Any] = [
                "initialInventoryValue": 50_000.0,
                "monthlyRevenue": 100_000.0,
                "costOfGoodsSoldPercentage": 1.5,  // Invalid
                "operatingExpenses": 20_000.0
            ]
            try template.validate(parameters: params)
        } catch {
            caughtError = error
        }
        #expect(caughtError is BusinessMathError)
    }

    // MARK: - Manufacturing Template Tests

    @Test("Manufacturing template creates valid model")
    func manufacturingTemplateCreatesModel() throws {
        let template = ManufacturingTemplate()

        let parameters: [String: Any] = [
            "productionCapacity": 10_000.0,
            "sellingPricePerUnit": 50.0,
            "directMaterialCostPerUnit": 20.0,
            "directLaborCostPerUnit": 10.0,
            "monthlyOverhead": 50_000.0
        ]

        let model = try template.create(parameters: parameters)

        #expect(model is ManufacturingModel)
        let mfgModel = model as! ManufacturingModel
        #expect(mfgModel.productionCapacity == 10_000.0)
        #expect(mfgModel.sellingPricePerUnit == 50.0)
    }

    // MARK: - Marketplace Template Tests

    @Test("Marketplace template creates valid model")
    func marketplaceTemplateCreatesModel() throws {
        let template = MarketplaceTemplate()

        let parameters: [String: Any] = [
            "initialBuyers": 1_000.0,
            "initialSellers": 100.0,
            "monthlyTransactionsPerBuyer": 4.0,
            "averageOrderValue": 250.0,
            "takeRate": 0.15,
            "newBuyersPerMonth": 100.0,
            "newSellersPerMonth": 10.0,
            "buyerChurnRate": 0.05,
            "sellerChurnRate": 0.03
        ]

        let model = try template.create(parameters: parameters)

        #expect(model is MarketplaceModel)
        let marketplaceModel = model as! MarketplaceModel
        #expect(marketplaceModel.initialBuyers == 1_000.0)
        #expect(marketplaceModel.takeRate == 0.15)
    }

    // MARK: - Subscription Box Template Tests

    @Test("Subscription box template creates valid model")
    func subscriptionBoxTemplateCreatesModel() throws {
        let template = SubscriptionBoxTemplate()

        let parameters: [String: Any] = [
            "initialSubscribers": 1_000.0,
            "monthlyBoxPrice": 49.99,
            "costOfGoodsPerBox": 20.0,
            "shippingCostPerBox": 5.0,
            "monthlyChurnRate": 0.08,
            "newSubscribersPerMonth": 500.0,
            "customerAcquisitionCost": 50.0
        ]

        let model = try template.create(parameters: parameters)

        #expect(model is SubscriptionBoxModel)
        let subBoxModel = model as! SubscriptionBoxModel
        #expect(subBoxModel.initialSubscribers == 1_000.0)
        #expect(subBoxModel.monthlyBoxPrice == 49.99)
    }

    // MARK: - Registry Integration Tests

    @Test("Register all standard templates")
    func registerAllStandardTemplates() async throws {
        let registry = TemplateRegistry()

        // Register SaaS
        let saas = SaaSTemplate()
        let saasMetadata = TemplateMetadata(
            name: "SaaS",
            description: "SaaS business model",
            author: "BusinessMath",
            version: "1.0.0",
            category: .saas,
            requiredParameters: ["initialMRR", "churnRate", "newCustomersPerMonth", "averageRevenuePerUser"],
            tags: ["saas", "recurring", "subscription"]
        )
        try await registry.register(saas, metadata: saasMetadata)

        // Register Retail
        let retail = RetailTemplate()
        let retailMetadata = TemplateMetadata(
            name: "Retail",
            description: "Retail business model",
            author: "BusinessMath",
            version: "1.0.0",
            category: .retail,
            requiredParameters: ["initialInventoryValue", "monthlyRevenue", "costOfGoodsSoldPercentage", "operatingExpenses"],
            tags: ["retail", "ecommerce", "store"]
        )
        try await registry.register(retail, metadata: retailMetadata)

        // Register Manufacturing
        let manufacturing = ManufacturingTemplate()
        let mfgMetadata = TemplateMetadata(
            name: "Manufacturing",
            description: "Manufacturing business model",
            author: "BusinessMath",
            version: "1.0.0",
            category: .manufacturing,
            requiredParameters: ["productionCapacity", "sellingPricePerUnit", "directMaterialCostPerUnit", "directLaborCostPerUnit", "monthlyOverhead"],
            tags: ["manufacturing", "production", "factory"]
        )
        try await registry.register(manufacturing, metadata: mfgMetadata)

        // Register Marketplace
        let marketplace = MarketplaceTemplate()
        let marketplaceMetadata = TemplateMetadata(
            name: "Marketplace",
            description: "Marketplace business model",
            author: "BusinessMath",
            version: "1.0.0",
            category: .marketplace,
            requiredParameters: ["initialBuyers", "initialSellers", "monthlyTransactionsPerBuyer", "averageOrderValue", "takeRate", "newBuyersPerMonth", "newSellersPerMonth", "buyerChurnRate", "sellerChurnRate"],
            tags: ["marketplace", "platform", "two-sided"]
        )
        try await registry.register(marketplace, metadata: marketplaceMetadata)

        // Register Subscription Box
        let subscriptionBox = SubscriptionBoxTemplate()
        let subBoxMetadata = TemplateMetadata(
            name: "Subscription Box",
            description: "Subscription box business model",
            author: "BusinessMath",
            version: "1.0.0",
            category: .subscription,
            requiredParameters: ["initialSubscribers", "monthlyBoxPrice", "costOfGoodsPerBox", "shippingCostPerBox", "monthlyChurnRate", "newSubscribersPerMonth", "customerAcquisitionCost"],
            tags: ["subscription", "box", "recurring"]
        )
        try await registry.register(subscriptionBox, metadata: subBoxMetadata)

        // Verify all registered
        #expect(await registry.count == 5)

        // Find by category
        let saasTemplates = await registry.templates(in: .saas)
        #expect(saasTemplates.count == 1)

        let retailTemplates = await registry.templates(in: .retail)
        #expect(retailTemplates.count == 1)
    }

    @Test("Schema completeness for all templates")
    func schemaCompletenessForAllTemplates() {
        let templates: [any TemplateProtocol] = [
            SaaSTemplate(),
            RetailTemplate(),
            ManufacturingTemplate(),
            MarketplaceTemplate(),
            SubscriptionBoxTemplate()
        ]

        for template in templates {
            let schema = template.schema()

            // Verify schema has parameters
            #expect(!schema.parameters.isEmpty)

            // Verify each parameter has required information
            for param in schema.parameters {
                #expect(!param.name.isEmpty)
                #expect(!param.description.isEmpty)
            }
        }
    }
}
