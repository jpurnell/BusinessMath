import Testing
@testable import BusinessMath

// A mock process for testing protocol conformance
struct MockConstantProcess: StochasticProcess {
    typealias State = Double

    let name: String = "MockConstant"
    let allowsNegativeValues: Bool = false
    let factors: Int = 1

    func step(from current: Double, dt: Double, normalDraws: Double) -> Double {
        current // Always returns current value unchanged
    }
}

struct MockDriftProcess: StochasticProcess {
    typealias State = Double

    let name: String = "MockDrift"
    let allowsNegativeValues: Bool = true
    let factors: Int = 1

    func step(from current: Double, dt: Double, normalDraws: Double) -> Double {
        current + dt // Deterministic unit drift
    }
}

@Suite("StochasticProcess Protocol")
struct StochasticProcessTests {

    @Test("Mock process conforms to StochasticProcess")
    func mockConformance() {
        let process = MockConstantProcess()
        #expect(process.name == "MockConstant")
        #expect(process.factors == 1)
        #expect(process.allowsNegativeValues == false)
    }

    @Test("Mock process step returns expected value")
    func mockStep() {
        let process = MockConstantProcess()
        let result = process.step(from: 100.0, dt: 1.0/12.0, normalDraws: 0.5)
        #expect(result == 100.0)
    }

    @Test("Mock drift process accumulates over steps")
    func mockDriftAccumulates() {
        let process = MockDriftProcess()
        var value = 0.0
        let dt = 1.0/12.0
        for _ in 0..<12 {
            value = process.step(from: value, dt: dt, normalDraws: 0.0)
        }
        #expect(abs(value - 1.0) < 1e-10)
    }

    @Test("Process with negative values allowed")
    func negativeValuesFlag() {
        let process = MockDriftProcess()
        #expect(process.allowsNegativeValues == true)
    }

    @Test("StochasticProcess is Sendable")
    func processSendable() {
        let process = MockConstantProcess()
        let _: any Sendable = process
        #expect(process.name == "MockConstant")
    }

    @Test("Process State associated type is Double for scalar processes")
    func stateType() {
        let process = MockConstantProcess()
        let result: MockConstantProcess.State = process.step(from: 50.0, dt: 0.1, normalDraws: 0.0)
        #expect(result == 50.0)
    }
}
