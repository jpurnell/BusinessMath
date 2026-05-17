import Testing
import Foundation
@testable import BusinessMath

@Suite("EMS Table Generator — Brennan's Algorithmic EMS Rules")
struct EMSTableGeneratorTests {

    // MARK: - Two-Facet EMS Table (p × r)

    @Test("Two-facet EMS table matches known p × r table")
    func testTwoFacetTable() throws {
        // p × r design: p(4), r(3)
        // Effects: {p}, {r}, {p,r}
        // EMS({p}) = n_r * sigma^2_p + 1 * sigma^2_{p,r}     [coeff for {p}: n_r=3, for {p,r}: 1]
        // EMS({r}) = n_p * sigma^2_r + 1 * sigma^2_{p,r}     [coeff for {r}: n_p=4, for {p,r}: 1]
        // EMS({p,r}) = 1 * sigma^2_{p,r}                     [coeff for {p,r}: 1]
        let table: [Set<String>: [EMSEntry<Double>]] = try generateEMSTable(
            facetNames: ["p", "r"],
            sampleSizes: ["p": 4, "r": 3]
        )

        #expect(table.count == 3) // 2^2 - 1 = 3 effects

        // Check EMS({p})
        let emsP = table[Set(["p"])]
        #expect(emsP != nil) // TEST-QUALITY: existence check
        #expect(emsP?.count == 2) // sigma^2_p and sigma^2_{p,r}

        let pSelfCoeff = emsP?.first { $0.component == Set(["p"]) }?.coefficient
        let pPRCoeff = emsP?.first { $0.component == Set(["p", "r"]) }?.coefficient

        #expect(abs((pSelfCoeff ?? 0) - 3.0) < 1e-6) // n_r = 3
        #expect(abs((pPRCoeff ?? 0) - 1.0) < 1e-6)   // empty product = 1

        // Check EMS({r})
        let emsR = table[Set(["r"])]
        #expect(emsR != nil) // TEST-QUALITY: existence check
        #expect(emsR?.count == 2)

        let rSelfCoeff = emsR?.first { $0.component == Set(["r"]) }?.coefficient
        let rPRCoeff = emsR?.first { $0.component == Set(["p", "r"]) }?.coefficient

        #expect(abs((rSelfCoeff ?? 0) - 4.0) < 1e-6) // n_p = 4
        #expect(abs((rPRCoeff ?? 0) - 1.0) < 1e-6)

        // Check EMS({p,r})
        let emsPR = table[Set(["p", "r"])]
        #expect(emsPR != nil) // TEST-QUALITY: existence check
        #expect(emsPR?.count == 1)
        #expect(abs((emsPR?.first?.coefficient ?? 0) - 1.0) < 1e-6)
    }

    // MARK: - Three-Facet EMS Table

    @Test("Three-facet table has 7 effects with correct EMS equations")
    func testThreeFacetTable() throws {
        // p(4) × r(3) × i(2) fully crossed
        // 2^3 - 1 = 7 effects
        let table: [Set<String>: [EMSEntry<Double>]] = try generateEMSTable(
            facetNames: ["p", "r", "i"],
            sampleSizes: ["p": 4, "r": 3, "i": 2]
        )

        #expect(table.count == 7)

        // Verify EMS({p}):
        // Supersets of {p}: {p}, {p,r}, {p,i}, {p,r,i}
        // c({p}, {p}) = n_r * n_i = 3 * 2 = 6
        // c({p,r}, {p}) = n_i = 2
        // c({p,i}, {p}) = n_r = 3
        // c({p,r,i}, {p}) = 1
        let emsP = table[Set(["p"])]
        #expect(emsP != nil) // TEST-QUALITY: existence check
        #expect(emsP?.count == 4)

        let pSelf = emsP?.first { $0.component == Set(["p"]) }?.coefficient
        let pPR = emsP?.first { $0.component == Set(["p", "r"]) }?.coefficient
        let pPI = emsP?.first { $0.component == Set(["p", "i"]) }?.coefficient
        let pPRI = emsP?.first { $0.component == Set(["p", "r", "i"]) }?.coefficient

        #expect(abs((pSelf ?? 0) - 6.0) < 1e-6)
        #expect(abs((pPR ?? 0) - 2.0) < 1e-6)
        #expect(abs((pPI ?? 0) - 3.0) < 1e-6)
        #expect(abs((pPRI ?? 0) - 1.0) < 1e-6)

        // Verify EMS({r}):
        // Supersets of {r}: {r}, {r,p}, {r,i}, {r,p,i}
        // c({r}, {r}) = n_p * n_i = 4 * 2 = 8
        let emsR = table[Set(["r"])]
        let rSelf = emsR?.first { $0.component == Set(["r"]) }?.coefficient
        #expect(abs((rSelf ?? 0) - 8.0) < 1e-6)

        // Verify EMS({r,i}):
        // Supersets: {r,i}, {p,r,i}
        // c({r,i}, {r,i}) = n_p = 4
        // c({p,r,i}, {r,i}) = 1
        let emsRI = table[Set(["r", "i"])]
        #expect(emsRI?.count == 2)
        let riSelf = emsRI?.first { $0.component == Set(["r", "i"]) }?.coefficient
        let riPRI = emsRI?.first { $0.component == Set(["p", "r", "i"]) }?.coefficient
        #expect(abs((riSelf ?? 0) - 4.0) < 1e-6)
        #expect(abs((riPRI ?? 0) - 1.0) < 1e-6)

        // Verify EMS({p,r,i}) — the residual always has coefficient 1
        let emsPRI = table[Set(["p", "r", "i"])]
        #expect(emsPRI?.count == 1)
        #expect(abs((emsPRI?.first?.coefficient ?? 0) - 1.0) < 1e-6)
    }

