//
//  CapitalAllocationRefusalTests.swift
//  BusinessMathTests
//
//  The 0-1 knapsack sizes its table from two caller-supplied numbers, and until this file one
//  ordinary-looking value in either of them ended the process:
//
//  | input                                   | before                                        |
//  | capitalRequired: -5                     | index out of range in the table — fatal       |
//  | the only project has capitalRequired nan| `for i in 1...0` — fatal                      |
//  | budget: 1e12 (finite, representable)    | an 8 TB allocation requested                  |
//  | capitalRequired nan, among clean ones   | project silently dropped, answer looks normal |
//  | budget: nan / +inf / -1                 | "fund nothing", totalNPV 0                    |
//
//  The first two were measured by running the test and watching the test process die; they are
//  marked below. The third was NOT run against the old source — doing so means asking a shared
//  machine for eight terabytes to find out what happens — and is asserted only after the fix.
//
//  A consumer reaches this from a network request: an MCP tool forwards a JSON `cost` straight
//  into `capitalRequired`. So "fatal" above means a remote caller stopping a server.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Capital allocation refuses input it cannot size")
struct CapitalAllocationRefusalTests {

    private typealias Optimizer = CapitalAllocationOptimizer<Double>
    private typealias P = CapitalAllocationOptimizer<Double>.Project

    private static let site = "CapitalAllocationOptimizer.optimizeIntegerProjects"

    private static let clean: [P] = [
        P(name: "A", npv: 100, capitalRequired: 50),
        P(name: "D", npv: 70, capitalRequired: 20),
    ]

    /// `clean` with one more project spliced into the middle, so its index is 1.
    private static func withMiddle(_ project: P) -> [P] {
        [clean[0], project, clean[1]]
    }

    /// The non-throwing form has no channel for a refusal except the result, so it answers with
    /// totals that cannot be read as "fund nothing".
    private static func isMarkedUnanswerable(_ result: Optimizer.AllocationResult) -> Bool {
        result.totalNPV.isNaN && result.capitalUsed.isNaN
            && result.projectsSelected.isEmpty && result.allocations.isEmpty
    }

    private static func refusal(_ body: () throws -> Optimizer.AllocationResult) -> BusinessMathError? {
        do {
            _ = try body()
            return nil
        } catch let error as BusinessMathError {
            return error
        } catch {
            return nil
        }
    }

    // MARK: - The stated limits

    @Test("Limits_AreTheStatedNumbers")
    func limitsAreTheStatedNumbers() {
        #expect(Optimizer.maximumAmount.isEqual(to: 9_007_199_254_740_992.0), "2^53")
        #expect(Optimizer.maximumTableCells == 10_000_000)
    }

    // MARK: - capitalRequired

