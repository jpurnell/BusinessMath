import Foundation
import Numerics

// MARK: - Seed Management

/// The random source for one Gibbs chain.
///
/// A chain with a seed runs on ``DeterministicRNG`` (`xoshiro256**`) and reproduces
/// exactly; a chain without one runs on the system generator and is non-reproducible
/// *by contract*. One generator threads through every draw of the sweep, which is what
/// makes the seeded case actually reproducible.
///
/// This replaced a local LCG that handed each draw a fixed array of pre-drawn uniforms —
/// ten of them per variance component. ``sampleInverseGamma`` consumes a data-dependent
/// number of uniforms, because the gamma sampler underneath it rejects, so a chain that
/// needed an eleventh silently finished the draw on the *global* generator and the seed
/// stopped meaning anything from that point on. Nothing reported it. Threading a
/// generator removes the budget, and with it the failure.
internal struct GibbsRNG: RandomNumberGenerator {
    private var deterministic: DeterministicRNG?
    private var system = SystemRandomNumberGenerator() // stochastic:exempt — the unseeded path; set `GibbsConfig.seed` for reproducibility

    init(seed: UInt64?) {
        if let seed {
            deterministic = DeterministicRNG(seed: seed)
        }
    }

    mutating func next() -> UInt64 {
        guard var generator = deterministic else {
            return system.next()
        }
        let value = generator.next()
        deterministic = generator
        return value
    }

    /// Two uniforms in (0, 1), in stream order — the pair Box-Muller wants.
    mutating func nextPair() -> (Double, Double) {
        let u1 = openUnitUniform(Double.self, using: &self)
        let u2 = openUnitUniform(Double.self, using: &self)
        return (u1, u2)
    }
}

// MARK: - Bayesian ICC (Complete Data)

/// One Gibbs draw of a variance component from its Inverse-Gamma full conditional.
///
/// The conjugate update is the same for all three components and both overloads: add half
/// the observation count to the prior shape, half the sum of squares to the prior scale,
/// and draw. It was written out six times — subject, rater and error variance, in each of
/// the complete-data and missing-data samplers.
///
/// ## Why a failed draw keeps the previous value
///
/// `sampleInverseGamma` can fail on rare numerical trouble. Aborting the run would discard
/// thousands of valid draws over one bad one, so the chain holds its previous value for
/// that iteration — which is a legitimate Markov transition, not a fabricated number.
///
/// This was six separate `try?` expressions, each silently discarding its error. Gathering
/// them here means the decision is made once and stated once; a silently swallowed `try?`
/// repeated across a file is how this package previously shipped a GPU path that fell back
/// to the CPU mid-run without telling anyone.
///
/// - Parameters:
///   - sumOfSquares: Σ of the squared effects or residuals this component explains.
///   - count: The number of terms in that sum, as `T`.
///   - prior: The Inverse-Gamma prior for this component.
///   - current: The value to retain if the draw fails.
///   - rng: The chain's generator, advanced by the draw.
/// - Returns: The new draw, or `current` when the draw could not be made.
internal func sampledVariance<T: Real, G: RandomNumberGenerator>(
    sumOfSquares: T,
    count: T,
    prior: VariancePrior<T>,
    current: T,
    using rng: inout G
) -> T where T: BinaryFloatingPoint {
    let shape: T = prior.shape + count / T(2)
    let scale: T = prior.scale + sumOfSquares / T(2)
    // silent: MCMC sampling — retain the previous value on rare numerical failure
    guard let sampled = try? sampleInverseGamma(shape: shape, scale: scale, using: &rng) else {
        return current
    }
    return sampled
}

// MARK: - Shared by both overloads

