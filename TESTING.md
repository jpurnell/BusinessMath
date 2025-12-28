# Testing Guide for BusinessMath

## Quick Start

To run the test suite with optimal performance:

```bash
swift test --parallel --num-workers 8
```

## Performance Optimizations

The BusinessMath test suite has been optimized for systems with 10 CPU cores. Key optimizations include:

### 1. Controlled Parallelism (8 workers)
- **Why**: Limits parallel test execution to 8 workers (80% of available cores)
- **Benefit**: Avoids context switching overhead and resource contention
- **Result**: ~20% faster test execution (1:49 vs 2:17)

### 2. Serialized CPU-Intensive Suites
The following test suites use `.serialized` to prevent resource contention:
- `ParallelOptimizerPerformanceTests`
- `MultivariateOptimizerPerformanceTests`
- `MultivariateOptimizerIntegrationTests`
- `MonteCarloSimulationTests`
- `SimulationResultsTests`
- `CorrelatedNormalsTests`
- `MultiVariableMonteCarloTests`
- `SparseMatrixPerformanceBenchmarks`
- `DDMPerformanceTests`

These suites run one at a time to ensure accurate performance measurements and prevent CPU thrashing.

## Performance Comparison

| Configuration | Time | CPU Usage | Improvement |
|--------------|------|-----------|-------------|
| Original (serial) | 2:17 | 549% | Baseline |
| Unlimited parallel | 2:10 | 607% | +6% |
| **8 workers (optimized)** | **1:49** | **646%** | **+20%** |

## Running Tests

### Full Test Suite (Optimized)
```bash
swift test --parallel --num-workers 8
```

### Single Test
```bash
swift test --filter "testName"
```

### Specific Suite
```bash
swift test --filter "SuiteName"
```

### Debug Mode (Serial)
For debugging test failures, run serially:
```bash
swift test
```

## CI/CD Configuration

For continuous integration, use the optimized configuration:

```yaml
# GitHub Actions example
- name: Run Tests
  run: swift test --parallel --num-workers 8
```

## Troubleshooting

### Tests Running Slowly
- Ensure you're using `--parallel --num-workers 8`
- Check CPU usage with `top` or Activity Monitor
- Verify no other CPU-intensive processes are running

### Random Test Failures
- Some failures may be due to resource contention
- Run the failing test individually: `swift test --filter "testName"`
- Check if the test is marked as CPU-intensive and should be `.serialized`

### Memory Issues
- Reduce `--num-workers` to 4 or 6
- Run tests serially: `swift test` (no --parallel flag)

## System Requirements

- **Recommended**: 10+ CPU cores
- **Minimum**: 4 CPU cores (use `--num-workers 3`)
- **Memory**: 8GB+ RAM

## Adding New Tests

When adding new performance-sensitive or CPU-intensive tests:

1. Mark the suite as serialized:
   ```swift
   @Suite("My Performance Tests", .serialized)
   struct MyPerformanceTests {
       // ...
   }
   ```

2. This prevents the suite from running in parallel with other tests
3. Use this for:
   - Optimization algorithm tests
   - Monte Carlo simulations
   - Matrix computations
   - Performance benchmarks
