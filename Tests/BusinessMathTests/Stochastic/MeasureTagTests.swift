import Testing
@testable import BusinessMath

@Suite("MeasureTag Protocol")
struct MeasureTagTests {

    @Test("RiskNeutral has correct name")
    func riskNeutralName() {
        #expect(RiskNeutral.name == "risk-neutral")
    }

    @Test("Physical has correct name")
    func physicalName() {
        #expect(Physical.name == "physical")
    }

    @Test("RiskNeutral is Sendable")
    func riskNeutralSendable() {
        let value = RiskNeutral()
        let _: any Sendable = value
        #expect(RiskNeutral.name == "risk-neutral")
    }

    @Test("Physical is Sendable")
    func physicalSendable() {
        let value = Physical()
        let _: any Sendable = value
        #expect(Physical.name == "physical")
    }
}