/// Merges the per-chain draws into one posterior and summarises it.
///
/// Both overloads — the complete-data sampler and the missing-data one — finished with the
/// same forty-three lines: flatten the chains, check something survived the burn-in,
/// compute the mean, median and 95% interval, average the variance components, and run the
/// two convergence diagnostics. Identical but for two comment lines.
///
/// - Parameters:
///   - allChainSigmaS: Per-chain subject-variance draws.
///   - allChainSigmaR: Per-chain rater-variance draws.
///   - allChainSigmaE: Per-chain error-variance draws.
///   - allChainICC: Per-chain ICC draws, kept per-chain because R-hat compares chains
///     against each other and cannot be computed from the merged sample.
/// - Returns: The summarised posterior.
/// - Throws: ``BusinessMathError/calculationFailed(operation:reason:suggestions:)`` when no
///   draw survived thinning and burn-in, which is a configuration error rather than a
///   result.
internal func summarisePosterior<T: Real>(
    allChainSigmaS: [[T]],
    allChainSigmaR: [[T]],
    allChainSigmaE: [[T]],
    allChainICC: [[T]]
) throws -> BayesianICCResult<T> where T: BinaryFloatingPoint {
    let mergedSigmaS = allChainSigmaS.flatMap { $0 }
    let mergedSigmaR = allChainSigmaR.flatMap { $0 }
    let mergedSigmaE = allChainSigmaE.flatMap { $0 }
    let mergedICC = allChainICC.flatMap { $0 }

    guard !mergedICC.isEmpty else {
        throw BusinessMathError.calculationFailed(
            operation: "Bayesian ICC",
            reason: "No post-burn-in samples collected; increase iterations or reduce burn-in")
    }

    let iccMeanVal = mean(mergedICC)
    let sortedICC = mergedICC.sorted()
    let iccMedianVal = sortedICC[sortedICC.count / 2]

    let lowerIdx = max(0, Int(Double(T(0.025) * T(sortedICC.count))))
    let upperIdx = min(sortedICC.count - 1, Int(Double(T(0.975) * T(sortedICC.count))))
    let credibleInterval = CredibleInterval(lower: sortedICC[lowerIdx], upper: sortedICC[upperIdx])

    let sigmaSubjectsMeanVal = mean(mergedSigmaS)
    let sigmaRatersMeanVal = mean(mergedSigmaR)
    let sigmaErrorMeanVal = mean(mergedSigmaE)

    let rHatVal = rHatStatistic(allChainICC)
    let essVal = effectiveSampleSize(mergedICC)

    return BayesianICCResult(
        sigmaSubjectsSamples: mergedSigmaS,
        sigmaRatersSamples: mergedSigmaR,
        sigmaErrorSamples: mergedSigmaE,
        iccSamples: mergedICC,
        iccMean: iccMeanVal,
        iccMedian: iccMedianVal,
        iccCredibleInterval: credibleInterval,
        sigmaSubjectsMean: sigmaSubjectsMeanVal,
        sigmaRatersMean: sigmaRatersMeanVal,
        sigmaErrorMean: sigmaErrorMeanVal,
        rHat: rHatVal,
        effectiveSampleSizeCount: essVal
    )
}


