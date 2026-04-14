# BusinessMath — Swift Financial Mathematics Library

This project follows the Design-First TDD workflow defined in `./development-guidelines/`.

## Session Start

Read documents in this order for full context recovery:
1. `./development-guidelines/00_CORE_RULES/00_MASTER_PLAN.md` — Vision and priorities
2. `./development-guidelines/00_CORE_RULES/01_CODING_RULES.md` — Forbidden patterns, safety rules
3. `./development-guidelines/00_CORE_RULES/09_TEST_DRIVEN_DEVELOPMENT.md` — Testing contract
4. `./development-guidelines/04_IMPLEMENTATION_CHECKLISTS/CURRENT_*.md` — Active tasks (if any)
5. Latest file in `./development-guidelines/05_SUMMARIES/` — Where we left off (if any)

For quick recovery (same-day, simple bug fixes), read only items 4-5.

## Development Workflow

```
0. DESIGN   → Propose architecture (05_DESIGN_PROPOSAL.md)
1. RED      → Write failing tests first
2. GREEN    → Minimum code to pass
3. REFACTOR → Clean up, keep tests green
4. DOCUMENT → DocC comments and examples
5. VERIFY   → Run quality-gate (zero warnings/errors)
```

## Key Rules

- No force unwraps (`!`), no `try!`, no force casts (`as!`)
- Guard clauses for all validation; early returns over nested ifs
- Division safety: always check for zero before dividing
- Swift 6 strict concurrency compliance
- All public APIs require DocC documentation
- Use `<T: Real>` generics (from swift-numerics) for numeric functions
- Fail-silent principle: never return plausible-but-wrong results

## Quality Gate

Run `swift build` and `swift test` before every commit. All checks must pass.

## References

- Full guidelines: `./development-guidelines/README.md`
- Coding rules: `./development-guidelines/00_CORE_RULES/01_CODING_RULES.md`
- TDD contract: `./development-guidelines/00_CORE_RULES/09_TEST_DRIVEN_DEVELOPMENT.md`
- Session workflow: `./development-guidelines/00_CORE_RULES/07_SESSION_WORKFLOW.md`
- DocC guidelines: `./development-guidelines/00_CORE_RULES/03_DOCC_GUIDELINES.md`
- Ergonomics & presentation: `./development-guidelines/03_STRATEGIES_AND_FRAMEWORKS/ergonomicsAndPresentation.md`
