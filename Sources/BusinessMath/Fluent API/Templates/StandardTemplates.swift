//
//  StandardTemplates.swift
//  BusinessMath
//
//  Created on December 2, 2025.
//

import Foundation

// MARK: - SaaS Template

/// Template wrapper for SaaS business model
///
/// Provides TemplateProtocol conformance for the SaaSModel,
/// enabling registration and sharing via TemplateRegistry.
///
/// Example:
/// ```swift
/// let registry = TemplateRegistry()
/// let saasTemplate = SaaSTemplate()
/// try await registry.register(saasTemplate, metadata: saasMetadata)
/// ```
public struct SaaSTemplate: TemplateProtocol {
    public let identifier: String = "com.businessmath.templates.saas"

    public init() {}

    public func schema() -> TemplateSchema {
        TemplateSchema(
            parameters: [
                TemplateSchema.Parameter(
                    name: "initialMRR",
                    type: .number,
                    description: "Initial Monthly Recurring Revenue",
                    required: true,
                    validation: [
                        TemplateSchema.ValidationRule(rule: "min", message: "Must be positive")
                    ]
                ),
                TemplateSchema.Parameter(
                    name: "churnRate",
                    type: .number,
                    description: "Monthly customer churn rate (0.0 to 1.0)",
                    required: true,
                    validation: [
                        TemplateSchema.ValidationRule(rule: "range", message: "Must be between 0.0 and 1.0")
                    ]
                ),
                TemplateSchema.Parameter(
                    name: "newCustomersPerMonth",
                    type: .number,
                    description: "Number of new customers acquired per month",
                    required: true,
                    validation: [
                        TemplateSchema.ValidationRule(rule: "min", message: "Must be positive")
                    ]
                ),
                TemplateSchema.Parameter(
                    name: "averageRevenuePerUser",
                    type: .number,
                    description: "Average revenue per user (ARPU)",
                    required: true,
                    validation: [
                        TemplateSchema.ValidationRule(rule: "min", message: "Must be positive")
                    ]
                ),
                TemplateSchema.Parameter(
                    name: "grossMargin",
                    type: .number,
                    description: "Gross margin percentage (0.0 to 1.0)",
                    required: false,
                    validation: [
                        TemplateSchema.ValidationRule(rule: "range", message: "Must be between 0.0 and 1.0 if provided")
                    ]
                ),
                TemplateSchema.Parameter(
                    name: "customerAcquisitionCost",
                    type: .number,
                    description: "Customer Acquisition Cost (CAC)",
                    required: false,
                    validation: [
                        TemplateSchema.ValidationRule(rule: "min", message: "Must be positive if provided")
                    ]
                )
            ],
            examples: [
                "startup": [
                    "initialMRR": "10000",
                    "churnRate": "0.05",
                    "newCustomersPerMonth": "100",
                    "averageRevenuePerUser": "100"
                ],
                "growth": [
                    "initialMRR": "50000",
                    "churnRate": "0.03",
                    "newCustomersPerMonth": "500",
                    "averageRevenuePerUser": "100",
                    "grossMargin": "0.85"
                ]
            ]
        )
    }

