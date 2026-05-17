import Foundation
import Numerics

// MARK: - Seed Management

/// A simple linear congruential generator for producing deterministic seed sequences.
///
/// Given an initial `UInt64` seed, generates a sequence of `Double` values in [0, 1]
/// for use with the library's distribution functions.
private struct SeedSequence: Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> Double {
        // LCG constants (Numerical Recipes)
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        // Map to [0, 1]
        return Double(state >> 11) / Double(1 << 53) // fp-safety:disable
    }

    mutating func nextArray(count: Int) -> [Double] {
        (0..<count).map { _ in next() }
    }
}

// MARK: - Bayesian ICC (Complete Data)

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
/// - **ICC(1,1)** (oneWayRandom): `sigma_s^2 / (sigma_s^2 + sigma_r^2 + sigma_e^2)`
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

    // ANOVA initialization
    let anova = try twoWayANOVA(ratings)
    let nT = T(n)
    let kT = T(k)

    // Initial variance estimates from ANOVA (clamped to positive)
    let initSigmaE = max(anova.msError, T(1) / T(1000))
    let initSigmaS = max((anova.msSubjects - anova.msError) / kT, T(1) / T(1000))
    let initSigmaR = max((anova.msRaters - anova.msError) / nT, T(1) / T(1000))

    // Grand mean
    var grandSum = T.zero
    for row in ratings {
        for value in row {
            grandSum += value
        }
    }
    let grandMean = grandSum / (nT * kT)

    // Run chains
    let totalN = n * k
    var allChainSigmaS: [[T]] = []
    var allChainSigmaR: [[T]] = []
    var allChainSigmaE: [[T]] = []
    var allChainICC: [[T]] = []

    for chain in 0..<config.chains {
        var seedGen: SeedSequence?
        if let seed = config.seed {
            seedGen = SeedSequence(seed: seed &+ UInt64(chain) &* 999_983)
        }

        // Initialize chain state
        var mu = grandMean
        var s = [T](repeating: T.zero, count: n)
        var r = [T](repeating: T.zero, count: k)
        var sigmaS = initSigmaS
        var sigmaR = initSigmaR
        var sigmaE = initSigmaE

        // Disperse starting points for multiple chains
        if chain > 0 {
            sigmaS = initSigmaS * T(1 + chain)
            sigmaR = initSigmaR * T(1 + chain)
            sigmaE = initSigmaE * T(1 + chain)
        }

        var chainSigmaS: [T] = []
        var chainSigmaR: [T] = []
        var chainSigmaE: [T] = []
        var chainICC: [T] = []

        let tauSquared: T = T(1_000_000) // vague prior variance on mu

        for iter in 0..<config.iterations {
            // --- 1. Sample mu | rest ---
            var residualSum = T.zero
            for i in 0..<n {
                for j in 0..<k {
                    residualSum += ratings[i][j] - s[i] - r[j]
                }
            }
            let totalNT = T(totalN)
            let muPostVar = T(1) / (totalNT / sigmaE + T(1) / tauSquared)
            let muPostMean = muPostVar * (residualSum / sigmaE + grandMean / tauSquared)

            if var sg = seedGen {
                let seeds = sg.nextArray(count: 2)
                seedGen = sg
                mu = distributionNormal(mean: muPostMean, variance: muPostVar, seeds[0], seeds[1])
            } else {
                mu = distributionNormal(mean: muPostMean, variance: muPostVar)
            }

            // --- 2. Sample s_i | rest ---
            for i in 0..<n {
                var sumResid = T.zero
                for j in 0..<k {
                    sumResid += ratings[i][j] - mu - r[j]
                }
                let vPost = T(1) / (kT / sigmaE + T(1) / sigmaS)
                let sPost = vPost * sumResid / sigmaE

                if var sg = seedGen {
                    let seeds = sg.nextArray(count: 2)
                    seedGen = sg
                    s[i] = distributionNormal(mean: sPost, variance: vPost, seeds[0], seeds[1])
                } else {
                    s[i] = distributionNormal(mean: sPost, variance: vPost)
                }
            }

            // --- 3. Sample r_j | rest ---
            for j in 0..<k {
                var sumResid = T.zero
                for i in 0..<n {
                    sumResid += ratings[i][j] - mu - s[i]
                }
                let vPost = T(1) / (nT / sigmaE + T(1) / sigmaR)
                let rPost = vPost * sumResid / sigmaE

                if var sg = seedGen {
                    let seeds = sg.nextArray(count: 2)
                    seedGen = sg
                    r[j] = distributionNormal(mean: rPost, variance: vPost, seeds[0], seeds[1])
                } else {
                    r[j] = distributionNormal(mean: rPost, variance: vPost)
                }
            }

            // --- 4. Sample sigma_s^2 | s ---
            var ssSub = T.zero
            for i in 0..<n {
                ssSub += s[i] * s[i]
            }
            let shapeS = subjectPrior.shape + nT / T(2)
            let scaleS = subjectPrior.scale + ssSub / T(2)

            if var sg = seedGen {
                var idx = 0
                let seeds = sg.nextArray(count: 10)
                seedGen = sg
                // silent: MCMC sampling — retain previous value on rare numerical failure
                if let sampled = try? sampleInverseGamma(shape: shapeS, scale: scaleS, seeds: seeds, seedIndex: &idx) {
                    sigmaS = sampled
                }
            } else {
                var idx = 0
                // silent: MCMC sampling — retain previous value on rare numerical failure
                if let sampled = try? sampleInverseGamma(shape: shapeS, scale: scaleS, seeds: nil, seedIndex: &idx) {
                    sigmaS = sampled
                }
            }

            // --- 5. Sample sigma_r^2 | r ---
            var ssRat = T.zero
            for j in 0..<k {
                ssRat += r[j] * r[j]
            }
            let shapeR = raterPrior.shape + kT / T(2)
            let scaleR = raterPrior.scale + ssRat / T(2)

            if var sg = seedGen {
                var idx = 0
                let seeds = sg.nextArray(count: 10)
                seedGen = sg
                // silent: MCMC sampling — retain previous value on rare numerical failure
                if let sampled = try? sampleInverseGamma(shape: shapeR, scale: scaleR, seeds: seeds, seedIndex: &idx) {
                    sigmaR = sampled
                }
            } else {
                var idx = 0
                // silent: MCMC sampling — retain previous value on rare numerical failure
                if let sampled = try? sampleInverseGamma(shape: shapeR, scale: scaleR, seeds: nil, seedIndex: &idx) {
                    sigmaR = sampled
                }
            }

            // --- 6. Sample sigma_e^2 | rest ---
            var ssErr = T.zero
            for i in 0..<n {
                for j in 0..<k {
                    let residual = ratings[i][j] - mu - s[i] - r[j]
                    ssErr += residual * residual
                }
            }
            let shapeE = errorPrior.shape + T(totalN) / T(2)
            let scaleE = errorPrior.scale + ssErr / T(2)

            if var sg = seedGen {
                var idx = 0
                let seeds = sg.nextArray(count: 10)
                seedGen = sg
                // silent: MCMC sampling — retain previous value on rare numerical failure
                if let sampled = try? sampleInverseGamma(shape: shapeE, scale: scaleE, seeds: seeds, seedIndex: &idx) {
                    sigmaE = sampled
                }
            } else {
                var idx = 0
                // silent: MCMC sampling — retain previous value on rare numerical failure
                if let sampled = try? sampleInverseGamma(shape: shapeE, scale: scaleE, seeds: nil, seedIndex: &idx) {
                    sigmaE = sampled
                }
            }

            // --- Collect post-burn-in samples ---
            if iter >= config.burnIn && (iter - config.burnIn) % config.thinning == 0 {
                chainSigmaS.append(sigmaS)
                chainSigmaR.append(sigmaR)
                chainSigmaE.append(sigmaE)

                let iccValue: T
                switch model {
                case .twoWayRandom, .oneWayRandom:
                    let denom = sigmaS + sigmaR + sigmaE
                    iccValue = denom > T.zero ? sigmaS / denom : T.zero
                case .twoWayMixed:
                    let denom = sigmaS + sigmaE
                    iccValue = denom > T.zero ? sigmaS / denom : T.zero
                }
                chainICC.append(iccValue)
            }
        }

        allChainSigmaS.append(chainSigmaS)
        allChainSigmaR.append(chainSigmaR)
        allChainSigmaE.append(chainSigmaE)
        allChainICC.append(chainICC)
    }

    // Merge all chains for summary statistics
    let mergedSigmaS = allChainSigmaS.flatMap { $0 }
    let mergedSigmaR = allChainSigmaR.flatMap { $0 }
    let mergedSigmaE = allChainSigmaE.flatMap { $0 }
    let mergedICC = allChainICC.flatMap { $0 }

    guard !mergedICC.isEmpty else {
        throw BusinessMathError.calculationFailed(
            operation: "Bayesian ICC",
            reason: "No post-burn-in samples collected; increase iterations or reduce burn-in")
    }

    // Summary statistics
    let iccMeanVal = mean(mergedICC)
    let sortedICC = mergedICC.sorted()
    let iccMedianVal = sortedICC[sortedICC.count / 2]

    let lowerIdx = max(0, Int(Double(T(0.025) * T(sortedICC.count))))
    let upperIdx = min(sortedICC.count - 1, Int(Double(T(0.975) * T(sortedICC.count))))
    let credibleInterval = CredibleInterval(lower: sortedICC[lowerIdx], upper: sortedICC[upperIdx])

    let sigmaSubjectsMeanVal = mean(mergedSigmaS)
    let sigmaRatersMeanVal = mean(mergedSigmaR)
    let sigmaErrorMeanVal = mean(mergedSigmaE)

    // Convergence diagnostics
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

    // Compute grand mean from observed data
    var grandSum = T.zero
    for row in ratings {
        for value in row {
            if let v = value {
                grandSum += v
            }
        }
    }
    let grandMean = grandSum / T(totalObs)

    // Initial variance estimates (simple heuristic for missing data)
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
    let initSigmaS = max(totalVar / T(3), T(1) / T(1000))
    let initSigmaR = max(totalVar / T(3), T(1) / T(1000))
    let initSigmaE = max(totalVar / T(3), T(1) / T(1000))

    let nT = T(n)
    let kT = T(k)

    // Run chains
    var allChainSigmaS: [[T]] = []
    var allChainSigmaR: [[T]] = []
    var allChainSigmaE: [[T]] = []
    var allChainICC: [[T]] = []

    for chain in 0..<config.chains {
        var seedGen: SeedSequence?
        if let seed = config.seed {
            seedGen = SeedSequence(seed: seed &+ UInt64(chain) &* 999_983)
        }

        var mu = grandMean
        var s = [T](repeating: T.zero, count: n)
        var r = [T](repeating: T.zero, count: k)
        var sigmaS = initSigmaS * T(1 + chain)
        var sigmaR = initSigmaR * T(1 + chain)
        var sigmaE = initSigmaE * T(1 + chain)

        var chainSigmaS: [T] = []
        var chainSigmaR: [T] = []
        var chainSigmaE: [T] = []
        var chainICC: [T] = []

        let tauSquared: T = T(1_000_000)

        for iter in 0..<config.iterations {
            // --- 1. Sample mu | rest (only observed cells) ---
            var residualSum = T.zero
            for i in 0..<n {
                for j in 0..<k {
                    if let xij = ratings[i][j] {
                        residualSum += xij - s[i] - r[j]
                    }
                }
            }
            let totalObsT = T(totalObs)
            let muPostVar = T(1) / (totalObsT / sigmaE + T(1) / tauSquared)
            let muPostMean = muPostVar * (residualSum / sigmaE + grandMean / tauSquared)

            if var sg = seedGen {
                let seeds = sg.nextArray(count: 2)
                seedGen = sg
                mu = distributionNormal(mean: muPostMean, variance: muPostVar, seeds[0], seeds[1])
            } else {
                mu = distributionNormal(mean: muPostMean, variance: muPostVar)
            }

            // --- 2. Sample s_i | rest ---
            for i in 0..<n {
                let ki = T(subjectObsCounts[i])
                guard ki > T.zero else { continue }

                var sumResid = T.zero
                for j in 0..<k {
                    if let xij = ratings[i][j] {
                        sumResid += xij - mu - r[j]
                    }
                }
                let vPost = T(1) / (ki / sigmaE + T(1) / sigmaS)
                let sPost = vPost * sumResid / sigmaE

                if var sg = seedGen {
                    let seeds = sg.nextArray(count: 2)
                    seedGen = sg
                    s[i] = distributionNormal(mean: sPost, variance: vPost, seeds[0], seeds[1])
                } else {
                    s[i] = distributionNormal(mean: sPost, variance: vPost)
                }
            }

            // --- 3. Sample r_j | rest ---
            for j in 0..<k {
                let nj = T(raterObsCounts[j])
                guard nj > T.zero else { continue }

                var sumResid = T.zero
                for i in 0..<n {
                    if let xij = ratings[i][j] {
                        sumResid += xij - mu - s[i]
                    }
                }
                let vPost = T(1) / (nj / sigmaE + T(1) / sigmaR)
                let rPost = vPost * sumResid / sigmaE

                if var sg = seedGen {
                    let seeds = sg.nextArray(count: 2)
                    seedGen = sg
                    r[j] = distributionNormal(mean: rPost, variance: vPost, seeds[0], seeds[1])
                } else {
                    r[j] = distributionNormal(mean: rPost, variance: vPost)
                }
            }

            // --- 4. Sample sigma_s^2 ---
            var ssSub = T.zero
            for i in 0..<n {
                ssSub += s[i] * s[i]
            }
            let shapeS = subjectPrior.shape + nT / T(2)
            let scaleS = subjectPrior.scale + ssSub / T(2)

            if var sg = seedGen {
                var idx = 0
                let seeds = sg.nextArray(count: 10)
                seedGen = sg
                // silent: MCMC sampling — retain previous value on rare numerical failure
                if let sampled = try? sampleInverseGamma(shape: shapeS, scale: scaleS, seeds: seeds, seedIndex: &idx) {
                    sigmaS = sampled
                }
            } else {
                var idx = 0
                // silent: MCMC sampling — retain previous value on rare numerical failure
                if let sampled = try? sampleInverseGamma(shape: shapeS, scale: scaleS, seeds: nil, seedIndex: &idx) {
                    sigmaS = sampled
                }
            }

            // --- 5. Sample sigma_r^2 ---
            var ssRat = T.zero
            for j in 0..<k {
                ssRat += r[j] * r[j]
            }
            let shapeR = raterPrior.shape + kT / T(2)
            let scaleR = raterPrior.scale + ssRat / T(2)

            if var sg = seedGen {
                var idx = 0
                let seeds = sg.nextArray(count: 10)
                seedGen = sg
                // silent: MCMC sampling — retain previous value on rare numerical failure
                if let sampled = try? sampleInverseGamma(shape: shapeR, scale: scaleR, seeds: seeds, seedIndex: &idx) {
                    sigmaR = sampled
                }
            } else {
                var idx = 0
                // silent: MCMC sampling — retain previous value on rare numerical failure
                if let sampled = try? sampleInverseGamma(shape: shapeR, scale: scaleR, seeds: nil, seedIndex: &idx) {
                    sigmaR = sampled
                }
            }

            // --- 6. Sample sigma_e^2 ---
            var ssErr = T.zero
            for i in 0..<n {
                for j in 0..<k {
                    if let xij = ratings[i][j] {
                        let residual = xij - mu - s[i] - r[j]
                        ssErr += residual * residual
                    }
                }
            }
            let shapeE = errorPrior.shape + T(totalObs) / T(2)
            let scaleE = errorPrior.scale + ssErr / T(2)

            if var sg = seedGen {
                var idx = 0
                let seeds = sg.nextArray(count: 10)
                seedGen = sg
                // silent: MCMC sampling — retain previous value on rare numerical failure
                if let sampled = try? sampleInverseGamma(shape: shapeE, scale: scaleE, seeds: seeds, seedIndex: &idx) {
                    sigmaE = sampled
                }
            } else {
                var idx = 0
                // silent: MCMC sampling — retain previous value on rare numerical failure
                if let sampled = try? sampleInverseGamma(shape: shapeE, scale: scaleE, seeds: nil, seedIndex: &idx) {
                    sigmaE = sampled
                }
            }

            // --- Collect post-burn-in samples ---
            if iter >= config.burnIn && (iter - config.burnIn) % config.thinning == 0 {
                chainSigmaS.append(sigmaS)
                chainSigmaR.append(sigmaR)
                chainSigmaE.append(sigmaE)

                let iccValue: T
                switch model {
                case .twoWayRandom, .oneWayRandom:
                    let denom = sigmaS + sigmaR + sigmaE
                    iccValue = denom > T.zero ? sigmaS / denom : T.zero
                case .twoWayMixed:
                    let denom = sigmaS + sigmaE
                    iccValue = denom > T.zero ? sigmaS / denom : T.zero
                }
                chainICC.append(iccValue)
            }
        }

        allChainSigmaS.append(chainSigmaS)
        allChainSigmaR.append(chainSigmaR)
        allChainSigmaE.append(chainSigmaE)
        allChainICC.append(chainICC)
    }

    // Merge all chains
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
