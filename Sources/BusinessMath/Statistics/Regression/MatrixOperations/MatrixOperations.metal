//
//  MatrixOperations.metal
//  BusinessMath
//
//  Created by Claude Code on 2026-02-15.
//

#include <metal_stdlib>
using namespace metal;

/// Matrix multiplication kernel: C = A × B
///
/// Computes the product of two matrices using GPU parallelization.
/// Each thread computes one element of the result matrix.
///
/// - Parameters:
///   - A: Left matrix (m × n) in row-major order
///   - B: Right matrix (n × p) in row-major order
///   - C: Result matrix (m × p) in row-major order
///   - m: Number of rows in A and C
///   - n: Number of columns in A, rows in B
///   - p: Number of columns in B and C
///
/// - Note: Launch with 2D grid: dispatch(threadsPerGrid: (p, m), ...)
kernel void matrixMultiply(
    device const float* A [[buffer(0)]],
    device const float* B [[buffer(1)]],
    device float* C [[buffer(2)]],
    constant uint& m [[buffer(3)]],
    constant uint& n [[buffer(4)]],
    constant uint& p [[buffer(5)]],
    uint2 gid [[thread_position_in_grid]]
)
{
    uint row = gid.y;
    uint col = gid.x;

    // Bounds check
    if (row >= m || col >= p) {
        return;
    }

    // Compute dot product of row from A and column from B
    float sum = 0.0f;
    for (uint k = 0; k < n; k++) {
        sum += A[row * n + k] * B[k * p + col];
    }

    C[row * p + col] = sum;
}

/// Optimized matrix multiplication using shared memory (tile-based)
///
/// Uses threadgroup memory to cache tiles of A and B, reducing global memory access.
/// Provides 2-3× speedup over naive kernel for large matrices.
///
/// - Note: Launch with threadgroup size matching TILE_SIZE (e.g., 16×16)
kernel void matrixMultiplyTiled(
    device const float* A [[buffer(0)]],
    device const float* B [[buffer(1)]],
    device float* C [[buffer(2)]],
    constant uint& m [[buffer(3)]],
    constant uint& n [[buffer(4)]],
    constant uint& p [[buffer(5)]],
    uint2 gid [[thread_position_in_grid]],
    uint2 tid [[thread_position_in_threadgroup]],
    uint2 tpg [[threads_per_threadgroup]]
)
{
    constexpr uint TILE_SIZE = 16;

    threadgroup float tileA[TILE_SIZE][TILE_SIZE];
    threadgroup float tileB[TILE_SIZE][TILE_SIZE];

    uint row = gid.y;
    uint col = gid.x;

    float sum = 0.0f;

    // Loop over tiles
    uint numTiles = (n + TILE_SIZE - 1) / TILE_SIZE;
    for (uint t = 0; t < numTiles; t++) {
        // Load tile from A into shared memory
        uint tileACol = t * TILE_SIZE + tid.x;
        if (row < m && tileACol < n) {
            tileA[tid.y][tid.x] = A[row * n + tileACol];
        } else {
            tileA[tid.y][tid.x] = 0.0f;
        }

        // Load tile from B into shared memory
        uint tileBRow = t * TILE_SIZE + tid.y;
        if (tileBRow < n && col < p) {
            tileB[tid.y][tid.x] = B[tileBRow * p + col];
        } else {
            tileB[tid.y][tid.x] = 0.0f;
        }

        // Synchronize to ensure tile is loaded
        threadgroup_barrier(mem_flags::mem_threadgroup);

        // Compute partial dot product using tile
        for (uint k = 0; k < TILE_SIZE; k++) {
            sum += tileA[tid.y][k] * tileB[k][tid.x];
        }

        // Synchronize before loading next tile
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    // Write result
    if (row < m && col < p) {
        C[row * p + col] = sum;
    }
}

/// Matrix-vector multiplication kernel: y = A × x
///
/// Each thread computes one element of the result vector.
///
/// - Parameters:
///   - A: Matrix (m × n) in row-major order
///   - x: Input vector (length n)
///   - y: Result vector (length m)
///   - m: Number of rows in A
///   - n: Number of columns in A
kernel void matrixVectorMultiply(
    device const float* A [[buffer(0)]],
    device const float* x [[buffer(1)]],
    device float* y [[buffer(2)]],
    constant uint& m [[buffer(3)]],
    constant uint& n [[buffer(4)]],
    uint gid [[thread_position_in_grid]]
)
{
    if (gid >= m) {
        return;
    }

    float sum = 0.0f;
    for (uint j = 0; j < n; j++) {
        sum += A[gid * n + j] * x[j];
    }

    y[gid] = sum;
}

