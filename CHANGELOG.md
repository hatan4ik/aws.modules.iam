# Changelog

All notable changes to this module are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Consumers pin the commit SHA of a release tag; see [Versioning and releases](README.md#versioning-and-releases).

## [Unreleased]

## [1.0.0] - 2026-09-27

Non-breaking release, in the strictest sense this module can offer: every role name, policy name, role path, trust-policy condition, and decoded policy document is byte-for-byte identical to v0.1.13 for the same inputs, proven in [`tests/golden_master.tftest.hcl`](tests/golden_master.tftest.hcl) against `sandbox-delivery`'s real production inputs and independently re-verified against unmodified v0.1.13. The reasoning is in [docs/DESIGN.md](docs/DESIGN.md); [docs/UPGRADE-1.0.md](docs/UPGRADE-1.0.md) confirms there is nothing to change beyond the version pin.

### Added

- Plan-time validation on `aws_account_id` (12 digits), `aws_region` (AWS-Region-shaped), `role_prefix` (IAM-legal characters), `github_subject_prefix` (`repo:` scheme), `github_oidc_thumbprints` (40-character hex), and every field of `state_backend` (bucket name, key prefix, KMS key UUID, lock table name). `image_publishers`' existing v0.1.13 validation is unchanged.
- `lifecycle.precondition` on the six fixed roles and on each `image_publishers` role, rejecting a `role_prefix` (or `role_prefix` + publisher key) that would push a role name past IAM's 64-character limit, at plan time instead of a raw API error at apply time.
- Advisory `check` blocks: `github_oidc_thumbprints_present` (warns when the thumbprint set is empty) and `oidc_role_session_durations_stay_short` (warns if any role's `max_session_duration` exceeds the platform's 1-hour ceiling).
- `tests/golden_master.tftest.hcl`, `tests/oidc.tftest.hcl`, `tests/preconditions.tftest.hcl`, `tests/validation.tftest.hcl`, `tests/checks.tftest.hcl`, and `tests/policy_shape.tftest.hcl`, covering every role's trust-policy condition, every validation and precondition (including exact boundary values), both checks, and a structural, fixture-independent proof that no policy grants a full-service or global wildcard action or an unscoped mutating `iam:` grant. `tests/sandbox_delivery_iam.tftest.hcl`, the original v0.1.13 suite, is kept unchanged.
- A documentation-only example, [`examples/sandbox-delivery-caller`](examples/sandbox-delivery-caller), showing the real call shape with placeholder values. It is illustrative, not runnable, and is not part of `make check` or the CI matrix; see its README for why.
- `docs/DESIGN.md`, `docs/UPGRADE-1.0.md`, `CONTRIBUTING.md`, `SECURITY.md`, `LICENSE`, the `Makefile` quality gate, pre-commit, tflint, and terraform-docs configuration, Dependabot, issue and pull request templates, and the `module-release` workflow.

### Changed

- `main.tf` (358 lines) is split into `oidc.tf`, `image_publishers.tf`, `delivery_policies.tf`, and `attachments.tf` by concern; `locals.tf` carries the original locals block unchanged. Every one of the 13 original resource addresses is preserved exactly; see the resource-address diff in the pull request that shipped this release. `policies.tf` (the policy documents) and `outputs.tf` are untouched.
- The AWS provider constraint is `>= 6.35.0, < 7.0.0` (was `>= 6.0, < 7.0`).
- CI runs the shared `terraform-quality` workflow over the root, with a docs drift check.

### Removed

- Nothing. No input, output, resource, or resource address was removed or renamed.

### Fixed

- Nothing behavioral. One test-only bug was found and fixed during this release's own development: comparing `keys()` of a `for_each` resource against a `tolist([...])` literal with `==` spuriously evaluated `false` in `tests/oidc.tftest.hcl` even when both sides were byte-identical under `jsonencode()`; the assertion now uses `toset()`, which is also the semantically correct comparison for an unordered `for_each` key set.

## Before this changelog (v0.1.0 – v0.1.13)

This file starts at 1.0.0. Releases v0.1.0 through v0.1.13 predate it; see each tag's own commit message and `git log v0.1.0..v0.1.13` for that history. v1.0.0 branches from v0.1.13 (commit `b4b40a9640cf464691b8d0c88a2ca5c2aa587bb4`), the version this module's one live consumer, `sandbox-delivery`, is pinned to today.

[Unreleased]: https://github.com/hatan4ik/aws.modules.iam/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/hatan4ik/aws.modules.iam/compare/v0.1.13...v1.0.0
[0.1.13]: https://github.com/hatan4ik/aws.modules.iam/releases/tag/v0.1.13
