# Security policy

This module creates the GitHub Actions OIDC provider and the roles GitHub Actions authenticates as to apply Terraform anywhere in this platform, including this module itself. Treat any concern about it as higher priority than a typical Terraform module bug.

## Supported versions

| Version | Supported |
| --- | --- |
| 1.x | Yes. Security fixes and functional fixes on the latest minor release. |
| 0.1.x | Security fixes only. `sandbox-delivery`, this module's one consumer, is expected to move to 1.x; see [docs/UPGRADE-1.0.md](docs/UPGRADE-1.0.md). |
| Unreleased `main` | Not supported for production use. |

## Reporting a vulnerability

Use GitHub private vulnerability reporting on this repository: open the Security tab and choose "Report a vulnerability". Do not open a public issue, pull request, or discussion for a security problem in this module — an issue here is more sensitive than in most modules, because it can describe how to widen who can authenticate as GitHub Actions for this entire platform.

Include the module version or commit SHA, the inputs that reproduce the problem, the resulting plan, and the impact you see. Redact account IDs, ARNs, and GitHub repository or organization identifiers.

## What counts

- Any change, in a released version or a proposed pull request, that would rename, move, or re-scope a role, a policy, or the OIDC provider that `sandbox-delivery`'s real inputs produce today — this is the specific failure mode `tests/golden_master.tftest.hcl` exists to catch, and a gap in that test is itself a finding.
- A policy statement that grants `iam:*`, `*:*`, or an unscoped `Resource = "*"` on a mutating action without a condition narrowing it — the structural property `tests/policy_shape.tftest.hcl` asserts.
- A trust-policy condition that would let a GitHub Actions run other than the one it names assume a role: an overly broad `sub` claim, a missing `aud` check, or a subject pattern that matches more than the intended pull request, branch, or environment.
- An image-publisher role able to do anything beyond push to its one declared ECR repository: pulling, deleting, or reaching a repository it was not declared for.
- A resource created without `lifecycle { prevent_destroy = true }`, or a change that would let `terraform destroy` remove a resource this module is supposed to protect permanently.
- A default that weakens security: a session duration beyond the platform's 1-hour ceiling, a validation that accepts a value it should reject, an advisory check that fails to fire when it should.
- A dependency problem in the release pipeline that could publish unverified code.

Findings in `sandbox-delivery`'s own configuration choices, or in AWS IAM itself, are out of scope here; report the latter to AWS.

## Response

We acknowledge a report within 2 business days for this module (faster than the platform's other modules, given what it controls) and keep you informed while we confirm, fix, and release. A fix ships as a patch release with a `CHANGELOG.md` entry that credits the reporter unless they ask otherwise. If a report describes an active exposure (a role or policy already granting more than it should in the real account), we prioritize confirming and remediating the live AWS state over publishing a module fix first. Please give us a reasonable window before disclosing publicly.

## Security design

Every resource carries `lifecycle { prevent_destroy = true }`; there is deliberately no way to remove one of this module's resources through Terraform, by design (ADR 0022). A role carries zero permissions of its own — only `attachments.tf` grants anything, so a permission change is reviewable as a policy-document diff independent of any role or trust-policy change. Every image-publisher role can push, never delete, to exactly one declared ECR repository. `tests/policy_shape.tftest.hcl` asserts, for any valid input, that no policy grants a full-service or global wildcard action and that no mutating `iam:` action gets an unscoped resource without a condition. `tests/golden_master.tftest.hcl` pins every role name, policy name, path, trust-policy condition, and decoded policy document to what `sandbox-delivery`'s real inputs produce today, so a regression is caught before it reaches a release. The full reasoning, including what was deliberately not changed and why, is in [docs/DESIGN.md](docs/DESIGN.md), and the description of what every policy actually grants is in the [Security model](README.md#security-model) section of the README.
