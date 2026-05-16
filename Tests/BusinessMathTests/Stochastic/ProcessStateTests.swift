import Testing
@testable import BusinessMath

@Suite("ProcessState Protocol")
struct ProcessStateTests {

    @Test("Double conforms to ProcessState")
    func doubleConformance() {
        let value: Double = 72.50
        let _: any ProcessState = value
        #expect(abs(value - 72.50) < 1e-6)
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
        #expect(abs(scalar - 42.0) < 1e-6)
    }

    @Test("Double NormalDraws is Double")
    func doubleNormalDraws() {
        // Verify the NormalDraws associated type
        let draw: Double.NormalDraws = 0.5
        #expect(abs(draw - 0.5) < 1e-6)
    }
}
