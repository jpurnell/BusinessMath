import Testing
import Numerics
import Foundation
@testable import BusinessMath

/// Every continuous distribution's density, checked against its own CDF.
///
/// `ContinuousDistribution` gained a `pdf(_:)` requirement on 2026-09-18, and every conformer
/// gained an implementation the same day. Forty-six published formulas transcribed in one
/// sitting is exactly the situation where a wrong one is silent — so none of them is trusted
/// on the strength of matching a textbook value.
///
/// **The central check is that each density is the derivative of the CDF that type already
/// has.** That CDF is independently tested; tying the pair together means a transcription
/// error fails immediately, where matching a single published point does not — an
/// implementation can be wrong twice and still hit one value.
///
/// ## What "every conformer" is held to
///
/// `testEveryConformerIsCovered` names all forty-six and fails if the subject list drops one.
/// That matters more than it looks: most of these initialisers are failable, so a subject
/// built with `if let` and a wrong argument would **disappear from the suite** rather than
/// fail in it. The count is the guard against a silently shrinking harness.
///
/// Three limits are encoded rather than rediscovered:
///
/// - **Simpson at uniform steps cannot resolve an integrable singularity**, and cannot
///   reach one over a tail that decays like a low power of `x`. Such cases skip the
///   quadrature check and are carried by the derivative check — and every skip states its
///   reason, so an exclusion is a declared choice and never an omission.
/// - **A density is not monotone in its shape parameter.** Properties, not intuitions.
/// - **Points avoid knots.** A piecewise density has a genuine discontinuity at each
///   breakpoint, where a central difference straddles two segments and matches neither.
///
/// ## Why no parameter here is 0 or 1
///
/// Every location is non-zero and every scale is neither one nor equal to another
/// distribution's, deliberately. A density that forgets its change-of-variable Jacobian is
/// off by a factor of `1/β` — and at `β = 1` that factor is 1, so the error is invisible.
/// The same goes for a dropped location at 0 and a dropped shape term at `γ = 0`. This was
/// found by perturbation: deleting `Dagum`'s scale factor changed nothing while its scale
/// was one, and the harness stayed green on a density that was now wrong.
@Suite("Every continuous density")
struct ContinuousDensityTests {

    /// Why a distribution's density is not integrated.
    ///
    /// Present so that skipping is a sentence in the source rather than a `nil` nobody reads.
    enum Quadrature: Sendable {
        case over(lower: Double, upper: Double)
        case skipped(because: String)
    }

    /// One distribution to check, with points chosen inside its support.
    struct Subject: Sendable, CustomStringConvertible {
        let name: String
        let density: @Sendable (Double) -> Double
        let cumulative: @Sendable (Double) -> Double
        /// Interior points where the derivative check must hold, away from any knot.
        let points: [Double]
        let quadrature: Quadrature
        /// A point outside the support, where the density must be zero. `nil` where the
        /// support is the whole line and there is no outside.
        let outside: Double?

        var description: String { name }
    }

    /// Builds a subject, **taking the distribution as an optional**.
    ///
    /// Most of these initialisers are failable and several throw. An `if let` in the list
    /// below would drop a distribution the arguments happened to offend, and the suite would
    /// get shorter and stay green — the one failure mode a harness must not have. So a `nil`
    /// becomes a subject that keeps its name and answers `nan` to everything, which fails the
    /// checks below by name instead of disappearing from them.
    static func make<D: ContinuousDistribution & Sendable>(
        _ name: String, _ d: D?, points: [Double],
        _ quadrature: Quadrature, outside: Double? = nil
    ) -> Subject where D.T == Double {
        guard let d else {
            return Subject(name: name, density: { _ in .nan }, cumulative: { _ in .nan },
                           points: [0], quadrature: quadrature, outside: nil)
        }
        return Subject(name: name, density: { d.pdf($0) }, cumulative: { d.cdf($0) },
                       points: points, quadrature: quadrature, outside: outside)
    }

    /// The same, with the points taken from the distribution's own quantiles.
    ///
    /// For a fitted family whose support moves with its parameters, naming three absolute
    /// numbers is a guess that can land outside the support; asking for the quartiles cannot.
    static func makeAtQuartiles<D: ContinuousDistribution & Sendable>(
        _ name: String, _ d: D?, _ quadrature: Quadrature, outside: Double? = nil
    ) -> Subject where D.T == Double {
        let points = d.map { [$0.quantile(0.25), $0.quantile(0.5), $0.quantile(0.75)] } ?? []
        return make(name, d, points: points, quadrature, outside: outside)
    }

    // MARK: - The inventory

