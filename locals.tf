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

  # The fixed roles the sandbox dev delivery pipeline itself runs as: PR and
  # main-branch plans, dev drift detection, and the dev apply. These are the
  # only fixed roles whose trust policy identity_dev_apply may rewrite.
  sandbox_dev_delivery_role_keys = ["dev_apply", "drift", "plan"]

  github_role_arns = {
    for key, name in local.github_role_names :
    key => "arn:${data.aws_partition.current.partition}:iam::${var.aws_account_id}:role/github-actions/${name}"
  }

  image_publisher_role_names = {
    for key in keys(var.image_publishers) :
    key => "${var.role_prefix}-${key}-ecr-push"
  }

  image_publisher_role_arns = {
    for key, name in local.image_publisher_role_names :
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
    sandbox_workload_plan      = "${var.role_prefix}-sandbox-workload-plan"
    sandbox_workload_dev_apply = "${var.role_prefix}-sandbox-workload-dev-apply"
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
    workload_plan_to_plan = {
      role_name  = local.github_role_names.plan
      policy_arn = aws_iam_policy.sandbox_workload_plan.arn
    }
    workload_plan_to_drift = {
      role_name  = local.github_role_names.drift
      policy_arn = aws_iam_policy.sandbox_workload_plan.arn
    }
    workload_apply_to_dev_apply = {
      role_name  = local.github_role_names.dev_apply
      policy_arn = aws_iam_policy.sandbox_workload_dev_apply.arn
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