    public func validate(parameters: [String: Any]) throws {
        guard let initialMRR = parameters["initialMRR"] as? Double else {
            throw BusinessMathError.missingData(
                account: "initialMRR",
                period: "template parameters"
            )
        }
        guard initialMRR > 0 else {
            throw BusinessMathError.invalidInput(
                message: "initialMRR must be positive",
                value: "\(initialMRR)",
                expectedRange: "> 0"
            )
        }

        guard let churnRate = parameters["churnRate"] as? Double else {
            throw BusinessMathError.missingData(
                account: "churnRate",
                period: "template parameters"
            )
        }
        guard churnRate >= 0 && churnRate <= 1 else {
            throw BusinessMathError.invalidInput(
                message: "churnRate must be between 0.0 and 1.0",
                value: "\(churnRate)",
                expectedRange: "0.0 to 1.0"
            )
        }

        guard let newCustomersPerMonth = parameters["newCustomersPerMonth"] as? Double else {
            throw BusinessMathError.missingData(
                account: "newCustomersPerMonth",
                period: "template parameters"
            )
        }
        guard newCustomersPerMonth > 0 else {
            throw BusinessMathError.invalidInput(
                message: "newCustomersPerMonth must be positive",
                value: "\(newCustomersPerMonth)",
                expectedRange: "> 0"
            )
        }

        guard let arpu = parameters["averageRevenuePerUser"] as? Double else {
            throw BusinessMathError.missingData(
                account: "averageRevenuePerUser",
                period: "template parameters"
            )
        }
        guard arpu > 0 else {
            throw BusinessMathError.invalidInput(
                message: "averageRevenuePerUser must be positive",
                value: "\(arpu)",
                expectedRange: "> 0"
            )
        }

        if let grossMargin = parameters["grossMargin"] as? Double {
            guard grossMargin >= 0 && grossMargin <= 1 else {
                throw BusinessMathError.invalidInput(
                    message: "grossMargin must be between 0.0 and 1.0",
                    value: "\(grossMargin)",
                    expectedRange: "0.0 to 1.0"
                )
            }
        }

        if let cac = parameters["customerAcquisitionCost"] as? Double {
            guard cac > 0 else {
                throw BusinessMathError.invalidInput(
                    message: "customerAcquisitionCost must be positive",
                    value: "\(cac)",
                    expectedRange: "> 0"
                )
            }
        }
    }

    public func create(parameters: [String: Any]) throws -> Any {
        try validate(parameters: parameters)

        let initialMRR = parameters["initialMRR"] as! Double
        let churnRate = parameters["churnRate"] as! Double
        let newCustomersPerMonth = parameters["newCustomersPerMonth"] as! Double
        let arpu = parameters["averageRevenuePerUser"] as! Double
        let grossMargin = parameters["grossMargin"] as? Double
        let cac = parameters["customerAcquisitionCost"] as? Double

        return SaaSModel(
            initialMRR: initialMRR,
            churnRate: churnRate,
            newCustomersPerMonth: newCustomersPerMonth,
            averageRevenuePerUser: arpu,
            grossMargin: grossMargin,
            customerAcquisitionCost: cac
        )
    }
}

// MARK: - Retail Template

/// Template wrapper for retail business model
public struct RetailTemplate: TemplateProtocol {
    public let identifier: String = "com.businessmath.templates.retail"

    public init() {}

    public func schema() -> TemplateSchema {
        TemplateSchema(
            parameters: [
                TemplateSchema.Parameter(
                    name: "initialInventoryValue",
                    type: .number,
                    description: "Initial inventory value",
                    required: true
                ),
                TemplateSchema.Parameter(
                    name: "monthlyRevenue",
                    type: .number,
                    description: "Expected monthly revenue",
                    required: true
                ),
                TemplateSchema.Parameter(
                    name: "costOfGoodsSoldPercentage",
                    type: .number,
                    description: "COGS as percentage of revenue",
                    required: true
                ),
                TemplateSchema.Parameter(
                    name: "operatingExpenses",
                    type: .number,
                    description: "Monthly operating expenses",
                    required: true
                )
            ]
        )
    }

    public func validate(parameters: [String: Any]) throws {
        guard let inventory = parameters["initialInventoryValue"] as? Double, inventory > 0 else {
            throw BusinessMathError.invalidInput(
                message: "initialInventoryValue must be positive",
                value: "\(parameters["initialInventoryValue"] ?? "nil")"
            )
        }

        guard let revenue = parameters["monthlyRevenue"] as? Double, revenue > 0 else {
            throw BusinessMathError.invalidInput(
                message: "monthlyRevenue must be positive",
                value: "\(parameters["monthlyRevenue"] ?? "nil")"
            )
        }

        guard let cogs = parameters["costOfGoodsSoldPercentage"] as? Double,
              cogs >= 0, cogs <= 1 else {
            throw BusinessMathError.invalidInput(
                message: "costOfGoodsSoldPercentage must be between 0.0 and 1.0",
                value: "\(parameters["costOfGoodsSoldPercentage"] ?? "nil")"
            )
        }

        guard let opex = parameters["operatingExpenses"] as? Double, opex > 0 else {
            throw BusinessMathError.invalidInput(
                message: "operatingExpenses must be positive",
                value: "\(parameters["operatingExpenses"] ?? "nil")"
            )
        }
    }

