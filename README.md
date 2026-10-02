# aws.modules.iam

The sandbox platform's own delivery identity: one module call creates the GitHub Actions OIDC provider, six fixed environment-scoped roles (`plan`, `dev_apply`, `staging_apply`, `prod_apply`, `drift`, `landing_zone`), opt-in per-repository image-publisher roles, and the reviewed delivery policies (and their attachments) for `sandbox-network`, `sandbox-platform`, `sandbox-workload`, and this module's own root, `identity`. It is consumed today by exactly one caller, `sandbox-delivery`, whose own `apply` role is one of the roles this module creates: GitHub Actions authenticates to every root in this platform, including this one, through credentials this module issues. Requires Terraform >= 1.7 and the AWS provider >= 6.35, < 7.

> **Frozen interface, by design.** The OIDC provider, the six fixed roles, the eight delivery policies, and their attachments all carry `lifecycle { prevent_destroy = true }` (the opt-in image-publisher roles deliberately do not; see Durability below), and there is no console-change escape hatch if a bad change ships (ADR 0022). Because of that, v1.0.0's interface is not just stable, it is **byte-for-byte frozen**: every role name, policy name, role path, trust-policy condition, and decoded policy document is identical to v0.1.13 for the same inputs, proven mechanically in [`tests/golden_master.tftest.hcl`](tests/golden_master.tftest.hcl) against `sandbox-delivery`'s real production inputs. If you are looking for the module that lets you rename or restructure things freely, this is not it — see [docs/DESIGN.md](docs/DESIGN.md) for the full reasoning and everything considered and deliberately not done.

## Why this module

- **One trust anchor, six roles, zero permissions of their own.** `aws_iam_openid_connect_provider.github_actions` is the only OIDC provider GitHub Actions authenticates against; the six fixed roles each have a distinct trust-policy condition (a specific GitHub environment, or a pull-request/push-to-main pair for `plan`) and carry no permissions until [`attachments.tf`](attachments.tf) wires a reviewed policy to them. A permission change is reviewable as a policy-document diff, independent of any role or trust-policy change.
- **Image-publisher roles scoped to exactly one repository.** Each `image_publishers` entry gets a dedicated role that can push (never delete) images to exactly the one ECR repository it names, plus the unscoped `ecr:GetAuthorizationToken` ECR itself requires.
- **Eight reviewed delivery policies**, one read-only `plan` and one create/update/delete `dev_apply` policy per consuming root (`sandbox-network`, `sandbox-platform`, `sandbox-workload`), plus this module's own `identity_plan`/`identity_dev_apply` pair that lets Terraform manage the other seven policies' versions and the role attachments, bounded to exactly the tracked policy ARNs.
- **Structurally provable safety.** [`tests/policy_shape.tftest.hcl`](tests/policy_shape.tftest.hcl) asserts, for any valid input, that no rendered policy grants a full-service or global wildcard action (`iam:*`, `*:*`) and that no mutating `iam:` action ever gets an unscoped `Resource = "*"` without a `Condition` narrowing it.
- **Plan-time validation of every input**: account ID shape, Region shape, IAM-legal characters in `role_prefix`, the GitHub OIDC subject scheme, thumbprint format, and every field of the dedicated `state_backend`. Two `lifecycle.precondition` blocks catch a role name that would exceed IAM's 64-character limit before it reaches the API.
- **An advisory check that never blocks a real run**: a warning if `github_oidc_thumbprints` is empty. Every role's 1-hour `max_session_duration` is a literal, not an input, and is pinned by tests rather than by a check that could never fire.
- **Zero data sources beyond the AWS partition.** Every account-qualified ARN is derived from the supplied account, Region, partition, and names; callers never repeat an account ID inside a policy document.

## The one real caller

