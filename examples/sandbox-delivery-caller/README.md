# Example: the sandbox-delivery caller shape

**Illustrative only. This directory contains no Terraform files and is not
run, validated, linted, or scanned by CI or by `make check`.** It exists so
a reader can see the real call shape without cloning `devops-aws-infra`.

> **Why there is no runnable example here.** Every other `aws.modules.*`
> module in this platform ships runnable examples that plan or apply against
> a disposable copy of themselves. This module cannot: its OIDC provider,
> fixed roles, delivery policies, and attachments carry
> `lifecycle { prevent_destroy = true }`, and a "disposable"
> second GitHub OIDC provider or a second set of delivery roles is exactly
> the kind of uncontrolled IAM sprawl this module exists to prevent — the
> same reasoning `aws.modules.state` gives for why it must never be applied
> against the backend it creates (see that module's README, "Bootstrap
> warning"). There is also only ever meant to be **one** caller of this
> module in this platform: `sandbox-delivery` itself, applied through the
> protected delivery lifecycle ADR 0022 describes. A second, throwaway
> caller is not a smaller version of the real thing; it is a second,
> uncoordinated source of truth for who can authenticate as GitHub Actions.

## The real call, with every value replaced by a placeholder

This mirrors `infra/active/roots/sandbox-delivery/us-east-2/global` in
`devops-aws-infra` exactly in shape: every variable it sets, in the same
order, with the real values replaced. It is not meant to be copied into a
`.tf` file and planned; it is meant to be read.

```hcl
module "sandbox_delivery_iam" {
  source = "git::https://github.com/hatan4ik/aws.modules.iam.git?ref=<commit-sha>" # v1.0.0

  # The account and Region that own the roles, policies, and OIDC provider
  # this module manages. Both are validated at plan time (twelve digits;
  # an AWS-Region-shaped string).
  aws_account_id = "<12-digit-account-id>"
  aws_region     = "<region, e.g. us-east-2>"

  # The prefix every role and policy name is built from. It is caller
  # input, not derived, because the trust bootstrap that creates the very
  # first OIDC provider and role happens once, outside Terraform, before
  # this module ever runs (ADR 0022): this module inherits that prefix
  # rather than choosing it.
  role_prefix = "<existing-role-prefix, e.g. my-platform-sandbox>"

  # The immutable GitHub OIDC subject prefix, without the trailing
  # pull_request/ref/environment suffix this module appends per role.
  github_subject_prefix = "repo:<github-org>/<repository>"

  # Current, approved SHA-1 thumbprints for GitHub's OIDC token issuer.
  # More than one during a planned rotation window.
  github_oidc_thumbprints = [
    "<40-character-hex-thumbprint>",
  ]

  # Optional. One entry per repository that needs to push (never delete)
  # images to exactly one ECR repository it owns. Omit entirely for none.
  image_publishers = {
    "<short-key>" = {
      github_subject  = "repo:<github-org>/<repository>:environment:dev"
      repository_name = "<ecr-repository-name>"
    }
  }

  # This module's own dedicated, non-secret remote-state configuration.
  # kms_key_id is the key's UUID, not an alias or ARN.
  state_backend = {
    bucket_name     = "<shared-state-bucket-name>"
    key_prefix      = "<this-root's-key-prefix>/"
    kms_key_id      = "<state-kms-key-uuid>"
    lock_table_name = "<shared-lock-table-name>"
  }
}
```

## What you get, without setting anything else

- The GitHub Actions OIDC provider and six fixed roles (`plan`, `dev_apply`,
  `staging_apply`, `prod_apply`, `drift`, `landing_zone`), each with zero
  permissions until a policy is attached.
- Every `image_publishers` entry as a dedicated role scoped to
  `ecr:GetAuthorizationToken` (unscoped, which ECR requires) plus push-only
  actions on exactly the one named repository — no delete, no other
  repository.
- The eight reviewed delivery policies (`sandbox-network`,
  `sandbox-platform`, and `sandbox-workload`, each split into a read-only
  `plan` policy and a create/update/delete `dev_apply` policy, plus this
  module's own `identity_plan`/`identity_dev_apply` pair) and the twelve
  attachments that wire them to the roles above.
- `policy_arns`, `role_arns`, `image_publisher_role_arns`, and
  `github_oidc_provider_arn` outputs, for anything downstream that needs to
  reference what this module created.

See [`docs/DESIGN.md`](../../docs/DESIGN.md) for why the interface stops
exactly here, and the README's Security model for what each policy actually
grants.