    public func create(parameters: [String: Any]) throws -> Any {
        try validate(parameters: parameters)

        return RetailModel(
            initialInventoryValue: parameters["initialInventoryValue"] as! Double,
            monthlyRevenue: parameters["monthlyRevenue"] as! Double,
            costOfGoodsSoldPercentage: parameters["costOfGoodsSoldPercentage"] as! Double,
            operatingExpenses: parameters["operatingExpenses"] as! Double
        )
    }
}

// MARK: - Manufacturing Template

/// Template wrapper for manufacturing business model
public struct ManufacturingTemplate: TemplateProtocol {
    public let identifier: String = "com.businessmath.templates.manufacturing"

    public init() {}

    public func schema() -> TemplateSchema {
        TemplateSchema(
            parameters: [
                TemplateSchema.Parameter(
                    name: "productionCapacity",
                    type: .number,
                    description: "Maximum units that can be produced per month",
                    required: true
                ),
                TemplateSchema.Parameter(
                    name: "sellingPricePerUnit",
                    type: .number,
                    description: "Price per unit",
                    required: true
                ),
                TemplateSchema.Parameter(
                    name: "directMaterialCostPerUnit",
                    type: .number,
                    description: "Raw material cost per unit",
                    required: true
                ),
                TemplateSchema.Parameter(
                    name: "directLaborCostPerUnit",
                    type: .number,
                    description: "Direct labor cost per unit",
                    required: true
                ),
                TemplateSchema.Parameter(
                    name: "monthlyOverhead",
                    type: .number,
                    description: "Fixed overhead costs per month",
                    required: true
                )
            ]
        )
    }

    public func validate(parameters: [String: Any]) throws {
        guard let capacity = parameters["productionCapacity"] as? Double, capacity > 0 else {
            throw BusinessMathError.invalidInput(
                message: "productionCapacity must be positive",
                value: "\(parameters["productionCapacity"] ?? "nil")"
            )
        }

        guard let price = parameters["sellingPricePerUnit"] as? Double, price > 0 else {
            throw BusinessMathError.invalidInput(
                message: "sellingPricePerUnit must be positive",
                value: "\(parameters["sellingPricePerUnit"] ?? "nil")"
            )
        }

        guard let materialCost = parameters["directMaterialCostPerUnit"] as? Double, materialCost > 0 else {
            throw BusinessMathError.invalidInput(
                message: "directMaterialCostPerUnit must be positive",
                value: "\(parameters["directMaterialCostPerUnit"] ?? "nil")"
            )
        }

        guard let laborCost = parameters["directLaborCostPerUnit"] as? Double, laborCost > 0 else {
            throw BusinessMathError.invalidInput(
                message: "directLaborCostPerUnit must be positive",
                value: "\(parameters["directLaborCostPerUnit"] ?? "nil")"
            )
        }

        guard let overhead = parameters["monthlyOverhead"] as? Double, overhead > 0 else {
            throw BusinessMathError.invalidInput(
                message: "monthlyOverhead must be positive",
                value: "\(parameters["monthlyOverhead"] ?? "nil")"
            )
        }
    }

    public func create(parameters: [String: Any]) throws -> Any {
        try validate(parameters: parameters)

        return ManufacturingModel(
            productionCapacity: parameters["productionCapacity"] as! Double,
            sellingPricePerUnit: parameters["sellingPricePerUnit"] as! Double,
            directMaterialCostPerUnit: parameters["directMaterialCostPerUnit"] as! Double,
            directLaborCostPerUnit: parameters["directLaborCostPerUnit"] as! Double,
            monthlyOverhead: parameters["monthlyOverhead"] as! Double
        )
    }
}

// MARK: - Marketplace Template

/// Template wrapper for marketplace business model
public struct MarketplaceTemplate: TemplateProtocol {
    public let identifier: String = "com.businessmath.templates.marketplace"

    public init() {}

