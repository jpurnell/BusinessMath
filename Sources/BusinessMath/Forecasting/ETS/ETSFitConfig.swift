//
//  ETSFitConfig.swift
//  BusinessMath
//
//  Step 3 of PROPOSAL_ets_fitting.md — what the parameter search is allowed to do.
//

import Foundation

/// How the smoothing-parameter search for a Holt-Winters fit is run.
///
/// The defaults suit every series this library has been tried on; a caller who never
/// touches this type gets a sensible search. The bounds exist because the search
/// optimises over an unbounded reparameterisation and maps back through a logistic, which
/// can only approach `0` and `1` asymptotically — so the feasible box is stated a hair
/// inside them and a parameter that saturates the transform is snapped to the true
/// boundary before it is reported.
///
/// ```swift
/// let tighter = ETSFitConfig(tolerance: 1e-9, maxIterations: 2000)
/// print(tighter.maxIterations)
/// ```
public struct ETSFitConfig: Sendable {

	/// Smallest smoothing value the search may propose. Defaults to `0.0001`.
	public let lowerBound: Double

	/// Largest smoothing value the search may propose. Defaults to `0.9999`.
	public let upperBound: Double

	/// Simplex-size tolerance the search converges to. Defaults to `1e-6`.
	public let tolerance: Double

	/// Iteration budget for each simplex restart. Defaults to `500`.
	public let maxIterations: Int

	/// Creates a fit configuration.
	///
	/// Values that cannot describe a search fall back to the defaults rather than being
	/// honoured — an inverted or degenerate box would delete the constraint silently,
	/// which is worse than any badly chosen pair. A bound outside `(0, 1)` is likewise
	/// replaced: the parameters being searched are smoothing weights and nothing outside
	/// the unit interval is meaningful for them.
	///
	/// - Parameters:
	///   - lowerBound: Smallest smoothing value the search may propose.
	///   - upperBound: Largest smoothing value the search may propose.
	///   - tolerance: Simplex-size tolerance.
	///   - maxIterations: Iteration budget per restart.
	public init(
		lowerBound: Double = 0.0001,
		upperBound: Double = 0.9999,
		tolerance: Double = 1e-6,
		maxIterations: Int = 500
	) {
		let fallbackLower = 0.0001
		let fallbackUpper = 0.9999
		let lowerIsUsable = lowerBound.isFinite && lowerBound > 0 && lowerBound < 1
		let upperIsUsable = upperBound.isFinite && upperBound > 0 && upperBound < 1
		let proposedLower = lowerIsUsable ? lowerBound : fallbackLower
		let proposedUpper = upperIsUsable ? upperBound : fallbackUpper
		let boxIsUsable = proposedLower < proposedUpper
		self.lowerBound = boxIsUsable ? proposedLower : fallbackLower
		self.upperBound = boxIsUsable ? proposedUpper : fallbackUpper
		let toleranceIsUsable = tolerance.isFinite && tolerance > 0
		self.tolerance = toleranceIsUsable ? tolerance : 1e-6
		self.maxIterations = maxIterations > 0 ? maxIterations : 500
	}

	/// The configuration used when a caller does not supply one.
	public static let `default` = ETSFitConfig()
}
