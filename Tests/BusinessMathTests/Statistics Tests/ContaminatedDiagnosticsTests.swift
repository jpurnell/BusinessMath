//
//  ContaminatedDiagnosticsTests.swift
//  BusinessMathTests
//
//  From the fanned-out triage of `Sources/BusinessMath/Statistics/`. Three functions whose
//  whole job is to tell a caller whether a result can be trusted.
//
//  `effectiveSampleSize` returns `n` — every draw independent, the best mixing a chain can
//  have — when it cannot compute the variance:
//
//      guard variance > T.zero else {
//          // Constant sequence: ESS = n (no autocorrelation structure to speak of)
//          return n
//      }
//
//  `nan > 0` is false, so a diverged or contaminated chain came out the door marked "constant
//  sequence". Measured on six draws with one `nan`:
//
//      clean ESS = 4 of 6        contaminated ESS = 6 of 6
//
//  The contaminated chain earns a *better* convergence certificate than the clean one. A
//  caller thresholding `ess > 400` concludes the sampler mixed perfectly.
//
//  `rHatStatistic`, in the same file, gets this right — it returns `10` on unusable input,
//  documented as "indicate non-convergence", the alarming end. Same file, same failure mode,
//  opposite direction.
//
//  `percentRank` sorts and interpolates, and `sorted()` on a collection containing a `nan`
//  leaves the *valid* elements out of order. Measured:
//
//      clean               = 0.167
//      nan in the middle   = 0.0625      <- finite, confident, wrong
//      nan at the front    = throws "outside the set's range"  <- wrong diagnosis
//
//  `selectBandwidth` returns the literal `0.1` through a guard commented "Data has no spread",
//  where the clean answer is 0.974 — a fabricated constant presented as a selected value, in a
//  throwing function whose other guards throw.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Diagnostics that could not be computed")
struct ContaminatedDiagnosticsTests {

    private let cleanChain: [Double] = [0.1, 0.2, 0.15, 0.3, 0.25, 0.22]
    private var contaminatedChain: [Double] {
        var v = cleanChain
        v[2] = .nan
        return v
    }

    /// The headline: a chain nobody can evaluate must not certify as perfectly mixed.
    @Test("EffectiveSampleSize_ContaminatedChain_IsNotPerfectMixing")
    func effectiveSampleSizeContaminatedChainIsNotPerfectMixing() {
        let ess = effectiveSampleSize(contaminatedChain)
        #expect(ess != contaminatedChain.count,
                "reported \(ess) of \(contaminatedChain.count) — every draw independent")
        #expect(ess == 0, "no usable draws, which is the end rHatStatistic also reports to")
    }

    /// The sibling in the same file that was always right.
    @Test("RHat_ContaminatedChain_AlreadyIndicatedNonConvergence")
    func rHatContaminatedChainAlreadyIndicatedNonConvergence() throws {
        let rHat = rHatStatistic([[0.1, 0.2, Double.nan], [0.3, 0.25, 0.22]])
        let value = try #require(rHat)
        #expect(value.isEqual(to: 10.0), "got \(value)")
    }

    /// A genuinely constant chain keeps the documented `n` — the case the guard was for.
    @Test("EffectiveSampleSize_ConstantChain_StillReportsN")
    func effectiveSampleSizeConstantChainStillReportsN() {
        let constant: [Double] = [0.5, 0.5, 0.5, 0.5, 0.5]
        #expect(effectiveSampleSize(constant) == constant.count)
    }

    /// A percentile that depends on where the `nan` sits is not a percentile.
    @Test("PercentRank_ContaminatedSample_IsRefused")
    func percentRankContaminatedSampleIsRefused() {
        let middle: [Double] = [1.0, 5.0, .nan, 3.0, 4.0]
        #expect(throws: BusinessMathError.self) {
            try percentRank(2.0, in: middle)
        }
        let front: [Double] = [.nan, 1.0, 5.0, 3.0, 4.0]
        #expect(throws: BusinessMathError.self) {
            try percentRank(2.0, in: front)
        }
    }

    /// A selected bandwidth must be selected, not invented.
    @Test("SelectBandwidth_ContaminatedSample_IsRefused")
    func selectBandwidthContaminatedSampleIsRefused() {
        let contaminated: [Double] = [1.0, 2.0, .nan, 4.0, 5.0]
        #expect(throws: BusinessMathError.self) {
            try selectBandwidth(contaminated)
        }
    }

    // MARK: - Controls

    @Test("CleanInputs_Unchanged")
    func cleanInputsUnchanged() throws {
        #expect(effectiveSampleSize(cleanChain) == 4, "got \(effectiveSampleSize(cleanChain))")
        let rank = try percentRank(2.0, in: [1.0, 3.0, 4.0, 5.0])
        #expect(abs(rank - 0.167) < 1e-3, "got \(rank)")
        let bandwidth = try selectBandwidth([1.0, 2.0, 3.0, 4.0, 5.0])
        #expect(abs(bandwidth - 0.9735846228506357) < 1e-12, "got \(bandwidth)")
    }
}