/// Estimates the intraclass correlation coefficient using Bayesian inference via Gibbs sampling.
///
/// Fits a two-way random effects model:
/// ```
/// x_ij = mu + s_i + r_j + e_ij
/// ```
/// where `s_i ~ N(0, sigma_s^2)`, `r_j ~ N(0, sigma_r^2)`, and `e_ij ~ N(0, sigma_e^2)`.
///
/// The ICC is computed from the posterior samples of the variance components:
/// - **ICC(2,1)** (twoWayRandom, absolute): `sigma_s^2 / (sigma_s^2 + sigma_r^2 + sigma_e^2)`
/// - **ICC(3,1)** (twoWayMixed, consistency): `sigma_s^2 / (sigma_s^2 + sigma_e^2)`
/// - **ICC(1,1)** (oneWayRandom): `(sigma_s^2 - sigma_r^2/k) / ((sigma_s^2 - sigma_r^2/k) +
///   sigma_r^2 + sigma_e^2)` — *not* the two-way formula. A one-way design has no separable
///   rater effect, so rater variation comes out of the subject term as well as sitting in the
///   denominator. This file used to carry the two-way line here, so both models returned the
///   same number. Both this sampler and the EM estimator now share one internal
///   `iccFromVarianceComponents(model:agreement:sigmaS2:sigmaR2:sigmaE2:raters:)`, so there is a
///   single place left where it can be got wrong.
///
/// - Parameters:
///   - ratings: Matrix where `ratings[i][j]` is the rating of subject `i` by rater `j`.
///     Must be a balanced design (all rows the same length).
///   - model: The ICC model type (see ``ICCModel``).
///   - priors: Optional tuple of Inverse-Gamma priors for the three variance components.
///     When `nil`, vague priors are used.
///   - config: Gibbs sampler configuration (iterations, burn-in, thinning, chains, seed).
/// - Returns: A ``BayesianICCResult`` with posterior samples, summary statistics,
///   and convergence diagnostics.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 subjects or raters.
///   `BusinessMathError.mismatchedDimensions` if rows differ in length.
public func bayesianICC<T: Real>(
    _ ratings: [[T]],
    model: ICCModel,
    priors: (subjects: VariancePrior<T>, raters: VariancePrior<T>, error: VariancePrior<T>)? = nil,
    config: GibbsConfig<T> = .default
) throws -> BayesianICCResult<T> where T: BinaryFloatingPoint {
    let n = ratings.count
    guard n >= 2 else {
        throw BusinessMathError.insufficientData(
            required: 2, actual: n,
            context: "Bayesian ICC requires at least 2 subjects (rows)")
    }

    let k = ratings[0].count
    guard k >= 2 else {
        throw BusinessMathError.insufficientData(
            required: 2, actual: k,
            context: "Bayesian ICC requires at least 2 raters (columns)")
    }

    // Validate balanced design
    for i in 1..<n {
        guard ratings[i].count == k else {
            throw BusinessMathError.mismatchedDimensions(
                message: "All rows must have the same number of columns (balanced design required)",
                expected: "\(k)", actual: "\(ratings[i].count)")
        }
    }

    // Set up priors
    let subjectPrior = priors?.subjects ?? .vague
    let raterPrior = priors?.raters ?? .vague
    let errorPrior = priors?.error ?? .vague

    // ANOVA initialization — the method-of-moments estimates, which start the chain near where
    // it is going. Only available here: the missing-data overload cannot form these mean squares.
    let anova = try twoWayANOVA(ratings)
    let nT = T(n)
    let kT = T(k)

    let initSigmaE = max(anova.msError, T(1) / T(1000))
    let initSigmaS = max((anova.msSubjects - anova.msError) / kT, T(1) / T(1000))
    let initSigmaR = max((anova.msRaters - anova.msError) / nT, T(1) / T(1000))

    var grandSum = T.zero
    for row in ratings {
        for value in row {
            grandSum += value
        }
    }
    let grandMean = grandSum / (nT * kT)

    return try gibbsICCPosterior(
        cells: ObservedCells(ratings, subjects: n, raters: k),
        subjects: n,
        raters: k,
        grandMean: grandMean,
        initialSubjectVariance: initSigmaS,
        initialRaterVariance: initSigmaR,
        initialErrorVariance: initSigmaE,
        model: model,
        subjectPrior: subjectPrior,
        raterPrior: raterPrior,
        errorPrior: errorPrior,
        config: config
    )
}

// MARK: - Bayesian ICC (Missing Data)

