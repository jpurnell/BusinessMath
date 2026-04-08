# Nightly Guideline Conformance Audit — BusinessMath

You are running headless in CI. Your job is to audit this Swift package against the project's development guidelines and apply trivial fixes. Be conservative — when in doubt, defer rather than auto-fix.

## Audit checklist

For each item below, scan the codebase and record findings. Apply fixes ONLY for items marked **auto-fix**; defer the rest into a checklist for human review.

1. **XCTest → Swift Testing migration** *(defer)*
   - Find any `import XCTest`, `XCTAssert*`, or `XCTestCase` in `Tests/`.
   - Do NOT migrate automatically — list each occurrence with file:line.

2. **Swift 6 strict concurrency** *(defer)*
   - Run `swift build -Xswiftc -strict-concurrency=complete 2>&1` and capture warnings.
   - Group by file and summarize each warning class (Sendable, actor isolation, etc.).

3. **DocC coverage on public API** *(auto-fix only for trivial cases)*
   - Find any `public` symbol in `Sources/` lacking a `///` doc comment immediately above it.
   - Auto-fix ONLY if the symbol's purpose is obvious from its name AND signature (e.g. a one-line getter). Otherwise list it.
   - Never invent semantics. If you would have to guess what it does, defer.

4. **Forbidden patterns** *(auto-fix)*
   - `!` force unwraps (excluding `!=`, `!Bool`)
   - `try!`
   - `as!` force casts
   - `String(format:)` calls
   - For each: replace with the safe equivalent (`guard let`, `try?`/`do-catch`, `as?`, string interpolation or `.formatted()`). If the safe rewrite changes semantics in a non-obvious way, defer instead.

5. **Hardcoded numeric constants in logic** *(defer)*
   - Flag magic numbers in computation paths (not test fixtures, not array indices like `0`/`1`).
   - List with file:line and suggested config field name.

6. **Division safety** *(defer)*
   - Find every `/` or `%` operator on numeric types and verify there's a guard against zero divisor in the same scope.
   - List unguarded ones.

7. **Dead code** *(defer)*
   - Find `private`/`fileprivate` symbols with no references in their own file.
   - List them — do NOT delete automatically.

## Output format

Write your findings to `audit-report.md` in this exact structure:

```markdown
# Nightly Conformance Audit — <date>

## Summary
- Auto-fixes applied: N
- Items deferred for review: M
- Test status after fixes: PASS / FAIL

## Auto-fixes applied
<bullet list, one per fix, with file:line and one-line description>

## Deferred items
### XCTest migration
- ...
### Strict concurrency warnings
- ...
### Missing DocC
- ...
### Hardcoded constants
- ...
### Division safety
- ...
### Dead code
- ...

## Notes
<anything surprising, anything you chose not to touch and why>
```

## Hard rules

- Do NOT modify tests other than to fix forbidden patterns inside them.
- Do NOT bump the package version.
- Do NOT touch `CHANGELOG.md`, `README.md`, or release notes.
- Do NOT add new dependencies.
- Do NOT delete files.
- If `swift build` fails after any of your edits, REVERT that edit before proceeding.
- Run `swift test` at the end. If it fails, revert all auto-fixes and report only the deferred items.
