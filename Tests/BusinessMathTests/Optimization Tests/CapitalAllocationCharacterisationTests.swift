//
//  CapitalAllocationCharacterisationTests.swift
//  BusinessMathTests
//
//  What `CapitalAllocationOptimizer` answers for ordinary input, recorded from the source as it
//  stood at `f10fc8eb` — BEFORE the knapsack's input screening and its table were touched — and
//  committed on its own, green, ahead of that change.
//
//  The point is the word "bit". Each case below is reduced to one line holding the selection in
//  the order the optimiser reports it, and the IEEE bit patterns of `totalNPV`, `capitalUsed` and
//  every allocation. Nothing is compared with a tolerance, so a rewrite that adds the same
//  numbers in a different order — which moves the last bit of a sum of tenths — fails here even
//  though every `abs(a - b) < 1e-9` assertion in the neighbouring suite would still pass.
//
//  The expected lines were MEASURED, not derived: `record(_:)` was printed for every case
//  against the unmodified source and pasted in. Three of them are also worked by hand in
//  `CapitalAllocationTests`-style assertions further down, so the fixture is not merely the
//  implementation agreeing with itself.
//
//  Some of what is pinned is not what anyone would design. The knapsack sizes a project by
//  `Int(capitalRequired)`, which truncates: a project costing 0.5 occupies no room in the table,
//  and one costing 99.75 occupies 99. That is recorded here deliberately and unchanged — this
//  file exists to prove the hardening altered nothing for valid input, and an improvement made
//  in passing would be exactly the kind of change it is meant to catch.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Capital allocation answers the same bits for ordinary input")
struct CapitalAllocationCharacterisationTests {

    // MARK: - Deterministic case generation

    /// SplitMix64. Integer-only, so the cases are the same on every platform and toolchain.
    private struct Mix {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
        mutating func below(_ bound: UInt64) -> Int {
            guard bound > 0 else { return 0 }
            return Int(next() % bound)
        }
    }

    private typealias P = CapitalAllocationOptimizer<Double>.Project

    /// One ordinary project list: non-negative finite costs, finite NPVs.
    ///
    /// The shapes are chosen to reach every branch the table has: whole costs, fractional costs
    /// (truncated by the sizing), a free project, a project the budget cannot reach, and NPVs
    /// that are whole, dyadic, decimal (tenths do not sum exactly, so addition order shows),
    /// zero and negative.
    private static func projects(count: Int, budget: Double, seed: UInt64) -> [P] {
        var mix = Mix(state: seed)
        let span = UInt64(budget * 1.5) + 2
        var result: [P] = []
        for index in 0..<count {
            let whole = Double(mix.below(span))
            let cost: Double
            switch mix.below(8) {
            case 5: cost = whole + 0.5
            case 6: cost = 0
            case 7: cost = budget.rounded(.down) + Double(mix.below(40)) + 0.25
            default: cost = whole
            }
            let magnitude = Double(mix.below(520))
            let npv: Double
            switch mix.below(6) {
            case 3: npv = magnitude / 8
            case 4: npv = magnitude * 0.1
            case 5: npv = Double(mix.below(3)) - magnitude / 16
            default: npv = magnitude - 20
            }
            result.append(P(name: "P\(index)", npv: npv, capitalRequired: cost,
                            risk: Double(mix.below(100)) / 100))
        }
        return result
    }

    private static let counts: [Int] = [1, 2, 3, 5, 8, 12]
    private static let budgets: [Double] = [0, 0.5, 1, 7, 30, 99.5, 250, 1000, 4096.75]
    private static let seedsPerCell: UInt64 = 4

    /// The whole grid, in a fixed order: 6 counts × 9 budgets × 4 seeds = 216 cases.
    private static func grid() -> [(label: String, projects: [P], budget: Double)] {
        var cases: [(label: String, projects: [P], budget: Double)] = []
        for count in counts {
            for budget in budgets {
                for seed in 0..<seedsPerCell {
                    let mixed = UInt64(count) &* 1_000_003 &+ UInt64(budget * 4) &* 7919 &+ seed
                    cases.append((label: "n=\(count) budget=\(budget) seed=\(seed)",
                                  projects: projects(count: count, budget: budget, seed: mixed),
                                  budget: budget))
                }
            }
        }
        return cases
    }

