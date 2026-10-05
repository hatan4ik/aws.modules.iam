# Wires each reviewed delivery policy to the role that needs it. This is the
# only file that grants permission: every role in oidc.tf and every policy in
# delivery_policies.tf exists with zero effect until it is attached here.

resource "aws_iam_role_policy_attachment" "delivery" {
  for_each = local.role_policy_attachments

  role       = each.value.role_name
  policy_arn = each.value.policy_arn

  lifecycle {
    prevent_destroy = true
  }

  # Most policy_arn values come from local.policy_arns (a string, so they
  # stay known at plan time); this makes the ordering explicit so no
  # attachment is attempted before its policy exists.
  depends_on = [
    aws_iam_policy.sandbox_network_plan,
    aws_iam_policy.sandbox_network_dev_apply,
    aws_iam_policy.sandbox_platform_plan,
    aws_iam_policy.sandbox_platform_dev_apply,
    aws_iam_policy.sandbox_workload_plan,
    aws_iam_policy.sandbox_workload_dev_apply,
    aws_iam_policy.identity_plan,
    aws_iam_policy.identity_dev_apply,
  ]
}
