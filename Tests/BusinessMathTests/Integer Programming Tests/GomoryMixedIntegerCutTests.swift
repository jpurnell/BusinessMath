import Testing
import Foundation
@testable import BusinessMath

/// Validity of the Gomory mixed-integer cut, checked against enumeration rather than itself.
///
/// ## Why this family exists
///
/// The classical Gomory **fractional** cut is derived by rounding, and the rounding step is
/// justified only when every non-basic variable in the row takes an integer value at every
/// integer-feasible point. That holds for the original rows of a problem with integer data —
/// their slacks are integral — and stops holding the moment a cut row joins the tableau,
/// because a cut's coefficients and right-hand side are fractional and its slack therefore is
/// too. Branch-and-cut kept deriving fractional cuts from such tableaux and cut off optimal
/// integer points; see `DegeneracyProtectionTests` for the symptom it produced.
///
/// The Gomory **mixed-integer** cut carries no such premise. Its derivation splits the row
/// into the columns that are integer-constrained and the columns that are not, and applies a
/// different coefficient rule to each, so it stays valid with continuous non-basic variables
/// present — which is exactly the situation from round one onward.
///
/// ## The oracle
///
/// A cut is valid when it excludes no feasible point, so these tests enumerate the feasible
/// points of a small row directly and require the cut to admit every one. Self-consistency —
/// deriving the cut twice and comparing — would pass for a wrong formula, and did: the
/// `generateMIRCut` this replaces gives non-basic continuous columns with a negative
/// coefficient a **negative** cut coefficient, where the derivation requires a positive one,
/// and nothing in the suite noticed.
@Suite("Gomory mixed-integer cuts")
struct GomoryMixedIntegerCutTests {

	/// A row `x_B + Σ a_j y_j = b` over two non-basic columns, plus which of them are integer.
	private struct Row {
		let a: [Double]
		let b: Double
		let integerColumns: Set<Int>
		let label: String
	}

	/// Non-basic column `j` of the synthetic row lives at original index `j + 1`.
	private static let columnCount: Int = 3

	private func makeRow(_ row: Row) -> SimplexRow {
		SimplexRow(
			rhs: row.b,
			coefficients: row.a,
			nonBasicVariableIndices: [1, 2],
			basicVariableIndex: 0
		)
	}

	/// Every point of the row's feasible set inside a small box.
	///
	/// A point is feasible when each `y_j` is non-negative, integer where the column is
	/// integer-constrained, and leaves `x_B = b - Σ a_j y_j` a non-negative integer. Continuous
	/// columns are swept on a fine grid, which is not exhaustive — but a cut that survives a
	/// dense sweep and fails elsewhere would have to be wrong in a very narrow band, and the
	/// integer columns, which is where the rounding argument actually lives, are exhaustive.
	private func feasiblePoints(_ row: Row) -> [[Double]] {
		var points: [[Double]] = []
		let integerGrid: [Double] = (0...12).map { Double($0) }
		let continuousGrid: [Double] = (0...240).map { Double($0) / 20.0 }

		let grid0: [Double] = row.integerColumns.contains(0) ? integerGrid : continuousGrid
		let grid1: [Double] = row.integerColumns.contains(1) ? integerGrid : continuousGrid

		for y0 in grid0 {
			for y1 in grid1 {
				let consumed: Double = row.a[0] * y0 + row.a[1] * y1
				let basic: Double = row.b - consumed
				guard basic > -1e-9 else { continue }
				let nearest: Double = (basic).rounded()
				guard abs(basic - nearest) < 1e-9 else { continue }
				points.append([0.0, y0, y1])
			}
		}
		return points
	}

	/// How far a cut is violated at a point. Positive means the point is excluded.
	private func violation(_ cut: CuttingPlane, at point: [Double]) -> Double {
		var lhs: Double = 0.0
		for index in 0..<Swift.min(cut.coefficients.count, point.count) {
			lhs += cut.coefficients[index] * point[index]
		}
		return lhs - cut.rhs
	}

