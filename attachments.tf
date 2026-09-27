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
}
