# Design: aws.modules.iam v1

Status: accepted 2026-09-27.

## Purpose

`aws.modules.iam` is the sandbox platform's own delivery identity. One module
call creates:

- the GitHub Actions OIDC provider (`aws_iam_openid_connect_provider.github_actions`);
- six fixed, environment-scoped GitHub Actions roles (`plan`, `dev_apply`,
  `staging_apply`, `prod_apply`, `drift`, `landing_zone`);
- opt-in, per-repository image-publisher roles that can push only to one
  declared ECR repository each;
- the reviewed delivery policies for `sandbox-network`, `sandbox-platform`,
  `sandbox-workload`, and this module's own root, `identity`; and
- the attachments that wire each policy to the role that needs it.

It is consumed today by exactly one caller,
`devops-aws-infra/infra/active/roots/sandbox-delivery/us-east-2/global`,
pinned at `v0.1.13` (commit `b4b40a9640cf464691b8d0c88a2ca5c2aa587bb4`), the
commit this v1.0.0 release branches from. That
root's own `apply` role is one of the six roles this module creates: GitHub
Actions authenticates to every other root in the platform, including this
one, through credentials this module issues. The OIDC provider, the six
fixed roles, the eight delivery policies, and the twelve attachments carry
`lifecycle { prevent_destroy = true }` by design (the opt-in image-publisher
roles and their inline policies deliberately do not; see Security defaults) (see README's Security
model and ADR 0022); there is no console-change escape hatch if a bad change
ships.

## Why v1 exists, and why it looks unlike every other v1 uplift in this series

Every other `aws.modules.*` v1 uplift in this session (`acm`, `s3`, `vpc`,
`ecs-service`, and the rest) treated "v1" as license to fix real problems in
the v0.1.x interface: rename an input, restructure an output, change a
default. This module cannot do that. A rename here is not a Terraform
refactor with a `moved` block; it is a delete-and-recreate of a role or
policy that GitHub Actions authenticates with **right now**, for every root
in the platform, including the one root that could fix a bad apply. ADR 0022
records that consequence as accepted and irreversible by design: there is no
break-glass path around this module.

So v1.0.0 of `aws.modules.iam` asks a narrower question than every sibling
module: *what can be improved without moving, renaming, or re-scoping a
single real-world IAM identity?* The answer, worked out resource by
resource, is: file organization, plan-time validation, advisory checks, and
test depth. Nothing about what GitHub Actions can authenticate as, or what
any policy grants, changes at all. That is deliberate, and it is the
headline feature of this release, not a limitation of it.

## What changed

- **File organization.** `main.tf` (358 lines, every concern mixed together)
  is split into `oidc.tf` (the OIDC provider and the six fixed roles),
  `image_publishers.tf` (the opt-in per-repository roles), `delivery_policies.tf`
  (the eight `aws_iam_policy` resources; the policy *documents* stay in
  `policies.tf`, untouched), and `attachments.tf` (the twelve
  `aws_iam_role_policy_attachment` resources). `locals.tf` carries the
  original locals block byte-for-byte. Every one of the 13 original resource
  addresses (`resource "type" "label"`, not instance) is unchanged; see
  the resource-address diff in the pull request description, produced by
  comparing against `git show main:main.tf` at the commit this branch
  started from.
- **Two new `lifecycle.precondition` blocks** (in `oidc.tf` and
  `image_publishers.tf`) that reject a `role_prefix` (or, for a publisher, a
  `role_prefix` + `image_publishers` key) that would push a role name past
  IAM's 64-character limit. Every value used by `sandbox-delivery` today is
  well under the limit, so this changes no name for any input in production
  use; it turns a raw AWS API error at apply time into a plan-time message
  for a caller who would have hit it.
