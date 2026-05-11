import Foundation
import Numerics

// MARK: - One-Facet G-Study (p x r)

/// Performs a one-facet generalizability study (p x r design).
///
/// Decomposes observed score variance into three components:
/// - Person variance (sigma-p-squared): true differences among persons.
/// - Facet variance (sigma-r-squared): systematic facet effects (e.g., rater leniency).
/// - Residual variance (sigma-e-squared): undifferentiated error including
///   person-by-facet interaction.
///
/// Uses the expected mean squares (EMS) from a two-way ANOVA without replication
/// to extract variance components:
/// ```
/// sigma_e^2 = MS_error
/// sigma_p^2 = (MS_persons - MS_error) / n_r
/// sigma_r^2 = (MS_facet - MS_error) / n_p
/// ```
///
/// Negative variance estimates are truncated to zero.
///
/// - Parameters:
///   - data: Matrix where `data[person][rater]` is the score for person `i`
///     rated by rater `j`. All rows must have the same length.
///   - facetLabel: Descriptive label for the facet (default: `"raters"`).
/// - Returns: A ``GStudyResult`` with three variance components.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 persons
///   or fewer than 2 raters. `BusinessMathError.mismatchedDimensions` if rows
///   have different lengths.
public func gStudy<T: Real>(
	_ data: [[T]],
	facetLabel: String = "raters"
) throws -> GStudyResult<T> {
	// Delegate dimensional validation to twoWayANOVA
	let anova = try twoWayANOVA(data)

	let nP = data.count
	let nR = data[0].count
	let nPT = T(nP)
	let nRT = T(nR)

	// Extract mean squares from ANOVA
	let msP = anova.msSubjects
	let msR = anova.msRaters
	let msE = anova.msError

	// Variance component extraction via EMS
	let sigmaE = msE
	let rawSigmaP = (msP - msE) / nRT
	let rawSigmaR = (msR - msE) / nPT

	// Truncate negative estimates to zero
	let sigmaP = rawSigmaP < T.zero ? T.zero : rawSigmaP
	let sigmaR = rawSigmaR < T.zero ? T.zero : rawSigmaR

	let total = sigmaP + sigmaR + sigmaE

	// Compute percentages (guard against all-zero variance)
	let hundred = T(100)
	let pctP: T
	let pctR: T
	let pctE: T
	if total > T.zero {
		pctP = sigmaP / total * hundred
		pctR = sigmaR / total * hundred
		pctE = sigmaE / total * hundred
	} else {
		pctP = T.zero
		pctR = T.zero
		pctE = T.zero
	}

	let components = [
		VarianceComponent(
			source: "p",
			variance: sigmaP,
			percentOfTotal: pctP,
			df: anova.dfSubjects,
			meanSquare: msP
		),
		VarianceComponent(
			source: facetLabel,
			variance: sigmaR,
			percentOfTotal: pctR,
			df: anova.dfRaters,
			meanSquare: msR
		),
		VarianceComponent(
			source: "p x \(facetLabel)",
			variance: sigmaE,
			percentOfTotal: pctE,
			df: anova.dfError,
			meanSquare: msE
		)
	]

	let facet = GFacet(label: facetLabel, levels: nR)

	return GStudyResult(
		components: components,
		facets: [facet],
		totalVariance: total,
		variancePersons: sigmaP,
		personCount: nP
	)
}

// MARK: - Two-Facet G-Study (p x r x i)

