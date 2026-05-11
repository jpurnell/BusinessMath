import Foundation
import Numerics

/// Performs a decision study (D-study) based on G-study variance components.
///
/// Projects the reliability of measurements under alternative designs by
/// specifying new sample sizes for each facet. Computes both relative
/// (generalizability coefficient, rho-squared) and absolute (dependability
/// coefficient, Phi) reliability indices.
///
/// For relative decisions (ranking persons):
/// ```
/// rho^2 = sigma_p^2 / (sigma_p^2 + sigma_delta^2)
/// ```
///
/// For absolute decisions (comparing to a standard):
/// ```
/// Phi = sigma_p^2 / (sigma_p^2 + sigma_Delta^2)
/// ```
///
/// - Parameters:
///   - gResult: The G-study result containing variance components and facet information.
///   - design: Dictionary mapping facet labels to their projected sample sizes.
///     Must contain an entry for every facet in the G-study, with values >= 1.
/// - Returns: A ``DStudyResult`` with reliability coefficients and error variances.
/// - Throws: `BusinessMathError.invalidInput` if design facets don't match the G-study
///   facets or if any facet size is less than 1.
public func dStudy<T: Real>(
	_ gResult: GStudyResult<T>,
	design: [String: Int]
) throws -> DStudyResult<T> {
	// Validate that design contains exactly the facets from the G-study
	let gFacetLabels = Set(gResult.facets.map { $0.label })
	let designLabels = Set(design.keys)

	guard gFacetLabels == designLabels else {
		throw BusinessMathError.invalidInput(
			message: "Design facets must match G-study facets",
			value: "\(designLabels.sorted())",
			expectedRange: "\(gFacetLabels.sorted())")
	}

	// Validate all facet sizes >= 1
	for (label, size) in design {
		guard size >= 1 else {
			throw BusinessMathError.invalidInput(
				message: "Facet size must be at least 1",
				value: "\(label): \(size)",
				expectedRange: ">= 1")
		}
	}

	let sigmaP = gResult.variancePersons

	if gResult.facets.count == 1 {
		return try oneFacetDStudy(gResult, design: design, sigmaP: sigmaP)
	} else {
		return try twoFacetDStudy(gResult, design: design, sigmaP: sigmaP)
	}
}

// MARK: - Private Helpers

/// Computes a one-facet D-study.
private func oneFacetDStudy<T: Real>(
	_ gResult: GStudyResult<T>,
	design: [String: Int],
	sigmaP: T
) throws -> DStudyResult<T> {
	let facetLabel = gResult.facets[0].label
	let nrPrime = T(design[facetLabel] ?? 1)

	// Find variance components by source
	let sigmaR = varianceFor(source: facetLabel, in: gResult)
	let sigmaE = varianceFor(source: "p x \(facetLabel)", in: gResult)

	// Relative error: sigma_delta^2 = sigma_e^2 / n_r'
	let relativeError = sigmaE / nrPrime

	// Absolute error: sigma_Delta^2 = sigma_r^2 / n_r' + sigma_e^2 / n_r'
	let absoluteError = sigmaR / nrPrime + sigmaE / nrPrime

	// Coefficients (guard against zero denominator)
	let rhoSquared: T
	let phi: T

	let relDenom = sigmaP + relativeError
	let absDenom = sigmaP + absoluteError

	if relDenom > T.zero {
		rhoSquared = sigmaP / relDenom
	} else {
		rhoSquared = T.zero
	}

	if absDenom > T.zero {
		phi = sigmaP / absDenom
	} else {
		phi = T.zero
	}

	let sem = T.sqrt(absoluteError)

	return DStudyResult(
		generalizabilityCoefficient: rhoSquared,
		dependabilityCoefficient: phi,
		relativeErrorVariance: relativeError,
		absoluteErrorVariance: absoluteError,
		standardErrorOfMeasurement: sem,
		designFacets: design
	)
}

/// Computes a two-facet D-study.
private func twoFacetDStudy<T: Real>(
	_ gResult: GStudyResult<T>,
	design: [String: Int],
	sigmaP: T
) throws -> DStudyResult<T> {
	let label1 = gResult.facets[0].label
	let label2 = gResult.facets[1].label
	let nr = T(design[label1] ?? 1)
	let ni = T(design[label2] ?? 1)
	let nri = nr * ni

	// Find variance components by source
	let sigmaR = varianceFor(source: label1, in: gResult)
	let sigmaI = varianceFor(source: label2, in: gResult)
	let sigmaPR = varianceFor(source: "p x \(label1)", in: gResult)
	let sigmaPI = varianceFor(source: "p x \(label2)", in: gResult)
	let sigmaRI = varianceFor(source: "\(label1) x \(label2)", in: gResult)
	let sigmaE = varianceFor(source: "p x \(label1) x \(label2)", in: gResult)

	// Relative error:
	// sigma_delta^2 = sigma_pr/n_r' + sigma_pi/n_i' + sigma_e/(n_r'*n_i')
	let relativeError = sigmaPR / nr + sigmaPI / ni + sigmaE / nri

	// Absolute error:
	// sigma_Delta^2 = sigma_r/n_r' + sigma_i/n_i' + sigma_pr/n_r'
	//              + sigma_pi/n_i' + sigma_ri/(n_r'*n_i') + sigma_e/(n_r'*n_i')
	let absoluteError = sigmaR / nr + sigmaI / ni
		+ sigmaPR / nr + sigmaPI / ni
		+ sigmaRI / nri + sigmaE / nri

	// Coefficients (guard against zero denominator)
	let rhoSquared: T
	let phi: T

	let relDenom = sigmaP + relativeError
	let absDenom = sigmaP + absoluteError

	if relDenom > T.zero {
		rhoSquared = sigmaP / relDenom
	} else {
		rhoSquared = T.zero
	}

	if absDenom > T.zero {
		phi = sigmaP / absDenom
	} else {
		phi = T.zero
	}

	let sem = T.sqrt(absoluteError)

	return DStudyResult(
		generalizabilityCoefficient: rhoSquared,
		dependabilityCoefficient: phi,
		relativeErrorVariance: relativeError,
		absoluteErrorVariance: absoluteError,
		standardErrorOfMeasurement: sem,
		designFacets: design
	)
}

/// Looks up the variance for a named source in a G-study result.
///
/// Returns zero if the source is not found (defensive against mismatched labels).
private func varianceFor<T: Real>(
	source: String,
	in gResult: GStudyResult<T>
) -> T {
	gResult.components.first { $0.source == source }?.variance ?? T.zero
}