- **Five new variable validations** (`aws_account_id`, `aws_region`,
  `role_prefix`, `github_subject_prefix`, `github_oidc_thumbprints`, and all
  four fields of `state_backend`) that reject syntactically invalid shapes.
  `image_publishers`' existing v0.1.13 validation is unchanged. Every new
  validation is proven against `sandbox-delivery`'s real, current inputs in
  `tests/validation.tftest.hcl`'s first run, so v1.0.0 never rejects what
  v0.1.13 accepts.
- **Advisory `check` blocks** (`checks.tf`): v1.0.0 shipped two, warning
  when `github_oidc_thumbprints` is empty and when any role's
  `max_session_duration` exceeds the platform's 1-hour ceiling. The second
  was dead: `max_session_duration` is a literal `3600` in `oidc.tf` and
  `image_publishers.tf`, not an input, so no caller could ever make it fire,
  and it never had a firing test case. It has since been removed (see
  CHANGELOG.md); `tests/oidc.tftest.hcl` asserts the literal directly for
  both role kinds. `github_oidc_thumbprints_present` remains, with a firing
  and a non-firing case.
- **Deepened tests**: from one 163-line file
  (`tests/sandbox_delivery_iam.tftest.hcl`, kept unchanged and still passing)
  to seven files covering every role's trust-policy condition, every new
  validation with both an accepting and a rejecting case, both new
  preconditions at and past their exact boundary, the thumbprint check with
  a firing and a non-firing case, and a structural, fixture-independent proof
  (`tests/policy_shape.tftest.hcl`) that no rendered policy grants a
  full-service or global wildcard action, and that no mutating `iam:` action
  ever gets an unscoped `Resource = "*"` without a `Condition` narrowing it.
  Centerpiece: `tests/golden_master.tftest.hcl`, built from
  `sandbox-delivery`'s real production inputs, asserting every role name,
  policy name, path, trust-policy condition, and decoded policy document is
  byte-for-byte what v0.1.13 produces for those same inputs. It was
  independently re-run against unmodified v0.1.13 (not just inherited as a
  claim) and passes there too.
- **`policies.tf` is untouched.** The option to extract its `jsonencode()`
  locals into a standalone policy-document-renderer submodule (as `state`
  did) was considered and declined for v1: it would need the same
  byte-identical proof this release already does for the golden master, for
  no behavioral benefit today. It remains available for a future release if
  a second policy-rendering consumer ever justifies it.

## What did not change, and why

Every resource's real-world identity is exactly what v0.1.13 produces for
the same inputs:

- Role names, paths (`/github-actions/`), and trust-policy conditions for
  all six fixed roles and every image-publisher role.
- Policy names and every decoded policy document (Sids, actions, resources,
  conditions) for all eight delivery policies.
- The OIDC provider's URL, audience, thumbprint list, and tags.
- Every `for_each` key set (`local.github_roles`, `var.image_publishers`,
  `local.role_policy_attachments`) and every resource's Terraform address.
- The `depends_on = [aws_iam_policy.identity_dev_apply]` on
  `sandbox_workload_plan` and `sandbox_workload_dev_apply`, kept exactly as
  in v0.1.13. `depends_on` affects only apply ordering, not any name, path,
  or policy value, so removing it would technically satisfy this release's
  freeze criteria — but doing so safely needs a live `terraform plan` against
  the real `sandbox-delivery` state showing no unexpected diff, which this
  offline PR cannot produce. It is left alone rather than guessed at; see
  "Deferred to v2" below.

This is confirmed three ways, all independently reproducible from the PR
alone: the resource-address diff, the golden-master test run against both
this branch and unmodified v0.1.13, and a direct `diff` of `variables.tf`
against `git show main:variables.tf` showing only new `validation` blocks
added, with no variable removed, retyped, or given a new default.

## Deferred to v2 (requires a live migration)

Everything below is a genuine, real improvement that this release
deliberately does **not** make, because making it would rename, move, or
re-scope a real, in-use IAM identity, or would need real-world coordination
(a new GitHub environment, a live plan against production state) that an
offline PR cannot provide or verify. Each entry is proven frozen today by
`tests/golden_master.tftest.hcl`, so nobody "cleans it up" by accident in a
future PR without that test failing first and this section being updated
deliberately alongside the migration.