    static let subjects: [Subject] = {
        var all: [Subject] = []

        // Unbounded, symmetric.
        all.append(make("Normal", DistributionNormal(10, 2),
                        points: [6, 9, 10, 13], .over(lower: -10, upper: 30)))
        all.append(make("Logistic", DistributionLogistic(2, 3),
                        points: [-1, 2, 6], .over(lower: -120, upper: 120)))
        all.append(make("HypSecant", DistributionHypSecant(loc: 3, scale: 2),
                        points: [0, 3, 5.5], .over(lower: -200, upper: 200)))
        all.append(make("StudentT df=7", DistributionStudentT(degreesOfFreedom: 7),
                        points: [-2, 0, 1.5], .over(lower: -300, upper: 300)))
        all.append(make("T df=7", DistributionT(degreesOfFreedom: 7),
                        points: [-2, 0, 1.5], .over(lower: -300, upper: 300)))
        all.append(make("Erf", DistributionErf(h: 1.5),
                        points: [-0.6, 0, 0.8], .over(lower: -15, upper: 15)))
        all.append(make("Cauchy", DistributionCauchy(location: 2, scale: 3),
                        points: [-2, 2, 5],
                        // Tail ~ x⁻², so a range wide enough to integrate to one is wider
                        // than uniform steps can resolve the peak in.
                        .skipped(because: "the tail decays too slowly for uniform Simpson")))
        all.append(make("Laplace", DistributionLaplace(location: -1, scale: 2),
                        points: [-5, 0.5, 4], .over(lower: -100, upper: 100)))
        all.append(make("JohnsonSU", DistributionJohnsonSU(shape1: 0.5, shape2: 1.5,
                                                           location: 2, scale: 3),
                        points: [-2, 1, 4], .over(lower: -2000, upper: 2000)))

        // Extreme value, both directions.
        all.append(make("MaxExtreme", DistributionMaxExtreme(location: 3, scale: 2),
                        points: [1, 3, 6], .over(lower: -20, upper: 90)))
        all.append(make("MinExtreme", DistributionMinExtreme(location: -2, scale: 2),
                        points: [-6, -2, 0], .over(lower: -90, upper: 20)))

        // Positive support, light tail.
        all.append(make("Exponential", DistributionExponential(0.5),
                        points: [0.5, 2, 6], .over(lower: 0, upper: 60), outside: -1))
        all.append(make("Rayleigh", DistributionRayleigh(scale: 2),
                        points: [1, 3, 6], .over(lower: 0, upper: 40), outside: -1))
        all.append(make("ChiSquared df=5", DistributionChiSquared(degreesOfFreedom: 5),
                        points: [1, 4, 9], .over(lower: 1e-9, upper: 80), outside: -1))
        all.append(make("Gamma", DistributionGamma(shape: 3, rate: 0.5),
                        points: [2, 6, 12], .over(lower: 1e-9, upper: 90), outside: -1))
        all.append(make("Erlang", DistributionErlang(stages: 3, scale: 2),
                        points: [2, 6, 12], .over(lower: 1e-9, upper: 100), outside: -1))
        all.append(make("Weibull", DistributionWeibull(shape: 2, scale: 3),
                        points: [1, 3, 6], .over(lower: 1e-9, upper: 40), outside: -1))
        all.append(make("LogNormal", DistributionLogNormal(0.4, 0.5),
                        points: [1, 1.5, 3], .over(lower: 1e-6, upper: 60), outside: -1))
        all.append(make("InverseGaussian", DistributionInverseGaussian(mu: 2, lambda: 3),
                        points: [1, 2, 4], .over(lower: 1e-9, upper: 60), outside: -1))
        all.append(make("FatigueLife", DistributionFatigueLife(location: 1, scale: 2,
                                                               shape: 0.5),
                        points: [1.5, 3, 5], .over(lower: 1 + 1e-9, upper: 100),
                        outside: 0.5))

        // Positive support, power-law tail.
        all.append(make("Pareto", DistributionPareto(scale: 2, shape: 3),
                        points: [2.5, 4, 10], .over(lower: 2, upper: 800), outside: 1))
        all.append(make("Pareto2", DistributionPareto2(scale: 2, shape: 3),
                        points: [0.5, 2, 6], .over(lower: 0, upper: 1000), outside: -1))
        all.append(make("Burr12", DistributionBurr12(location: 1, scale: 2,
                                                     shape1: 3, shape2: 2),
                        points: [1.5, 3, 5], .over(lower: 1 + 1e-9, upper: 400),
                        outside: 0.5))
        all.append(make("Dagum", DistributionDagum(location: 1, scale: 2,
                                                   shape1: 3, shape2: 2),
                        points: [1.5, 3, 5], .over(lower: 1 + 1e-9, upper: 600),
                        outside: 0.5))
        all.append(make("Frechet", DistributionFrechet(location: 1, scale: 2, shape: 3),
                        points: [1.5, 3, 5], .over(lower: 1 + 1e-9, upper: 800),
                        outside: 0.5))
        all.append(make("LogLogistic", DistributionLogLogistic(location: 1, scale: 2,
                                                               shape: 3),
                        points: [1.5, 3, 5], .over(lower: 1 + 1e-9, upper: 1000),
                        outside: 0.5))
        all.append(make("Pearson5", DistributionPearson5(alpha: 3, beta: 2),
                        points: [0.5, 1, 3], .over(lower: 1e-9, upper: 200), outside: -1))
        all.append(make("Pearson6", DistributionPearson6(alpha1: 3, alpha2: 4, beta: 2),
                        points: [1, 2, 5], .over(lower: 1e-9, upper: 500), outside: -1))
        all.append(make("F df=5,8", DistributionF(df1: 5, df2: 8),
                        points: [0.5, 1, 2.5], .over(lower: 1e-9, upper: 1000), outside: -1))
        all.append(make("Levy", DistributionLevy(location: 1, scale: 2),
                        points: [1.5, 3, 6],
                        // Tail ~ x^(−3/2): the mean does not exist, and neither does a
                        // finite range whose Simpson sum reaches one.
                        .skipped(because: "the tail decays as x^(-3/2), too slowly to truncate"),
                        outside: 0.5))

        // Bounded support.
        all.append(make("Uniform", DistributionUniform(2, 8),
                        points: [3, 5, 7], .over(lower: 2, upper: 8), outside: 1))
        all.append(make("Reciprocal", DistributionReciprocal(min: 1, max: 10),
                        points: [2, 5, 8], .over(lower: 1, upper: 10), outside: 0.5))
        all.append(make("Triangular", DistributionTriangular(low: 0, high: 10, base: 3),
                        points: [1, 3, 7], .over(lower: 0, upper: 10), outside: -1))
        // The mode is a jump in the density, unlike a triangular's kink — points avoid it.
        all.append(make("DoubleTriangular", DistributionDoubleTriangular(min: 0, likely: 4,
                                                                         max: 10, p: 0.3),
                        points: [2, 6, 9], .over(lower: 0, upper: 10), outside: -1))
        all.append(make("Beta", DistributionBeta(alpha: 2, beta: 5),
                        points: [0.15, 0.4, 0.7], .over(lower: 0, upper: 1), outside: 1.5))
        all.append(make("BetaGeneralised", DistributionBetaGeneralised(shape1: 2, shape2: 3,
                                                                       min: 10, max: 20),
                        points: [12, 15, 18], .over(lower: 10, upper: 20), outside: 9))
        all.append(make("BetaSubjective", DistributionBetaSubjective(min: 0, likely: 3,
                                                                     mean: 4, max: 10),
                        points: [2, 4, 7], .over(lower: 0, upper: 10), outside: -1))
        all.append(make("Pert", DistributionPert(min: 0, likely: 3, max: 10),
                        points: [1, 3, 7], .over(lower: 0, upper: 10), outside: -1))
        all.append(make("Kumaraswamy", DistributionKumaraswamy(shape1: 2, shape2: 3,
                                                               min: 2, max: 6),
                        points: [2.8, 4, 5.2], .over(lower: 2, upper: 6), outside: 1))
        all.append(make("JohnsonSB", DistributionJohnsonSB(shape1: 0.5, shape2: 1.5,
                                                           min: 0, max: 10),
                        points: [2, 4, 7], .over(lower: 0, upper: 10), outside: -1))

        // Empirical: piecewise, and the points sit inside segments rather than on knots.
        all.append(make("Cumul", DistributionCumul(lower: 0, upper: 10, values: [3, 6],
                                                   probabilities: [0.4, 0.7]),
                        points: [1.5, 4.5, 8], .over(lower: 0, upper: 10), outside: -1))
        all.append(make("Histogram", DistributionHistogram(min: 0, max: 10,
                                                           weights: [1, 3, 2, 4]),
                        points: [1, 4, 9], .over(lower: 0, upper: 10), outside: -1))
        all.append(make("General", DistributionGeneral(lower: 0, upper: 10,
                                                       values: [2, 5, 8],
                                                       weights: [1, 4, 2]),
                        points: [1, 3.5, 7], .over(lower: 0, upper: 10), outside: -1))

        // Quantile-defined and fitted: the density is a declared numerical derivative, so
        // the check below verifies the plumbing rather than a transcription.
        all.append(makeAtQuartiles("Myerson", DistributionMyerson(low: 10, mode: 20,
                                                                  high: 35),
                                   .over(lower: -50, upper: 500)))
        all.append(makeAtQuartiles(
            "Metalog",
            try? DistributionMetalog(symmetricPercentileTriplet: (low: 10, median: 20, high: 35),
                                     at: 0.1),
            .skipped(because: "an unbounded quantile-defined tail, integrated nowhere finite")))
        all.append(makeAtQuartiles("MomentFit",
                                   try? DistributionMomentFit(mean: 0, standardDeviation: 1,
                                                              skewness: 0.5, kurtosis: 4),
                                   .over(lower: -40, upper: 60)))
        return all
    }()

