# GPU Buffer Caching Implementation Plan

**Created:** March 9, 2026
**Status:** Deferred (correctness fixes first)
**Priority:** Performance Optimization
**Estimated Effort:** 8-12 hours

---

## Background

### Current State

The GPU buffer caching mechanism in `MonteCarloGPUDevice.swift` was disabled due to data staleness issues:

```swift
// Lines 72-73
private var bufferCache: [Int: Buffers] = [:]  // Variable exists but unused
private let bufferCacheLock = NSLock()

// Lines 375-376 (comment)
// TODO: Re-enable buffer caching with proper data clearing
// Currently disabled due to stale data issues
// Allocate new buffers every time (ensures clean state)
```

### Problem Being Solved

GPU buffer allocation is expensive. For high-frequency simulations:
- **Current:** 5 buffer allocations per simulation run
- **PSO:** 9 buffer allocations per iteration × 500 iterations = 4,500 allocations
- **DE:** 6 buffer allocations per generation × 100 generations = 600 allocations

Each allocation involves:
1. Metal API call overhead
2. GPU memory allocation
3. Potential memory fragmentation

### Why It Was Disabled

The original caching had "stale data issues" — likely:
1. Buffer contents from previous run contaminating new run
2. Race conditions between cache lookup and buffer update
3. Buffer size mismatches when simulation parameters change

---

## Proposed Solution

### Architecture: Keyed Buffer Pool with Explicit Invalidation

```
┌─────────────────────────────────────────────────────────┐
│                    BufferPoolManager                     │
├─────────────────────────────────────────────────────────┤
│  pools: [ConfigKey: BufferPool]                         │
│  lock: NSLock                                           │
├─────────────────────────────────────────────────────────┤
│  + acquire(for config: SimulationConfig) -> BufferSet   │
│  + release(_ buffers: BufferSet)                        │
│  + invalidateAll()                                      │
│  + invalidate(for config: SimulationConfig)             │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                      BufferPool                          │
├─────────────────────────────────────────────────────────┤
│  available: [BufferSet]  // Ready to use                │
│  inUse: Set<BufferSet>   // Currently borrowed          │
│  config: SimulationConfig // Size/type requirements     │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                       BufferSet                          │
├─────────────────────────────────────────────────────────┤
│  rngStates: MTLBuffer                                   │
│  distributions: MTLBuffer                               │
│  distTypes: MTLBuffer                                   │
│  modelOps: MTLBuffer                                    │
│  outputs: MTLBuffer                                     │
│  configKey: ConfigKey   // For validation               │
│  lastUsed: Date         // For eviction                 │
└─────────────────────────────────────────────────────────┘
```

### Key Design Decisions

#### 1. Configuration-Based Keying

Buffer size depends on simulation parameters. Key must include:
```swift
struct ConfigKey: Hashable {
    let pathCount: Int
    let iterationCount: Int
    let distributionCount: Int
    let operationCount: Int

    // Derived buffer sizes
    var rngStateSize: Int { pathCount * MemoryLayout<UInt64>.stride * 4 }
    var outputSize: Int { pathCount * iterationCount * MemoryLayout<Float>.stride }
    // ...
}
```

Different configs get different pools — no size mismatch possible.

#### 2. Explicit Zero-Fill on Acquire

Root cause of staleness was likely leftover data. Fix:
```swift
func acquire(for config: SimulationConfig) -> BufferSet {
    lock.lock()
    defer { lock.unlock() }

    let key = ConfigKey(from: config)

    if let pool = pools[key], let bufferSet = pool.available.popLast() {
        // CRITICAL: Zero-fill before returning
        zeroFillBuffers(bufferSet)
        pool.inUse.insert(bufferSet)
        return bufferSet
    }

    // No cached buffer available, create new
    return createNewBufferSet(for: key)
}

private func zeroFillBuffers(_ set: BufferSet) {
    // Use Metal blit encoder for GPU-side zeroing (faster than CPU)
    let commandBuffer = commandQueue.makeCommandBuffer()!
    let blitEncoder = commandBuffer.makeBlitCommandEncoder()!

    blitEncoder.fill(buffer: set.rngStates, range: 0..<set.rngStates.length, value: 0)
    blitEncoder.fill(buffer: set.outputs, range: 0..<set.outputs.length, value: 0)
    // ... other buffers

    blitEncoder.endEncoding()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()  // Sync point
}
```