    // MARK: - Reduction to bits

    private static func hex(_ value: Double) -> String {
        String(value.bitPattern, radix: 16)
    }

    /// Everything observable about a result, exactly.
    private static func record(_ result: CapitalAllocationOptimizer<Double>.AllocationResult) -> String {
        let allocations = result.allocations
            .sorted { $0.key < $1.key }
            .map { "\($0.key):\(hex($0.value))" }
            .joined(separator: ",")
        return "sel=\(result.projectsSelected.joined(separator: ","))"
            + "|npv=\(hex(result.totalNPV))|cap=\(hex(result.capitalUsed))|alloc=\(allocations)"
    }

    /// FNV-1a over the record. A digest rather than the line itself only to keep 432 fixtures
    /// readable; the worked cases below spell their lines out in full.
    private static func digest(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }

    // MARK: - The grid

    @Test("Knapsack_OrdinaryGrid_BitIdentical")
    func knapsackOrdinaryGridBitIdentical() throws {
        let optimizer = CapitalAllocationOptimizer<Double>()
        let cases = Self.grid()
        try #require(cases.count == 216)
        try #require(Self.knapsackGolden.count == 216, "one measured digest per case")
        var selectedSomething = 0
        for (index, entry) in cases.enumerated() {
            let result = optimizer.optimizeIntegerProjects(projects: entry.projects, budget: entry.budget)
            let line = Self.record(result)
            #expect(Self.digest(line) == Self.knapsackGolden[index], "\(entry.label): \(line)")
            if !result.projectsSelected.isEmpty { selectedSomething += 1 }
        }
        // The grid must exercise the table, not 216 ways of funding nothing.
        #expect(selectedSomething == Self.knapsackCasesThatFund, "got \(selectedSomething)")
    }

    @Test("Greedy_OrdinaryGrid_BitIdentical")
    func greedyOrdinaryGridBitIdentical() throws {
        let optimizer = CapitalAllocationOptimizer<Double>()
        let cases = Self.grid()
        try #require(Self.greedyGolden.count == 216, "one measured digest per case")
        for (index, entry) in cases.enumerated() {
            let result = optimizer.optimize(projects: entry.projects, budget: entry.budget)
            let line = Self.record(result)
            #expect(Self.digest(line) == Self.greedyGolden[index], "\(entry.label): \(line)")
        }
    }

    // MARK: - Cases spelled out

    /// The type's own documentation example, at the size its DocC uses: a 3 × 120,001 table.
    @Test("Knapsack_DocumentedExample_BitIdentical")
    func knapsackDocumentedExampleBitIdentical() {
        let optimizer = CapitalAllocationOptimizer<Double>()
        let projects = [
            P(name: "Project A", npv: 100_000, capitalRequired: 50_000, risk: 0.2),
            P(name: "Project B", npv: 150_000, capitalRequired: 100_000, risk: 0.3),
        ]
        let result = optimizer.optimizeIntegerProjects(projects: projects, budget: 120_000)
        // By hand: A and B together need 150,000, over budget; B alone is worth more than A alone.
        #expect(Self.record(result) == Self.documentedExampleLine, "got \(Self.record(result))")
        #expect(result.projectsSelected == ["Project B"])
        #expect(result.totalNPV.isEqual(to: 150_000))
        #expect(result.capitalUsed.isEqual(to: 100_000))
    }

    /// Greedy and optimal disagree here, which is the reason the knapsack exists.
    @Test("Knapsack_BeatsGreedy_BitIdentical")
    func knapsackBeatsGreedyBitIdentical() {
        let optimizer = CapitalAllocationOptimizer<Double>()
        let projects = [
            P(name: "Dense", npv: 60, capitalRequired: 10),
            P(name: "Left", npv: 100, capitalRequired: 20),
            P(name: "Right", npv: 120, capitalRequired: 30),
        ]
        let optimal = optimizer.optimizeIntegerProjects(projects: projects, budget: 50)
        let greedy = optimizer.optimize(projects: projects, budget: 50)
        // By hand: ROI is 6, 5, 4, so greedy takes Dense + Left (160, 30 used) and cannot fit
        // Right. The best subset within 50 is Left + Right = 220.
        #expect(Self.record(optimal) == Self.beatsGreedyOptimalLine, "got \(Self.record(optimal))")
        #expect(Self.record(greedy) == Self.beatsGreedyGreedyLine, "got \(Self.record(greedy))")
        #expect(optimal.totalNPV.isEqual(to: 220))
        #expect(greedy.totalNPV.isEqual(to: 160))
    }