    public func schema() -> TemplateSchema {
        TemplateSchema(
            parameters: [
                TemplateSchema.Parameter(
                    name: "initialBuyers",
                    type: .number,
                    description: "Number of buyers on the platform initially",
                    required: true
                ),
                TemplateSchema.Parameter(
                    name: "initialSellers",
                    type: .number,
                    description: "Number of sellers on the platform initially",
                    required: true
                ),
                TemplateSchema.Parameter(
                    name: "monthlyTransactionsPerBuyer",
                    type: .number,
                    description: "Average transactions per buyer per month",
                    required: true
                ),
                TemplateSchema.Parameter(
                    name: "averageOrderValue",
                    type: .number,
                    description: "Average order value per transaction",
                    required: true
                ),
                TemplateSchema.Parameter(
                    name: "takeRate",
                    type: .number,
                    description: "Platform commission rate (0.0 to 1.0)",
                    required: true
                ),
                TemplateSchema.Parameter(
                    name: "newBuyersPerMonth",
                    type: .number,
                    description: "New buyers acquired per month",
                    required: true
                ),
                TemplateSchema.Parameter(
                    name: "newSellersPerMonth",
                    type: .number,
                    description: "New sellers acquired per month",
                    required: true
                ),
                TemplateSchema.Parameter(
                    name: "buyerChurnRate",
                    type: .number,
                    description: "Monthly buyer churn rate (0.0 to 1.0)",
                    required: true
                ),
                TemplateSchema.Parameter(
                    name: "sellerChurnRate",
                    type: .number,
                    description: "Monthly seller churn rate (0.0 to 1.0)",
                    required: true
                )
            ]
        )
    }

    public func validate(parameters: [String: Any]) throws {
        guard let buyers = parameters["initialBuyers"] as? Double, buyers > 0 else {
            throw BusinessMathError.invalidInput(
                message: "initialBuyers must be positive",
                value: "\(parameters["initialBuyers"] ?? "nil")"
            )
        }

        guard let sellers = parameters["initialSellers"] as? Double, sellers > 0 else {
            throw BusinessMathError.invalidInput(
                message: "initialSellers must be positive",
                value: "\(parameters["initialSellers"] ?? "nil")"
            )
        }

        guard let txPerBuyer = parameters["monthlyTransactionsPerBuyer"] as? Double, txPerBuyer > 0 else {
            throw BusinessMathError.invalidInput(
                message: "monthlyTransactionsPerBuyer must be positive",
                value: "\(parameters["monthlyTransactionsPerBuyer"] ?? "nil")"
            )
        }

        guard let aov = parameters["averageOrderValue"] as? Double, aov > 0 else {
            throw BusinessMathError.invalidInput(
                message: "averageOrderValue must be positive",
                value: "\(parameters["averageOrderValue"] ?? "nil")"
            )
        }

        guard let takeRate = parameters["takeRate"] as? Double,
              takeRate >= 0, takeRate <= 1 else {
            throw BusinessMathError.invalidInput(
                message: "takeRate must be between 0.0 and 1.0",
                value: "\(parameters["takeRate"] ?? "nil")"
            )
        }

        guard let newBuyers = parameters["newBuyersPerMonth"] as? Double, newBuyers >= 0 else {
            throw BusinessMathError.invalidInput(
                message: "newBuyersPerMonth must be non-negative",
                value: "\(parameters["newBuyersPerMonth"] ?? "nil")"
            )
        }

        guard let newSellers = parameters["newSellersPerMonth"] as? Double, newSellers >= 0 else {
            throw BusinessMathError.invalidInput(
                message: "newSellersPerMonth must be non-negative",
                value: "\(parameters["newSellersPerMonth"] ?? "nil")"
            )
        }

        guard let buyerChurn = parameters["buyerChurnRate"] as? Double,
              buyerChurn >= 0, buyerChurn <= 1 else {
            throw BusinessMathError.invalidInput(
                message: "buyerChurnRate must be between 0.0 and 1.0",
                value: "\(parameters["buyerChurnRate"] ?? "nil")"
            )
        }

        guard let sellerChurn = parameters["sellerChurnRate"] as? Double,
              sellerChurn >= 0, sellerChurn <= 1 else {
            throw BusinessMathError.invalidInput(
                message: "sellerChurnRate must be between 0.0 and 1.0",
                value: "\(parameters["sellerChurnRate"] ?? "nil")"
            )
        }
    }

