import Testing
@testable import BusinessMath

@Suite("ProcessState Protocol")
struct ProcessStateTests {

    @Test("Double conforms to ProcessState")
    func doubleConformance() {
        let value: Double = 72.50
        let _: any ProcessState = value
        #expect(value == 72.50)
    }

    @Test("Double dimension is 1")
    func doubleDimension() {
        #expect(Double.dimension == 1)
    }

    @Test("Double Scalar is Double")
    func doubleScalar() {
        // Verify the associated type by using it
        let value: Double = 42.0
        let scalar: Double.Scalar = value
        #expect(scalar == 42.0)
    }

    @Test("Double NormalDraws is Double")
    func doubleNormalDraws() {
        // Verify the NormalDraws associated type
        let draw: Double.NormalDraws = 0.5
        #expect(draw == 0.5)
    }
}
