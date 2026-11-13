//
//  ConvergenceReport.swift
//  BusinessMath
//

import Foundation

/// How an iterative metric's iteration ended.
///
/// ```swift
/// let report = ConvergenceReport(
/// 	iterations: 42, converged: true, residual: 3e-11, tolerance: 1e-10, maxIterations: 200)
/// print(report.converged)   // true
/// ```
public struct ConvergenceReport: Sendable, Codable, Hashable {
	/// Passes run.
	public let iterations: Int
	/// Whether the change fell below ``tolerance`` within the ceiling.
	public let converged: Bool
	/// The L1 change between the last two iterates.
	public let residual: Double
	/// The threshold the change was compared with.
	public let tolerance: Double
	/// The ceiling on passes.
	public let maxIterations: Int

	/// Creates a report.
	public init(iterations: Int, converged: Bool, residual: Double, tolerance: Double, maxIterations: Int) {
		self.iterations = iterations
		self.converged = converged
		self.residual = residual
		self.tolerance = tolerance
		self.maxIterations = maxIterations
	}
}

/// One human-readable sentence about a convergence outcome, for a command-line tool or a log.
///
/// ```swift
/// let report = ConvergenceReport(
/// 	iterations: 151, converged: true, residual: 8.2e-11, tolerance: 1e-10, maxIterations: 200)
/// print(ConvergenceNote.sentence(report))
/// // Converged in 151 passes (final change 8.20E-11, tolerance 1.00E-10).
/// ```
///
/// Pass `nil` (for instance `envelope.convergence` of a record stored before version 4) to
/// get the "not recorded" sentence, so callers need no branch of their own. Numbers use the
/// POSIX locale, so the text is the same on every machine.
public enum ConvergenceNote {

	/// The sentence for a report, or for a result that carries none.
	///
	/// - Parameter report: How the iteration ended, or `nil` if it is unknown.
	public static func sentence(_ report: ConvergenceReport?) -> String {
		guard let report else { return "Convergence was not recorded for this result." }
		let change = scientific(report.residual)
		let tolerance = scientific(report.tolerance)
		if report.converged {
			let passes = report.iterations == 1 ? "1 pass" : "\(report.iterations) passes"
			return "Converged in \(passes) (final change \(change), tolerance \(tolerance))."
		}
		return "Did not converge: stopped at the \(report.maxIterations)-pass ceiling with a final "
			+ "change of \(change) against a tolerance of \(tolerance), so these scores may be "
			+ "far from the true eigenvector. Raise maxIterations to check."
	}

	private static func scientific(_ value: Double) -> String {
		value.formatted(
			.number.notation(.scientific).precision(.significantDigits(3))
				.locale(Locale(identifier: "en_US_POSIX")))
	}
}
