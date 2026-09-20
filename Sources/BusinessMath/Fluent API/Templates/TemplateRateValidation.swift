//
//  TemplateRateValidation.swift
//  BusinessMath
//

import Foundation

/// The one place a template's churn or retention rate is checked.
///
/// The range is not new. `StandardTemplates.createSaaSModel(parameters:)` has always rejected
/// a `churnRate` outside `0.0...1.0` with exactly this error, and `SaaSModel.retentionRate`
/// and `SubscriptionBoxModel.retentionRate` have always guarded the same three conditions
/// before answering. What was missing was any check on the path that projects a customer
/// count, so a model the template constructor would have refused could be built directly and
/// asked to project — and it answered.
///
/// A churn rate above 1 means the model loses more customers than it has. `SaaSModel` at
/// `churnRate: 1.2` with a hundred customers and no acquisition returned **−20** customers for
/// month 1: a negative headcount, arrived at by arithmetic that is individually correct at
/// every step. `SubscriptionBoxModel.calculateSubscribers` and `MarketplaceModel`'s buyer and
/// seller counts had the same shape, because they are the same recurrence.
///
/// Collected here rather than repeated per model because the same range had already been
/// written out four times, in two files, and the copies had already diverged: two guarded and
/// returned `nil`, one threw, and the projections did neither.
///
/// - Parameters:
///   - value: The rate to check.
///   - name: The property's name, for the error message.
/// - Returns: `value`, unchanged, when it is a usable rate.
/// - Throws: ``BusinessMathError/invalidInput(message:value:expectedRange:)`` when `value` is
///   not finite or falls outside `0.0...1.0`.
internal func validatedRate(_ value: Double, named name: String) throws -> Double {
	guard value.isFinite, value >= 0, value <= 1 else {
		throw BusinessMathError.invalidInput(
			message: "\(name) must be between 0.0 and 1.0",
			value: "\(value)",
			expectedRange: "0.0 to 1.0"
		)
	}
	return value
}