    public func create(parameters: [String: Any]) throws -> Any {
        try validate(parameters: parameters)

        return MarketplaceModel(
            initialBuyers: parameters["initialBuyers"] as! Double,
            initialSellers: parameters["initialSellers"] as! Double,
            monthlyTransactionsPerBuyer: parameters["monthlyTransactionsPerBuyer"] as! Double,
            averageOrderValue: parameters["averageOrderValue"] as! Double,
            takeRate: parameters["takeRate"] as! Double,
            newBuyersPerMonth: parameters["newBuyersPerMonth"] as! Double,
            newSellersPerMonth: parameters["newSellersPerMonth"] as! Double,
            buyerChurnRate: parameters["buyerChurnRate"] as! Double,
            sellerChurnRate: parameters["sellerChurnRate"] as! Double
        )
    }
}

// MARK: - Subscription Box Template

/// Template wrapper for subscription box business model
public struct SubscriptionBoxTemplate: TemplateProtocol {
    public let identifier: String = "com.businessmath.templates.subscriptionbox"

    public init() {}

    public func schema() -> TemplateSchema {
        TemplateSchema(
            parameters: [
                TemplateSchema.Parameter(
                    name: "initialSubscribers",
                    type: .number,
                    description: "Number of subscribers at start",
                    required: true
                ),
                TemplateSchema.Parameter(
                    name: "monthlyBoxPrice",
                    type: .number,
                    description: "Monthly subscription price",
                    required: true
                ),
                TemplateSchema.Parameter(
                    name: "costOfGoodsPerBox",
                    type: .number,
                    description: "Cost of goods per box",
                    required: true
                ),
                TemplateSchema.Parameter(
                    name: "shippingCostPerBox",
                    type: .number,
                    description: "Shipping cost per box",
                    required: true
                ),
                TemplateSchema.Parameter(
                    name: "monthlyChurnRate",
                    type: .number,
                    description: "Monthly subscriber churn rate (0.0 to 1.0)",
                    required: true
                ),
                TemplateSchema.Parameter(
                    name: "newSubscribersPerMonth",
                    type: .number,
                    description: "New subscribers acquired per month",
                    required: true
                ),
                TemplateSchema.Parameter(
                    name: "customerAcquisitionCost",
                    type: .number,
                    description: "Cost to acquire each subscriber",
                    required: true
                )
            ]
        )
    }

    public func validate(parameters: [String: Any]) throws {
        guard let subscribers = parameters["initialSubscribers"] as? Double, subscribers > 0 else {
            throw BusinessMathError.invalidInput(
                message: "initialSubscribers must be positive",
                value: "\(parameters["initialSubscribers"] ?? "nil")"
            )
        }

        guard let price = parameters["monthlyBoxPrice"] as? Double, price > 0 else {
            throw BusinessMathError.invalidInput(
                message: "monthlyBoxPrice must be positive",
                value: "\(parameters["monthlyBoxPrice"] ?? "nil")"
            )
        }

        guard let cogs = parameters["costOfGoodsPerBox"] as? Double, cogs > 0 else {
            throw BusinessMathError.invalidInput(
                message: "costOfGoodsPerBox must be positive",
                value: "\(parameters["costOfGoodsPerBox"] ?? "nil")"
            )
        }

        guard let shipping = parameters["shippingCostPerBox"] as? Double, shipping > 0 else {
            throw BusinessMathError.invalidInput(
                message: "shippingCostPerBox must be positive",
                value: "\(parameters["shippingCostPerBox"] ?? "nil")"
            )
        }

        guard let churn = parameters["monthlyChurnRate"] as? Double,
              churn >= 0, churn <= 1 else {
            throw BusinessMathError.invalidInput(
                message: "monthlyChurnRate must be between 0.0 and 1.0",
                value: "\(parameters["monthlyChurnRate"] ?? "nil")"
            )
        }

        guard let newSubs = parameters["newSubscribersPerMonth"] as? Double, newSubs > 0 else {
            throw BusinessMathError.invalidInput(
                message: "newSubscribersPerMonth must be positive",
                value: "\(parameters["newSubscribersPerMonth"] ?? "nil")"
            )
        }

        guard let cac = parameters["customerAcquisitionCost"] as? Double, cac > 0 else {
            throw BusinessMathError.invalidInput(
                message: "customerAcquisitionCost must be positive",
                value: "\(parameters["customerAcquisitionCost"] ?? "nil")"
            )
        }
    }