/// Performs a two-facet generalizability study (p x r x i design).
///
/// Decomposes observed score variance into seven components using a fully
/// crossed three-way ANOVA:
/// - Person (p), Rater (r), Item (i)
/// - Person x Rater (pr), Person x Item (pi), Rater x Item (ri)
/// - Residual (p x r x i, confounded with higher-order interactions)
///
/// The data must be a balanced three-dimensional array where
/// `data[person][rater][item]` is the score.
///
/// Negative variance estimates are truncated to zero.
///
/// - Parameters:
///   - data: Three-dimensional array where `data[p][r][i]` is the score for
///     person `p`, rater `r`, item `i`. Must be fully balanced (rectangular).
///   - facetLabels: Labels for the two facets (default: `("raters", "items")`).
/// - Returns: A ``GStudyResult`` with seven variance components.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 persons,
///   2 levels of facet 1, or 2 levels of facet 2.
///   `BusinessMathError.mismatchedDimensions` if the data is not rectangular.
public func gStudy<T: Real>(
	_ data: [[[T]]],
	facetLabels: (String, String) = ("raters", "items")
) throws -> GStudyResult<T> {
	let nP = data.count

	guard nP >= 2 else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: nP,
			context: "G-study requires at least 2 persons")
	}

	guard !data[0].isEmpty else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: 0,
			context: "G-study requires at least 2 levels of \(facetLabels.0)")
	}

	let nR = data[0].count

	guard nR >= 2 else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: nR,
			context: "G-study requires at least 2 levels of \(facetLabels.0)")
	}

	guard !data[0][0].isEmpty else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: 0,
			context: "G-study requires at least 2 levels of \(facetLabels.1)")
	}

	let nI = data[0][0].count

	guard nI >= 2 else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: nI,
			context: "G-study requires at least 2 levels of \(facetLabels.1)")
	}

	// Validate balanced design
	for p in 0..<nP {
		guard data[p].count == nR else {
			throw BusinessMathError.mismatchedDimensions(
				message: "All persons must have the same number of \(facetLabels.0)",
				expected: "\(nR)", actual: "\(data[p].count)")
		}
		for r in 0..<nR {
			guard data[p][r].count == nI else {
				throw BusinessMathError.mismatchedDimensions(
					message: "All rater-person cells must have the same number of \(facetLabels.1)",
					expected: "\(nI)", actual: "\(data[p][r].count)")
			}
		}
	}

	let nPT = T(nP)
	let nRT = T(nR)
	let nIT = T(nI)
	let nTotal = T(nP * nR * nI)

	// Compute grand mean
	var grandSum = T.zero
	for p in 0..<nP {
		for r in 0..<nR {
			for i in 0..<nI {
				grandSum += data[p][r][i]
			}
		}
	}
	let grandMean = grandSum / nTotal

	// Compute marginal means
	// Person means X_p..
	var personMeans = [T](repeating: T.zero, count: nP)
	for p in 0..<nP {
		var sum = T.zero
		for r in 0..<nR {
			for i in 0..<nI {
				sum += data[p][r][i]
			}
		}
		personMeans[p] = sum / (nRT * nIT)
	}

	// Rater means X_.r.
	var raterMeans = [T](repeating: T.zero, count: nR)
	for r in 0..<nR {
		var sum = T.zero
		for p in 0..<nP {
			for i in 0..<nI {
				sum += data[p][r][i]
			}
		}
		raterMeans[r] = sum / (nPT * nIT)
	}

	// Item means X_..i
	var itemMeans = [T](repeating: T.zero, count: nI)
	for i in 0..<nI {
		var sum = T.zero
		for p in 0..<nP {
			for r in 0..<nR {
				sum += data[p][r][i]
			}
		}
		itemMeans[i] = sum / (nPT * nRT)
	}

	// Person x Rater means X_pr.
	var prMeans = [[T]](repeating: [T](repeating: T.zero, count: nR), count: nP)
	for p in 0..<nP {
		for r in 0..<nR {
			var sum = T.zero
			for i in 0..<nI {
				sum += data[p][r][i]
			}
			prMeans[p][r] = sum / nIT
		}
	}

	// Person x Item means X_p.i
	var piMeans = [[T]](repeating: [T](repeating: T.zero, count: nI), count: nP)
	for p in 0..<nP {
		for i in 0..<nI {
			var sum = T.zero
			for r in 0..<nR {
				sum += data[p][r][i]
			}
			piMeans[p][i] = sum / nRT
		}
	}

	// Rater x Item means X_.ri
	var riMeans = [[T]](repeating: [T](repeating: T.zero, count: nI), count: nR)
	for r in 0..<nR {
		for i in 0..<nI {
			var sum = T.zero
			for p in 0..<nP {
				sum += data[p][r][i]
			}
			riMeans[r][i] = sum / nPT
		}
	}

	// Sums of squares
	// SS_p = n_r * n_i * sum_p (X_p.. - X_...)^2
	var ssP = T.zero
	for p in 0..<nP {
		let diff = personMeans[p] - grandMean
		ssP += diff * diff
	}
	ssP = nRT * nIT * ssP

	// SS_r = n_p * n_i * sum_r (X_.r. - X_...)^2
	var ssR = T.zero
	for r in 0..<nR {
		let diff = raterMeans[r] - grandMean
		ssR += diff * diff
	}
	ssR = nPT * nIT * ssR

	// SS_i = n_p * n_r * sum_i (X_..i - X_...)^2
	var ssI = T.zero
	for i in 0..<nI {
		let diff = itemMeans[i] - grandMean
		ssI += diff * diff
	}
	ssI = nPT * nRT * ssI

	// SS_pr = n_i * sum_pr (X_pr. - X_p.. - X_.r. + X_...)^2
	var ssPR = T.zero
	for p in 0..<nP {
		for r in 0..<nR {
			let diff = prMeans[p][r] - personMeans[p] - raterMeans[r] + grandMean
			ssPR += diff * diff
		}
	}
	ssPR = nIT * ssPR

	// SS_pi = n_r * sum_pi (X_p.i - X_p.. - X_..i + X_...)^2
	var ssPI = T.zero
	for p in 0..<nP {
		for i in 0..<nI {
			let diff = piMeans[p][i] - personMeans[p] - itemMeans[i] + grandMean
			ssPI += diff * diff
		}
	}
	ssPI = nRT * ssPI

	// SS_ri = n_p * sum_ri (X_.ri - X_.r. - X_..i + X_...)^2
	var ssRI = T.zero
	for r in 0..<nR {
		for i in 0..<nI {
			let diff = riMeans[r][i] - raterMeans[r] - itemMeans[i] + grandMean
			ssRI += diff * diff
		}
	}
	ssRI = nPT * ssRI

	// SS_total = sum_pri (X_pri - X_...)^2
	var ssTotal = T.zero
	for p in 0..<nP {
		for r in 0..<nR {
			for i in 0..<nI {
				let diff = data[p][r][i] - grandMean
				ssTotal += diff * diff
			}
		}
	}

	// SS_e = SS_total - SS_p - SS_r - SS_i - SS_pr - SS_pi - SS_ri
	let ssE = ssTotal - ssP - ssR - ssI - ssPR - ssPI - ssRI

	// Degrees of freedom
	let dfP = nP - 1
	let dfR = nR - 1
	let dfI = nI - 1
	let dfPR = dfP * dfR
	let dfPI = dfP * dfI
	let dfRI = dfR * dfI
	let dfE = dfP * dfR * dfI

	// Mean squares (safe: all df >= 1 given the guards above)
	let msP = ssP / T(dfP)
	let msR = ssR / T(dfR)
	let msI = ssI / T(dfI)
	let msPR: T = dfPR > 0 ? ssPR / T(dfPR) : T.zero
	let msPI: T = dfPI > 0 ? ssPI / T(dfPI) : T.zero
	let msRI: T = dfRI > 0 ? ssRI / T(dfRI) : T.zero
	let msE: T = dfE > 0 ? ssE / T(dfE) : T.zero

	// Variance components via EMS
	let sigmaE = msE
	let rawSigmaPR = (msPR - msE) / nIT
	let rawSigmaPI = (msPI - msE) / nRT
	let rawSigmaRI = (msRI - msE) / nPT
	let rawSigmaP = (msP - msPR - msPI + msE) / (nRT * nIT)
	let rawSigmaR = (msR - msPR - msRI + msE) / (nPT * nIT)
	let rawSigmaI = (msI - msPI - msRI + msE) / (nPT * nRT)

	// Truncate negative estimates to zero
	let sigmaP = rawSigmaP < T.zero ? T.zero : rawSigmaP
	let sigmaR = rawSigmaR < T.zero ? T.zero : rawSigmaR
	let sigmaI = rawSigmaI < T.zero ? T.zero : rawSigmaI
	let sigmaPR = rawSigmaPR < T.zero ? T.zero : rawSigmaPR
	let sigmaPI = rawSigmaPI < T.zero ? T.zero : rawSigmaPI
	let sigmaRI = rawSigmaRI < T.zero ? T.zero : rawSigmaRI

	let total = sigmaP + sigmaR + sigmaI + sigmaPR + sigmaPI + sigmaRI + sigmaE

	// Compute percentages
	let hundred = T(100)
	let pcts: [T]
	if total > T.zero {
		pcts = [sigmaP, sigmaR, sigmaI, sigmaPR, sigmaPI, sigmaRI, sigmaE]
			.map { $0 / total * hundred }
	} else {
		pcts = [T](repeating: T.zero, count: 7)
	}

	let label1 = facetLabels.0
	let label2 = facetLabels.1

	let components = [
		VarianceComponent(source: "p", variance: sigmaP,
						  percentOfTotal: pcts[0], df: dfP, meanSquare: msP),
		VarianceComponent(source: label1, variance: sigmaR,
						  percentOfTotal: pcts[1], df: dfR, meanSquare: msR),
		VarianceComponent(source: label2, variance: sigmaI,
						  percentOfTotal: pcts[2], df: dfI, meanSquare: msI),
		VarianceComponent(source: "p x \(label1)", variance: sigmaPR,
						  percentOfTotal: pcts[3], df: dfPR, meanSquare: msPR),
		VarianceComponent(source: "p x \(label2)", variance: sigmaPI,
						  percentOfTotal: pcts[4], df: dfPI, meanSquare: msPI),
		VarianceComponent(source: "\(label1) x \(label2)", variance: sigmaRI,
						  percentOfTotal: pcts[5], df: dfRI, meanSquare: msRI),
		VarianceComponent(source: "p x \(label1) x \(label2)", variance: sigmaE,
						  percentOfTotal: pcts[6], df: dfE, meanSquare: msE)
	]

	let facets = [
		GFacet(label: label1, levels: nR),
		GFacet(label: label2, levels: nI)
	]

	return GStudyResult(
		components: components,
		facets: facets,
		totalVariance: total,
		variancePersons: sigmaP,
		personCount: nP
	)
}