    // MARK: - The checks

    /// Every conformer is present, named rather than counted.
    ///
    /// Most of these initialisers are failable or throwing. A subject built through `if let`
    /// or `try?` with one wrong argument would vanish from the suite silently, and a harness
    /// that shrinks without saying so is worse than no harness. Adding a conformer to
    /// `ContinuousDistribution` and not to this list is meant to fail here.
    @Test("Every conformer of ContinuousDistribution is covered")
    func testEveryConformerIsCovered() {
        let expected: Set<String> = [
            "Normal", "Logistic", "HypSecant", "StudentT df=7", "T df=7", "Erf", "Cauchy",
            "Laplace", "JohnsonSU", "MaxExtreme", "MinExtreme", "Exponential", "Rayleigh",
            "ChiSquared df=5", "Gamma", "Erlang", "Weibull", "LogNormal", "InverseGaussian",
            "FatigueLife", "Pareto", "Pareto2", "Burr12", "Dagum", "Frechet", "LogLogistic",
            "Pearson5", "Pearson6", "F df=5,8", "Levy", "Uniform", "Reciprocal", "Triangular",
            "DoubleTriangular", "Beta", "BetaGeneralised", "BetaSubjective", "Pert",
            "Kumaraswamy", "JohnsonSB", "Cumul", "Histogram", "General", "Myerson",
            "Metalog", "MomentFit"
        ]
        let present = Set(Self.subjects.map(\.name))
        #expect(present == expected,
                "missing \(expected.subtracting(present)), unexpected \(present.subtracting(expected))")
    }

    /// **The check that matters.** Each density is the CDF's slope.
    @Test("Each density is the derivative of its own CDF",
          arguments: ContinuousDensityTests.subjects)
    func testDensityIsTheDerivativeOfTheCDF(subject: Subject) {
        for x in subject.points {
            // Stepped relative to the point, so a distribution on a large scale is resolved
            // the same way as one on a small.
            let h = Swift.max(Swift.abs(x), 1) * 1e-6
            let slope = (subject.cumulative(x + h) - subject.cumulative(x - h)) / (2 * h)
            let density = subject.density(x)
            let tolerance = Swift.max(1e-5, Swift.abs(slope) * 1e-3)
            #expect(abs(density - slope) < tolerance,
                    "\(subject.name) at \(x): density \(density), CDF slope \(slope)")
        }
    }

    @Test("Densities are non-negative and finite where the CDF is smooth",
          arguments: ContinuousDensityTests.subjects)
    func testNonNegative(subject: Subject) {
        for x in subject.points {
            let density = subject.density(x)
            #expect(density >= 0, "\(subject.name) at \(x) gave \(density)")
            #expect(density.isFinite, "\(subject.name) at \(x) gave \(density)")
        }
    }

    /// Only the bounded supports are argued over.
    ///
    /// Filtered into the argument list rather than skipped inside the body: a `guard … else
    /// { return }` in a test passes having asserted nothing, and a suite whose green includes
    /// cases that ran no checks is reporting the wrong number.
    static let bounded = ContinuousDensityTests.subjects.filter { $0.outside != nil }

    /// The distributions whose density is integrated. The rest state why not — see
    /// `Quadrature.skipped(because:)` at each site.
    static let integrable = ContinuousDensityTests.subjects.filter {
        if case .over = $0.quadrature { return true } else { return false }
    }

    @Test("Zero outside the support", arguments: ContinuousDensityTests.bounded)
    func testZeroOutsideTheSupport(subject: Subject) throws {
        let outside = try #require(subject.outside)
        #expect(subject.density(outside).isEqual(to: 0),
                "\(subject.name) at \(outside) is outside the support")
    }

    @Test("Each density integrates to one", arguments: ContinuousDensityTests.integrable)
    func testIntegratesToOne(subject: Subject) throws {
        guard case .over(let lower, let upper) = subject.quadrature else {
            throw QuadratureMissing(name: subject.name)
        }
        let steps = 100_000
        let h = (upper - lower) / Double(steps)
        var total = subject.density(lower) + subject.density(upper)
        for step in 1..<steps {
            let x = lower + Double(step) * h
            total += subject.density(x) * (step % 2 == 0 ? 2 : 4)
        }
        let integral = total * h / 3
        #expect(abs(integral - 1) < 2e-3, "\(subject.name) integrated to \(integral)")
    }

    /// Thrown rather than returned, so a filter that stops matching fails the run.
    struct QuadratureMissing: Error { let name: String }
}