    public func create(parameters: [String: Any]) throws -> Any {
        try validate(parameters: parameters)

        return SubscriptionBoxModel(
            initialSubscribers: parameters["initialSubscribers"] as! Double,
            monthlyBoxPrice: parameters["monthlyBoxPrice"] as! Double,
            costOfGoodsPerBox: parameters["costOfGoodsPerBox"] as! Double,
            shippingCostPerBox: parameters["shippingCostPerBox"] as! Double,
            monthlyChurnRate: parameters["monthlyChurnRate"] as! Double,
            newSubscribersPerMonth: parameters["newSubscribersPerMonth"] as! Double,
            customerAcquisitionCost: parameters["customerAcquisitionCost"] as! Double
        )
    }
}

// MARK: - Real Estate Template

/// Template wrapper for real estate investment model
public struct RealEstateTemplate: TemplateProtocol {
    public let identifier: String = "com.businessmath.templates.realestate"

    public init() {}

    public func schema() -> TemplateSchema {
        TemplateSchema(
            parameters: [
                TemplateSchema.Parameter(
                    name: "purchasePrice",
                    type: .number,
                    description: "Purchase price of the property",
                    required: true
                ),
                TemplateSchema.Parameter(
                    name: "downPaymentPercentage",
                    type: .number,
                    description: "Down payment as percentage (0.0 to 1.0)",
                    required: true
                ),
                TemplateSchema.Parameter(
                    name: "interestRate",
                    type: .number,
                    description: "Annual interest rate on mortgage (0.0 to 1.0)",
                    required: true
                ),
                TemplateSchema.Parameter(
                    name: "loanTermYears",
                    type: .number,
                    description: "Loan term in years",
                    required: true
                ),
                TemplateSchema.Parameter(
                    name: "annualRent",
                    type: .number,
                    description: "Expected annual rental income",
                    required: true
                ),
                TemplateSchema.Parameter(
                    name: "vacancyRate",
                    type: .number,
                    description: "Vacancy rate (0.0 to 1.0)",
                    required: false
                ),
                TemplateSchema.Parameter(
                    name: "annualOperatingExpenses",
                    type: .number,
                    description: "Annual operating expenses",
                    required: true
                ),
                TemplateSchema.Parameter(
                    name: "annualAppreciationRate",
                    type: .number,
                    description: "Annual property appreciation rate (0.0 to 1.0)",
                    required: true
                ),
                TemplateSchema.Parameter(
                    name: "closingCostsPercentage",
                    type: .number,
                    description: "Closing costs as percentage (0.0 to 1.0)",
                    required: false
                ),
                TemplateSchema.Parameter(
                    name: "rentGrowthRate",
                    type: .number,
                    description: "Annual rent increase rate (0.0 to 1.0)",
                    required: false
                ),
                TemplateSchema.Parameter(
                    name: "depreciationPeriodYears",
                    type: .number,
                    description: "Property depreciation period in years",
                    required: false
                ),
                TemplateSchema.Parameter(
                    name: "taxRate",
                    type: .number,
                    description: "Marginal tax rate for investor (0.0 to 1.0)",
                    required: false
                )
            ],
            examples: [
                "single-family": [
                    "purchasePrice": "500000",
                    "downPaymentPercentage": "0.25",
                    "interestRate": "0.055",
                    "loanTermYears": "30",
                    "annualRent": "36000",
                    "annualOperatingExpenses": "12000",
                    "annualAppreciationRate": "0.03"
                ],
                "multifamily": [
                    "purchasePrice": "1200000",
                    "downPaymentPercentage": "0.30",
                    "interestRate": "0.06",
                    "loanTermYears": "30",
                    "annualRent": "120000",
                    "vacancyRate": "0.08",
                    "annualOperatingExpenses": "45000",
                    "annualAppreciationRate": "0.025"
                ]
            ]
        )
    }

