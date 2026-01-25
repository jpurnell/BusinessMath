//
//  Shaders.metal
//  BusinessMath
//
//  GPU compute kernels for genetic algorithm operations.
//
//  Created by Justin Purnell on 12/27/25.
//

#include <metal_stdlib>
using namespace metal;

// ============================================================================
// MARK: - Random Number Generation
// ============================================================================

/// PCG random number generator (GPU-friendly, no global state).
///
/// Uses permuted congruential generator for fast, high-quality randomness.
inline uint pcg_hash(uint input) {
    uint state = input * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

/// Generate random float in [0, 1) from seed and index.
///
/// - Parameters:
///   - seed: Base random seed
///   - index: Index to make each call unique
/// - Returns: Pseudo-random float in [0, 1)
inline float random_float(uint seed, uint index) {
    uint hash = pcg_hash(seed + index);
    return float(hash) / 4294967296.0;
}

// ============================================================================
// MARK: - Crossover Kernel
// ============================================================================

/// Uniform crossover: each gene randomly inherited from parent1 or parent2.
///
/// Runs in parallel across all offspring. Each thread handles one individual.
///
/// - Parameters:
///   - parent1: First parent population buffer
///   - parent2: Second parent population buffer
///   - offspring: Output offspring population buffer
///   - randomSeeds: Random seed per individual
///   - dimension: Number of genes per individual
///   - crossoverRate: Probability of crossover occurring [0, 1]
///   - id: Thread index (individual index)
kernel void crossoverPopulation(
    device const float* parent1 [[buffer(0)]],
    device const float* parent2 [[buffer(1)]],
    device float* offspring [[buffer(2)]],
    device const uint* randomSeeds [[buffer(3)]],
    constant int& dimension [[buffer(4)]],
    constant float& crossoverRate [[buffer(5)]],
    uint id [[thread_position_in_grid]]
) {
    uint seed = randomSeeds[id];
    uint offset = id * dimension;

    // Check if crossover occurs for this individual
    float r = random_float(seed, 0);
    bool doCrossover = r < crossoverRate;

    if (doCrossover) {
        // Uniform crossover: each gene from random parent
        for (int i = 0; i < dimension; i++) {
            float geneRand = random_float(seed, uint(i) + 1);
            if (geneRand < 0.5) {
                offspring[offset + i] = parent1[offset + i];
            } else {
                offspring[offset + i] = parent2[offset + i];
            }
        }
    } else {
        // No crossover: copy parent1
        for (int i = 0; i < dimension; i++) {
            offspring[offset + i] = parent1[offset + i];
        }
    }
}

// ============================================================================
// MARK: - Mutation Kernel
// ============================================================================

/// Gaussian mutation: add random perturbation to genes.
///
/// Uses Box-Muller transform to generate Gaussian-distributed mutations.
/// Clamps mutated values to stay within search space bounds.
///
/// - Parameters:
///   - population: Population to mutate (in-place)
///   - randomSeeds: Random seed per individual
///   - dimension: Number of genes per individual
///   - mutationRate: Probability of mutation per gene [0, 1]
///   - mutationStrength: Standard deviation of Gaussian mutation
///   - searchSpace: Bounds per dimension (lower, upper)
///   - id: Thread index (individual index)
kernel void mutatePopulation(
    device float* population [[buffer(0)]],
    device const uint* randomSeeds [[buffer(1)]],
    constant int& dimension [[buffer(2)]],
    constant float& mutationRate [[buffer(3)]],
    constant float& mutationStrength [[buffer(4)]],
    constant float2* searchSpace [[buffer(5)]],
    uint id [[thread_position_in_grid]]
) {
    uint seed = randomSeeds[id];
    uint offset = id * dimension;

    for (int i = 0; i < dimension; i++) {
        float r = random_float(seed, uint(i) * 2);

        if (r < mutationRate) {
            // Box-Muller transform for Gaussian distribution
            float u1 = random_float(seed, uint(i) * 2 + 1);
            float u2 = random_float(seed, uint(i) * 2 + 2);

            // Clamp u1 to avoid log(0)
            u1 = max(u1, 1e-8);

            float gaussian = sqrt(-2.0 * log(u1)) * cos(2.0 * M_PI_F * u2);

            // Apply mutation
            float lower = searchSpace[i].x;
            float upper = searchSpace[i].y;
            float range = upper - lower;
            float mutation = gaussian * mutationStrength * range;

            float newValue = population[offset + i] + mutation;

            // Clamp to bounds
            population[offset + i] = clamp(newValue, lower, upper);
        }
    }
}

// ============================================================================
// MARK: - Tournament Selection Kernel
// ============================================================================

/// Tournament selection: pick best of k random individuals.
///
/// For each output position, randomly select k individuals and choose the
/// one with the best (lowest) fitness.
///
/// - Parameters:
///   - population: Input population buffer
///   - fitness: Fitness values (one per individual)
///   - selected: Output selected individuals buffer
///   - randomSeeds: Random seed per output position
///   - dimension: Number of genes per individual
///   - tournamentSize: Number of individuals per tournament (k)
///   - populationSize: Total population size
///   - id: Thread index (output individual index)
kernel void tournamentSelection(
    device const float* population [[buffer(0)]],
    device const float* fitness [[buffer(1)]],
    device float* selected [[buffer(2)]],
    device const uint* randomSeeds [[buffer(3)]],
    constant int& dimension [[buffer(4)]],
    constant int& tournamentSize [[buffer(5)]],
    constant int& populationSize [[buffer(6)]],
    uint id [[thread_position_in_grid]]
) {
    uint seed = randomSeeds[id];

    int bestIndex = -1;
    float bestFitness = INFINITY;

    // Run tournament
    for (int t = 0; t < tournamentSize; t++) {
        // Pick random individual
        float r = random_float(seed, uint(t));
        int candidateIndex = int(r * float(populationSize)) % populationSize;
        float candidateFitness = fitness[candidateIndex];

        // Track best
        if (candidateFitness < bestFitness) {
            bestFitness = candidateFitness;
            bestIndex = candidateIndex;
        }
    }

    // Copy best individual to output
    uint outputOffset = id * dimension;
    uint inputOffset = bestIndex * dimension;

    for (int i = 0; i < dimension; i++) {
        selected[outputOffset + i] = population[inputOffset + i];
    }
}

// ============================================================================
// MARK: - Utility Kernels
// ============================================================================

/// Copy individuals from source to destination (for elitism).
///
/// - Parameters:
///   - source: Source buffer
///   - destination: Destination buffer
///   - dimension: Number of genes per individual
///   - id: Thread index (individual index)
kernel void copyIndividuals(
    device const float* source [[buffer(0)]],
    device float* destination [[buffer(1)]],
    constant int& dimension [[buffer(2)]],
    uint id [[thread_position_in_grid]]
) {
    uint offset = id * dimension;
    for (int i = 0; i < dimension; i++) {
        destination[offset + i] = source[offset + i];
    }
}

// ============================================================================
// MARK: - Differential Evolution Kernels
// ============================================================================

/// DE Mutation: Create mutant vectors using vector differences.
///
/// Supports three strategies:
/// - strategy=0 (rand/1): mutant = r1 + F × (r2 - r3)
/// - strategy=1 (best/1): mutant = best + F × (r1 - r2)
/// - strategy=2 (currentToBest1): mutant = current + F × (best - current) + F × (r1 - r2)
///
/// - Parameters:
///   - population: Current population buffer
///   - mutants: Output mutant vectors buffer
///   - randomIndices: Pre-computed random indices (3 per individual)
///   - bestIndex: Index of best individual in population
///   - dimension: Number of components per vector
///   - mutationFactor: F parameter for scaling differences
///   - strategy: Mutation strategy (0=rand/1, 1=best/1, 2=currentToBest1)
///   - searchSpace: Bounds per dimension (lower, upper)
///   - id: Thread index (individual index)
kernel void deMutation(
    device const float* population [[buffer(0)]],
    device float* mutants [[buffer(1)]],
    device const uint* randomIndices [[buffer(2)]],
    constant int& bestIndex [[buffer(3)]],
    constant int& dimension [[buffer(4)]],
    constant float& mutationFactor [[buffer(5)]],
    constant int& strategy [[buffer(6)]],
    constant float2* searchSpace [[buffer(7)]],
    uint id [[thread_position_in_grid]]
) {
    uint offset = id * dimension;
    uint indicesOffset = id * 3;  // Each individual has 3 random indices

    uint r1_idx = randomIndices[indicesOffset];
    uint r2_idx = randomIndices[indicesOffset + 1];
    uint r3_idx = randomIndices[indicesOffset + 2];

    for (int i = 0; i < dimension; i++) {
        float mutant;

        if (strategy == 0) {
            // rand/1: mutant = r1 + F × (r2 - r3)
            float r1 = population[r1_idx * dimension + i];
            float r2 = population[r2_idx * dimension + i];
            float r3 = population[r3_idx * dimension + i];
            mutant = r1 + mutationFactor * (r2 - r3);

        } else if (strategy == 1) {
            // best/1: mutant = best + F × (r1 - r2)
            float best = population[bestIndex * dimension + i];
            float r1 = population[r1_idx * dimension + i];
            float r2 = population[r2_idx * dimension + i];
            mutant = best + mutationFactor * (r1 - r2);

        } else {
            // currentToBest1: mutant = current + F × (best - current) + F × (r1 - r2)
            float current = population[offset + i];
            float best = population[bestIndex * dimension + i];
            float r1 = population[r1_idx * dimension + i];
            float r2 = population[r2_idx * dimension + i];
            mutant = current + mutationFactor * (best - current) + mutationFactor * (r1 - r2);
        }

        // Clamp to search space bounds
        float lower = searchSpace[i].x;
        float upper = searchSpace[i].y;
        mutants[offset + i] = clamp(mutant, lower, upper);
    }
}

/// DE Crossover: Binomial crossover between target and mutant.
///
/// Each component is inherited from mutant with probability CR, or from target.
/// At least one component is always inherited from mutant (jRand).
///
/// - Parameters:
///   - targets: Target population buffer
///   - mutants: Mutant vectors buffer
///   - trials: Output trial vectors buffer
///   - randomSeeds: Random seed per individual
///   - dimension: Number of components per vector
///   - crossoverRate: CR parameter - probability of using mutant component
///   - id: Thread index (individual index)
kernel void deCrossover(
    device const float* targets [[buffer(0)]],
    device const float* mutants [[buffer(1)]],
    device float* trials [[buffer(2)]],
    device const uint* randomSeeds [[buffer(3)]],
    constant int& dimension [[buffer(4)]],
    constant float& crossoverRate [[buffer(5)]],
    uint id [[thread_position_in_grid]]
) {
    uint offset = id * dimension;
    uint seed = randomSeeds[id];

    // Ensure at least one component from mutant
    float jRandFloat = random_float(seed, 0);
    int jRand = int(jRandFloat * float(dimension)) % dimension;

    for (int i = 0; i < dimension; i++) {
        float r = random_float(seed, uint(i) + 1);

        if (r < crossoverRate || i == jRand) {
            trials[offset + i] = mutants[offset + i];
        } else {
            trials[offset + i] = targets[offset + i];
        }
    }
}

/// DE Selection: Compare trial vs target, keep better.
///
/// Simple greedy selection: if trial has better (lower) fitness, replace target.
///
/// - Parameters:
///   - population: Current population (will be updated in-place)
///   - trials: Trial vectors
///   - fitness: Current fitness values (will be updated in-place)
///   - trialFitness: Trial fitness values
///   - dimension: Number of components per vector
///   - id: Thread index (individual index)
kernel void deSelection(
    device float* population [[buffer(0)]],
    device const float* trials [[buffer(1)]],
    device float* fitness [[buffer(2)]],
    device const float* trialFitness [[buffer(3)]],
    constant int& dimension [[buffer(4)]],
    uint id [[thread_position_in_grid]]
) {
    uint offset = id * dimension;

    // If trial is better, replace target
    if (trialFitness[id] < fitness[id]) {
        for (int i = 0; i < dimension; i++) {
            population[offset + i] = trials[offset + i];
        }
        fitness[id] = trialFitness[id];
    }
}

// ============================================================================
// MARK: - Particle Swarm Optimization Kernel
// ============================================================================

/// PSO Update: Update particle velocities and positions.
///
/// Applies the standard PSO velocity update equation:
/// v = w×v + c1×r1×(pbest - x) + c2×r2×(gbest - x)
///
/// Then updates position: x = x + v
///
/// - Parameters:
///   - currentVelocities: Current velocity vectors
///   - currentPositions: Current position vectors
///   - personalBest: Each particle's personal best position
///   - globalBest: Global best position (shared across all particles)
///   - newVelocities: Output velocity vectors
///   - newPositions: Output position vectors
///   - randomSeeds: Random seed per particle
///   - dimension: Number of dimensions
///   - inertiaWeight: w - inertia weight for previous velocity
///   - cognitiveCoeff: c1 - cognitive coefficient (attraction to personal best)
///   - socialCoeff: c2 - social coefficient (attraction to global best)
///   - searchSpace: Bounds per dimension (lower, upper)
///   - velocityLimits: Velocity bounds per dimension (optional clamping)
///   - hasVelocityClamp: Whether to apply velocity clamping
///   - id: Thread index (particle index)
kernel void psoUpdateParticles(
    device const float* currentVelocities [[buffer(0)]],
    device const float* currentPositions [[buffer(1)]],
    device const float* personalBest [[buffer(2)]],
    device const float* globalBest [[buffer(3)]],
    device float* newVelocities [[buffer(4)]],
    device float* newPositions [[buffer(5)]],
    device const uint* randomSeeds [[buffer(6)]],
    constant int& dimension [[buffer(7)]],
    constant float& inertiaWeight [[buffer(8)]],
    constant float& cognitiveCoeff [[buffer(9)]],
    constant float& socialCoeff [[buffer(10)]],
    constant float2* searchSpace [[buffer(11)]],
    constant float2* velocityLimits [[buffer(12)]],
    constant bool& hasVelocityClamp [[buffer(13)]],
    uint id [[thread_position_in_grid]]
) {
    uint seed = randomSeeds[id];
    uint offset = id * dimension;

    for (int d = 0; d < dimension; d++) {
        // Generate random values r1, r2
        float r1 = random_float(seed, uint(d) * 2);
        float r2 = random_float(seed, uint(d) * 2 + 1);

        // PSO velocity update: v = w×v + c1×r1×(pbest - x) + c2×r2×(gbest - x)
        float v = currentVelocities[offset + d];
        float x = currentPositions[offset + d];
        float pbest = personalBest[offset + d];
        float gbest = globalBest[d];

        float newV = inertiaWeight * v
                   + cognitiveCoeff * r1 * (pbest - x)
                   + socialCoeff * r2 * (gbest - x);

        // Clamp velocity if needed
        if (hasVelocityClamp) {
            float vLower = velocityLimits[d].x;
            float vUpper = velocityLimits[d].y;
            newV = clamp(newV, vLower, vUpper);
        }

        // Update position: x = x + v
        float newX = x + newV;

        // Clamp position to search space
        float xLower = searchSpace[d].x;
        float xUpper = searchSpace[d].y;
        newX = clamp(newX, xLower, xUpper);

        // Write outputs
        newVelocities[offset + d] = newV;
        newPositions[offset + d] = newX;
    }
}
