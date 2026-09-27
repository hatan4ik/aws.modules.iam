# The GitHub Actions OIDC trust anchor and the six delivery roles it issues
# short-lived credentials to. No role here carries a permission policy of its
# own; permissions arrive only through the attachments in attachments.tf,
# which is what lets a reviewed policy change ship without ever touching a
# trust policy or a role name.

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = tolist(var.github_oidc_thumbprints)
  tags            = local.github_oidc_tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_role" "github_actions" {
  for_each = local.github_roles

  name                 = "${var.role_prefix}-${replace(each.key, "_", "-")}"
  path                 = "/github-actions/"
  description          = each.value.description
  max_session_duration = 3600
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = aws_iam_openid_connect_provider.github_actions.arn }
      Condition = each.value.condition
    }]
  })
  tags = local.github_oidc_tags

  lifecycle {
    prevent_destroy = true

    # IAM rejects a role name over 64 characters. role_prefix is caller
    # input; catching an overlong prefix here gives a plan-time message
    # instead of a raw API error, without changing the name itself for any
    # role_prefix that fits (every value used today does).
    precondition {
      condition     = length("${var.role_prefix}-${replace(each.key, "_", "-")}") <= 64
      error_message = "role_prefix \"${var.role_prefix}\" makes the ${each.key} role name exceed IAM's 64-character limit. Shorten role_prefix."
    }
  }
}