    public func validate(parameters: [String: Any]) throws {
        guard let purchasePrice = parameters["purchasePrice"] as? Double, purchasePrice > 0 else {
            throw BusinessMathError.invalidInput(
                message: "purchasePrice must be positive",
                value: "\(parameters["purchasePrice"] ?? "nil")"
            )
        }

        guard let downPayment = parameters["downPaymentPercentage"] as? Double,
              downPayment >= 0, downPayment <= 1 else {
            throw BusinessMathError.invalidInput(
                message: "downPaymentPercentage must be between 0.0 and 1.0",
                value: "\(parameters["downPaymentPercentage"] ?? "nil")"
            )
        }

        guard let interestRate = parameters["interestRate"] as? Double,
              interestRate >= 0, interestRate <= 1 else {
            throw BusinessMathError.invalidInput(
                message: "interestRate must be between 0.0 and 1.0",
                value: "\(parameters["interestRate"] ?? "nil")"
            )
        }

        guard let loanTerm = parameters["loanTermYears"] as? Double, loanTerm > 0 else {
            throw BusinessMathError.invalidInput(
                message: "loanTermYears must be positive",
                value: "\(parameters["loanTermYears"] ?? "nil")"
            )
        }

        guard let rent = parameters["annualRent"] as? Double, rent > 0 else {
            throw BusinessMathError.invalidInput(
                message: "annualRent must be positive",
                value: "\(parameters["annualRent"] ?? "nil")"
            )
        }

        if let vacancy = parameters["vacancyRate"] as? Double {
            guard vacancy >= 0, vacancy <= 1 else {
                throw BusinessMathError.invalidInput(
                    message: "vacancyRate must be between 0.0 and 1.0",
                    value: "\(vacancy)"
                )
            }
        }

        guard let opex = parameters["annualOperatingExpenses"] as? Double, opex > 0 else {
            throw BusinessMathError.invalidInput(
                message: "annualOperatingExpenses must be positive",
                value: "\(parameters["annualOperatingExpenses"] ?? "nil")"
            )
        }

        guard let appreciation = parameters["annualAppreciationRate"] as? Double,
              appreciation >= -1, appreciation <= 1 else {
            throw BusinessMathError.invalidInput(
                message: "annualAppreciationRate must be between -1.0 and 1.0",
                value: "\(parameters["annualAppreciationRate"] ?? "nil")"
            )
        }

        if let closingCosts = parameters["closingCostsPercentage"] as? Double {
            guard closingCosts >= 0, closingCosts <= 1 else {
                throw BusinessMathError.invalidInput(
                    message: "closingCostsPercentage must be between 0.0 and 1.0",
                    value: "\(closingCosts)"
                )
            }
        }

        if let rentGrowth = parameters["rentGrowthRate"] as? Double {
            guard rentGrowth >= -1, rentGrowth <= 1 else {
                throw BusinessMathError.invalidInput(
                    message: "rentGrowthRate must be between -1.0 and 1.0",
                    value: "\(rentGrowth)"
                )
            }
        }

        if let taxRate = parameters["taxRate"] as? Double {
            guard taxRate >= 0, taxRate <= 1 else {
                throw BusinessMathError.invalidInput(
                    message: "taxRate must be between 0.0 and 1.0",
                    value: "\(taxRate)"
                )
            }
        }
    }

    public func create(parameters: [String: Any]) throws -> Any {
        try validate(parameters: parameters)

        return RealEstateModel(
            purchasePrice: parameters["purchasePrice"] as! Double,
            downPaymentPercentage: parameters["downPaymentPercentage"] as! Double,
            interestRate: parameters["interestRate"] as! Double,
            loanTermYears: Int(parameters["loanTermYears"] as! Double),
            annualRent: parameters["annualRent"] as! Double,
            vacancyRate: parameters["vacancyRate"] as? Double ?? 0.05,
            annualOperatingExpenses: parameters["annualOperatingExpenses"] as! Double,
            annualAppreciationRate: parameters["annualAppreciationRate"] as! Double,
            closingCostsPercentage: parameters["closingCostsPercentage"] as? Double ?? 0.03,
            rentGrowthRate: parameters["rentGrowthRate"] as? Double ?? 0.025,
            depreciationPeriodYears: parameters["depreciationPeriodYears"] as? Double ?? 27.5,
            taxRate: parameters["taxRate"] as? Double ?? 0.24
        )
    }
}