    /// Tenths, where the order of addition is visible in the last bit, and truncated costs.
    ///
    /// Read the fixture before trusting it as a specification: the budget is 6.5 and the answer
    /// spends 7.25 (`cap=401d…`). The table sizes the four projects at 1, 2, 3 and 0 whole
    /// units against a budget of 6, so all four "fit", and the result then reports their real
    /// costs. That is a defect in the sizing of fractional amounts, it predates this file, and
    /// it is pinned rather than fixed for the reason given at the top.
    @Test("Knapsack_DecimalValuesAndFractionalCost_BitIdentical")
    func knapsackDecimalValuesAndFractionalCostBitIdentical() {
        let optimizer = CapitalAllocationOptimizer<Double>()
        let projects = [
            P(name: "a", npv: 0.1, capitalRequired: 1),
            P(name: "b", npv: 0.2, capitalRequired: 2),
            P(name: "c", npv: 0.3, capitalRequired: 3.75),
            P(name: "d", npv: 0.7, capitalRequired: 0.5),
        ]
        let result = optimizer.optimizeIntegerProjects(projects: projects, budget: 6.5)
        #expect(Self.record(result) == Self.decimalLine, "got \(Self.record(result))")
    }

    /// The generic parameter is not decoration: `Float` runs the same table.
    @Test("Knapsack_Float_BitIdentical")
    func knapsackFloatBitIdentical() {
        let optimizer = CapitalAllocationOptimizer<Float>()
        let projects = [
            CapitalAllocationOptimizer<Float>.Project(name: "a", npv: 0.1, capitalRequired: 3),
            CapitalAllocationOptimizer<Float>.Project(name: "b", npv: 0.7, capitalRequired: 4),
            CapitalAllocationOptimizer<Float>.Project(name: "c", npv: 0.2, capitalRequired: 2.5),
            CapitalAllocationOptimizer<Float>.Project(name: "d", npv: 1.3, capitalRequired: 9),
        ]
        let result = optimizer.optimizeIntegerProjects(projects: projects, budget: 10)
        let line = "sel=\(result.projectsSelected.joined(separator: ","))"
            + "|npv=\(String(result.totalNPV.bitPattern, radix: 16))"
            + "|cap=\(String(result.capitalUsed.bitPattern, radix: 16))"
        #expect(line == Self.floatLine, "got \(line)")
    }

    /// The early exits, which are valid questions with a true answer of "nothing".
    @Test("Knapsack_NothingToFund_BitIdentical")
    func knapsackNothingToFundBitIdentical() {
        let optimizer = CapitalAllocationOptimizer<Double>()
        let one = [P(name: "a", npv: 10, capitalRequired: 5)]
        let nothing = "sel=|npv=0|cap=0|alloc="
        #expect(Self.record(optimizer.optimizeIntegerProjects(projects: one, budget: 0)) == nothing)
        #expect(Self.record(optimizer.optimizeIntegerProjects(projects: [], budget: 100)) == nothing)
        #expect(Self.record(optimizer.optimizeIntegerProjects(projects: one, budget: 4)) == nothing)
    }

    // MARK: - Measured fixtures

    private static let documentedExampleLine =
        "sel=Project B|npv=41024f8000000000|cap=40f86a0000000000|alloc=Project B:40f86a0000000000"
    private static let beatsGreedyOptimalLine =
        "sel=Right,Left|npv=406b800000000000|cap=4049000000000000"
        + "|alloc=Left:4034000000000000,Right:403e000000000000"
    private static let beatsGreedyGreedyLine =
        "sel=Dense,Left|npv=4064000000000000|cap=403e000000000000"
        + "|alloc=Dense:4024000000000000,Left:4034000000000000"
    private static let decimalLine =
        "sel=d,c,b,a|npv=3ff4cccccccccccd|cap=401d000000000000"
        + "|alloc=a:3ff0000000000000,b:4000000000000000,c:400e000000000000,d:3fe0000000000000"
    private static let floatLine = "sel=d|npv=3fa66666|cap=41100000"
    private static let knapsackCasesThatFund = 171

