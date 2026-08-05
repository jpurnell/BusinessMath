# Migration Report — BusinessMath

Migrated to the v2 layout on 2026-08-04.

- Files in the pre-migration tree: 9605
- Project documents repatriated to `project/`: 187
- Pre-migration tree preserved at: `development-guidelines.pre-v2/` (gitignored)
- Framework files untracked from the index: 0
- Master plan: **filled**

## Framework divergence

Content found locally that upstream does not ship. **Nothing was discarded** — it
remains in `development-guidelines.pre-v2/`. Each item is an upstream candidate.

### Local-only rules
- `00_CORE_RULES/03_DOCC_GUIDELINES.md`
- `00_CORE_RULES/09_TEST_DRIVEN_DEVELOPMENT.md`
- `00_CORE_RULES/RELEASE_CHECKLIST.md`
- `00_CORE_RULES/05_DESIGN_PROPOSAL.md`
- `00_CORE_RULES/scripts/update_readme.sh`
- `00_CORE_RULES/06_ARCHITECTURE_DECISIONS.md`
- `00_CORE_RULES/01_CODING_RULES.md`

### Locally modified rules
Content upstream has never held — genuine local edits.

_none_

### Stale rules (no action needed)
Older upstream releases, superseded by the framework just installed. Listed for
completeness only — nothing to upstream.

- `08_FLOATING_POINT_FORMATTING.md`
- `TESTING.md`
- `PERFORMANCE.md`
- `02_USAGE_EXAMPLES.md`
- `11_NO_HARDCODED_CONSTANTS.md`
- `10_APPLICATION_TESTING_PATTERNS.md`
- `07_SESSION_WORKFLOW.md`

## Next steps

1. Review `project/` and commit it to this repository.
2. Upstream anything listed above that belongs in the framework.
3. Only then remove `development-guidelines.pre-v2/`.
4. The `project-state/*` branch on the development-guidelines remote may be
   deleted only after this repository's commit is pushed.