    @Test("NegativeCapitalRequired_IsRefusedByName")
    func negativeCapitalRequiredIsRefusedByName() {
        let projects = Self.withMiddle(P(name: "C", npv: 80, capitalRequired: -5))
        let error = Self.refusal {
            try Optimizer().optimizeIntegerProjects(validating: projects, budget: 60)
        }
        #expect(error == .negativeValue(name: "projects[1].capitalRequired", value: -5, context: Self.site))
        #expect(error?.errorDescription
                == "Negative value for 'projects[1].capitalRequired' (-5.0) in \(Self.site)")
    }

    @Test("NonFiniteCapitalRequired_IsRefusedByName", arguments: [
        (Double.nan, "nan"), (Double.infinity, "inf"), (-Double.infinity, "-inf"),
    ])
    func nonFiniteCapitalRequiredIsRefusedByName(cost: Double, spelled: String) {
        let projects = Self.withMiddle(P(name: "C", npv: 80, capitalRequired: cost))
        let error = Self.refusal {
            try Optimizer().optimizeIntegerProjects(validating: projects, budget: 60)
        }
        #expect(error == .invalidInput(
            message: "projects[1].capitalRequired must be a finite number",
            value: spelled, expectedRange: "0...9007199254740992"))
    }

    @Test("NonFiniteCapitalRequired_Message")
    func nonFiniteCapitalRequiredMessage() {
        let projects = Self.withMiddle(P(name: "C", npv: 80, capitalRequired: .nan))
        let error = Self.refusal {
            try Optimizer().optimizeIntegerProjects(validating: projects, budget: 60)
        }
        #expect(error?.errorDescription
                == "Invalid input: projects[1].capitalRequired must be a finite number"
                + " (provided: nan) (expected: 0...9007199254740992)")
    }

    @Test("CapitalRequiredBeyondTheBound_IsRefusedByName")
    func capitalRequiredBeyondTheBoundIsRefusedByName() {
        let projects = [P(name: "huge", npv: 1, capitalRequired: 1e300), Self.clean[0]]
        let error = Self.refusal {
            try Optimizer().optimizeIntegerProjects(validating: projects, budget: 60)
        }
        #expect(error == .outOfRange(
            value: 1e300, min: 0, max: 9_007_199_254_740_992,
            context: "projects[0].capitalRequired of \(Self.site)"))
        #expect(error?.errorDescription
                == "Value 1e+300 out of range [0.0, 9007199254740992.0]"
                + " in projects[0].capitalRequired of \(Self.site)")
    }

    /// The bound itself is usable; the first value past it is not.
    @Test("CapitalRequired_BoundIsInclusive")
    func capitalRequiredBoundIsInclusive() throws {
        let atBound = [P(name: "edge", npv: 1, capitalRequired: 9_007_199_254_740_992), Self.clean[1]]
        let result = try Optimizer().optimizeIntegerProjects(validating: atBound, budget: 60)
        #expect(result.projectsSelected == ["D"], "unaffordable, not unusable")
        let past = [P(name: "edge", npv: 1, capitalRequired: 9_007_199_254_740_994)]
        #expect(Self.refusal { try Optimizer().optimizeIntegerProjects(validating: past, budget: 60) }
                == .outOfRange(value: 9_007_199_254_740_994, min: 0, max: 9_007_199_254_740_992,
                               context: "projects[0].capitalRequired of \(Self.site)"))
    }

    // MARK: - npv

    @Test("NonFiniteNPV_IsRefusedByName", arguments: [(Double.nan, "nan"), (Double.infinity, "inf")])
    func nonFiniteNPVIsRefusedByName(npv: Double, spelled: String) {
        let projects = [Self.clean[0], Self.clean[1], P(name: "C", npv: npv, capitalRequired: 5)]
        let error = Self.refusal {
            try Optimizer().optimizeIntegerProjects(validating: projects, budget: 60)
        }
        #expect(error == .invalidInput(
            message: "projects[2].npv must be a finite number",
            value: spelled, expectedRange: "any finite value"))
    }

    // MARK: - budget

    @Test("NonFiniteBudget_IsRefusedByName", arguments: [(Double.nan, "nan"), (Double.infinity, "inf")])
    func nonFiniteBudgetIsRefusedByName(budget: Double, spelled: String) {
        let error = Self.refusal {
            try Optimizer().optimizeIntegerProjects(validating: Self.clean, budget: budget)
        }
        #expect(error == .invalidInput(
            message: "budget must be a finite number",
            value: spelled, expectedRange: "0...9007199254740992"))
    }

    @Test("NegativeBudget_IsRefusedByName")
    func negativeBudgetIsRefusedByName() {
        let error = Self.refusal {
            try Optimizer().optimizeIntegerProjects(validating: Self.clean, budget: -1)
        }
        #expect(error == .negativeValue(name: "budget", value: -1, context: Self.site))
        #expect(error?.errorDescription == "Negative value for 'budget' (-1.0) in \(Self.site)")
    }

    @Test("BudgetBeyondTheBound_IsRefusedByName")
    func budgetBeyondTheBoundIsRefusedByName() {
        let error = Self.refusal {
            try Optimizer().optimizeIntegerProjects(validating: Self.clean, budget: 1e300)
        }
        #expect(error == .outOfRange(value: 1e300, min: 0, max: 9_007_199_254_740_992,
                                     context: "budget of \(Self.site)"))
    }

    /// The budget is checked before the early exits, so contamination is not hidden by an
    /// empty project list.
    @Test("UnusableBudget_IsRefusedEvenWithNoProjects")
    func unusableBudgetIsRefusedEvenWithNoProjects() {
        let error = Self.refusal {
            try Optimizer().optimizeIntegerProjects(validating: [], budget: .nan)
        }
        #expect(error == .invalidInput(message: "budget must be a finite number",
                                       value: "nan", expectedRange: "0...9007199254740992"))
    }

    // MARK: - The table

    /// One project, so the table is two rows. 4,999,999 whole units of reachable budget is
    /// 2 × 5,000,000 cells — exactly the ceiling — and is answered; one more unit is refused.
    @Test("Table_CeilingIsExact")
    func tableCeilingIsExact() throws {
        let fits = [P(name: "only", npv: 3, capitalRequired: 4_999_999)]
        let answered = try Optimizer().optimizeIntegerProjects(validating: fits, budget: 4_999_999)
        #expect(answered.projectsSelected == ["only"])
        #expect(answered.totalNPV.isEqual(to: 3))

        let over = [P(name: "only", npv: 3, capitalRequired: 5_000_000)]
        let error = Self.refusal {
            try Optimizer().optimizeIntegerProjects(validating: over, budget: 5_000_000)
        }
        let context = "\(Self.site): 2 rows × 5000001 budget units = 10000002 cells;"
            + " express budget and capitalRequired in a coarser unit (thousands, millions),"
            + " or use optimize(projects:budget:)"
        #expect(error == .resourceExhausted(
            resource: "capital allocation table cells", limit: 10_000_000, context: context))
        #expect(error?.errorDescription
                == "capital allocation table cells limit exceeded (10000000) in \(context)")
    }

    /// A project count large enough to overflow the cell arithmetic is a refusal, not a wrap.
    @Test("Table_ManyProjectsAgainstALargeBudget_IsRefused")
    func tableManyProjectsAgainstALargeBudgetIsRefused() {
        var projects: [P] = []
        for index in 0..<2_000 {
            projects.append(P(name: "p\(index)", npv: 1, capitalRequired: 9_000_000_000_000_000))
        }
        let error = Self.refusal {
            try Optimizer().optimizeIntegerProjects(validating: projects, budget: 9_007_199_254_740_992)
        }
        guard case .resourceExhausted(let resource, let limit, _)? = error else {
            Issue.record("expected resourceExhausted, got \(String(describing: error))")
            return
        }
        #expect(resource == "capital allocation table cells")
        #expect(limit == 10_000_000)
    }

    /// The table is as wide as the money that can actually be spent, not as wide as the budget.
    /// A budget of a trillion over projects costing 77 in total is a 78-column problem, and its
    /// answer is the answer at a budget of 77. NOT run against the old source: see the header.
    @Test("BudgetFarAboveTotalCost_IsAnsweredNotAllocated")
    func budgetFarAboveTotalCostIsAnsweredNotAllocated() throws {
        let projects = [
            P(name: "a", npv: 0.1, capitalRequired: 30),
            P(name: "b", npv: -4, capitalRequired: 5),
            P(name: "c", npv: 0.2, capitalRequired: 40),
            P(name: "d", npv: 0.7, capitalRequired: 7),
        ]
        let vast = try Optimizer().optimizeIntegerProjects(validating: projects, budget: 1e12)
        let exact = try Optimizer().optimizeIntegerProjects(validating: projects, budget: 77)
        #expect(vast.projectsSelected == ["d", "c", "a"])
        #expect(vast.projectsSelected == exact.projectsSelected)
        #expect(vast.totalNPV.bitPattern == exact.totalNPV.bitPattern)
        #expect(vast.capitalUsed.isEqual(to: 77))
        #expect(Optimizer().optimizeIntegerProjects(projects: projects, budget: 1e12).projectsSelected
                == ["d", "c", "a"])
    }

    // MARK: - The non-throwing form

    /// RED BY CRASH before the fix: `dp[i - 1][w - cost]` with a negative cost indexes past the
    /// end of the row.
    @Test("NonThrowing_NegativeCapitalRequired_IsMarkedNotFatal")
    func nonThrowingNegativeCapitalRequiredIsMarkedNotFatal() {
        let projects = Self.withMiddle(P(name: "C", npv: 80, capitalRequired: -5))
        let result = Optimizer().optimizeIntegerProjects(projects: projects, budget: 60)
        #expect(Self.isMarkedUnanswerable(result), "got \(result)")
    }

    /// RED BY CRASH before the fix: the unsizable project was filtered out, leaving none, and
    /// `1...0` is not a range.
    @Test("NonThrowing_OnlyProjectUnsizable_IsMarkedNotFatal")
    func nonThrowingOnlyProjectUnsizableIsMarkedNotFatal() {
        let projects = [P(name: "C", npv: 80, capitalRequired: .nan)]
        let result = Optimizer().optimizeIntegerProjects(projects: projects, budget: 60)
        #expect(Self.isMarkedUnanswerable(result), "got \(result)")
    }

    /// Before the fix this returned the clean projects' allocation with nothing to say one had
    /// been left out — the "silently dropping a value" the contamination contract forbids.
    @Test("NonThrowing_UnsizableAmongClean_IsMarkedNotDropped")
    func nonThrowingUnsizableAmongCleanIsMarkedNotDropped() {
        let projects = Self.withMiddle(P(name: "C", npv: 80, capitalRequired: .nan))
        let result = Optimizer().optimizeIntegerProjects(projects: projects, budget: 60)
        #expect(Self.isMarkedUnanswerable(result), "got \(result)")
    }

    /// Before the fix each of these was "fund nothing, NPV 0" — a measured-looking zero.
    @Test("NonThrowing_UnusableBudget_IsMarked", arguments: [Double.nan, Double.infinity, -1.0, 1e300])
    func nonThrowingUnusableBudgetIsMarked(budget: Double) {
        let result = Optimizer().optimizeIntegerProjects(projects: Self.clean, budget: budget)
        #expect(Self.isMarkedUnanswerable(result), "got \(result)")
    }

    @Test("NonThrowing_TableOverCeiling_IsMarked")
    func nonThrowingTableOverCeilingIsMarked() {
        let over = [P(name: "only", npv: 3, capitalRequired: 5_000_000)]
        let result = Optimizer().optimizeIntegerProjects(projects: over, budget: 5_000_000)
        #expect(Self.isMarkedUnanswerable(result), "got \(result)")
    }

    // MARK: - Controls

    /// The two forms are one computation. Passes before and after.
    @Test("ValidInput_BothFormsAgreeToTheBit")
    func validInputBothFormsAgreeToTheBit() throws {
        let projects = [
            P(name: "a", npv: 0.1, capitalRequired: 1),
            P(name: "b", npv: 0.2, capitalRequired: 2),
            P(name: "c", npv: 0.3, capitalRequired: 3.75),
            P(name: "d", npv: 0.7, capitalRequired: 0.5),
        ]
        for budget in [0.0, 0.5, 3, 6.5, 100] {
            let plain = Optimizer().optimizeIntegerProjects(projects: projects, budget: budget)
            let checked = try Optimizer().optimizeIntegerProjects(validating: projects, budget: budget)
            #expect(plain.projectsSelected == checked.projectsSelected)
            #expect(plain.totalNPV.bitPattern == checked.totalNPV.bitPattern)
            #expect(plain.capitalUsed.bitPattern == checked.capitalUsed.bitPattern)
            #expect(plain.allocations == checked.allocations)
        }
    }

    /// A zero budget and an empty list are valid questions whose true answer is zero, and stay so.
    @Test("NothingToFund_IsZeroNotMarked")
    func nothingToFundIsZeroNotMarked() throws {
        let none = try Optimizer().optimizeIntegerProjects(validating: [], budget: 100)
        let broke = try Optimizer().optimizeIntegerProjects(validating: Self.clean, budget: 0)
        for result in [none, broke] {
            #expect(result.totalNPV.isEqual(to: 0))
            #expect(result.capitalUsed.isEqual(to: 0))
            #expect(result.projectsSelected.isEmpty)
        }
    }

    /// `risk` is carried by `Project` and read by neither allocator, so it is not screened.
    @Test("Risk_IsNotAnInputToEitherAllocator")
    func riskIsNotAnInputToEitherAllocator() throws {
        let projects = [P(name: "A", npv: 100, capitalRequired: 50, risk: .nan)]
        let result = try Optimizer().optimizeIntegerProjects(validating: projects, budget: 60)
        #expect(result.projectsSelected == ["A"])
        #expect(result.totalNPV.isEqual(to: 100))
    }
}
