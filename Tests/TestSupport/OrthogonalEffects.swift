//
//  OrthogonalEffects.swift
//  BusinessMath
//
//  Building data whose analysis-of-variance decomposition is known before it is analysed.
//
//  A balanced crossed design's sums of squares are fixed by the effects the data was built
//  from, provided those effects are projected onto their own contrast spaces first: main
//  effects centred, two-way terms double-centred, the three-way term triple-centred. Every
//  margin of every term is then exactly zero, the terms are mutually orthogonal, and
//
//      SS(A)   = n_b n_c SUM a^2        SS(AB)  = n_c SUM ab^2        SS(ABC) = SUM abc^2
//
//  holds in closed form. Nothing has to be recomputed from the data, so a test built this
//  way is checking an answer rather than a second implementation — the two can be wrong
//  together, the construction cannot be wrong with itself.
//
//  Shared by `GStudyTwoFacetOracleTests` and `MultiWayANOVAOracleTests`, which need the same
//  construction for different functions. It lives here rather than in either of them because
//  this package has repeatedly paid for the other choice: an ICC formula in three files, a
//  churn range in four places, a gap interpolation written out three times.
//

import Foundation

/// Building blocks for data whose variance decomposition is known in advance.
public enum OrthogonalEffects {

	/// Subtracts the mean, so the values sum to zero.
	public static func centred(_ v: [Double]) -> [Double] {
		let total = v.reduce(0, +)
		let mean = total / Double(v.count)
		return v.map { $0 - mean }
	}

	/// Double-centred, so both margins are exactly zero.
	public static func doubleCentred(_ m: [[Double]]) -> [[Double]] {
		let rows = m.count
		let cols = m[0].count
		var rowMean = [Double](repeating: 0, count: rows)
		var colMean = [Double](repeating: 0, count: cols)
		var grand = 0.0
		for a in 0..<rows {
			for b in 0..<cols {
				rowMean[a] += m[a][b]
				colMean[b] += m[a][b]
				grand += m[a][b]
			}
		}
		for a in 0..<rows { rowMean[a] /= Double(cols) }
		for b in 0..<cols { colMean[b] /= Double(rows) }
		grand /= Double(rows * cols)

		var out = m
		for a in 0..<rows {
			for b in 0..<cols {
				let corrected = m[a][b] - rowMean[a] - colMean[b]
				out[a][b] = corrected + grand
			}
		}
		return out
	}

	/// Triple-centred: the three-way contrast, every margin exactly zero.
	public static func tripleCentred(_ t: [[[Double]]]) -> [[[Double]]] {
		let nP = t.count, nR = t[0].count, nI = t[0][0].count
		var mPR = [[Double]](repeating: [Double](repeating: 0, count: nR), count: nP)
		var mPI = [[Double]](repeating: [Double](repeating: 0, count: nI), count: nP)
		var mRI = [[Double]](repeating: [Double](repeating: 0, count: nI), count: nR)
		var mP = [Double](repeating: 0, count: nP)
		var mR = [Double](repeating: 0, count: nR)
		var mI = [Double](repeating: 0, count: nI)
		var grand = 0.0
		for p in 0..<nP {
			for r in 0..<nR {
				for i in 0..<nI {
					let v = t[p][r][i]
					mPR[p][r] += v; mPI[p][i] += v; mRI[r][i] += v
					mP[p] += v; mR[r] += v; mI[i] += v; grand += v
				}
			}
		}
		for p in 0..<nP { for r in 0..<nR { mPR[p][r] /= Double(nI) } }
		for p in 0..<nP { for i in 0..<nI { mPI[p][i] /= Double(nR) } }
		for r in 0..<nR { for i in 0..<nI { mRI[r][i] /= Double(nP) } }
		for p in 0..<nP { mP[p] /= Double(nR * nI) }
		for r in 0..<nR { mR[r] /= Double(nP * nI) }
		for i in 0..<nI { mI[i] /= Double(nP * nR) }
		grand /= Double(nP * nR * nI)

		var out = t
		for p in 0..<nP {
			for r in 0..<nR {
				for i in 0..<nI {
					let pairs: Double = mPR[p][r] + mPI[p][i] + mRI[r][i]
					let singles: Double = mP[p] + mR[r] + mI[i]
					let corrected: Double = t[p][r][i] - pairs + singles
					out[p][r][i] = corrected - grand
				}
			}
		}
		return out
	}

	/// The sum of squares of a flat array.
	public static func sumSquares(_ v: [Double]) -> Double {
		v.reduce(0) { $0 + $1 * $1 }
	}

	/// The sum of squares of a two-dimensional array.
	public static func sumSquares(_ m: [[Double]]) -> Double {
		m.reduce(0) { $0 + sumSquares($1) }
	}

	/// The sum of squares of a three-dimensional array.
	public static func sumSquares(_ t: [[[Double]]]) -> Double {
		t.reduce(0) { $0 + sumSquares($1) }
	}
}