#### 3. Pool Size Limits

Prevent unbounded memory growth:
```swift
struct BufferPool {
    static let maxPooledBuffersPerConfig = 4
    static let maxTotalPools = 10

    var available: [BufferSet] = []

    mutating func release(_ bufferSet: BufferSet) {
        if available.count < Self.maxPooledBuffersPerConfig {
            available.append(bufferSet)
        }
        // If pool full, let ARC deallocate the buffer
    }
}
```

#### 4. LRU Eviction for Pool Management

When total pools exceed limit:
```swift
private func evictLeastRecentlyUsed() {
    guard pools.count > Self.maxTotalPools else { return }

    let sortedByAge = pools.sorted { $0.value.lastAccessed < $1.value.lastAccessed }
    let toEvict = sortedByAge.prefix(pools.count - Self.maxTotalPools)

    for (key, _) in toEvict {
        pools.removeValue(forKey: key)
    }
}
```

---

## Implementation Steps

### Phase 1: Infrastructure (2 hours)

```
[ ] Create Sources/BusinessMath/Optimization/Heuristic/GPU/BufferPoolManager.swift
    - ConfigKey struct
    - BufferSet struct
    - BufferPool class
    - BufferPoolManager class

[ ] Add tests for buffer pool lifecycle
    - Acquire/release cycles
    - Config mismatch detection
    - Pool size limits
    - Concurrent access
```

### Phase 2: Zero-Fill Implementation (2 hours)

```
[ ] Implement Metal blit-based zero-fill
    - Faster than CPU memset
    - Runs on GPU timeline
    - Proper synchronization

[ ] Test that zero-fill eliminates staleness
    - Run simulation A, cache buffers
    - Run simulation B with same config
    - Verify B results unaffected by A's data
```

### Phase 3: Integration with MonteCarloGPUDevice (3 hours)

```
[ ] Replace direct buffer allocation:

    BEFORE:
      guard let rngStates = device.makeBuffer(length: rngStateSize, ...)

    AFTER:
      let bufferSet = bufferPool.acquire(for: config)
      defer { bufferPool.release(bufferSet) }

[ ] Update runSimulation() method
[ ] Update any other GPU entry points
```

### Phase 4: Integration with Optimization Algorithms (3 hours)

```
[ ] ParticleSwarmOptimization.swift
    - Create PSOBufferPool subclass
    - Integrate with GPU iteration loop

[ ] DifferentialEvolution.swift
    - Create DEBufferPool subclass
    - Integrate with generation loop

[ ] GeneticAlgorithm.swift (if GPU-accelerated)
    - Same pattern
```

### Phase 5: Testing & Benchmarking (2 hours)

```
[ ] Correctness tests
    - Results match non-cached implementation
    - No data contamination between runs
    - Thread safety under concurrent use

[ ] Performance benchmarks
    - Measure allocation time savings
    - Measure memory high-water mark
    - Compare pooled vs non-pooled throughput

[ ] Stress tests
    - Many configs → pool eviction works
    - Rapid acquire/release → no leaks
    - Long-running server → memory stable
```

---

## Success Criteria

| Metric | Target |
|--------|--------|
| Correctness | Results identical to non-cached |
| Allocation reduction | 90%+ for repeated configs |
| Memory overhead | <2x single-run memory |
| Thread safety | Pass TSan under load |
| Performance | 20%+ throughput improvement |

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Zero-fill adds overhead | GPU blit is fast; measure actual impact |
| Pool fragmentation | LRU eviction + size limits |
| Config key collisions | Include all relevant parameters in key |
| Sync point stalls | Consider async zero-fill with fence |

---

## Dependencies

- Phase 5 of security/memory fixes (GPU buffer cleanup patterns)
- Metal compute encoder `defer` pattern established

---

## Future Enhancements

1. **Async zero-fill** — Queue zero-fill as part of previous run's cleanup
2. **Predictive pre-allocation** — Anticipate next simulation's config
3. **Memory pressure response** — Release pools when system memory low
4. **Metrics/logging** — Track cache hit rate, pool sizes

---

*Plan created March 9, 2026 — Deferred pending correctness fixes*