	private static let rows: [Row] = [
		Row(a: [0.25, -0.5], b: 2.5, integerColumns: [], label: "both continuous, mixed signs"),
		Row(a: [0.25, -0.5], b: 2.5, integerColumns: [0, 1], label: "both integer, mixed signs"),
		Row(a: [0.75, 0.3], b: 3.4, integerColumns: [0], label: "one integer with frac above f0"),
		Row(a: [-1.0, 0.6], b: 1.5, integerColumns: [1], label: "negative continuous column"),
		Row(a: [0.5, 1.0], b: 2.5, integerColumns: [0, 1], label: "half and unit, both integer"),
		Row(a: [-0.4, -0.9], b: 4.25, integerColumns: [0], label: "both negative"),
		Row(a: [2.3, -1.7], b: 5.8, integerColumns: [1], label: "magnitudes above one")
	]

	@Test("The cut admits every feasible point of its row", arguments: rows.indices)
	func cutAdmitsEveryFeasiblePoint(_ index: Int) throws {
		let row = Self.rows[index]
		let generator = CuttingPlaneGenerator()
		let produced = try generator.generateGomoryMixedIntegerCut(
			from: makeRow(row),
			totalVariableCount: Self.columnCount,
			integerVariables: Set(row.integerColumns.map { $0 + 1 })
		)
		let cut = try #require(produced,
							   "\(row.label): the right-hand side is fractional, so a cut exists")

		let points = feasiblePoints(row)
		#expect(!points.isEmpty, "\(row.label): the oracle found no feasible point to check against")

		var worst: Double = -.infinity
		var worstPoint: [Double] = []
		for point in points {
			let excess: Double = violation(cut, at: point)
			if excess > worst { worst = excess; worstPoint = point }
		}

