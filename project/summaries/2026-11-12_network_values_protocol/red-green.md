# Red then green: Network metrics values protocol (step 2 foundation)

Branch `feature/network-values-protocol`, stacked on `integration/network-base`.

## Method

1. Scratch program `golden/main.swift` (outside both repos at `/private/tmp/claude-501/golden/`,
   depending on SwiftGraphMetrics by path) encoded fixed values and envelopes with SGM's own
   encoder (`.sortedKeys`). Output: `golden/sgm_output.txt`. Those strings are the constants in
   `StoredRecordGoldenTests`.
2. Compile-stub: the eight ported types with the same public signatures and wrong behaviour
   (`ranked` unsorted, `top` returns everything, `bottom` returns nothing, `groups` empty,
   `communityCount` 0, `nodes` empty, `totalGain` 0, every `kind` "stub", `JSONValue` object
   decoding gives null, `value(as:)` always nil, `convergence` always nil, `ConvergenceNote` returns
   "", `DiagnosedScores` decoding drops `convergence`).
3. Ported and extended tests run against the stub. Every failure below is a failed assertion,
   not a compile error (the stub compiled and the build was clean). One earlier attempt crashed the
   test process on an out-of-range index (`groups[0]` on the empty stub); the tests were changed
   to compare whole arrays so a wrong answer fails an assertion instead of trapping.
4. Real implementation copied in; same command, green.

Command: `swift test --filter "NodeScoresTests|PartitionAndSelectionTests|MetricEnvelopeTests|ConvergenceEnvelopeTests|StoredRecordGoldenTests"`

## Red (stub): 49 tests in 5 suites, 460 issues; 37 tests failed

- Test "A custom value type travels through an envelope" => 1 issues
- Test "A known kind with a malformed payload throws" => 2 issues
- Test "A miss names the ceiling, not the passes run, and says what to do" => 4 issues
- Test "A NaN score still ranks every node once, and cannot be stored in an envelope" => 2 issues
- Test "A node type that is not a string still round-trips" => 1 issues
- Test "A selection keeps its picks in order with their marginal gains" => 2 issues
- Test "A stored version 3 envelope decodes, and its convergence reads as unknown" => 1 issues
- Test "A version 4 envelope is still readable as plain NodeScores" => 1 issues
- Test "An unknown kind decodes as an opaque envelope and survives re-encoding" => 1 issues
- Test "Bottom breaks ties in the reverse of ranked order" => 2 issues
- Test "Decoding DiagnosedScores directly: absent and null convergence are nil, malformed throws" => 2 issues
- Test "Each built-in value round-trips through its envelope exactly" => 4 issues
- Test "Envelopes of each value encode to exactly the stored text" => 6 issues
- Test "Groups of equal size are ordered by community number, ascending" => 3 issues
- Test "JSONValue decodes every JSON shape and encodes it back" => 2 issues
- Test "Kinds are stable strings" => 5 issues
- Test "Limits: zero and negative are empty, exact count is everything, more is clamped" => 5 issues
- Test "Negative and infinite scores order as numbers do" => 3 issues
- Test "Negative community numbers are ordinary identifiers" => 2 issues
- Test "Only a scores envelope is read for convergence, whatever another kind's payload holds" => 1 issues
- Test "Partition groups are largest first with members sorted" => 3 issues
- Test "Ranks descending with ties broken by node ascending, whatever the insertion order" => 3 issues
- Test "Re-encoding a decoded stored envelope reproduces the stored text" => 7 issues
- Test "Seeded: DiagnosedScores with and without a report round-trip through JSON" with 4 test cases => 8 issues
- Test "Seeded: groups partition the nodes exactly and are ordered by size then number" with 5 test cases => 5 issues
- Test "Seeded: random values survive value to envelope to JSON text to envelope to value" with 8 test cases => 48 issues
- Test "Seeded: ranked is a permutation, non-increasing, ties ascending; top and bottom agree" with 8 test cases => 301 issues
- Test "Seeded: the ranking does not depend on dictionary construction order" with 4 test cases => 4 issues
- Test "Stored envelopes decode, yield equal typed values and the same convergence" => 7 issues
- Test "The convergence accessor reads a diagnosed scores envelope" => 2 issues
- Test "The envelope carries the kind of what it wraps" => 4 issues
- Test "The sentence says which it was, with the numbers" => 6 issues
- Test "The sentences for the stored reports are the ones the previous package wrote" => 3 issues
- Test "The stored text decodes to equal values" => 2 issues
- Test "Top and bottom read from opposite ends" => 6 issues
- Test "Typed access is nil for a different known kind and never throws for it" => 1 issues

Sample failing assertions (from the log): `bottom.count == expected` with `bottom.count -> 0`;
`envelope.convergence` with `envelope.kind -> "stub"`, `payload -> .null`; golden
`encoded(...) == Golden.envScores` with the stub's kind.

The other 12 tests passed against the stub (they assert things the stub leaves true, such as
subscripts, empty inputs and equality). They are not red-first evidence; the mutation check
(`mutation_output.txt`) is what shows the suite bites.

## Green (real implementation)

`Test run with 49 tests in 5 suites passed`.