    private static let knapsackGolden: [UInt64] = [
        0xC5A71F33138C69AE, 0xC5A71F33138C69AE, 0xC5A71F33138C69AE, 0xC5A71F33138C69AE,
        0xC5A71F33138C69AE, 0xC5A71F33138C69AE, 0x847FE9C188F3FB05, 0xC5A71F33138C69AE,
        0xC5A71F33138C69AE, 0x59863AE5D019C9BC, 0xC5A71F33138C69AE, 0xE33AAEC629EEDBC5,
        0x1A56C41B88C3095A, 0x09276CF68E7A823B, 0x35A91E6612440A2F, 0x2838FF43FE8BC841,
        0x175C34F0074047B5, 0xC5A71F33138C69AE, 0xC5A71F33138C69AE, 0x1CC3D7B6ED8A5936,
        0xC5A71F33138C69AE, 0xC5A71F33138C69AE, 0xFC3F825FECEB55FE, 0x27A0B59E3DBC3EF3,
        0xD8E0BF7920CABBEB, 0x849651A524435A9C, 0x7D615DE110C5C3E2, 0xCBF75DD3978C4184,
        0x9305AF25C6D7959E, 0xC5A71F33138C69AE, 0xF5EF432957E071F2, 0x5E6C18666149E848,
        0x650ACEBCA55D178A, 0x5FE3E5864E5612A4, 0xED0F0F90565D88F1, 0x94020B37E1FEBA99,
        0xC5A71F33138C69AE, 0xC5A71F33138C69AE, 0xC5A71F33138C69AE, 0xC5A71F33138C69AE,
        0x98E7AE756E9E645A, 0x5891E485A843F89D, 0xC5A71F33138C69AE, 0xFA39954DCB581242,
        0xC5A71F33138C69AE, 0xC5A71F33138C69AE, 0xC8710154E49D93E9, 0xB684A821C4019B70,
        0xF99572886F0963C5, 0xC5A71F33138C69AE, 0x2845F1A41998A2C3, 0xC5A71F33138C69AE,
        0xB739A21E3BC9B534, 0x2A80195A0FEE3781, 0x9763F0C6B61A04E9, 0x882F3FFCCCDAD106,
        0x0E3211F480E56661, 0x55D2BCE2E22F4F2D, 0x39107DDAB687C074, 0xE657B944E284CB65,
        0xC5A71F33138C69AE, 0xE4BB1063D314E59B, 0xC18DE7E3248EE22F, 0xF77A62AD37F75473,
        0x4384B05BE7BF9025, 0x1F9763F5235A2166, 0x667C301670462B2B, 0x13888064DD817283,
        0x66A71DC352F9888E, 0xC5A71F33138C69AE, 0x12263BC3B4511F96, 0xD8CBB04B9D746A20,
        0xC5A71F33138C69AE, 0xC5A71F33138C69AE, 0xC5A71F33138C69AE, 0xC5A71F33138C69AE,
        0xC5A71F33138C69AE, 0x14C0C8206AE37380, 0x507AA84128FF7589, 0x88829535D7DC6DB2,
        0x2BD16A4403D22E61, 0x8C8911AA68E81990, 0xF6164044C538F5F6, 0xB6AADDE96887F6CF,
        0xDD5D93B815387B4E, 0x478C5A2C097466ED, 0x7D18D2A14F718CBE, 0xFD6B3A90BAF1AB05,
        0xB693DA6F2AC6E11C, 0x4440291D02ABD6DB, 0x248FF238CA476196, 0xADC91723CAD80137,
        0x9A1BEFFA8678A70C, 0xBD652F8CBDA2CEB2, 0x097BB84DD92AFECB, 0xFF42C56EF0790BF5,
        0x950C26467F4226E7, 0x2605FCB88F5DE64C, 0xC73E6B2EDCB345B6, 0xAF6099D732555C34,
        0xEE5FA627282054BC, 0x5A95E8E9EE98030A, 0xC4FAFEA2631B8E1E, 0xC5A71F33138C69AE,
        0x508D076297DD63E0, 0xE1847EBC17FD4333, 0xCB3A6C4287C8D3C6, 0xE5D72ACDF10E54E3,
        0xC5A71F33138C69AE, 0xC5A71F33138C69AE, 0xC5A71F33138C69AE, 0xC5A71F33138C69AE,
        0x3C57A0126EAD7099, 0x4B5C580F8796E6DE, 0xBB9F8871741C16D3, 0x6E2752B74B47264E,
        0x0BBC06B8A29145F8, 0xFB5DBC567AD7A18B, 0x7AB3C2EC88E389DD, 0x382212C5D23AF14E,
        0x57818B284118D76A, 0x108A6782AC13F4FF, 0xC5A71F33138C69AE, 0x4CA48369330122DB,
        0x90844E8C732353A3, 0x856A2E6144920EB0, 0xE65286311FC730EC, 0x9DAC04CE7BC33EE7,
        0xF5E499D521524ABB, 0x58209F5ECF8014DA, 0x57A7DB13C4A74212, 0xE0CB93362C2B1467,
        0xE24D4FCD107CF32C, 0x30D19D7BCFA102AE, 0x3F19958ECAF30CF6, 0x09288C79B3FF8369,
        0x5D9DAAD81AE8A023, 0xD949592660FC07F5, 0x0E1B1216E8216C21, 0xAB967DF5EA9E1240,
        0x63BC4D3CD6080820, 0xADA5B1FE499FAFAE, 0x4A6EE261D854A82E, 0xEA071313CC8DD43B,
        0xC5A71F33138C69AE, 0xC5A71F33138C69AE, 0xC5A71F33138C69AE, 0xC5A71F33138C69AE,
        0x58AE8A8BEEE35086, 0xFC5719718A21D92D, 0xA71488D5236EF970, 0x2317A1A29EB93224,
        0x1FB60813DFBBE2B8, 0xB28DD63C9E4AA1EC, 0x1BFD202BE1BB6230, 0x688F2FA2952015EA,
        0xF8F290ED7D37A0B0, 0xC5A71F33138C69AE, 0x19D37679A568B345, 0xC54FA024BE031E73,
        0x84C8427F25723301, 0x67EDC96F60CFA0A1, 0x1B59636F3210CEEB, 0x460AAC71AE48A50C,
        0x3D186B6FABB1FB23, 0xA8C5748E463EF1E4, 0x6A09DA5978CBEB5C, 0xA5B6A0C1360CDBDA,
        0xA645F9FCCF5837E6, 0x149297DB2B8AF956, 0x9CE1EDEAFE72F830, 0x9C767D73E36296E5,
        0xD2D7561B8C5433EB, 0xD9AD8F0CB2739C18, 0xC2E2E35333126C4B, 0xAFCF54445C900484,
        0xBC4AF549AD6E3C16, 0x134F5697B273EA13, 0xF7EB7CEC35155F8C, 0x9F9E5CD82004DE51,
        0xC5A71F33138C69AE, 0xC5A71F33138C69AE, 0xC5A71F33138C69AE, 0xC5A71F33138C69AE,
        0x83EB76A9FD0952A7, 0xC40354A88667F8D1, 0x5357EB52E9CC7CF4, 0x249481C60984AE85,
        0x1139CE4C63BE0CA6, 0xEBC120C42B2BA75F, 0x71AB09EDFE2CCAD4, 0x2D26E6EAC82C6C97,
        0xF298B5F954295B31, 0x81EC62831A587F7B, 0x37D6759943C5C180, 0x282BAFB53B5A5670,
        0x699F4621BA237702, 0x589FD3ECC7E33E69, 0xEEC46E6F4C9557FA, 0x71D12706CC6ECC50,
        0x2D4042EC043522EC, 0x040B5E42D16601C1, 0x9282027EB5E1925F, 0x0365B732A634B4AC,
        0x70490503B684BCD9, 0x045FAAF337D3320B, 0x7ACE79A6913C36F3, 0xB102CFFE88D4DE6B,
        0x4DC98898898206D7, 0x52DC9D12AF0F5B5F, 0x8A1D79156D721ECD, 0x5B5650A5B6BA2629,
        0xD44BF672887CC549, 0x5E438E7F30304868, 0x9B496086AF88AB2A, 0x108814122F82DAE5,
    ]