/// Estimates the ICC with support for missing observations.
///
/// Operates identically to ``bayesianICC(_:model:priors:config:)`` but allows `nil`
/// entries in the ratings matrix. Only observed (non-`nil`) cells contribute to the
/// full conditionals. Subjects or raters with zero observed cells are silently excluded.
///
/// - Parameters:
///   - ratings: Matrix where `ratings[i][j]` is the rating of subject `i` by rater `j`,
///     or `nil` if unobserved.
///   - model: The ICC model type.
///   - priors: Optional Inverse-Gamma priors for variance components.
///   - config: Gibbs sampler configuration.
/// - Returns: A ``BayesianICCResult`` with posterior samples, summaries, and diagnostics.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 subjects have observations
///   or fewer than 2 raters have observations.
public func bayesianICC<T: Real>(
    _ ratings: [[T?]],
    model: ICCModel,
    priors: (subjects: VariancePrior<T>, raters: VariancePrior<T>, error: VariancePrior<T>)? = nil,
    config: GibbsConfig<T> = .default
) throws -> BayesianICCResult<T> where T: BinaryFloatingPoint {
    let n = ratings.count
    guard n >= 2 else {
        throw BusinessMathError.insufficientData(
            required: 2, actual: n,
            context: "Bayesian ICC requires at least 2 subjects (rows)")
    }

    let k = ratings[0].count
    guard k >= 2 else {
        throw BusinessMathError.insufficientData(
            required: 2, actual: k,
            context: "Bayesian ICC requires at least 2 raters (columns)")
    }

    // Validate consistent column counts
    for i in 1..<n {
        guard ratings[i].count == k else {
            throw BusinessMathError.mismatchedDimensions(
                message: "All rows must have the same number of columns",
                expected: "\(k)", actual: "\(ratings[i].count)")
        }
    }

    // Check which subjects and raters have data
    var subjectObsCounts = [Int](repeating: 0, count: n)
    var raterObsCounts = [Int](repeating: 0, count: k)
    var totalObs = 0

    for i in 0..<n {
        for j in 0..<k {
            if ratings[i][j] != nil {
                subjectObsCounts[i] += 1
                raterObsCounts[j] += 1
                totalObs += 1
            }
        }
    }

    let subjectsWithData = subjectObsCounts.filter { $0 > 0 }.count
    let ratersWithData = raterObsCounts.filter { $0 > 0 }.count

    guard subjectsWithData >= 2 else {
        throw BusinessMathError.insufficientData(
            required: 2, actual: subjectsWithData,
            context: "Bayesian ICC requires at least 2 subjects with observed data")
    }
    guard ratersWithData >= 2 else {
        throw BusinessMathError.insufficientData(
            required: 2, actual: ratersWithData,
            context: "Bayesian ICC requires at least 2 raters with observed data")
    }

    // Check if data is complete — delegate to the non-optional overload
    let isComplete = totalObs == n * k
    if isComplete {
        let completeRatings: [[T]] = ratings.map { row in
            row.map { $0 ?? T.zero } // safe: we know all are non-nil
        }
        return try bayesianICC(completeRatings, model: model, priors: priors, config: config)
    }

    // Set up priors
    let subjectPrior = priors?.subjects ?? .vague
    let raterPrior = priors?.raters ?? .vague
    let errorPrior = priors?.error ?? .vague

    // Grand mean and a starting scale, over the observed cells only.
    var grandSum = T.zero
    for row in ratings {
        for value in row {
            if let v = value {
                grandSum += v
            }
        }
    }
    let grandMean = grandSum / T(totalObs)

    var ssTotal = T.zero
    for row in ratings {
        for value in row {
            if let v = value {
                let diff = v - grandMean
                ssTotal += diff * diff
            }
        }
    }
    let totalVar = totalObs > 1 ? ssTotal / T(totalObs - 1) : T(1)
    // A third of the total variance each, as a heuristic — the two-way mean squares the
    // complete-data overload starts from cannot be formed when cells are absent.
    let initSigmaS = max(totalVar / T(3), T(1) / T(1000))
    let initSigmaR = max(totalVar / T(3), T(1) / T(1000))
    let initSigmaE = max(totalVar / T(3), T(1) / T(1000))

    return try gibbsICCPosterior(
        cells: ObservedCells(ratings, subjects: n, raters: k),
        subjects: n,
        raters: k,
        grandMean: grandMean,
        initialSubjectVariance: initSigmaS,
        initialRaterVariance: initSigmaR,
        initialErrorVariance: initSigmaE,
        model: model,
        subjectPrior: subjectPrior,
        raterPrior: raterPrior,
        errorPrior: errorPrior,
        config: config
    )
}
