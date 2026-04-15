/// Deterministic RNG for stochastic process tests.
/// Uses LCG per TDD contract with Box-Muller for normal draws.
struct StochasticTestRNG {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    /// Generate next uniform in (0, 1).
    mutating func nextUniform() -> Double {
        state = state &* 6364136223846793005 &+ 1
        return Double(state) / Double(UInt64.max)
    }

    /// Generate a standard normal draw via Box-Muller.
    mutating func nextNormal() -> Double {
        let u1 = max(nextUniform(), 1e-15)
        let u2 = nextUniform()
        return (-2.0 * Double.log(u1)).squareRoot() * Double.cos(2.0 * .pi * u2)
    }
}
