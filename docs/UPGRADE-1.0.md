# Upgrading from 0.1.x to 1.0.0

## What changed and why

Nothing about what this module creates in your AWS account changes. Every
role name, role path, policy name, decoded policy document, and the OIDC
provider's URL, audience, and thumbprint list are identical to v0.1.13 for
the same inputs — proven mechanically in
[`tests/golden_master.tftest.hcl`](../tests/golden_master.tftest.hcl) using
`sandbox-delivery`'s real production inputs, run against both this release
and unmodified v0.1.13. The reasoning for why this release is this
conservative, and everything that was considered and deliberately not done,
is in [DESIGN.md](DESIGN.md).

What v1.0.0 actually adds: `main.tf` is split into focused files by concern,
five variables gained plan-time validation (`aws_account_id`, `aws_region`,
`role_prefix`, `github_subject_prefix`, `github_oidc_thumbprints`, and every
field of `state_backend`), two new `lifecycle.precondition` blocks catch an
over-length role name before it reaches the AWS API, two advisory `check`
blocks warn about an empty thumbprint set or an unusually long session
duration, and the test suite grew from one 163-line file to seven covering
every role, every validation, every precondition boundary, both checks, and
a structural proof that no policy ever grants a wildcard or unscoped
mutating IAM permission.

## Input and output mapping

There is no mapping to give, because nothing was renamed, retyped, given a
new default, or removed. Every input (`aws_account_id`, `aws_region`,
`role_prefix`, `github_subject_prefix`, `github_oidc_thumbprints`,
`image_publishers`, `state_backend`) and every output (`policy_arns`,
`role_arns`, `image_publisher_role_arns`, `github_oidc_provider_arn`) means
exactly what it meant in v0.1.13, with the same type, the same default where
one exists, and the same shape. `image_publishers`' own v0.1.13 validation
(key shape, subject shape, repository name shape) is unchanged; five new
validations were added elsewhere, and every one of them accepts
`sandbox-delivery`'s real, currently-deployed inputs unmodified — proven in
`tests/validation.tftest.hcl`'s first run.

Your existing module call needs no changes beyond the version pin:

```hcl
# 0.1.13
module "sandbox_delivery_iam" {
  source = "git::https://github.com/hatan4ik/aws.modules.iam.git?ref=b4b40a9640cf464691b8d0c88a2ca5c2aa587bb4" # v0.1.13

  aws_account_id          = var.aws_account_id
  aws_region              = var.aws_region
  role_prefix             = var.role_prefix
  github_subject_prefix   = var.github_subject_prefix
  github_oidc_thumbprints = var.github_oidc_thumbprints
  image_publishers        = var.image_publishers
  state_backend           = var.state_backend
}

# 1.0.0
module "sandbox_delivery_iam" {
  source = "git::https://github.com/hatan4ik/aws.modules.iam.git?ref=<commit-sha>" # v1.0.0

  aws_account_id          = var.aws_account_id
  aws_region              = var.aws_region
  role_prefix             = var.role_prefix
  github_subject_prefix   = var.github_subject_prefix
  github_oidc_thumbprints = var.github_oidc_thumbprints
  image_publishers        = var.image_publishers
  state_backend           = var.state_backend
}
```

## Preserving existing resources

There is nothing to preserve, because there is nothing that moves, renames,
or replaces. Every resource address is identical (see the table below), and
every real-world identity — role names, policy names, paths, trust-policy
conditions, and decoded policy documents — is identical for the same
inputs. `terraform plan` against your real state after bumping the version
pin should show **no changes at all**. If it shows anything other than "No
changes", stop and compare your actual inputs against
`tests/golden_master.tftest.hcl`'s `variables` block before applying:
something in your call differs from what this release was proven against.

## State addresses

Unchanged, for a consumer block named `module.sandbox_delivery_iam`:

| 0.1.13 address | 1.0.0 address |
| --- | --- |
| `module.sandbox_delivery_iam.aws_iam_openid_connect_provider.github_actions` | unchanged |
| `module.sandbox_delivery_iam.aws_iam_role.github_actions["<key>"]` (6 keys) | unchanged |
| `module.sandbox_delivery_iam.aws_iam_role.image_publisher["<key>"]` | unchanged |
| `module.sandbox_delivery_iam.aws_iam_role_policy.image_publisher["<key>"]` | unchanged |
| `module.sandbox_delivery_iam.aws_iam_policy.sandbox_network_plan` | unchanged |
| `module.sandbox_delivery_iam.aws_iam_policy.sandbox_network_dev_apply` | unchanged |
| `module.sandbox_delivery_iam.aws_iam_policy.sandbox_platform_plan` | unchanged |
| `module.sandbox_delivery_iam.aws_iam_policy.sandbox_platform_dev_apply` | unchanged |
| `module.sandbox_delivery_iam.aws_iam_policy.sandbox_workload_plan` | unchanged |
| `module.sandbox_delivery_iam.aws_iam_policy.sandbox_workload_dev_apply` | unchanged |
| `module.sandbox_delivery_iam.aws_iam_policy.identity_plan` | unchanged |
| `module.sandbox_delivery_iam.aws_iam_policy.identity_dev_apply` | unchanged |
| `module.sandbox_delivery_iam.aws_iam_role_policy_attachment.delivery["<key>"]` (12 keys) | unchanged |

No `moved` block is needed anywhere, because nothing moved. The full
resource-address diff against v0.1.13's `main.tf` is in the pull request
description that shipped this release.

## Procedure

1. Pin the 1.0.0 release: copy the commit SHA of tag `v1.0.0` into
   `?ref=<commit-sha>` and keep the tag in a trailing comment.
2. Run `terraform init -upgrade` to fetch the new module source, then
   `terraform plan`.
3. Verify the plan shows **no changes**. This is the one release in this
   module's history where anything else is a bug in the release, not
   something for you to work around: open an issue with the plan output
   (redact account IDs and ARNs) rather than applying it.
4. Apply. There is nothing to apply, by design.

## Looking ahead

`DESIGN.md`'s "Deferred to v2" section lists every genuine improvement this
release considered and declined because it would rename, move, or re-scope
a real identity, or needs coordination this module's interface alone cannot
provide (a new GitHub environment, a live plan against production state).
None of it is silently planned; each entry explains what a future migration
would need. Nothing here is scheduled, and nothing changes for you until a
future major version says so explicitly, with its own upgrade guide.
