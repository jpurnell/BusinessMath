import Foundation
import Numerics

/// Result of a two-way analysis of variance without replication.
///
/// Decomposes total variation into subject effects, rater effects,
/// and residual error for a balanced n subjects x k raters design.
///
/// - Note: This implementation assumes no replication (one observation
///   per subject-rater combination).
public struct TwoWayANOVAResult<T: Real & Sendable>: Sendable, Equatable {
	/// Sum of squares between subjects (rows).
	public let ssSubjects: T
	/// Sum of squares between raters (columns).
	public let ssRaters: T
	/// Sum of squares for residual error.
	public let ssError: T
	/// Total sum of squares.
	public let ssTotal: T
	/// Mean square between subjects (ssSubjects / dfSubjects).
	public let msSubjects: T
	/// Mean square between raters (ssRaters / dfRaters).
	public let msRaters: T
	/// Mean square for residual error (ssError / dfError).
	public let msError: T
	/// Degrees of freedom for subjects (n - 1).
	public let dfSubjects: Int
	/// Degrees of freedom for raters (k - 1).
	public let dfRaters: Int
	/// Degrees of freedom for error ((n - 1)(k - 1)).
	public let dfError: Int
}

/// Two-way ANOVA without replication (n subjects x k raters).
///
/// Performs a two-way analysis of variance on a balanced rectangular matrix
/// where rows represent subjects and columns represent raters (or conditions).
/// Assumes exactly one observation per subject-rater combination.
///
/// The total sum of squares is decomposed as:
/// ```
/// SS_total = SS_subjects + SS_raters + SS_error
/// ```
///
/// - Parameter ratings: Matrix where `ratings[i][j]` is the rating of
///   subject `i` by rater `j`. All rows must have the same length.
/// - Returns: A ``TwoWayANOVAResult`` containing the decomposed sums
///   of squares, mean squares, and degrees of freedom.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 subjects
///   or fewer than 2 raters.
///   `BusinessMathError.mismatchedDimensions` if rows have different lengths.
public func twoWayANOVA<T: Real>(_ ratings: [[T]]) throws -> TwoWayANOVAResult<T> {
	let n = ratings.count

	guard n >= 2 else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: n,
			context: "Two-way ANOVA requires at least 2 subjects (rows)")
	}

	let k = ratings[0].count

	guard k >= 2 else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: k,
			context: "Two-way ANOVA requires at least 2 raters (columns)")
	}

	// Validate balanced design
	for i in 1..<n {
		guard ratings[i].count == k else {
			throw BusinessMathError.mismatchedDimensions(
				message: "All rows must have the same number of columns",
				expected: "\(k)", actual: "\(ratings[i].count)")
		}
	}

	let nT = T(n)
	let kT = T(k)

	// Grand mean
	var grandSum = T.zero
	for row in ratings {
		for value in row {
			grandSum += value
		}
	}
	let grandMean = grandSum / (nT * kT)

	// Row means (subject means)
	var rowMeans: [T] = []
	rowMeans.reserveCapacity(n)
	for row in ratings {
		let rowSum = row.reduce(T.zero, +)
		rowMeans.append(rowSum / kT)
	}

	// Column means (rater means)
	var colMeans: [T] = []
	colMeans.reserveCapacity(k)
	for j in 0..<k {
		var colSum = T.zero
		for i in 0..<n {
			colSum += ratings[i][j]
		}
		colMeans.append(colSum / nT)
	}

	// SS Subjects = k * Σ (rowMean_i - grandMean)²
	var ssSubjects = T.zero
	for i in 0..<n {
		let diff = rowMeans[i] - grandMean
		ssSubjects += diff * diff
	}
	ssSubjects = kT * ssSubjects

	// SS Raters = n * Σ (colMean_j - grandMean)²
	var ssRaters = T.zero
	for j in 0..<k {
		let diff = colMeans[j] - grandMean
		ssRaters += diff * diff
	}
	ssRaters = nT * ssRaters

	// SS Total = Σ (x_ij - grandMean)²
	var ssTotal = T.zero
	for row in ratings {
		for value in row {
			let diff = value - grandMean
			ssTotal += diff * diff
		}
	}

	// SS Error = SS Total - SS Subjects - SS Raters
	let ssError = ssTotal - ssSubjects - ssRaters

	// Degrees of freedom
	let dfSubjects = n - 1
	let dfRaters = k - 1
	let dfError = dfSubjects * dfRaters

	// Mean squares (safe division — df values are always >= 1 given guards above)
	let msSubjects = ssSubjects / T(dfSubjects)
	let msRaters = ssRaters / T(dfRaters)
	let msError: T
	if dfError > 0 {
		msError = ssError / T(dfError)
	} else {
		msError = T.zero
	}

	return TwoWayANOVAResult(
		ssSubjects: ssSubjects,
		ssRaters: ssRaters,
		ssError: ssError,
		ssTotal: ssTotal,
		msSubjects: msSubjects,
		msRaters: msRaters,
		msError: msError,
		dfSubjects: dfSubjects,
		dfRaters: dfRaters,
		dfError: dfError
	)
}
