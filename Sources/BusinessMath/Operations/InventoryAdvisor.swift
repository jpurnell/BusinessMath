//
//  InventoryAdvisor.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-05-09.
//

import Foundation
import Numerics

/// A decision-support tool that recommends the appropriate inventory model based on
/// available data.
///
/// Many Shopify-scale vendors lack deep operations expertise. `InventoryAdvisor`
/// examines what data the user has and routes them to the right model — analytical
/// safety stock, newsvendor, EOQ, or Monte Carlo simulation — with plain-language
/// reasoning for each recommendation.
///
/// ```swift
/// let profile = InventoryAdvisor.DataProfile(
///     demandHistory: dailySales,
///     leadTimeMean: 7.0,
///     leadTimeStdDev: 2.0
/// )
/// let rec = InventoryAdvisor.recommended(for: profile)
/// print(rec.recommendedModel)  // .reorderPoint
/// print(rec.reasoning)         // ["Lead time variability detected...", ...]
/// ```
public struct InventoryAdvisor: Sendable {

    /// Describes what data the user has available for inventory decisions.
    public struct DataProfile: Sendable {
        /// Historical demand observations per period.
        public let demandHistory: [Double]
        /// The mean replenishment lead time in periods.
        public let leadTimeMean: Double
        /// The standard deviation of lead time, if known.
        public let leadTimeStdDev: Double?
        /// The root mean square error of a demand forecast, if available.
        public let forecastRMSE: Double?
        /// The per-unit cost of stocking too few (underage cost), for newsvendor analysis.
        public let underageCost: Double?
        /// The per-unit cost of stocking too many (overage cost), for newsvendor analysis.
        public let overageCost: Double?
        /// Whether the product is perishable or seasonal (single selling period).
        public let isPerishable: Bool
        /// Annual demand in units, for EOQ analysis.
        public let annualDemand: Double?
        /// Fixed cost per order placed, for EOQ analysis.
        public let orderingCost: Double?
        /// Annual holding cost per unit, for EOQ analysis.
        public let holdingCostPerUnit: Double?

        /// Creates an inventory context from demand history and optional supply-chain parameters.
        ///
        /// - Parameters:
        ///   - demandHistory: Historical demand observations used to estimate demand distribution.
        ///   - leadTimeMean: Average replenishment lead time in the same time unit as demand observations.
        ///   - leadTimeStdDev: Standard deviation of lead time; `nil` assumes deterministic lead time.
        ///   - forecastRMSE: Root-mean-square forecast error for safety-stock sizing.
        ///   - underageCost: Per-unit cost of a stockout (lost-sale or backorder penalty).
        ///   - overageCost: Per-unit cost of excess inventory (holding or obsolescence).
        ///   - isPerishable: Whether the item has a limited shelf life.
        ///   - annualDemand: Annualised demand; inferred from history when `nil`.
        ///   - orderingCost: Fixed cost per order, used for EOQ analysis.
        ///   - holdingCostPerUnit: Annual holding cost per unit, used for EOQ analysis.
        public init(
            demandHistory: [Double],
            leadTimeMean: Double,
            leadTimeStdDev: Double? = nil,
            forecastRMSE: Double? = nil,
            underageCost: Double? = nil,
            overageCost: Double? = nil,
            isPerishable: Bool = false,
            annualDemand: Double? = nil,
            orderingCost: Double? = nil,
            holdingCostPerUnit: Double? = nil
        ) {
            self.demandHistory = demandHistory
            self.leadTimeMean = leadTimeMean
            self.leadTimeStdDev = leadTimeStdDev
            self.forecastRMSE = forecastRMSE
            self.underageCost = underageCost
            self.overageCost = overageCost
            self.isPerishable = isPerishable
            self.annualDemand = annualDemand
            self.orderingCost = orderingCost
            self.holdingCostPerUnit = holdingCostPerUnit
        }
    }

    /// The primary inventory model recommended for the user's situation.
    public enum RecommendedModel: String, Sendable {
        /// Reorder point / safety stock model for continuous replenishment.
        case reorderPoint
        /// Newsvendor model for perishable or single-period items.
        case newsvendor
    }