This module has exactly one consumer today, and is built to have exactly one: `devops-aws-infra/infra/active/roots/sandbox-delivery/us-east-2/global`, pinned at `v0.1.13` before this release (commit `b4b40a9640cf464691b8d0c88a2ca5c2aa587bb4`). [`examples/sandbox-delivery-caller`](examples/sandbox-delivery-caller) shows that root's exact call shape with every real value replaced by a placeholder. **It is documentation, not a runnable example** — read its README for why a second, disposable caller of this module is not a smaller version of the real thing, but a second, uncoordinated source of truth for who can authenticate as GitHub Actions.

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

A caller changes what a role can do only by changing `policies.tf`'s inputs (state backend, account, Region) or by reviewing and merging a change to the policy documents themselves — never by touching a role's name, path, or trust condition, none of which this module exposes as an input. The full data-flow description and every design decision behind it are in [docs/DESIGN.md](docs/DESIGN.md).

## Security model

Identity

- The OIDC provider trusts exactly `token.actions.githubusercontent.com` for the `sts.amazonaws.com` audience, with the thumbprint list you declare. Six fixed roles each require a distinct GitHub Actions `sub` claim: `plan` accepts a pull request or a push to `main`; every other role accepts exactly one GitHub environment. A role has no permissions of its own — see "Permissions" below.
- Every image-publisher role's trust condition is scoped to the exact `github_subject` declared for it, and the variable's own validation requires that subject to name the `dev` environment specifically.

Permissions

- Delivery policies are split into a read-only `plan` policy (state read only — no `s3:PutObject` — plus lock-table item access pinned by `dynamodb:LeadingKeys` to that root's own lock keys, plus narrow `Describe`/`Get`/`List` reads) and a `dev_apply` policy (the same, plus exactly the create/update/delete actions each root needs, most of them resource-scoped to that root's own state prefix, KMS alias, log group, or role path).
- The `identity_dev_apply` policy — the one that lets Terraform manage this module's own resources — is itself bounded: it may create policy versions only for the policies this module tracks (`values(local.policy_arns)`), attach or detach only this module's own tracked policies (an `ArnEquals` `iam:PolicyARN` condition) on the six fixed roles, rewrite the trust policy of only the `plan`, `dev_apply`, and `drift` roles (never `staging_apply`, `prod_apply`, or `landing_zone`), and manage the OIDC provider's client ID list and thumbprint, never anything broader.
- `tests/policy_shape.tftest.hcl` asserts structurally, for any valid input, that no statement grants `iam:*`, `*:*`, or an unscoped `Resource = "*"` on a mutating `iam:` action without a `Condition`. The few non-IAM statements that use `Resource = "*"` (for example EC2 security-group management, which AWS gives no resource-level permission for) are pre-existing, frozen behavior, not something this test flags.

Durability

- `lifecycle { prevent_destroy = true }` is on the OIDC provider, the six fixed roles, the eight delivery policies, and the twelve attachments. The opt-in image-publisher roles (`aws_iam_role.image_publisher`) and their inline policies (`aws_iam_role_policy.image_publisher`) deliberately do not carry it: removing an `image_publishers` entry is supposed to delete that publisher's role, and nothing else in the platform authenticates through it. `terraform test` cannot see a `lifecycle` block, so this is confirmed by reading the diff directly, not by a test assertion; see [CONTRIBUTING.md](CONTRIBUTING.md).
- There is deliberately no integration suite: this module has no safe way to create a disposable copy of itself, and `prevent_destroy` means a mistaken apply cannot be cleaned up by `terraform destroy` either. See "Testing" below.

Not created here

- The GitHub environments themselves (protection rules, required reviewers, the `dev`/`staging`/`prod`/`landing-zone` environment names the trust conditions reference) and the repository that dispatches the workflows. Those are configured in GitHub, outside Terraform, and are a prerequisite this module assumes rather than manages.

## Lifecycle notes

