import Testing
@testable import BusinessMath

@Suite("LME Application/Convenience Functions")
struct LMEApplicationsTests {

    // MARK: - Shared test data

    /// Strongly clustered data: 4 groups with distinct means.
    /// Group means: ~10, ~20, ~15, ~25
    let clusteredValues: [[Double]] = [
        [10.2, 9.8, 10.0],      // Group 0: mean ~10
        [20.5, 19.7, 20.3],     // Group 1: mean ~20
        [14.8, 15.3, 15.0],     // Group 2: mean ~15
        [25.1, 24.9, 25.2]      // Group 3: mean ~25
    ]

    /// Unclustered data: all groups drawn from the same distribution.
    let unclusteredValues: [[Double]] = [
        [5.1, 4.9, 5.0],
        [5.2, 4.8, 5.1],
        [5.0, 4.9, 5.1],
        [5.0, 5.2, 4.8]
    ]

    /// Data with varying slopes — random-slope model is clearly better.
    /// 4 groups, slopes vary: 2.0, 0.5, 1.0, 1.5
    let slopeData: (y: [Double], x: [Double], groups: [Int]) = {
        let x: [Double] = [1, 2, 3, 4, 5, 1, 2, 3, 4, 5, 1, 2, 3, 4, 5, 1, 2, 3, 4, 5]
        // Group 0: 10 + 2.0*x
        // Group 1: 20 + 0.5*x
        // Group 2: 25 + 1.0*x
        // Group 3: 15 + 1.5*x
        let y: [Double] = [
            12.1, 14.0, 15.9, 18.1, 19.9,
            20.6, 21.0, 21.4, 22.1, 22.4,
            26.1, 26.9, 28.1, 29.0, 29.9,
            16.6, 18.1, 19.4, 21.1, 22.4
        ]
        let groups = [0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3]
        return (y, x, groups)
    }()

    // MARK: - Helper: Fit both models on slope data

    private func fitBothModels() throws -> (
        reduced: RandomInterceptResult<Double>,
        full: RandomSlopeResult<Double>
    ) {
        let xRows = slopeData.x.map { [1.0, $0] }
        let X = try DenseMatrix(xRows)
        let grouping = try GroupingFactor(slopeData.groups)

        let interceptModel = RandomInterceptModel(
            fixedEffects: X, response: slopeData.y, grouping: grouping)
        let reduced = try fitRandomIntercept(interceptModel)

        let slopeModel = RandomSlopeModel(
            fixedEffects: X, response: slopeData.y,
            grouping: grouping, slopeColumn: 1)
        let full = try fitRandomSlope(slopeModel)

        return (reduced, full)
    }

    // MARK: - Test 1: clusterICC from nested arrays matches fitted model ICC

    @Test("clusterICC from nested arrays matches fitted model ICC")
    func clusterICCNestedMatchesFitted() throws {
        let iccValue: Double = try clusterICC(clusteredValues)

        // Manually fit the same model
        let y = clusteredValues.flatMap { $0 }
        var groups = [Int]()
        for (g, group) in clusteredValues.enumerated() {
            groups.append(contentsOf: Array(repeating: g, count: group.count))
        }
        let grouping = try GroupingFactor(groups)
        let X = DenseMatrix<Double>(rows: y.count, columns: 1, repeating: 1.0)
        let model = RandomInterceptModel(fixedEffects: X, response: y, grouping: grouping)
        let result = try fitRandomIntercept(model)

        #expect(abs(iccValue - result.icc) < 1e-10)
    }

    // MARK: - Test 2: clusterICC from flat arrays matches nested arrays version

    @Test("clusterICC from flat arrays matches nested arrays version")
    func clusterICCFlatMatchesNested() throws {
        let iccNested: Double = try clusterICC(clusteredValues)

        let flatValues = clusteredValues.flatMap { $0 }
        var flatGroups = [Int]()
        for (g, group) in clusteredValues.enumerated() {
            flatGroups.append(contentsOf: Array(repeating: g, count: group.count))
        }
        let iccFlat: Double = try clusterICC(values: flatValues, groups: flatGroups)

        #expect(abs(iccNested - iccFlat) < 1e-10)
    }

    // MARK: - Test 3: clusterICC high for clustered data (>0.8)

    @Test("clusterICC high for strongly clustered data")
    func clusterICCHighForClusteredData() throws {
        let iccValue: Double = try clusterICC(clusteredValues)
        #expect(iccValue > 0.8)
    }

    // MARK: - Test 4: clusterICC low for unclustered data (<0.3)

    @Test("clusterICC low for unclustered data")
    func clusterICCLowForUnclusteredData() throws {
        let iccValue: Double = try clusterICC(unclusteredValues)
        #expect(iccValue < 0.3)
    }

