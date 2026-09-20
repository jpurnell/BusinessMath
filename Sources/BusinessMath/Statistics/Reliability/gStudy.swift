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

	let pcts = gStudyPercentages([sigmaP, sigmaR, sigmaE], total: total)

	let components = [
		VarianceComponent(
			source: "p",
			variance: sigmaP,
			percentOfTotal: pcts[0],
			df: anova.dfSubjects,
			meanSquare: msP
		),
		VarianceComponent(
			source: facetLabel,
			variance: sigmaR,
			percentOfTotal: pcts[1],
			df: anova.dfRaters,
			meanSquare: msR
		),
		VarianceComponent(
			source: "p x \(facetLabel)",
			variance: sigmaE,
			percentOfTotal: pcts[2],
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

// MARK: - Shared

/// Each component's share of the total, in percent.
///
/// Shared by both overloads. It was written out twice, once per design, with the same
/// `total > 0` guard and the same fallback to zeros — the kind of duplication that has
/// already cost this package an ICC formula in three files and a churn range in four
/// places. One copy is one place to get it wrong.
///
/// - Parameters:
///   - variances: The component variances, in the order they will be reported.
///   - total: Their sum.
/// - Returns: One percentage per variance, or all zeros when there is no variance to share
///   out — which is the honest answer for data that does not vary, rather than a set of
///   percentages arrived at by dividing by zero.
private func gStudyPercentages<T: Real>(_ variances: [T], total: T) -> [T] {
	let hundred = T(100)
	guard total > T.zero else {
		return [T](repeating: T.zero, count: variances.count)
	}
	return variances.map { $0 / total * hundred }
}

// MARK: - Two-Facet support

/// The marginal means a three-way decomposition is built from.
private struct GStudyThreeWayMeans<T: Real> {
	let grand: T
	let person: [T]
	let rater: [T]
	let item: [T]
	let personRater: [[T]]
	let personItem: [[T]]
	let raterItem: [[T]]
}

/// Sums of squares for the seven sources.
private struct GStudyThreeWaySums<T: Real> {
	let p: T, r: T, i: T, pr: T, pi: T, ri: T, e: T
}

/// Mean squares and the degrees of freedom they were divided by.
private struct GStudyThreeWayMeanSquares<T: Real> {
	let p: T, r: T, i: T, pr: T, pi: T, ri: T, e: T
	let dfP: Int, dfR: Int, dfI: Int, dfPR: Int, dfPI: Int, dfRI: Int, dfE: Int
}

/// Dimensional validation for the `p x r x i` design.
///
/// - Parameters:
///   - data: The three-dimensional score array.
///   - facetLabels: Labels for the two facets, used in the error messages.
/// - Returns: The three dimensions.
/// - Throws: `BusinessMathError.insufficientData` when any dimension is below 2,
///   `BusinessMathError.mismatchedDimensions` when the design is not balanced.
private func gStudyValidateThreeWay<T: Real>(
	_ data: [[[T]]], facetLabels: (String, String)
) throws -> (nP: Int, nR: Int, nI: Int) {
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
	return (nP, nR, nI)
}

/// The mean of every observation.
///
/// - Parameters:
///   - data: The balanced score array.
///   - nP: Person count.
///   - nR: Levels of the first facet.
///   - nI: Levels of the second facet.
/// - Returns: The grand mean.
private func gStudyGrandMean<T: Real>(
	_ data: [[[T]]], nP: Int, nR: Int, nI: Int
) -> T {
	var grandSum = T.zero
	for p in 0..<nP {
		for r in 0..<nR {
			for i in 0..<nI {
				grandSum += data[p][r][i]
			}
		}
	}
	return grandSum / T(nP * nR * nI)
}

/// The three one-way marginal means: each level of one axis, averaged over the other two.
///
/// - Parameters:
///   - data: The balanced score array.
///   - nP: Person count.
///   - nR: Levels of the first facet.
///   - nI: Levels of the second facet.
/// - Returns: Person, first-facet and second-facet means.
private func gStudyOneWayMeans<T: Real>(
	_ data: [[[T]]], nP: Int, nR: Int, nI: Int
) -> (person: [T], rater: [T], item: [T]) {
	let nPT = T(nP), nRT = T(nR), nIT = T(nI)

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

	return (personMeans, raterMeans, itemMeans)
}

/// The three two-way marginal means: each cell of one pair of axes, averaged over the third.
///
/// - Parameters:
///   - data: The balanced score array.
///   - nP: Person count.
///   - nR: Levels of the first facet.
///   - nI: Levels of the second facet.
/// - Returns: Person-by-facet-1, person-by-facet-2 and facet-1-by-facet-2 means.
private func gStudyTwoWayMeans<T: Real>(
	_ data: [[[T]]], nP: Int, nR: Int, nI: Int
) -> (personRater: [[T]], personItem: [[T]], raterItem: [[T]]) {
	let nPT = T(nP), nRT = T(nR), nIT = T(nI)

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

	return (prMeans, piMeans, riMeans)
}

/// Every marginal mean of the balanced `p x r x i` array.
///
/// - Parameters:
///   - data: The balanced score array.
///   - nP: Person count.
///   - nR: Levels of the first facet.
///   - nI: Levels of the second facet.
/// - Returns: The grand mean, the three one-way means and the three two-way means.
private func gStudyThreeWayMeans<T: Real>(
	_ data: [[[T]]], nP: Int, nR: Int, nI: Int
) -> GStudyThreeWayMeans<T> {
	let grand: T = gStudyGrandMean(data, nP: nP, nR: nR, nI: nI)
	let oneWay = gStudyOneWayMeans(data, nP: nP, nR: nR, nI: nI)
	let twoWay = gStudyTwoWayMeans(data, nP: nP, nR: nR, nI: nI)
	return GStudyThreeWayMeans(
		grand: grand,
		person: oneWay.person, rater: oneWay.rater, item: oneWay.item,
		personRater: twoWay.personRater, personItem: twoWay.personItem,
		raterItem: twoWay.raterItem)
}

/// The seven sums of squares.
///
/// The residual is taken by subtraction from the total rather than summed directly, which
/// is what makes it the *confounded* term: whatever the six named sources do not account
/// for lands here, including the three-way interaction they cannot separate it from.
///
/// - Parameters:
///   - data: The balanced score array.
///   - means: Its marginal means.
///   - nP: Person count.
///   - nR: Levels of the first facet.
///   - nI: Levels of the second facet.
/// - Returns: One sum of squares per source.
private func gStudyThreeWaySums<T: Real>(
	_ data: [[[T]]], means: GStudyThreeWayMeans<T>, nP: Int, nR: Int, nI: Int
) -> GStudyThreeWaySums<T> {
	let nPT = T(nP), nRT = T(nR), nIT = T(nI)
	let grandMean = means.grand

	var ssP = T.zero
	for p in 0..<nP {
		let diff = means.person[p] - grandMean
		ssP += diff * diff
	}
	ssP = nRT * nIT * ssP

	var ssR = T.zero
	for r in 0..<nR {
		let diff = means.rater[r] - grandMean
		ssR += diff * diff
	}
	ssR = nPT * nIT * ssR

	var ssI = T.zero
	for i in 0..<nI {
		let diff = means.item[i] - grandMean
		ssI += diff * diff
	}
	ssI = nPT * nRT * ssI

	var ssPR = T.zero
	for p in 0..<nP {
		for r in 0..<nR {
			let diff = means.personRater[p][r] - means.person[p] - means.rater[r] + grandMean
			ssPR += diff * diff
		}
	}
	ssPR = nIT * ssPR

	var ssPI = T.zero
	for p in 0..<nP {
		for i in 0..<nI {
			let diff = means.personItem[p][i] - means.person[p] - means.item[i] + grandMean
			ssPI += diff * diff
		}
	}
	ssPI = nRT * ssPI

	var ssRI = T.zero
	for r in 0..<nR {
		for i in 0..<nI {
			let diff = means.raterItem[r][i] - means.rater[r] - means.item[i] + grandMean
			ssRI += diff * diff
		}
	}
	ssRI = nPT * ssRI

	var ssTotal = T.zero
	for p in 0..<nP {
		for r in 0..<nR {
			for i in 0..<nI {
				let diff = data[p][r][i] - grandMean
				ssTotal += diff * diff
			}
		}
	}

	let ssE = ssTotal - ssP - ssR - ssI - ssPR - ssPI - ssRI
	return GStudyThreeWaySums(p: ssP, r: ssR, i: ssI, pr: ssPR, pi: ssPI, ri: ssRI, e: ssE)
}

/// Mean squares from the sums of squares, with the degrees of freedom they used.
///
/// - Parameters:
///   - sums: The seven sums of squares.
///   - nP: Person count.
///   - nR: Levels of the first facet.
///   - nI: Levels of the second facet.
/// - Returns: The mean squares and their degrees of freedom.
private func gStudyThreeWayMeanSquares<T: Real>(
	_ sums: GStudyThreeWaySums<T>, nP: Int, nR: Int, nI: Int
) -> GStudyThreeWayMeanSquares<T> {
	let dfP = nP - 1
	let dfR = nR - 1
	let dfI = nI - 1
	let dfPR = dfP * dfR
	let dfPI = dfP * dfI
	let dfRI = dfR * dfI
	let dfE = dfP * dfR * dfI

	let msP = sums.p / T(dfP)
	let msR = sums.r / T(dfR)
	let msI = sums.i / T(dfI)
	let msPR: T = dfPR > 0 ? sums.pr / T(dfPR) : T.zero
	let msPI: T = dfPI > 0 ? sums.pi / T(dfPI) : T.zero
	let msRI: T = dfRI > 0 ? sums.ri / T(dfRI) : T.zero
	let msE: T = dfE > 0 ? sums.e / T(dfE) : T.zero

	return GStudyThreeWayMeanSquares(
		p: msP, r: msR, i: msI, pr: msPR, pi: msPI, ri: msRI, e: msE,
		dfP: dfP, dfR: dfR, dfI: dfI, dfPR: dfPR, dfPI: dfPI, dfRI: dfRI, dfE: dfE)
}

/// The expected-mean-square inversion, with negative estimates truncated to zero.
///
/// Each divisor is a different product of the three dimensions, which is why a design with
/// two dimensions equal cannot tell a swapped one from a correct one:
///
///     sigma_p  = (MS_p  - MS_pr - MS_pi + MS_e) / (n_r n_i)
///     sigma_r  = (MS_r  - MS_pr - MS_ri + MS_e) / (n_p n_i)
///     sigma_i  = (MS_i  - MS_pi - MS_ri + MS_e) / (n_p n_r)
///     sigma_pr = (MS_pr - MS_e) / n_i
///     sigma_pi = (MS_pi - MS_e) / n_r
///     sigma_ri = (MS_ri - MS_e) / n_p
///     sigma_e  =  MS_e
///
/// A negative estimate is not a negative variance; it is an estimator landing below the
/// boundary of the thing it estimates. Truncating is the convention, and it is why "every
/// component is non-negative" can never be a test of this function.
///
/// - Parameters:
///   - ms: The mean squares.
///   - nP: Person count.
///   - nR: Levels of the first facet.
///   - nI: Levels of the second facet.
/// - Returns: The seven variance components in reporting order: `p`, facet 1, facet 2,
///   `p x f1`, `p x f2`, `f1 x f2`, residual.
private func gStudyThreeWayComponents<T: Real>(
	_ ms: GStudyThreeWayMeanSquares<T>, nP: Int, nR: Int, nI: Int
) -> [T] {
	let nPT = T(nP), nRT = T(nR), nIT = T(nI)

	let sigmaE = ms.e
	let rawSigmaPR = (ms.pr - ms.e) / nIT
	let rawSigmaPI = (ms.pi - ms.e) / nRT
	let rawSigmaRI = (ms.ri - ms.e) / nPT
	let rawSigmaP = (ms.p - ms.pr - ms.pi + ms.e) / (nRT * nIT)
	let rawSigmaR = (ms.r - ms.pr - ms.ri + ms.e) / (nPT * nIT)
	let rawSigmaI = (ms.i - ms.pi - ms.ri + ms.e) / (nPT * nRT)

	let raw = [rawSigmaP, rawSigmaR, rawSigmaI, rawSigmaPR, rawSigmaPI, rawSigmaRI, sigmaE]
	return raw.map { $0 < T.zero ? T.zero : $0 }
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
	let (nP, nR, nI) = try gStudyValidateThreeWay(data, facetLabels: facetLabels)

	let means = gStudyThreeWayMeans(data, nP: nP, nR: nR, nI: nI)
	let sums = gStudyThreeWaySums(data, means: means, nP: nP, nR: nR, nI: nI)
	let ms = gStudyThreeWayMeanSquares(sums, nP: nP, nR: nR, nI: nI)
	let variances = gStudyThreeWayComponents(ms, nP: nP, nR: nR, nI: nI)

	let sigmaP = variances[0]
	let sigmaR = variances[1]
	let sigmaI = variances[2]
	let sigmaPR = variances[3]
	let sigmaPI = variances[4]
	let sigmaRI = variances[5]
	let sigmaE = variances[6]

	let total = sigmaP + sigmaR + sigmaI + sigmaPR + sigmaPI + sigmaRI + sigmaE
	let pcts = gStudyPercentages(variances, total: total)

	let msP = ms.p, msR = ms.r, msI = ms.i
	let msPR = ms.pr, msPI = ms.pi, msRI = ms.ri, msE = ms.e
	let dfP = ms.dfP, dfR = ms.dfR, dfI = ms.dfI
	let dfPR = ms.dfPR, dfPI = ms.dfPI, dfRI = ms.dfRI, dfE = ms.dfE

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