- Nothing here is designed to change often. A role's trust condition, name, or path is not exposed as an input at all; the only inputs that shape identity are `role_prefix`, `github_subject_prefix`, `github_oidc_thumbprints`, and `image_publishers`, and every one of them is validated at plan time.
- `github_oidc_thumbprints` accepts more than one entry specifically to support a rotation window: add the new thumbprint, apply, confirm, then remove the old one in a second apply.
- `depends_on = [aws_iam_policy.identity_dev_apply]` on the two workload delivery policies is unchanged from v0.1.13, kept for the bootstrap ordering it was written for; see docs/DESIGN.md's "Deferred to v2" for why it was not removed even though it looks safe to.
- One advisory `check` block warns without blocking: `github_oidc_thumbprints_present`. (v1.0.0 also shipped `oidc_role_session_durations_stay_short`; it was removed because `max_session_duration` is a literal 3600, so it could never fire. `tests/oidc.tftest.hcl` pins the literal for both role kinds instead.)

## Testing

Contract tests only, deliberately. There is no integration suite:

- **`tests/golden_master.tftest.hcl`** is the release gate. Built from `sandbox-delivery`'s real production `terraform.tfvars`, it asserts every role name, policy name, path, trust-policy condition, and decoded policy document is byte-for-byte what v0.1.13 produces for those same inputs. Any difference is a stop-and-revert signal.
- **`tests/oidc.tftest.hcl`, `tests/preconditions.tftest.hcl`, `tests/validation.tftest.hcl`, `tests/checks.tftest.hcl`** use generic, non-production inputs to prove the same rules hold for any valid caller, including every validation's accept and reject case and both preconditions at their exact 64-character boundary.
- **`tests/policy_shape.tftest.hcl`** is fixture-independent: it holds for any input, so a future policy change is caught here regardless of which caller is exercised elsewhere.
- **`tests/sandbox_delivery_iam.tftest.hcl`** is the original v0.1.13 suite, kept unchanged and still passing.
- **No `tests/integration/`.** A "disposable" second OIDC provider or delivery role is exactly the kind of uncontrolled IAM sprawl this module exists to prevent, and `prevent_destroy` means a mistaken apply cannot be torn down afterward either. See [CONTRIBUTING.md](CONTRIBUTING.md) for what would need to be true before proposing one.

## Design principles

- Single responsibility, split by file: `oidc.tf` (trust anchor and fixed roles), `image_publishers.tf` (opt-in roles), `delivery_policies.tf` and `policies.tf` (reviewed grants), `attachments.tf` (the only file that grants permission), `checks.tf` (advisory warnings).
- Secure by default: zero permissions on a role until attached, push-only single-repository ECR grants, a 1-hour session ceiling, and a structural test that no policy ever reaches for a wildcard.
- Open for genuinely safe extension (a new `image_publishers` entry, a new advisory check), closed for anything that would rename, move, or re-scope an existing identity — enforced by the golden-master test, not just documented.
- No data sources beyond `data.aws_partition.current`; every account-qualified value comes from caller input.

The full rationale, including everything considered and deliberately deferred, is in [docs/DESIGN.md](docs/DESIGN.md).

## Compatibility and scope

- Terraform `>= 1.7.0, < 2.0.0`. AWS provider `>= 6.35.0, < 7.0.0`.
- One module call manages the whole sandbox delivery identity: the OIDC provider, the six fixed roles, opt-in image-publisher roles, and the delivery policies for `sandbox-network`, `sandbox-platform`, `sandbox-workload`, and this module's own root.
- The v1 interface is frozen, not just stable: nothing in it is scheduled to change without a coordinated, reviewed migration. See `docs/DESIGN.md`'s "Deferred to v2" for what that would take.

## Versioning and releases

Releases follow semantic versioning: incompatible interface changes bump the major version, new optional inputs and outputs bump the minor version, fixes bump the patch version. For this module specifically, a major version is also the only place a live-migration change (a role or policy rename) may ever ship, and only with a reviewed migration plan alongside it. Every release is a signed annotated tag `vX.Y.Z`.

Pin the full commit SHA of the release tag and record the tag in a comment, so the source cannot move under you:

```hcl
module "sandbox_delivery_iam" {
  source = "git::https://github.com/hatan4ik/aws.modules.iam.git?ref=<commit-sha>" # v1.0.0
}
```

