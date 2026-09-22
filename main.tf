data "aws_partition" "current" {}

locals {
  state_bucket_arn     = "arn:${data.aws_partition.current.partition}:s3:::${var.state_backend.bucket_name}"
  state_object_arn     = "${local.state_bucket_arn}/${var.state_backend.key_prefix}*"
  state_kms_key_arn    = "arn:${data.aws_partition.current.partition}:kms:${var.aws_region}:${var.aws_account_id}:key/${var.state_backend.kms_key_id}"
  state_lock_table_arn = "arn:${data.aws_partition.current.partition}:dynamodb:${var.aws_region}:${var.aws_account_id}:table/${var.state_backend.lock_table_name}"

  github_oidc_provider_arn = "arn:${data.aws_partition.current.partition}:iam::${var.aws_account_id}:oidc-provider/token.actions.githubusercontent.com"

  github_oidc_tags = {
    IaCOwnership = "terraform"
    ManagedBy    = "devops-aws-infra"
    Purpose      = "github-actions-oidc"
  }

  github_role_names = {
    plan          = "${var.role_prefix}-plan"
    dev_apply     = "${var.role_prefix}-dev-apply"
    staging_apply = "${var.role_prefix}-staging-apply"
    prod_apply    = "${var.role_prefix}-prod-apply"
    drift         = "${var.role_prefix}-drift"
    landing_zone  = "${var.role_prefix}-landing-zone"
  }

  github_role_arns = {
    for key, name in local.github_role_names :
    key => "arn:${data.aws_partition.current.partition}:iam::${var.aws_account_id}:role/github-actions/${name}"
  }

  github_roles = {
    plan = {
      description = "OIDC plan role. No permissions until a reviewed root policy is attached."
      condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        "ForAnyValue:StringEquals" = {
          "token.actions.githubusercontent.com:sub" = [
            "${var.github_subject_prefix}:pull_request",
            "${var.github_subject_prefix}:ref:refs/heads/main",
          ]
        }
      }
    }
    dev_apply = {
      description = "OIDC dev apply/proof role. No permissions until a reviewed root policy is attached."
      condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "${var.github_subject_prefix}:environment:dev"
        }
      }
    }
    staging_apply = {
      description = "OIDC staging apply role. No permissions until a reviewed root policy is attached."
      condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "${var.github_subject_prefix}:environment:staging"
        }
      }
    }
    prod_apply = {
      description = "OIDC prod apply role. No permissions until a reviewed root policy is attached."
      condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "${var.github_subject_prefix}:environment:prod"
        }
      }
    }
    drift = {
      description = "OIDC drift role. No permissions until a reviewed root policy is attached."
      condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "${var.github_subject_prefix}:environment:dev"
        }
      }
    }
    landing_zone = {
      description = "OIDC landing-zone role. No permissions until a reviewed control-plane policy is attached."
      condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "${var.github_subject_prefix}:environment:landing-zone"
        }
      }
    }
  }

  policy_names = {
    sandbox_network_plan       = "${var.role_prefix}-sandbox-network-plan"
    sandbox_network_dev_apply  = "${var.role_prefix}-sandbox-network-dev-apply"
    sandbox_platform_plan      = "${var.role_prefix}-sandbox-platform-plan"
    sandbox_platform_dev_apply = "${var.role_prefix}-sandbox-platform-dev-apply"
    identity_plan              = "${var.role_prefix}-sandbox-delivery-identity-plan"
    identity_dev_apply         = "${var.role_prefix}-sandbox-delivery-identity-dev-apply"
  }

  policy_arns = {
    for key, name in local.policy_names :
    key => "arn:${data.aws_partition.current.partition}:iam::${var.aws_account_id}:policy/${name}"
  }

  role_policy_attachments = {
    network_plan_to_plan = {
      role_name  = local.github_role_names.plan
      policy_arn = local.policy_arns.sandbox_network_plan
    }
    network_plan_to_drift = {
      role_name  = local.github_role_names.drift
      policy_arn = local.policy_arns.sandbox_network_plan
    }
    network_apply_to_dev_apply = {
      role_name  = local.github_role_names.dev_apply
      policy_arn = local.policy_arns.sandbox_network_dev_apply
    }
    platform_plan_to_plan = {
      role_name  = local.github_role_names.plan
      policy_arn = local.policy_arns.sandbox_platform_plan
    }
    platform_plan_to_drift = {
      role_name  = local.github_role_names.drift
      policy_arn = local.policy_arns.sandbox_platform_plan
    }
    platform_apply_to_dev_apply = {
      role_name  = local.github_role_names.dev_apply
      policy_arn = local.policy_arns.sandbox_platform_dev_apply
    }
    identity_plan_to_plan = {
      role_name  = local.github_role_names.plan
      policy_arn = local.policy_arns.identity_plan
    }
    identity_plan_to_drift = {
      role_name  = local.github_role_names.drift
      policy_arn = local.policy_arns.identity_plan
    }
    identity_apply_to_dev_apply = {
      role_name  = local.github_role_names.dev_apply
      policy_arn = local.policy_arns.identity_dev_apply
    }
  }
}

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
  }
}

resource "aws_iam_policy" "sandbox_network_plan" {
  name        = local.policy_names.sandbox_network_plan
  description = "Read and state-lock access required to plan or detect drift for the sandbox-network root."
  policy      = jsonencode(local.sandbox_network_plan_policy)

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_policy" "sandbox_network_dev_apply" {
  name        = local.policy_names.sandbox_network_dev_apply
  description = "Exact create, update, delete, state, and read access for the sandbox-network root."
  policy      = jsonencode(local.sandbox_network_dev_apply_policy)

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_policy" "sandbox_platform_plan" {
  name        = local.policy_names.sandbox_platform_plan
  description = "Read and state-lock access required to plan or detect drift for the sandbox-platform root."
  policy      = jsonencode(local.sandbox_platform_plan_policy)

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_policy" "sandbox_platform_dev_apply" {
  name        = local.policy_names.sandbox_platform_dev_apply
  description = "Root-specific platform provisioning and state access for the protected sandbox dev environment."
  policy      = jsonencode(local.sandbox_platform_dev_apply_policy)

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_policy" "identity_plan" {
  name        = local.policy_names.identity_plan
  description = "Read-only Terraform state and IAM-policy inspection for sandbox delivery identity plans and drift detection."
  policy      = jsonencode(local.identity_plan_policy)

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_policy" "identity_dev_apply" {
  name        = local.policy_names.identity_dev_apply
  description = "Bounded Terraform management of sandbox delivery IAM policy versions and reviewed role attachments."
  policy      = jsonencode(local.identity_dev_apply_policy)

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "delivery" {
  for_each = local.role_policy_attachments

  role       = each.value.role_name
  policy_arn = each.value.policy_arn

  lifecycle {
    prevent_destroy = true
  }
}
