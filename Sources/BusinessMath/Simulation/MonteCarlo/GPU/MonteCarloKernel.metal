//
//  MonteCarloKernel.metal
//  BusinessMath
//
//  Main GPU Kernel for Monte Carlo Simulation
//
//  Integrates:
//  - RNG (Xorshift128+, Box-Muller)
//  - Distribution sampling (Normal, Uniform, Triangular, Exponential, Lognormal)
//  - Bytecode model evaluation (stack-based interpreter)
//  - Main Monte Carlo iteration kernel
//

#include <metal_stdlib>
#include "MonteCarloCommon.h"
using namespace metal;

// Note: RNG and distribution functions are declared in MonteCarloCommon.h
// and implemented in MonteCarloRNG.metal and MonteCarloDistributions.metal
// This file only contains the bytecode evaluator and main kernel.

// MARK: - Bytecode Model Evaluator

/// Evaluate bytecode model using stack-based interpreter
///
/// The interpreter uses a simple stack machine:
/// - INPUT: Push input[arg1] onto stack
/// - CONST: Push arg2 (constant) onto stack
/// - ADD/SUB/MUL/DIV: Pop two values, apply operation, push result
///
/// **Example**: `inputs[0] * inputs[1] - inputs[2]`
/// ```
/// INPUT 0    // stack: [in0]
/// INPUT 1    // stack: [in0, in1]
/// MUL        // stack: [in0*in1]
/// INPUT 2    // stack: [in0*in1, in2]
/// SUB        // stack: [in0*in1-in2]
/// ```
///
/// - Parameters:
///   - inputs: Array of sampled input values
///   - ops: Bytecode operations
///   - numOps: Number of operations
/// - Returns: Final result (top of stack)
///
/// **Complexity**: O(numOps) - Linear scan through bytecode
inline float evaluateModel(
    thread float* inputs,
    constant ModelOp* ops,
    int numOps
) {
    float stack[MAX_STACK];
    int stackPtr = 0;

    for (int i = 0; i < numOps; i++) {
        constant ModelOp& op = ops[i];

        switch (op.opcode) {
            // Stack operations
            case OP_INPUT:
                stack[stackPtr++] = inputs[op.arg1];
                break;

            case OP_CONST:
                stack[stackPtr++] = op.arg2;
                break;

            // Binary arithmetic operations
            case OP_ADD:
                stack[stackPtr - 2] = stack[stackPtr - 2] + stack[stackPtr - 1];
                stackPtr--;
                break;

            case OP_SUB:
                stack[stackPtr - 2] = stack[stackPtr - 2] - stack[stackPtr - 1];
                stackPtr--;
                break;

            case OP_MUL:
                stack[stackPtr - 2] = stack[stackPtr - 2] * stack[stackPtr - 1];
                stackPtr--;
                break;

            case OP_DIV:
                stack[stackPtr - 2] = stack[stackPtr - 2] / stack[stackPtr - 1];
                stackPtr--;
                break;

            case OP_POW:
                stack[stackPtr - 2] = pow(stack[stackPtr - 2], stack[stackPtr - 1]);
                stackPtr--;
                break;

            case OP_MIN:
                stack[stackPtr - 2] = min(stack[stackPtr - 2], stack[stackPtr - 1]);
                stackPtr--;
                break;

            case OP_MAX:
                stack[stackPtr - 2] = max(stack[stackPtr - 2], stack[stackPtr - 1]);
                stackPtr--;
                break;

            // Unary operations
            case OP_NEG:
                stack[stackPtr - 1] = -stack[stackPtr - 1];
                break;

            case OP_ABS:
                stack[stackPtr - 1] = abs(stack[stackPtr - 1]);
                break;

            case OP_SQRT:
                stack[stackPtr - 1] = sqrt(stack[stackPtr - 1]);
                break;

            case OP_LOG:
                stack[stackPtr - 1] = log(stack[stackPtr - 1]);
                break;

            case OP_EXP:
                stack[stackPtr - 1] = exp(stack[stackPtr - 1]);
                break;

            case OP_SIN:
                stack[stackPtr - 1] = sin(stack[stackPtr - 1]);
                break;

            case OP_COS:
                stack[stackPtr - 1] = cos(stack[stackPtr - 1]);
                break;

            case OP_TAN:
                stack[stackPtr - 1] = tan(stack[stackPtr - 1]);
                break;

            // Comparison operations (return 1.0 for true, 0.0 for false)
            case OP_LT:
                stack[stackPtr - 2] = (stack[stackPtr - 2] < stack[stackPtr - 1]) ? 1.0f : 0.0f;
                stackPtr--;
                break;

            case OP_GT:
                stack[stackPtr - 2] = (stack[stackPtr - 2] > stack[stackPtr - 1]) ? 1.0f : 0.0f;
                stackPtr--;
                break;

            case OP_LE:
                stack[stackPtr - 2] = (stack[stackPtr - 2] <= stack[stackPtr - 1]) ? 1.0f : 0.0f;
                stackPtr--;
                break;

            case OP_GE:
                stack[stackPtr - 2] = (stack[stackPtr - 2] >= stack[stackPtr - 1]) ? 1.0f : 0.0f;
                stackPtr--;
                break;

            case OP_EQ:
                stack[stackPtr - 2] = (abs(stack[stackPtr - 2] - stack[stackPtr - 1]) < EPSILON) ? 1.0f : 0.0f;
                stackPtr--;
                break;

            case OP_NE:
                stack[stackPtr - 2] = (abs(stack[stackPtr - 2] - stack[stackPtr - 1]) >= EPSILON) ? 1.0f : 0.0f;
                stackPtr--;
                break;

            // Conditional operation: condition ? trueValue : falseValue
            case OP_SELECT:
                {
                    float falseValue = stack[stackPtr - 1];
                    float trueValue = stack[stackPtr - 2];
                    float condition = stack[stackPtr - 3];
                    stack[stackPtr - 3] = (condition != 0.0f) ? trueValue : falseValue;
                    stackPtr -= 2;
                }
                break;
        }
    }

    return stack[0];
}