The `module-release` workflow publishes an immutable GitHub release only from a GitHub-verified, signed, annotated semantic-version tag that points at the merged `main` revision; lightweight or unsigned tags are rejected before anything is published. With a GitHub-associated GPG or SSH signing key configured:

```bash
git fetch origin
git tag -s vX.Y.Z <commit> -m "vX.Y.Z"
git push origin vX.Y.Z
gh workflow run module-release.yml --ref vX.Y.Z -f release_tag=vX.Y.Z
```

Dispatch from the tag, never from `main`.

Upgrading from 0.1.x: read [docs/UPGRADE-1.0.md](docs/UPGRADE-1.0.md) — there is nothing to change beyond the version pin, and a `terraform plan` after bumping it should show no changes at all. All changes are listed in [CHANGELOG.md](CHANGELOG.md).

## Contributing

Development setup, the local quality gate, the test-first workflow (golden master first, for this module), and the release process are described in [CONTRIBUTING.md](CONTRIBUTING.md). Security reports go through [SECURITY.md](SECURITY.md) — this module controls who can authenticate as GitHub Actions in this platform, so a concern here is higher priority than a typical module bug.

## License

Apache-2.0. See [LICENSE](LICENSE).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.35.0, < 7.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.35.0, < 7.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_openid_connect_provider.github_actions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_policy.identity_dev_apply](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.identity_plan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.sandbox_network_dev_apply](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.sandbox_network_plan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.sandbox_platform_dev_apply](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.sandbox_platform_plan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.sandbox_workload_dev_apply](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.sandbox_workload_plan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.github_actions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.image_publisher](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.image_publisher](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.delivery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_account_id"></a> [aws\_account\_id](#input\_aws\_account\_id) | AWS account that owns the existing sandbox GitHub OIDC roles and delivery policies. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Region containing the sandbox delivery Terraform state backend. | `string` | n/a | yes |
| <a name="input_github_oidc_thumbprints"></a> [github\_oidc\_thumbprints](#input\_github\_oidc\_thumbprints) | Current approved SHA-1 thumbprints for GitHub's OIDC provider. | `set(string)` | n/a | yes |
| <a name="input_github_subject_prefix"></a> [github\_subject\_prefix](#input\_github\_subject\_prefix) | Immutable GitHub OIDC repository subject prefix, without the pull-request/ref/environment suffix. | `string` | n/a | yes |
| <a name="input_image_publishers"></a> [image\_publishers](#input\_image\_publishers) | Dedicated GitHub OIDC image-publisher roles. Each role can push only immutable images to its declared ECR repository. | <pre>map(object({<br/>    github_subject  = string<br/>    repository_name = string<br/>  }))</pre> | `{}` | no |
| <a name="input_role_prefix"></a> [role\_prefix](#input\_role\_prefix) | Existing GitHub OIDC role-name prefix created by the one-time trust bootstrap. | `string` | n/a | yes |
| <a name="input_state_backend"></a> [state\_backend](#input\_state\_backend) | Non-secret, dedicated remote-state configuration for the sandbox delivery IAM root. | <pre>object({<br/>    bucket_name     = string<br/>    key_prefix      = string<br/>    kms_key_id      = string<br/>    lock_table_name = string<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_github_oidc_provider_arn"></a> [github\_oidc\_provider\_arn](#output\_github\_oidc\_provider\_arn) | Terraform-owned GitHub Actions OIDC provider ARN. |
| <a name="output_image_publisher_role_arns"></a> [image\_publisher\_role\_arns](#output\_image\_publisher\_role\_arns) | Dedicated GitHub OIDC role ARNs that can push only to their declared ECR repositories. |
| <a name="output_policy_arns"></a> [policy\_arns](#output\_policy\_arns) | ARNs of the Terraform-owned sandbox delivery policies. |
| <a name="output_role_arns"></a> [role\_arns](#output\_role\_arns) | Existing GitHub OIDC roles that receive the reviewed delivery policies. |
<!-- END_TF_DOCS -->