    // MARK: - Four-Facet EMS Table

    @Test("Four-facet: EMS({p}) has 8 terms")
    func testFourFacetPHas8Terms() throws {
        // p × a × b × c: 2^4 - 1 = 15 effects
        // Supersets of {p}: all subsets containing p = 2^3 = 8
        let table: [Set<String>: [EMSEntry<Double>]] = try generateEMSTable(
            facetNames: ["p", "a", "b", "c"],
            sampleSizes: ["p": 5, "a": 3, "b": 4, "c": 2]
        )

        #expect(table.count == 15) // 2^4 - 1

        let emsP = table[Set(["p"])]
        #expect(emsP?.count == 8) // 2^3 supersets containing p
    }

    // MARK: - Properties

    @Test("Coefficient of residual (full set) is always 1")
    func testResidualCoefficientAlwaysOne() throws {
        let table3: [Set<String>: [EMSEntry<Double>]] = try generateEMSTable(
            facetNames: ["p", "r", "i"],
            sampleSizes: ["p": 10, "r": 5, "i": 3]
        )

        let fullSet = Set(["p", "r", "i"])
        let emsResidual = table3[fullSet]
        #expect(emsResidual?.count == 1)
        #expect(abs((emsResidual?.first?.coefficient ?? 0) - 1.0) < 1e-6)
        #expect(emsResidual?.first?.component == fullSet)

        // Also for 2-facet
        let table2: [Set<String>: [EMSEntry<Double>]] = try generateEMSTable(
            facetNames: ["x", "y"],
            sampleSizes: ["x": 7, "y": 4]
        )

        let fullSet2 = Set(["x", "y"])
        let emsResidual2 = table2[fullSet2]
        #expect(emsResidual2?.count == 1)
        #expect(abs((emsResidual2?.first?.coefficient ?? 0) - 1.0) < 1e-6)
    }

    @Test("Number of entries = 2^f - 1")
    func testEntryCount() throws {
        let table2: [Set<String>: [EMSEntry<Double>]] = try generateEMSTable(
            facetNames: ["a", "b"],
            sampleSizes: ["a": 2, "b": 2]
        )
        #expect(table2.count == 3)

        let table3: [Set<String>: [EMSEntry<Double>]] = try generateEMSTable(
            facetNames: ["a", "b", "c"],
            sampleSizes: ["a": 2, "b": 2, "c": 2]
        )
        #expect(table3.count == 7)

        let table4: [Set<String>: [EMSEntry<Double>]] = try generateEMSTable(
            facetNames: ["a", "b", "c", "d"],
            sampleSizes: ["a": 2, "b": 2, "c": 2, "d": 2]
        )
        #expect(table4.count == 15)
    }

    @Test("Empty facet list throws insufficientData")
    func testEmptyFacetListThrows() throws {
        #expect(throws: BusinessMathError.self) {
            let _: [Set<String>: [EMSEntry<Double>]] = try generateEMSTable(
                facetNames: [],
                sampleSizes: [:]
            )
        }
    }

    @Test("Missing sample size throws invalidInput")
    func testMissingSampleSizeThrows() throws {
        #expect(throws: BusinessMathError.self) {
            let _: [Set<String>: [EMSEntry<Double>]] = try generateEMSTable(
                facetNames: ["p", "r"],
                sampleSizes: ["p": 4]
            )
        }
    }

    @Test("Single-facet EMS table: 1 effect with coefficient 1")
    func testSingleFacetTable() throws {
        let table: [Set<String>: [EMSEntry<Double>]] = try generateEMSTable(
            facetNames: ["p"],
            sampleSizes: ["p": 10]
        )

        #expect(table.count == 1)
        let emsP = table[Set(["p"])]
        #expect(emsP?.count == 1)
        #expect(abs((emsP?.first?.coefficient ?? 0) - 1.0) < 1e-6)
    }
}