    private static let greedyGolden: [UInt64] = [
        0xC5A71F33138C69AE, 0xC5A71F33138C69AE, 0xC5A71F33138C69AE, 0xC5A71F33138C69AE,
        0xC5A71F33138C69AE, 0xC5A71F33138C69AE, 0x847FE9C188F3FB05, 0xC5A71F33138C69AE,
        0xC5A71F33138C69AE, 0x59863AE5D019C9BC, 0x0056A7DD830DC635, 0xE33AAEC629EEDBC5,
        0x1A56C41B88C3095A, 0x09276CF68E7A823B, 0x35A91E6612440A2F, 0x2838FF43FE8BC841,
        0x175C34F0074047B5, 0x9A34FC2AD7CA6CBE, 0xBABE1B00E2E86E94, 0x1CC3D7B6ED8A5936,
        0xC5A71F33138C69AE, 0xC5A71F33138C69AE, 0xFC3F825FECEB55FE, 0x27A0B59E3DBC3EF3,
        0xD8E0BF7920CABBEB, 0x849651A524435A9C, 0x7D615DE110C5C3E2, 0xCBF75DD3978C4184,
        0x9305AF25C6D7959E, 0x0328BD161445091F, 0xF5EF432957E071F2, 0x5E6C18666149E848,
        0x650ACEBCA55D178A, 0x5FE3E5864E5612A4, 0xED0F0F90565D88F1, 0x94020B37E1FEBA99,
        0xC5A71F33138C69AE, 0xC5A71F33138C69AE, 0xC5A71F33138C69AE, 0xC5A71F33138C69AE,
        0x98E7AE756E9E645A, 0x5891E485A843F89D, 0xC5A71F33138C69AE, 0xFA39954DCB581242,
        0xE602145C3A88F817, 0xB22336D7093BBEA9, 0xC8710154E49D93E9, 0xD9D20088635205D2,
        0xF99572886F0963C5, 0xC5A71F33138C69AE, 0x2845F1A41998A2C3, 0x9604A762D154B791,
        0xB739A21E3BC9B534, 0x2A80195A0FEE3781, 0x9763F0C6B61A04E9, 0x551B775ECB61E9BC,
        0xAC7EB12135A44203, 0x55D2BCE2E22F4F2D, 0x39107DDAB687C074, 0xE657B944E284CB65,
        0xC5A71F33138C69AE, 0xE4BB1063D314E59B, 0xC18DE7E3248EE22F, 0xF77A62AD37F75473,
        0x55FE731DDEC04C03, 0x1F9763F5235A2166, 0x42513BEFCEE09EB9, 0x13888064DD817283,
        0x20A8E5BE6CD65FAF, 0xC5A71F33138C69AE, 0x12263BC3B4511F96, 0xE94C7165813920AA,
        0xC5A71F33138C69AE, 0xC5A71F33138C69AE, 0xC5A71F33138C69AE, 0xC5A71F33138C69AE,
        0xF1BC7B6176F84A13, 0x96286979B75521A4, 0x507AA84128FF7589, 0x4678C630973198CC,
        0x8A0060410F3A6263, 0x8C8911AA68E81990, 0xF6164044C538F5F6, 0xB6AADDE96887F6CF,
        0xDD5D93B815387B4E, 0x478C5A2C097466ED, 0x2260A6D5DEC93C35, 0x3E9F61C1B00EDF27,
        0xB693DA6F2AC6E11C, 0x983349AC9C867321, 0x5E66AE264B2A0062, 0xDD149FBD0787E519,
        0x9A1BEFFA8678A70C, 0x63327507B25FF782, 0x91D5C28BC448FD11, 0x4F48BC6346957211,
        0x950C26467F4226E7, 0x2605FCB88F5DE64C, 0xAB83B53045AE4634, 0xAF6099D732555C34,
        0x98A471B8E4F5D1A6, 0x5A95E8E9EE98030A, 0xC4FAFEA2631B8E1E, 0x762A2F0FAF9236F2,
        0x508D076297DD63E0, 0x0E7534A57001A2FF, 0x6022D3B1F442AC10, 0xE5D72ACDF10E54E3,
        0xC5A71F33138C69AE, 0xC5A71F33138C69AE, 0xC5A71F33138C69AE, 0xC5A71F33138C69AE,
        0xB9AD60329106BC15, 0xD69868415EB58B47, 0x7BC667A6778526E9, 0x7175F1ADDCFA3E76,
        0x2C351116967ECDD7, 0x53DC4E3E94931E32, 0xE4A4E235FE8875E5, 0x5DF1FFF5DB538983,
        0x83F727E24C87B2A0, 0x108A6782AC13F4FF, 0x6F61724D3362908D, 0x981D87C711F22D4B,
        0x8F66EBB146ECBF71, 0xD3662042EDD27864, 0x2746029A2E6D790A, 0x9DAC04CE7BC33EE7,
        0xC054189DA22F416E, 0xB0337B72D9753208, 0x57A7DB13C4A74212, 0xE0CB93362C2B1467,
        0x534FE996FD7436DC, 0x30D19D7BCFA102AE, 0xFA9563C29CC65C0E, 0x7876A7AA42918F51,
        0x164FD476014C3084, 0x54AE6FF0026EEA4F, 0x7E629CB43C8252AB, 0x0FFA6BEE747B7106,
        0x63BC4D3CD6080820, 0xF835F9D3B1CBE9C4, 0x4A6EE261D854A82E, 0xCF90839583825511,
        0xC5A71F33138C69AE, 0xC5A71F33138C69AE, 0xC5A71F33138C69AE, 0xC5A71F33138C69AE,
        0xDCB12DF7C109CD4B, 0xFA82704206CB7DED, 0x0E9737BAA90359AD, 0x09F2BE8E792563FD,
        0x52FD08479C1FCFB2, 0xB28DD63C9E4AA1EC, 0x042A4E9842050A8E, 0xF50ABA4F7DD83F1E,
        0xF8F290ED7D37A0B0, 0x9B0DEF9B52FD609D, 0xD71DB8E3307BEC98, 0xB34C54086357F5FF,
        0x5E6962493326DD7A, 0x67EDC96F60CFA0A1, 0xC168F71FB89D396B, 0xE8A7618FB96BF66A,
        0x143669C6DBCE8EC2, 0x539EFD49814BD432, 0x75418C7724553EE6, 0x278DAD87F9EA1C4F,
        0xB017C9F312D695CF, 0xBC6AFBC0E2375DE1, 0xD95715BE0C901C7C, 0xD95EC4A5104BDC1D,
        0x6D7AC569AE3260DB, 0x6FCF2B04E8D20488, 0xC2E2E35333126C4B, 0xAFCF54445C900484,
        0xFDA508A5650C6222, 0xE616CDF40EAF1DB1, 0x5D8C03C4B44B2E3C, 0x2EFD1F14FDBF8CAE,
        0xC5A71F33138C69AE, 0xC5A71F33138C69AE, 0xC5A71F33138C69AE, 0xC5A71F33138C69AE,
        0xE5601A723CFB3CE3, 0x43609A182628D029, 0x91B9BCF922403736, 0x1B704CD082152CED,
        0x040C21E5F1D72ECC, 0xC929E58CD313FB39, 0x8EEFDCF8295F4E02, 0xF34419A9B72090DF,
        0x6F25865546D46C4B, 0xB20A109C1029A63B, 0x114ECD1C90EC6C25, 0xE4963E06A2DF4402,
        0x924FEAE55BCAC882, 0x03726F8353FE7867, 0xE41AC822491AA39A, 0xBBD4A8E919499D3F,
        0x40B56C201E737CA5, 0xA7274BBDA768F385, 0xD791FEAEF4DC17EF, 0xA3328318B776E009,
        0x931BC23B177EA1A1, 0xFE68DE765B8DE811, 0xF2CD2BE16F6785B3, 0xE95B771E80DA8707,
        0x72FAD3F109273EBB, 0x6F7AA3F92EC3D871, 0x8A1D79156D721ECD, 0x0D36B6CDC6C00833,
        0x9F78DA453C37F7AA, 0xA96A437140240FDF, 0xD798A1466AABE110, 0x8293E8E95E950C42,
    ]
}
