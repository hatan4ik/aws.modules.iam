# Opt-in, per-repository GitHub OIDC roles that can push images to exactly
# one declared ECR repository each. Absent var.image_publishers, this file
# creates nothing.

resource "aws_iam_role" "image_publisher" {
  for_each = var.image_publishers

  name                 = local.image_publisher_role_names[each.key]
  path                 = "/github-actions/"
  description          = "GitHub OIDC image publisher for ${each.value.repository_name}."
  max_session_duration = 3600
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = aws_iam_openid_connect_provider.github_actions.arn }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = each.value.github_subject
        }
      }
    }]
  })
  tags = merge(local.github_oidc_tags, {
    Purpose = "github-actions-ecr-image-publisher"
  })

  lifecycle {
    # Same 64-character IAM role-name limit as the six fixed delivery roles;
    # here the caller-controlled part is both role_prefix and the
    # image_publishers key, so it is worth guarding explicitly.
    precondition {
      condition     = length(local.image_publisher_role_names[each.key]) <= 64
      error_message = "role_prefix \"${var.role_prefix}\" and image_publishers key \"${each.key}\" together make the publisher role name exceed IAM's 64-character limit."
    }
  }
}

resource "aws_iam_role_policy" "image_publisher" {
  for_each = var.image_publishers

  name = "ecr-image-publish"
  role = aws_iam_role.image_publisher[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "GetEcrAuthorizationToken"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "PushOnlyDeclaredRepository"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
        ]
        Resource = "arn:${data.aws_partition.current.partition}:ecr:${var.aws_region}:${var.aws_account_id}:repository/${each.value.repository_name}"
      },
    ]
  })
}
