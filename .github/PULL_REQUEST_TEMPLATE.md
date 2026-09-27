## Summary

<!-- What changes and why. Link the issue this closes, if any. -->

## Type of change

- [ ] fix: bug fix, non-breaking
- [ ] feat: new input, output, or behaviour, non-breaking
- [ ] breaking: existing callers must change configuration or state
- [ ] docs: documentation only
- [ ] chore: tooling, CI, or dependencies

## Checklist

- [ ] `tests/golden_master.tftest.hcl` passes and no existing assertion's expected value changed (only new `run` blocks may be added, for a resource this PR adds)
- [ ] Tests added or updated, and `terraform test` passes
- [ ] `make check` passes locally
- [ ] Docs regenerated with terraform-docs (`make docs`)
- [ ] `CHANGELOG.md` `Unreleased` section updated
- [ ] No data sources added beyond `data.aws_partition.current`
- [ ] Any real improvement this PR could not safely make is recorded under "Deferred to v2" in `docs/DESIGN.md`, not implemented
- [ ] Breaking changes (a live migration of a real role or policy) documented in `docs/UPGRADE-<version>.md` and reviewed as a coordinated migration, not merged as a normal change
