# Sandbox delivery IAM module

Owns the sandbox GitHub Actions OIDC provider, six environment-scoped roles,
the existing sandbox network/platform delivery policies, and their attachments.
All account-qualified ARNs are derived from the supplied account, Region, AWS
partition, names, and state KMS key ID; callers do not repeat an account ID
inside policy documents.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.35.0, < 7.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.65.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_openid_connect_provider.github_actions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_policy.identity_dev_apply](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.identity_plan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.sandbox_network_dev_apply](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.sandbox_network_plan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.sandbox_platform_dev_apply](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.sandbox_platform_plan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.github_actions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.delivery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_account_id"></a> [aws\_account\_id](#input\_aws\_account\_id) | AWS account that owns the existing sandbox GitHub OIDC roles and delivery policies. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Region containing the sandbox delivery Terraform state backend. | `string` | n/a | yes |
| <a name="input_github_oidc_thumbprints"></a> [github\_oidc\_thumbprints](#input\_github\_oidc\_thumbprints) | Current approved SHA-1 thumbprints for GitHub's OIDC provider. | `set(string)` | n/a | yes |
| <a name="input_github_subject_prefix"></a> [github\_subject\_prefix](#input\_github\_subject\_prefix) | Immutable GitHub OIDC repository subject prefix, without the pull-request/ref/environment suffix. | `string` | n/a | yes |
| <a name="input_role_prefix"></a> [role\_prefix](#input\_role\_prefix) | Existing GitHub OIDC role-name prefix created by the one-time trust bootstrap. | `string` | n/a | yes |
| <a name="input_state_backend"></a> [state\_backend](#input\_state\_backend) | Non-secret, dedicated remote-state configuration for the sandbox delivery IAM root. | <pre>object({<br/>    bucket_name     = string<br/>    key_prefix      = string<br/>    kms_key_id      = string<br/>    lock_table_name = string<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_github_oidc_provider_arn"></a> [github\_oidc\_provider\_arn](#output\_github\_oidc\_provider\_arn) | Terraform-owned GitHub Actions OIDC provider ARN. |
| <a name="output_policy_arns"></a> [policy\_arns](#output\_policy\_arns) | ARNs of the Terraform-owned sandbox delivery policies. |
| <a name="output_role_arns"></a> [role\_arns](#output\_role\_arns) | Existing GitHub OIDC roles that receive the reviewed delivery policies. |
<!-- END_TF_DOCS -->