- **The "sandbox-sandbox" naming stutter.** `role_prefix` is
  `devops-aws-infra-sandbox`, and four of the eight policy names
  (`sandbox_network_plan`, `sandbox_network_dev_apply`,
  `sandbox_platform_plan`, `sandbox_platform_dev_apply`, and the two
  workload policies) prepend a second, literal `sandbox-` segment from
  `local.policy_names`, producing names like
  `devops-aws-infra-sandbox-sandbox-network-plan`. This is real, deployed,
  and asserted verbatim by `tests/golden_master.tftest.hcl`'s
  `delivery_policy_names` run specifically so nobody "fixes" the stutter by
  editing `local.policy_names` without realizing it renames four live
  policies. A v2 migration would need `moved` blocks (policies do not
  support `moved` for a name change; it would need
  `terraform state mv` or an import/re-attach) and a plan verified against
  the real `sandbox-delivery` state before it ships.
- **The `drift` role reuses `dev_apply`'s exact trust-policy subject**
  (`environment:dev`), not a dedicated `drift` GitHub environment, even
  though a `landing_zone`-style dedicated environment exists for every other
  role. This is current, intentional behavior (there is no separate `drift`
  environment configured in GitHub today), not an oversight, and is pinned
  by `tests/golden_master.tftest.hcl`. Splitting it out is a genuine
  hardening (narrower blast radius for the read-only drift workflow) but
  requires creating and protecting a new GitHub environment first and
  updating the trust condition in the same coordinated change; changing the
  condition alone, without that GitHub-side setup, would just break the
  drift workflow's credentials.