		#expect(worst < 1e-9,
				"\(row.label): cut excludes the feasible point \(worstPoint) by \(worst)")
	}

	@Test("The cut excludes the fractional vertex it was derived from", arguments: rows.indices)
	func cutExcludesTheCurrentVertex(_ index: Int) throws {
		let row = Self.rows[index]
		let generator = CuttingPlaneGenerator()
		let produced = try generator.generateGomoryMixedIntegerCut(
			from: makeRow(row),
			totalVariableCount: Self.columnCount,
			integerVariables: Set(row.integerColumns.map { $0 + 1 })
		)
		let cut = try #require(produced,
							   "\(row.label): the right-hand side is fractional, so a cut exists")

		// At the simplex optimum every non-basic variable is zero, and the basic variable takes
		// the fractional value that motivated the cut. A cut that does not exclude that point
		// is valid but useless — the LP re-solves to the same vertex and the round is wasted.
		let vertex: [Double] = [0.0, 0.0, 0.0]
		let excess: Double = violation(cut, at: vertex)
		#expect(excess > 1e-9, "\(row.label): the cut does not exclude the vertex; violation \(excess)")
	}

	/// A row that proves its own node infeasible yields no cut, and the node is explored anyway.
	///
	/// `x_B + y₀ + y₁ = 2.5` with `x_B`, `y₀`, `y₁` all integer has no solution: an integer
	/// minus integers cannot be `2.5`. The derivation notices — every `α_j` is `frac(1.0) = 0`,
	/// so the cut reads `0 ≥ 0.5`, which is the strongest possible statement and a certificate
	/// that this subproblem is empty.
	///
	/// ``CuttingPlane/isWeak`` then discards it, because it tests "are all coefficients
	/// negligible" and reads a certificate of infeasibility as a cut that does nothing. The
	/// node survives and is branched instead of being pruned.
	///
	/// Pinned rather than fixed: the same predicate guards the fractional cut, so changing it
	/// changes two paths at once and belongs in its own piece of work. The cost is search time,
	/// not correctness — an infeasible subtree still yields nothing, just more slowly.
	// MARK: - The MIR entry point resolves to the same inequality

	/// ``CuttingPlaneGenerator/generateMIRCut(from:totalVariableCount:integerVariables:)`` is
	/// held to the same oracle, because a caller can reach it through `enableMIRCuts` and get
	/// cuts into the same LP.
	///
	/// It used to fail this on three of the seven rows, excluding a feasible point by as much as
	/// 41, because its continuous-column rule produced a negative coefficient where the
	/// derivation requires a non-negative one. It now delegates.
	@Test("The MIR entry point admits every feasible point too", arguments: rows.indices)
	func mirAdmitsEveryFeasiblePoint(_ index: Int) throws {
		let row = Self.rows[index]
		let generator = CuttingPlaneGenerator()
		let produced = try generator.generateMIRCut(
			from: makeRow(row),
			totalVariableCount: Self.columnCount,
			integerVariables: Set(row.integerColumns.map { $0 + 1 })
		)
		let cut = try #require(produced, "\(row.label): the right-hand side is fractional")

		var worst: Double = -.infinity
		var worstPoint: [Double] = []
		for point in feasiblePoints(row) {
			let excess: Double = violation(cut, at: point)
			if excess > worst { worst = excess; worstPoint = point }
		}
		#expect(worst < 1e-9,
				"\(row.label): MIR cut excludes the feasible point \(worstPoint) by \(worst)")
	}

	/// Same inequality, different label — that is the whole of the difference, and stating it
	/// keeps the delegation from quietly growing a second derivation again.
	@Test("MIR and GMI produce the same inequality under different tags", arguments: rows.indices)
	func mirAndGomoryAgree(_ index: Int) throws {
		let row = Self.rows[index]
		let generator = CuttingPlaneGenerator()
		let gmi = try #require(try generator.generateGomoryMixedIntegerCut(
			from: makeRow(row),
			totalVariableCount: Self.columnCount,
			integerVariables: Set(row.integerColumns.map { $0 + 1 })
		))
		let mir = try #require(try generator.generateMIRCut(
			from: makeRow(row),
			totalVariableCount: Self.columnCount,
			integerVariables: Set(row.integerColumns.map { $0 + 1 })
		))

		#expect(gmi.coefficients.count == mir.coefficients.count, "\(row.label): widths differ")
		for position in 0..<Swift.min(gmi.coefficients.count, mir.coefficients.count) {
			let difference: Double = abs(gmi.coefficients[position] - mir.coefficients[position])
			#expect(difference < 1e-12, "\(row.label): column \(position) differs by \(difference)")
		}
		let rhsDifference: Double = abs(gmi.rhs - mir.rhs)
		#expect(rhsDifference < 1e-12, "\(row.label): right-hand sides differ by \(rhsDifference)")
		#expect(mir.type == .mixedIntegerRounding, "\(row.label): the MIR tag is the difference")
		#expect(gmi.type == .gomory, "\(row.label): the Gomory tag is the difference")
	}

	@Test("A row certifying infeasibility is discarded as weak")
	func infeasibilityCertificateIsDiscarded() throws {
		let generator = CuttingPlaneGenerator()
		let row = SimplexRow(
			rhs: 2.5,
			coefficients: [1.0, 1.0],
			nonBasicVariableIndices: [1, 2],
			basicVariableIndex: 0
		)
		let cut = try generator.generateGomoryMixedIntegerCut(
			from: row,
			totalVariableCount: Self.columnCount,
			integerVariables: [1, 2]
		)
		#expect(cut == nil, "the certificate 0 >= 0.5 is currently discarded by isWeak")
	}

	@Test("An integral right-hand side yields no cut")
	func integralRightHandSideYieldsNoCut() throws {
		let generator = CuttingPlaneGenerator()
		let row = SimplexRow(
			rhs: 3.0,
			coefficients: [0.25, -0.5],
			nonBasicVariableIndices: [1, 2],
			basicVariableIndex: 0
		)
		let cut = try generator.generateGomoryMixedIntegerCut(
			from: row,
			totalVariableCount: Self.columnCount,
			integerVariables: []
		)
		#expect(cut == nil, "nothing to cut off when the basic variable is already integral")
	}
}