    /// The output of the advisor: which models to use, why, and how.
    public struct Recommendation: Sendable {
        /// The primary inventory model recommended.
        public let recommendedModel: RecommendedModel
        /// The safety stock calculation method to use with the reorder point model.
        public let safetyStockMethod: SafetyStockModel<Double>.Method?
        /// Whether simulation is recommended in addition to analytical methods.
        public let simulationRecommended: Bool
        /// The sampling strategy to use if simulation is recommended.
        public let samplingStrategy: InventorySimulator.SamplingStrategy?
        /// Whether EOQ analysis is applicable given the available cost data.
        public let eoqApplicable: Bool
        /// Plain-language explanations for each recommendation decision.
        public let reasoning: [String]
    }

    private static let minimumHistoryForSimulation = 30

    /// Analyzes the available data and recommends the appropriate inventory model configuration.
    ///
    /// The advisor follows this decision tree:
    /// 1. If the item is perishable and cost data is available → newsvendor
    /// 2. If forecast RMSE is available → forecast-error safety stock method
    /// 3. If lead time variability is known → demand-and-lead-time method
    /// 4. Otherwise → demand-only method
    ///
    /// Simulation is recommended when at least 30 demand observations are available,
    /// and EOQ is flagged when ordering/holding cost data is present.
    ///
    /// - Parameter profile: A ``DataProfile`` describing what data the user has.
    /// - Returns: A ``Recommendation`` with model choices, strategy, and reasoning.
    public static func recommended(for profile: DataProfile) -> Recommendation {
        var reasoning: [String] = []
        var model: RecommendedModel = .reorderPoint
        var ssMethod: SafetyStockModel<Double>.Method? = .demandOnly
        var simRecommended = false
        var samplingStrat: InventorySimulator.SamplingStrategy? = nil
        var eoq = false

        let hasLeadTimeVariability = profile.leadTimeStdDev.map { $0 > 0 } ?? false
        let hasForecastRMSE = profile.forecastRMSE.map { $0 > 0 } ?? false
        let hasCostData = profile.underageCost != nil && profile.overageCost != nil
        let hasEOQData = profile.annualDemand != nil
            && profile.orderingCost != nil
            && profile.holdingCostPerUnit != nil
        let historyCount = profile.demandHistory.count

        if profile.isPerishable && hasCostData {
            model = .newsvendor
            ssMethod = nil
            reasoning.append(
                "Item is perishable with known underage/overage costs — the newsvendor model "
                + "finds the single-period optimal order quantity that balances stockout risk "
                + "against spoilage cost."
            )
        } else if profile.isPerishable {
            model = .reorderPoint
            reasoning.append(
                "Item is perishable, but underage and overage cost data is not available. "
                + "Falling back to reorder point model — provide per-unit cost of stockout "
                + "and per-unit cost of excess to enable newsvendor analysis."
            )
        }

        if model == .reorderPoint {
            if hasForecastRMSE {
                ssMethod = .forecastError
                reasoning.append(
                    "Forecast RMSE is available — using the forecast-error safety stock method, "
                    + "which accounts for systematic forecast bias rather than raw demand variability."
                )
            } else if hasLeadTimeVariability {
                ssMethod = .demandAndLeadTime
                reasoning.append(
                    "Lead time variability detected — using the combined demand-and-lead-time "
                    + "safety stock formula, which accounts for both sources of uncertainty: "
                    + "SS = z × √(L × σ_d² + d̄² × σ_L²)."
                )
            } else {
                ssMethod = .demandOnly
                reasoning.append(
                    "Using demand-only safety stock method: SS = z × σ_d × √L. "
                    + "To improve accuracy, provide lead time variability or forecast RMSE."
                )
            }
        }

        if historyCount >= minimumHistoryForSimulation {
            simRecommended = true
            samplingStrat = .empirical
            reasoning.append(
                "With \(historyCount) demand observations, Monte Carlo simulation is recommended "
                + "to capture non-normal demand patterns. Empirical (bootstrap) sampling preserves "
                + "the actual demand distribution without distributional assumptions."
            )
        } else {
            simRecommended = false
            reasoning.append(
                "Only \(historyCount) demand observations available — insufficient for reliable "
                + "simulation (minimum 30 recommended). Using analytical methods only."
            )
        }

        if hasEOQData {
            eoq = true
            reasoning.append(
                "Ordering and holding cost data is available — EOQ analysis can determine the "
                + "optimal order quantity that minimizes total annual inventory cost."
            )
        }

        return Recommendation(
            recommendedModel: model,
            safetyStockMethod: ssMethod,
            simulationRecommended: simRecommended,
            samplingStrategy: samplingStrat,
            eoqApplicable: eoq,
            reasoning: reasoning
        )
    }
}