// MARK: - Main Monte Carlo Kernel

/// Main Monte Carlo simulation kernel
///
/// This kernel performs one complete Monte Carlo iteration per GPU thread:
/// 1. Sample from all input distributions
/// 2. Evaluate the model using bytecode interpreter
/// 3. Store result
///
/// **Thread Layout**: 1 thread = 1 Monte Carlo iteration
///
/// **Performance** (measured on Apple M-series chips):
/// - Simple models (a+b): 2-3x speedup for 100K+ iterations
/// - Complex models (10+ ops): 5-15x speedup for 100K+ iterations
/// - Very large runs (1M+ iters): Up to 20x speedup
/// - Note: GPU overhead (buffer allocation, data transfer) dominates for small/simple models
///
/// - Parameters:
///   - rngStates: Per-thread RNG state (one per iteration)
///   - distributions: Array of distribution parameters (one per input)
///   - distTypes: Array of distribution types (one per input)
///   - modelOps: Bytecode operations for model evaluation
///   - outputs: Output buffer for results (one per iteration)
///   - numInputs: Number of input distributions
///   - numOps: Number of bytecode operations
///   - tid: Thread ID (maps to iteration index)
kernel void monteCarloIteration(
    device RNGState* rngStates [[buffer(0)]],
    constant DistributionParams* distributions [[buffer(1)]],
    constant int* distTypes [[buffer(2)]],
    constant ModelOp* modelOps [[buffer(3)]],
    device float* outputs [[buffer(4)]],
    constant int& numInputs [[buffer(5)]],
    constant int& numOps [[buffer(6)]],
    uint tid [[thread_position_in_grid]]
) {
    // Thread-local input storage
    thread float inputs[MAX_INPUTS];

    // Sample all inputs from their distributions
    for (int i = 0; i < numInputs; i++) {
        inputs[i] = sampleDistribution(
            &rngStates[tid],
            &distributions[i],
            distTypes[i]
        );
    }

    // Evaluate model using bytecode interpreter
    float result = evaluateModel(inputs, modelOps, numOps);

    // Store result
    outputs[tid] = result;

    // Note: RNG state is automatically persisted (device memory)
    // for multi-pass simulations if needed
}

// MARK: - Helper Kernels
// Note: initializeRNG kernel is defined in MonteCarloRNG.metal

/// Evaluate models only (for testing with pre-sampled inputs)
kernel void evaluateModels(
    constant float* inputs [[buffer(0)]],
    constant ModelOp* ops [[buffer(1)]],
    constant int& numInputs [[buffer(2)]],
    constant int& numOps [[buffer(3)]],
    device float* outputs [[buffer(4)]],
    uint tid [[thread_position_in_grid]]
) {
    // Get input pointer for this iteration
    constant float* iterationInputs = inputs + (tid * numInputs);

    // Copy to thread-local storage (evaluateModel expects thread float*)
    thread float localInputs[MAX_INPUTS];
    for (int i = 0; i < numInputs; i++) {
        localInputs[i] = iterationInputs[i];
    }

    // Evaluate model
    outputs[tid] = evaluateModel(localInputs, ops, numOps);
}
