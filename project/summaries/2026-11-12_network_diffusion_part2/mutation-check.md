# Mutation check: seed selection, sweep, codec, conformances, siting from scores (step 3, part 2)

Script `mutation-check.py` (104 hand-written mutants), scratch lab `mutlab2` (`mutation-lab-Package.swift.txt`,
`mutation-lab-sync.sh`): the diffusion, siting and metric-value sources, `WeightedGraph` and the ported tests (without the
integer-program suite). Each mutant is one textual change asserted to match exactly once; the file is restored after each.
Output: `mutation-output.txt` (run 1 was split over three identical labs for speed, run 2 re-ran the closed survivors).

Result: **104 mutants: 88 killed, 16 survived; 5 of the survivors were closed by two new tests (re-run: 5 of 5 killed);
the 11 that remain are equivalent.** None failed to compile.

| Group | Mutants | What was flipped |
| --- | --- | --- |
| V (validation, early exits) | 10 | trial and budget bounds, validation order, empty and zero-budget exits, target clamp |
| R (streams, totals) | 6 | trial numbering, stream keying, trial range, sum, first-pass node |
| P (chunking, parallel collection, async) | 9 | chunk size and count, slot writes, async ordering, single-candidate path, refresh slot |
| G (greedy, lazy refresh, tie-breaks) | 22 | stale-bound test, round stamping, gain net of total, divide by trials, sort direction and tie-break, eligibility, front width, loop bound, stale filter |
| B (submodularity gate, batching) | 9 | gate inverted, removed, narrowed, batch default and override, internal init |
| W (sweep) | 8 | empty-sweep guard, per-point seed and probability, order, default builder |
| J (SeedSweep summary) | 21 | frequency denominator and count, diagonal, symmetry, pair loop bound, mean arithmetic and fallback, Jaccard union and intersection, `alwaysPicked` threshold and order |
| K (codec, kind strings) | 7 | coding key, encode order, decode drop, `"seed-sweep"`, `"site-assignment"` |
| D (descriptor) | 6 | identifier, version, title, label, opposite meaning, instance descriptor |
| N (siting from scores) | 5 | weights scaled, sites reversed, cost shifted, zero and negative scores |
| A (SiteAssignment shape) | 1 | a stored key renamed |

## Closed by new tests (red against the mutant first)

| Mutants | Change | Test |
| --- | --- | --- |
| G8, G21, G22, B7 | fresh candidates refreshed again; front one wider or one narrower than the batch; batch of at least two | `declaredWorkMatchesReference`: the number of trials a declared-submodular model is asked to run equals the count from a reference that replays the lazy rule (batches 1, 2, 3, 7; three graphs). Their output is identical to the original by design, so only the work distinguishes them; refresh batching is part of what must not change. |
| N5 | negative scores clipped to zero before the weights are validated | `nodeScoresDemand` now requires `invalidWeight` for a negative and a NaN score. |

## Equivalent survivors

- V6 (`budget >= 0` builds an engine) and V7 (`nodeCount >= 0`): with budget 0 or an empty graph the engine's target is 0 and it returns no picks; only wasted first-pass work differs.
- V10 (target not clamped to the node count): the inner `guard let best = front.first else { break }` ends the pick loop once every node is chosen.
- G15 (`0..<n` instead of `0...n` refresh passes): a pick needs at most `n - pick` refreshes plus one pick pass, which is at most `n` for `pick >= 1`, and none for pick 0.
- G13 (seed appended twice): the cascade models de-duplicate seeds, so a repeated index changes nothing.
- P1, P2 (chunk size rounds down; fewer chunks): the chunks still cover every node and the result does not depend on chunking by design.
- P7 (single-candidate refresh goes through the parallel path): same slot, same value.
- B4 (undeclared batch of `nodeCount - 1`): at pick 1 exactly `n - 1` nodes remain and later rounds have fewer, so the front is the same.
- B5, B8 (default batch of one): a smaller batch changes how much is refreshed, not what is picked; the default is the machine's core count, so its work is not reproducible across machines and cannot be pinned.