- **The `sandbox_workload_plan`/`sandbox_workload_dev_apply` → `identity_dev_apply`
  `depends_on`.** Added when the workload policies were first introduced
  (v0.1.13's history), because `identity_dev_apply` needed `iam:CreatePolicy`
  before Terraform could create them. Now that both policies exist in the
  real account, the `depends_on` may no longer be load-bearing — but
  confirming that needs a live plan against production state showing the
  removal produces no diff and no ordering error, which is exactly the kind
  of check this offline PR is not positioned to make safely. Left in place.
- **A policy-document-renderer submodule for `policies.tf`.** Available, not
  attempted (see "What changed" above); would need its own byte-identical
  proof the same way this release's golden master proves the root.
- **A `check` warning when an `image_publishers` entry pushes to a
  repository owned by a different root than the caller declares.** The brief
  for this release names this as an example of a useful advisory check, but
  implementing it would need a new input surfacing which root owns which
  repository name prefix — an interface this module does not have today.
  Adding that input is possible without breaking anything (a new optional
  variable is additive), but deciding its shape deserves its own review
  rather than a guess folded into an already-sensitive release. Not
  implemented; flagged here as an open question for a future minor release.

## Architecture

```text
root (one call = the whole sandbox delivery identity)
├── locals.tf             Unmodified from v0.1.13: ARNs, role/policy name maps, attachment map.
├── oidc.tf                aws_iam_openid_connect_provider.github_actions,
│                          aws_iam_role.github_actions[6 fixed roles], role-name-length precondition.
├── image_publishers.tf    aws_iam_role.image_publisher[opt-in], aws_iam_role_policy.image_publisher,
│                          role-name-length precondition.
├── delivery_policies.tf   aws_iam_policy.{sandbox_network,sandbox_platform,sandbox_workload}_{plan,dev_apply},
│                          aws_iam_policy.identity_{plan,dev_apply}. Documents rendered in policies.tf.
├── policies.tf            Every policy's jsonencode() document.
├── attachments.tf         aws_iam_role_policy_attachment.delivery[12 pairs]. The only file that grants
│                          permission: every role and policy exists with zero effect until attached here.
├── checks.tf              Advisory check: github_oidc_thumbprints_present.
└── outputs.tf              policy_arns, role_arns, image_publisher_role_arns,
                            github_oidc_provider_arn.
```

Data flow is unchanged from v0.1.13: `locals.tf` derives every real-world
name and ARN from `var.role_prefix`, `var.aws_account_id`,
`var.aws_region`, the AWS partition, and `var.state_backend`; `oidc.tf` and
`image_publishers.tf` create roles with zero permissions; `policies.tf`
renders the reviewed documents; `delivery_policies.tf` wraps them as
`aws_iam_policy` resources; `attachments.tf` is the only file that connects
a role to a policy. A caller changes what a role can do only by changing
`policies.tf`'s inputs (state backend, account, region) or by reviewing and
merging a change to the policy documents themselves — never by touching a
role's name, path, or trust condition, which this module does not expose as
an input at all.

## Security defaults (unchanged from v0.1.13)

- `lifecycle { prevent_destroy = true }` is on the OIDC provider
  (`oidc.tf`), the six fixed roles (`oidc.tf`), the eight delivery policies
  (`delivery_policies.tf`), and the twelve attachments (`attachments.tf`).
  This cannot be asserted by `terraform test`, which does not see
  `lifecycle` blocks; a reviewer confirms it directly in those files.
- The opt-in image-publisher roles (`aws_iam_role.image_publisher`) and
  their inline policies (`aws_iam_role_policy.image_publisher`) in
  `image_publishers.tf` deliberately do **not** carry `prevent_destroy`:
  removing an `image_publishers` entry is meant to delete that publisher's
  role, and no delivery pipeline authenticates through it.
- A role carries zero permissions on its own; only `attachments.tf` grants
  anything, so a permission change is reviewable as a policy-document diff
  independent of role or trust-policy changes.
- Every image-publisher role can push (not delete) images to exactly one
  declared ECR repository; `ecr:GetAuthorizationToken` is the only
  `Resource = "*"` grant, which ECR requires (the action has no
  resource-level permission).
- `tests/policy_shape.tftest.hcl` asserts structurally, for any valid input,
  that no policy grants a full-service or global wildcard action and that no
  mutating `iam:` action gets an unscoped resource without a condition.

## Testing strategy

- Contract tests use `mock_provider` with `command = plan`; no credentials,
  no real AWS calls, ever.
- `tests/golden_master.tftest.hcl` uses `sandbox-delivery`'s real production
  inputs and is the release gate: any difference from what v0.1.13 renders
  for the same inputs is a stop-and-revert signal, not something to update.
- `tests/oidc.tftest.hcl`, `tests/preconditions.tftest.hcl`,
  `tests/validation.tftest.hcl`, and `tests/checks.tftest.hcl` use generic,
  non-production inputs to prove the same rules hold for any valid caller,
  not just the one real one.
- `tests/policy_shape.tftest.hcl` is fixture-independent by design: it holds
  for any input, so a future policy change is caught here regardless of
  which caller happens to be exercised elsewhere.
- `tests/sandbox_delivery_iam.tftest.hcl`, the original v0.1.13 suite, is
  kept unchanged and still passes; it is not removed because it is real,
  valid, additional regression coverage, even though
  `tests/golden_master.tftest.hcl` now subsumes most of what it checks.
- No integration suite. This module has no safe way to create a disposable
  copy of itself: a second OIDC provider or a second set of delivery roles
  is exactly the kind of uncontrolled IAM sprawl this module exists to
  prevent, and the core resources' `prevent_destroy` means a mistaken apply
  cannot be cleaned up by `terraform destroy` either. See README's Testing
  section for the full reasoning and what would need to be true before one
  could be added.

## Compatibility

- Terraform `>= 1.7.0, < 2.0.0`. AWS provider `>= 6.35.0, < 7.0.0`.
- The v1 interface is not just stable, it is frozen: every input, output,
  resource address, and real-world identity is identical to v0.1.13. See
  `docs/UPGRADE-1.0.md`.
