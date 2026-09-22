output "policy_arns" {
  description = "ARNs of the Terraform-owned sandbox delivery policies."
  value = {
    sandbox_network_plan       = aws_iam_policy.sandbox_network_plan.arn
    sandbox_network_dev_apply  = aws_iam_policy.sandbox_network_dev_apply.arn
    sandbox_platform_plan      = aws_iam_policy.sandbox_platform_plan.arn
    sandbox_platform_dev_apply = aws_iam_policy.sandbox_platform_dev_apply.arn
    sandbox_workload_plan      = aws_iam_policy.sandbox_workload_plan.arn
    sandbox_workload_dev_apply = aws_iam_policy.sandbox_workload_dev_apply.arn
    identity_plan              = aws_iam_policy.identity_plan.arn
    identity_dev_apply         = aws_iam_policy.identity_dev_apply.arn
  }
}

output "role_arns" {
  description = "Existing GitHub OIDC roles that receive the reviewed delivery policies."
  value       = local.github_role_arns
}

output "image_publisher_role_arns" {
  description = "Dedicated GitHub OIDC role ARNs that can push only to their declared ECR repositories."
  value       = { for key, role in aws_iam_role.image_publisher : key => role.arn }
}

output "github_oidc_provider_arn" {
  description = "Terraform-owned GitHub Actions OIDC provider ARN."
  value       = aws_iam_openid_connect_provider.github_actions.arn
}