    // MARK: - Test 5: clusterICC with single group throws

    @Test("clusterICC with single group throws")
    func clusterICCSingleGroupThrows() throws {
        let singleGroup: [[Double]] = [[1.0, 2.0, 3.0]]
        #expect(throws: BusinessMathError.self) {
            let _: Double = try clusterICC(singleGroup)
        }
    }

    // MARK: - Test 6: clusterICC with empty input throws

    @Test("clusterICC with empty input throws")
    func clusterICCEmptyInputThrows() throws {
        let empty: [[Double]] = []
        #expect(throws: BusinessMathError.self) {
            let _: Double = try clusterICC(empty)
        }
    }

    // MARK: - Test 7: LRT chi-square is non-negative

    @Test("LRT chi-square statistic is non-negative")
    func lrtChiSquareNonNegative() throws {
        let (reduced, full) = try fitBothModels()
        let lrt = try likelihoodRatioTest(reduced: reduced, full: full)

        #expect(lrt.chiSquare >= 0.0)
        #expect(lrt.degreesOfFreedom == 2)
    }

    // MARK: - Test 8: LRT p-value in [0, 1]

    @Test("LRT p-value is in [0, 1]")
    func lrtPValueInRange() throws {
        let (reduced, full) = try fitBothModels()
        let lrt = try likelihoodRatioTest(reduced: reduced, full: full)

        #expect(lrt.pValue >= 0.0)
        #expect(lrt.pValue <= 1.0)
    }

    // MARK: - Test 9: AIC selection picks correct model

    @Test("AIC selection picks full model when slopes vary")
    func aicSelectsFullModel() throws {
        let (reduced, full) = try fitBothModels()
        let selection = selectByAIC(reduced: reduced, full: full)

        // With clearly varying slopes, the slope model should be preferred
        #expect(selection == .full)
    }

    // MARK: - Test 10: BIC selection picks correct model

    @Test("BIC selection picks full model when slopes vary")
    func bicSelectsFullModel() throws {
        let (reduced, full) = try fitBothModels()
        let selection = selectByBIC(reduced: reduced, full: full)

        // With clearly varying slopes, the slope model should be preferred
        #expect(selection == .full)
    }

    // MARK: - Test 11: Design effect >= 1 for clustered data

    @Test("Design effect >= 1 for clustered data")
    func designEffectAtLeastOne() throws {
        let y = clusteredValues.flatMap { $0 }
        var groups = [Int]()
        for (g, group) in clusteredValues.enumerated() {
            groups.append(contentsOf: Array(repeating: g, count: group.count))
        }
        let grouping = try GroupingFactor(groups)
        let X = DenseMatrix<Double>(rows: y.count, columns: 1, repeating: 1.0)
        let model = RandomInterceptModel(fixedEffects: X, response: y, grouping: grouping)
        let result = try fitRandomIntercept(model)

        let deff = designEffect(result)
        #expect(deff >= 1.0)
        // With high ICC and cluster size 3, DEFF should be > 2
        #expect(deff > 2.0)
    }

    // MARK: - Test 12: Design effect ≈ 1 when ICC ≈ 0

    @Test("Design effect approximately 1 when ICC is near zero")
    func designEffectNearOneWhenNoGroupEffect() throws {
        let y = unclusteredValues.flatMap { $0 }
        var groups = [Int]()
        for (g, group) in unclusteredValues.enumerated() {
            groups.append(contentsOf: Array(repeating: g, count: group.count))
        }
        let grouping = try GroupingFactor(groups)
        let X = DenseMatrix<Double>(rows: y.count, columns: 1, repeating: 1.0)
        let model = RandomInterceptModel(fixedEffects: X, response: y, grouping: grouping)
        let result = try fitRandomIntercept(model)

        let deff = designEffect(result)
        // With ICC near 0, DEFF should be close to 1
        #expect(deff < 1.5)
        #expect(deff >= 1.0)
    }

    // MARK: - Test 13: clusterICC from flat arrays with mismatched lengths throws

    @Test("clusterICC from flat arrays with mismatched lengths throws")
    func clusterICCFlatMismatchedLengthsThrows() throws {
        #expect(throws: BusinessMathError.self) {
            let _: Double = try clusterICC(values: [1.0, 2.0, 3.0], groups: [0, 1])
        }
    }

    // MARK: - Test 14: LRT degrees of freedom is 2

    @Test("LRT degrees of freedom equals 2 for intercept vs slope")
    func lrtDegreesOfFreedom() throws {
        let (reduced, full) = try fitBothModels()
        let lrt = try likelihoodRatioTest(reduced: reduced, full: full)

        #expect(lrt.degreesOfFreedom == 2)
    }
}
