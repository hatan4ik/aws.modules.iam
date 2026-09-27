# GOLDEN MASTER: the exact IAM identity that GitHub Actions authenticates with
# today, rendered from sandbox-delivery's real, live inputs.
#
#   infra/active/roots/sandbox-delivery/us-east-2/global/terraform.tfvars
#
# This root pins aws.modules.iam at v0.1.13 (commit b4b40a9, the tag the
# consumer's module block comments as "# v0.1.13") and is the sole owner of
# the GitHub OIDC provider, the six GitHub Actions roles, the image-publisher
# roles, and every sandbox/identity delivery policy: the credentials that let
# GitHub Actions apply Terraform anywhere in this platform, including this
# module itself (see docs/DESIGN.md and ADR 0022). Every value asserted here
# was captured by running this exact test (mechanically, not retyped by hand)
# against the UNMODIFIED v0.1.13 source with these same real inputs, so it did
# not originate from this branch and cannot tautologically match it.
#
# If an assertion here fails, the change under test renames, moves, or
# re-scopes a role, a policy, an attachment, or the OIDC provider that the
# live delivery pipeline depends on to authenticate. That is a delete-and-
# recreate of a real, in-use IAM identity, never a test to update: revert the
# change and, if the improvement is genuinely wanted, record it under
# "Deferred to v2" in docs/DESIGN.md instead.
#
# Trust-policy conditions are asserted against local.github_roles / the
# image_publishers input rather than the rendered aws_iam_role.*.assume_role_
# policy attribute: that attribute embeds the OIDC provider's ARN, which is
# unknown under `command = plan` (it does not exist yet), so Terraform cannot
# decode it before apply. local.github_roles is the exact, unmodified source
# that v0.1.13 and this branch both feed into that attribute, so pinning it
# here pins the same real-world authorization behavior. Policy documents have
# no such unknown: none of them reference a computed attribute, so their
# rendered .policy string is fully known at plan time and is asserted
# directly, decoded, exactly as the brief requires.

mock_provider "aws" {}

override_data {
  target = data.aws_partition.current
  values = {
    partition = "aws"
  }
}

variables {
  aws_account_id        = "448871779014"
  aws_region            = "us-east-2"
  role_prefix           = "devops-aws-infra-sandbox"
  github_subject_prefix = "repo:hatan4ik@12816536/devops-aws-infra@1375932356"
  github_oidc_thumbprints = [
    "ab9d0263244dd0326eb67015705a667e79cfe998",
  ]
  image_publishers = {
    "auth-demo" = {
      github_subject  = "repo:hatan4ik@12816536/sandbox-auth-demo@1381754132:environment:dev"
      repository_name = "sandbox-platform-dev-application"
    }
  }
  state_backend = {
    bucket_name     = "platform-tf-state-shared-f3ddb8cc"
    key_prefix      = "gitops/sandbox-delivery/us-east-2/global/"
    kms_key_id      = "34605b23-fafd-43f8-b708-db4dbe385189"
    lock_table_name = "platform-tf-lock-table"
  }
}

run "oidc_provider_identity" {
  command = plan

  assert {
    condition     = aws_iam_openid_connect_provider.github_actions.url == "https://token.actions.githubusercontent.com"
    error_message = "GOLDEN MASTER: the GitHub OIDC provider URL changed; GitHub Actions authenticates against this exact provider."
  }

  assert {
    condition     = aws_iam_openid_connect_provider.github_actions.client_id_list == toset(["sts.amazonaws.com"])
    error_message = "GOLDEN MASTER: the OIDC provider's client_id_list (audience) changed."
  }

  assert {
    condition     = aws_iam_openid_connect_provider.github_actions.thumbprint_list == tolist(["ab9d0263244dd0326eb67015705a667e79cfe998"])
    error_message = "GOLDEN MASTER: the OIDC provider's thumbprint_list changed for the same github_oidc_thumbprints input."
  }

  assert {
    condition = aws_iam_openid_connect_provider.github_actions.tags == tomap({
      IaCOwnership = "terraform"
      ManagedBy    = "devops-aws-infra"
      Purpose      = "github-actions-oidc"
    })
    error_message = "GOLDEN MASTER: the OIDC provider's tags changed."
  }
}

run "github_actions_role_identity" {
  command = plan

  assert {
    condition     = aws_iam_role.github_actions["plan"].name == "devops-aws-infra-sandbox-plan"
    error_message = "GOLDEN MASTER: the plan role name changed; this is the identity GitHub Actions plan runs assume today."
  }
  assert {
    condition     = aws_iam_role.github_actions["dev_apply"].name == "devops-aws-infra-sandbox-dev-apply"
    error_message = "GOLDEN MASTER: the dev_apply role name changed; this is the identity the protected dev environment assumes today."
  }
  assert {
    condition     = aws_iam_role.github_actions["staging_apply"].name == "devops-aws-infra-sandbox-staging-apply"
    error_message = "GOLDEN MASTER: the staging_apply role name changed."
  }
  assert {
    condition     = aws_iam_role.github_actions["prod_apply"].name == "devops-aws-infra-sandbox-prod-apply"
    error_message = "GOLDEN MASTER: the prod_apply role name changed."
  }
  assert {
    condition     = aws_iam_role.github_actions["drift"].name == "devops-aws-infra-sandbox-drift"
    error_message = "GOLDEN MASTER: the drift role name changed; this is the identity the read-only drift workflow assumes today."
  }
  assert {
    condition     = aws_iam_role.github_actions["landing_zone"].name == "devops-aws-infra-sandbox-landing-zone"
    error_message = "GOLDEN MASTER: the landing_zone role name changed."
  }

  assert {
    condition = alltrue([
      for key, role in aws_iam_role.github_actions : role.path == "/github-actions/"
    ])
    error_message = "GOLDEN MASTER: a GitHub Actions role path changed from /github-actions/, which is part of its ARN."
  }

  # Trust-policy conditions, asserted against the exact unmodified source
  # local (see the file header for why the rendered resource attribute
  # cannot be asserted directly under `command = plan`).
  assert {
    condition = local.github_roles["plan"].condition == {
      StringEquals = {
        "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
      }
      "ForAnyValue:StringEquals" = {
        "token.actions.githubusercontent.com:sub" = [
          "repo:hatan4ik@12816536/devops-aws-infra@1375932356:pull_request",
          "repo:hatan4ik@12816536/devops-aws-infra@1375932356:ref:refs/heads/main",
        ]
      }
    }
    error_message = "GOLDEN MASTER: the plan role's trust-policy condition changed; this controls which GitHub Actions runs may assume it."
  }

  assert {
    condition = local.github_roles["dev_apply"].condition == {
      StringEquals = {
        "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        "token.actions.githubusercontent.com:sub" = "repo:hatan4ik@12816536/devops-aws-infra@1375932356:environment:dev"
      }
    }
    error_message = "GOLDEN MASTER: the dev_apply role's trust-policy condition changed."
  }

  assert {
    condition = local.github_roles["staging_apply"].condition == {
      StringEquals = {
        "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        "token.actions.githubusercontent.com:sub" = "repo:hatan4ik@12816536/devops-aws-infra@1375932356:environment:staging"
      }
    }
    error_message = "GOLDEN MASTER: the staging_apply role's trust-policy condition changed."
  }

  assert {
    condition = local.github_roles["prod_apply"].condition == {
      StringEquals = {
        "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        "token.actions.githubusercontent.com:sub" = "repo:hatan4ik@12816536/devops-aws-infra@1375932356:environment:prod"
      }
    }
    error_message = "GOLDEN MASTER: the prod_apply role's trust-policy condition changed."
  }

  # Same subject as dev_apply today: the drift role is intentionally scoped to
  # the protected dev environment, not a separate "drift" environment. This is
  # current, real behavior, not an oversight to "fix" in this test.
  assert {
    condition = local.github_roles["drift"].condition == {
      StringEquals = {
        "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        "token.actions.githubusercontent.com:sub" = "repo:hatan4ik@12816536/devops-aws-infra@1375932356:environment:dev"
      }
    }
    error_message = "GOLDEN MASTER: the drift role's trust-policy condition changed."
  }

  assert {
    condition = local.github_roles["landing_zone"].condition == {
      StringEquals = {
        "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        "token.actions.githubusercontent.com:sub" = "repo:hatan4ik@12816536/devops-aws-infra@1375932356:environment:landing-zone"
      }
    }
    error_message = "GOLDEN MASTER: the landing_zone role's trust-policy condition changed."
  }
}

run "image_publisher_identity" {
  command = plan

  assert {
    condition     = aws_iam_role.image_publisher["auth-demo"].name == "devops-aws-infra-sandbox-auth-demo-ecr-push"
    error_message = "GOLDEN MASTER: the auth-demo image-publisher role name changed."
  }
  assert {
    condition     = aws_iam_role.image_publisher["auth-demo"].path == "/github-actions/"
    error_message = "GOLDEN MASTER: the auth-demo image-publisher role path changed."
  }
  assert {
    condition     = var.image_publishers["auth-demo"].github_subject == "repo:hatan4ik@12816536/sandbox-auth-demo@1381754132:environment:dev"
    error_message = "GOLDEN MASTER (input contract): the auth-demo publisher's trust subject changed in the fixture; this test would then no longer reflect the live input."
  }
  assert {
    condition     = aws_iam_role_policy.image_publisher["auth-demo"].name == "ecr-image-publish"
    error_message = "GOLDEN MASTER: the auth-demo image-publisher inline policy name changed."
  }
  assert {
    condition = jsondecode(aws_iam_role_policy.image_publisher["auth-demo"].policy) == jsondecode(<<-JSON
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Sid": "GetEcrAuthorizationToken",
          "Effect": "Allow",
          "Action": "ecr:GetAuthorizationToken",
          "Resource": "*"
        },
        {
          "Sid": "PushOnlyDeclaredRepository",
          "Effect": "Allow",
          "Action": [
            "ecr:BatchCheckLayerAvailability",
            "ecr:BatchGetImage",
            "ecr:CompleteLayerUpload",
            "ecr:DescribeImages",
            "ecr:InitiateLayerUpload",
            "ecr:PutImage",
            "ecr:UploadLayerPart"
          ],
          "Resource": "arn:aws:ecr:us-east-2:448871779014:repository/sandbox-platform-dev-application"
        }
      ]
    }
    JSON
    )
    error_message = "GOLDEN MASTER: the auth-demo image-publisher policy document changed (push-only, single-repository ECR grant)."
  }
}

run "delivery_policy_names" {
  command = plan

  assert {
    condition     = aws_iam_policy.sandbox_network_plan.name == "devops-aws-infra-sandbox-sandbox-network-plan"
    error_message = "GOLDEN MASTER: the sandbox-network plan policy name changed."
  }
  assert {
    condition     = aws_iam_policy.sandbox_network_dev_apply.name == "devops-aws-infra-sandbox-sandbox-network-dev-apply"
    error_message = "GOLDEN MASTER: the sandbox-network dev-apply policy name changed."
  }
  assert {
    condition     = aws_iam_policy.sandbox_platform_plan.name == "devops-aws-infra-sandbox-sandbox-platform-plan"
    error_message = "GOLDEN MASTER: the sandbox-platform plan policy name changed."
  }
  assert {
    condition     = aws_iam_policy.sandbox_platform_dev_apply.name == "devops-aws-infra-sandbox-sandbox-platform-dev-apply"
    error_message = "GOLDEN MASTER: the sandbox-platform dev-apply policy name changed."
  }
  assert {
    condition     = aws_iam_policy.sandbox_workload_plan.name == "devops-aws-infra-sandbox-sandbox-workload-plan"
    error_message = "GOLDEN MASTER: the sandbox-workload plan policy name changed."
  }
  assert {
    condition     = aws_iam_policy.sandbox_workload_dev_apply.name == "devops-aws-infra-sandbox-sandbox-workload-dev-apply"
    error_message = "GOLDEN MASTER: the sandbox-workload dev-apply policy name changed."
  }
  assert {
    condition     = aws_iam_policy.identity_plan.name == "devops-aws-infra-sandbox-sandbox-delivery-identity-plan"
    error_message = "GOLDEN MASTER: the identity plan policy name changed."
  }
  assert {
    condition     = aws_iam_policy.identity_dev_apply.name == "devops-aws-infra-sandbox-sandbox-delivery-identity-dev-apply"
    error_message = "GOLDEN MASTER: the identity dev-apply policy name changed."
  }

  # These names carry a "sandbox-sandbox" stutter (role_prefix already
  # contains "sandbox", and each of these four policy_names entries adds a
  # second, literal "sandbox-" segment). It is real, deployed, and frozen: see
  # "Deferred to v2" in docs/DESIGN.md. This assertion exists so nobody
  # "cleans up" the local and silently renames a live policy.
  assert {
    condition = alltrue([
      for name in [
        aws_iam_policy.sandbox_network_plan.name,
        aws_iam_policy.sandbox_network_dev_apply.name,
        aws_iam_policy.sandbox_platform_plan.name,
        aws_iam_policy.sandbox_platform_dev_apply.name,
        aws_iam_policy.sandbox_workload_plan.name,
        aws_iam_policy.sandbox_workload_dev_apply.name,
      ] : can(regex("^devops-aws-infra-sandbox-sandbox-", name))
    ])
    error_message = "GOLDEN MASTER: the documented 'sandbox-sandbox' naming stutter no longer matches; either the names changed (revert) or docs/DESIGN.md's Deferred-to-v2 entry is now stale (update the doc, not this assertion, only alongside a deliberate v2 migration)."
  }
}
run "delivery_policy_documents_network" {
  command = plan

  assert {
    condition = jsondecode(aws_iam_policy.sandbox_network_plan.policy) == jsondecode(<<-JSON
    {
      "Statement": [
        {
          "Action": "s3:ListBucket",
          "Condition": {
            "StringLike": {
              "s3:prefix": "gitops/sandbox-network/us-east-2/dev/*"
            }
          },
          "Effect": "Allow",
          "Resource": "arn:aws:s3:::platform-tf-state-shared-f3ddb8cc",
          "Sid": "ListOnlyTheSandboxNetworkStatePrefix"
        },
        {
          "Action": [
            "s3:GetObject",
            "s3:PutObject"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:s3:::platform-tf-state-shared-f3ddb8cc/gitops/sandbox-network/us-east-2/dev/*",
          "Sid": "ReadAndWriteOnlyTheSandboxNetworkStateObject"
        },
        {
          "Action": [
            "kms:Decrypt",
            "kms:DescribeKey",
            "kms:Encrypt",
            "kms:GenerateDataKey"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:kms:us-east-2:448871779014:key/34605b23-fafd-43f8-b708-db4dbe385189",
          "Sid": "UseOnlyTheStateEncryptionKey"
        },
        {
          "Action": [
            "dynamodb:DeleteItem",
            "dynamodb:DescribeTable",
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:UpdateItem"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:dynamodb:us-east-2:448871779014:table/platform-tf-lock-table",
          "Sid": "LockOnlyTheDedicatedStateTable"
        },
        {
          "Action": [
            "ec2:Describe*",
            "ec2:GetVpcResourcesBlockingEncryptionEnforcement",
            "iam:GetRole",
            "iam:GetRolePolicy",
            "iam:ListAttachedRolePolicies",
            "iam:ListInstanceProfilesForRole",
            "iam:ListRolePolicies",
            "kms:DescribeKey",
            "kms:GetKeyPolicy",
            "kms:GetKeyRotationStatus",
            "kms:ListAliases",
            "kms:ListResourceTags",
            "logs:Describe*",
            "logs:ListTagsForResource",
            "tag:GetResources"
          ],
          "Effect": "Allow",
          "Resource": "*",
          "Sid": "ReadSandboxNetworkResources"
        }
      ],
      "Version": "2012-10-17"
    }
    JSON
    )
    error_message = "GOLDEN MASTER: the sandbox-network plan policy document changed."
  }

  assert {
    condition = jsondecode(aws_iam_policy.sandbox_network_dev_apply.policy) == jsondecode(<<-JSON
    {
      "Statement": [
        {
          "Action": "s3:ListBucket",
          "Condition": {
            "StringLike": {
              "s3:prefix": "gitops/sandbox-network/us-east-2/dev/*"
            }
          },
          "Effect": "Allow",
          "Resource": "arn:aws:s3:::platform-tf-state-shared-f3ddb8cc",
          "Sid": "ListOnlyTheSandboxNetworkStatePrefix"
        },
        {
          "Action": [
            "s3:GetObject",
            "s3:PutObject"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:s3:::platform-tf-state-shared-f3ddb8cc/gitops/sandbox-network/us-east-2/dev/*",
          "Sid": "ReadAndWriteOnlyTheSandboxNetworkStateObject"
        },
        {
          "Action": [
            "kms:Decrypt",
            "kms:DescribeKey",
            "kms:Encrypt",
            "kms:GenerateDataKey"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:kms:us-east-2:448871779014:key/34605b23-fafd-43f8-b708-db4dbe385189",
          "Sid": "UseOnlyTheStateEncryptionKey"
        },
        {
          "Action": [
            "dynamodb:DeleteItem",
            "dynamodb:DescribeTable",
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:UpdateItem"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:dynamodb:us-east-2:448871779014:table/platform-tf-lock-table",
          "Sid": "LockOnlyTheDedicatedStateTable"
        },
        {
          "Action": [
            "ec2:Describe*",
            "ec2:GetVpcResourcesBlockingEncryptionEnforcement",
            "iam:GetRole",
            "iam:GetRolePolicy",
            "iam:ListAttachedRolePolicies",
            "iam:ListInstanceProfilesForRole",
            "iam:ListRolePolicies",
            "kms:DescribeKey",
            "kms:GetKeyPolicy",
            "kms:GetKeyRotationStatus",
            "kms:ListAliases",
            "kms:ListResourceTags",
            "logs:Describe*",
            "logs:ListTagsForResource",
            "tag:GetResources"
          ],
          "Effect": "Allow",
          "Resource": "*",
          "Sid": "ReadSandboxNetworkResources"
        },
        {
          "Action": [
            "ec2:AssociateRouteTable",
            "ec2:AuthorizeSecurityGroupEgress",
            "ec2:AuthorizeSecurityGroupIngress",
            "ec2:CreateFlowLogs",
            "ec2:CreateRouteTable",
            "ec2:CreateSubnet",
            "ec2:CreateTags",
            "ec2:CreateVpc",
            "ec2:CreateVpcEncryptionControl",
            "ec2:DeleteFlowLogs",
            "ec2:DeleteRouteTable",
            "ec2:DeleteSubnet",
            "ec2:DeleteTags",
            "ec2:DeleteVpc",
            "ec2:DeleteVpcEncryptionControl",
            "ec2:DisassociateRouteTable",
            "ec2:ModifySubnetAttribute",
            "ec2:ModifyVpcAttribute",
            "ec2:ModifyVpcEncryptionControl",
            "ec2:RevokeSecurityGroupEgress",
            "ec2:RevokeSecurityGroupIngress"
          ],
          "Effect": "Allow",
          "Resource": "*",
          "Sid": "ManageOnlyTheSandboxNetworkVpcResources"
        },
        {
          "Action": [
            "logs:CreateLogGroup",
            "logs:DeleteLogGroup",
            "logs:PutRetentionPolicy",
            "logs:TagResource",
            "logs:UntagResource"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:logs:us-east-2:448871779014:log-group:/aws/vpc/sandbox-network-dev/flow-logs*",
          "Sid": "ManageSandboxNetworkFlowLogGroup"
        },
        {
          "Action": [
            "kms:CreateKey"
          ],
          "Condition": {
            "StringEquals": {
              "aws:RequestTag/Root": "sandbox-network"
            }
          },
          "Effect": "Allow",
          "Resource": "*",
          "Sid": "CreateDedicatedSandboxNetworkFlowLogKey"
        },
        {
          "Action": [
            "kms:CreateAlias",
            "kms:DeleteAlias"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:kms:us-east-2:448871779014:alias/sandbox-network-dev-flow-logs",
          "Sid": "ManageOnlyTheDedicatedSandboxNetworkFlowLogAlias"
        },
        {
          "Action": [
            "kms:CreateAlias",
            "kms:DeleteAlias",
            "kms:DescribeKey",
            "kms:EnableKeyRotation",
            "kms:GetKeyPolicy",
            "kms:GetKeyRotationStatus",
            "kms:ListAliases",
            "kms:ListResourceTags",
            "kms:PutKeyPolicy",
            "kms:ScheduleKeyDeletion",
            "kms:TagResource",
            "kms:UntagResource"
          ],
          "Condition": {
            "StringEquals": {
              "aws:ResourceTag/Root": "sandbox-network"
            }
          },
          "Effect": "Allow",
          "Resource": "*",
          "Sid": "ManageDedicatedSandboxNetworkFlowLogKey"
        },
        {
          "Action": [
            "iam:CreateRole",
            "iam:DeleteRole",
            "iam:GetRole",
            "iam:PassRole",
            "iam:PutRolePolicy",
            "iam:DeleteRolePolicy",
            "iam:GetRolePolicy",
            "iam:ListAttachedRolePolicies",
            "iam:ListInstanceProfilesForRole",
            "iam:ListRolePolicies",
            "iam:TagRole",
            "iam:UntagRole"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:iam::448871779014:role/sandbox-network-dev-vpc-flow-logs",
          "Sid": "CreateAndPassOnlyTheSandboxNetworkFlowLogRole"
        }
      ],
      "Version": "2012-10-17"
    }
    JSON
    )
    error_message = "GOLDEN MASTER: the sandbox-network dev-apply policy document changed."
  }

}
run "delivery_policy_documents_platform" {
  command = plan

  assert {
    condition = jsondecode(aws_iam_policy.sandbox_platform_plan.policy) == jsondecode(<<-JSON
    {
      "Statement": [
        {
          "Action": "s3:ListBucket",
          "Condition": {
            "StringLike": {
              "s3:prefix": "gitops/sandbox-platform/us-east-2/dev/*"
            }
          },
          "Effect": "Allow",
          "Resource": "arn:aws:s3:::platform-tf-state-shared-f3ddb8cc",
          "Sid": "ListOnlySandboxPlatformStatePrefix"
        },
        {
          "Action": [
            "s3:GetObject",
            "s3:PutObject"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:s3:::platform-tf-state-shared-f3ddb8cc/gitops/sandbox-platform/us-east-2/dev/*",
          "Sid": "ReadAndWriteOnlySandboxPlatformStateObject"
        },
        {
          "Action": [
            "kms:Decrypt",
            "kms:DescribeKey",
            "kms:Encrypt",
            "kms:GenerateDataKey"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:kms:us-east-2:448871779014:key/34605b23-fafd-43f8-b708-db4dbe385189",
          "Sid": "UseOnlyTheStateEncryptionKey"
        },
        {
          "Action": [
            "dynamodb:DeleteItem",
            "dynamodb:DescribeTable",
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:UpdateItem"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:dynamodb:us-east-2:448871779014:table/platform-tf-lock-table",
          "Sid": "LockOnlyTheDedicatedStateTable"
        },
        {
          "Action": [
            "cognito-idp:DescribeUserPool",
            "cognito-idp:GetUserPoolMfaConfig",
            "cognito-idp:ListResourceServers",
            "cognito-idp:ListTagsForResource",
            "cognito-idp:ListUserPoolClients",
            "cognito-idp:ListUserPools",
            "dynamodb:DescribeContinuousBackups",
            "dynamodb:DescribeTable",
            "dynamodb:DescribeTimeToLive",
            "dynamodb:ListTables",
            "dynamodb:ListTagsOfResource",
            "ec2:Describe*",
            "ecr:DescribeImages",
            "ecr:DescribeRepositories",
            "ecr:GetLifecyclePolicy",
            "ecr:GetRepositoryPolicy",
            "ecr:ListImages",
            "ecr:ListTagsForResource",
            "ecs:DescribeClusters",
            "ecs:ListClusters",
            "ecs:ListTagsForResource",
            "logs:DescribeLogGroups",
            "logs:ListTagsForResource",
            "kms:DescribeKey",
            "kms:GetKeyPolicy",
            "kms:GetKeyRotationStatus",
            "kms:ListAliases",
            "kms:ListResourceTags",
            "tag:GetResources"
          ],
          "Effect": "Allow",
          "Resource": "*",
          "Sid": "ReadSandboxPlatformResources"
        }
      ],
      "Version": "2012-10-17"
    }
    JSON
    )
    error_message = "GOLDEN MASTER: the sandbox-platform plan policy document changed."
  }

  assert {
    condition = jsondecode(aws_iam_policy.sandbox_platform_dev_apply.policy) == jsondecode(<<-JSON
    {
      "Statement": [
        {
          "Action": "s3:ListBucket",
          "Condition": {
            "StringLike": {
              "s3:prefix": "gitops/sandbox-platform/us-east-2/dev/*"
            }
          },
          "Effect": "Allow",
          "Resource": "arn:aws:s3:::platform-tf-state-shared-f3ddb8cc",
          "Sid": "ListOnlySandboxPlatformStatePrefix"
        },
        {
          "Action": [
            "s3:GetObject",
            "s3:PutObject"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:s3:::platform-tf-state-shared-f3ddb8cc/gitops/sandbox-platform/us-east-2/dev/*",
          "Sid": "ReadAndWriteOnlySandboxPlatformStateObject"
        },
        {
          "Action": [
            "kms:Decrypt",
            "kms:DescribeKey",
            "kms:Encrypt",
            "kms:GenerateDataKey"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:kms:us-east-2:448871779014:key/34605b23-fafd-43f8-b708-db4dbe385189",
          "Sid": "UseOnlyTheStateEncryptionKey"
        },
        {
          "Action": [
            "dynamodb:DeleteItem",
            "dynamodb:DescribeTable",
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:UpdateItem"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:dynamodb:us-east-2:448871779014:table/platform-tf-lock-table",
          "Sid": "LockOnlyTheDedicatedStateTable"
        },
        {
          "Action": [
            "cognito-idp:DescribeUserPool",
            "cognito-idp:GetUserPoolMfaConfig",
            "cognito-idp:ListResourceServers",
            "cognito-idp:ListTagsForResource",
            "cognito-idp:ListUserPoolClients",
            "cognito-idp:ListUserPools",
            "dynamodb:DescribeContinuousBackups",
            "dynamodb:DescribeTable",
            "dynamodb:DescribeTimeToLive",
            "dynamodb:ListTables",
            "dynamodb:ListTagsOfResource",
            "ec2:Describe*",
            "ecr:DescribeImages",
            "ecr:DescribeRepositories",
            "ecr:GetLifecyclePolicy",
            "ecr:GetRepositoryPolicy",
            "ecr:ListImages",
            "ecr:ListTagsForResource",
            "ecs:DescribeClusters",
            "ecs:ListClusters",
            "ecs:ListTagsForResource",
            "logs:DescribeLogGroups",
            "logs:ListTagsForResource",
            "kms:DescribeKey",
            "kms:GetKeyPolicy",
            "kms:GetKeyRotationStatus",
            "kms:ListAliases",
            "kms:ListResourceTags",
            "tag:GetResources"
          ],
          "Effect": "Allow",
          "Resource": "*",
          "Sid": "ReadSandboxPlatformResources"
        },
        {
          "Action": [
            "ec2:AuthorizeSecurityGroupEgress",
            "ec2:AuthorizeSecurityGroupIngress",
            "ec2:CreateSecurityGroup",
            "ec2:CreateTags",
            "ec2:CreateVpcEndpoint",
            "ec2:DeleteSecurityGroup",
            "ec2:DeleteTags",
            "ec2:DeleteVpcEndpoints",
            "ec2:ModifyVpcEndpoint",
            "ec2:RevokeSecurityGroupEgress",
            "ec2:RevokeSecurityGroupIngress"
          ],
          "Effect": "Allow",
          "Resource": "*",
          "Sid": "ManageSandboxPrivateConnectivity"
        },
        {
          "Action": [
            "ecr:BatchDeleteImage",
            "ecr:CreateRepository",
            "ecr:DeleteLifecyclePolicy",
            "ecr:DeleteRepository",
            "ecr:PutImageScanningConfiguration",
            "ecr:PutImageTagMutability",
            "ecr:PutLifecyclePolicy",
            "ecr:TagResource",
            "ecr:UntagResource"
          ],
          "Effect": "Allow",
          "Resource": "*",
          "Sid": "ManageSandboxContainerRegistry"
        },
        {
          "Action": [
            "ecs:CreateCluster",
            "ecs:DeleteCluster",
            "ecs:TagResource",
            "ecs:UntagResource",
            "ecs:UpdateCluster"
          ],
          "Effect": "Allow",
          "Resource": "*",
          "Sid": "ManageSandboxEcsCluster"
        },
        {
          "Action": [
            "logs:CreateLogGroup",
            "logs:DeleteLogGroup",
            "logs:PutRetentionPolicy",
            "logs:TagResource",
            "logs:UntagResource"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:logs:us-east-2:448871779014:log-group:/aws/ecs/sandbox-platform-dev/*",
          "Sid": "ManageSandboxApplicationLogs"
        },
        {
          "Action": [
            "kms:CreateKey"
          ],
          "Condition": {
            "StringEquals": {
              "aws:RequestTag/Root": "sandbox-platform"
            }
          },
          "Effect": "Allow",
          "Resource": "*",
          "Sid": "CreateDedicatedSandboxPlatformDataKey"
        },
        {
          "Action": [
            "kms:CreateAlias",
            "kms:CreateGrant",
            "kms:Decrypt",
            "kms:DeleteAlias",
            "kms:DescribeKey",
            "kms:EnableKeyRotation",
            "kms:Encrypt",
            "kms:GenerateDataKey",
            "kms:GetKeyPolicy",
            "kms:GetKeyRotationStatus",
            "kms:ListAliases",
            "kms:ListResourceTags",
            "kms:PutKeyPolicy",
            "kms:ReEncryptFrom",
            "kms:ReEncryptTo",
            "kms:ScheduleKeyDeletion",
            "kms:TagResource",
            "kms:UntagResource"
          ],
          "Condition": {
            "StringEquals": {
              "aws:ResourceTag/Root": "sandbox-platform"
            }
          },
          "Effect": "Allow",
          "Resource": "*",
          "Sid": "ManageDedicatedSandboxPlatformDataKey"
        },
        {
          "Action": [
            "kms:CreateAlias",
            "kms:DeleteAlias"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:kms:us-east-2:448871779014:alias/sandbox-platform-dev-application-data",
          "Sid": "ManageDedicatedSandboxPlatformDataAlias"
        },
        {
          "Action": [
            "dynamodb:CreateTable",
            "dynamodb:DeleteTable",
            "dynamodb:TagResource",
            "dynamodb:UntagResource",
            "dynamodb:UpdateContinuousBackups",
            "dynamodb:UpdateTable",
            "dynamodb:UpdateTimeToLive"
          ],
          "Effect": "Allow",
          "Resource": "*",
          "Sid": "ManageSandboxSessionTable"
        },
        {
          "Action": [
            "cognito-idp:CreateUserPool",
            "cognito-idp:DeleteUserPool",
            "cognito-idp:SetUserPoolMfaConfig",
            "cognito-idp:TagResource",
            "cognito-idp:UntagResource",
            "cognito-idp:UpdateUserPool"
          ],
          "Effect": "Allow",
          "Resource": "*",
          "Sid": "ManageSandboxCognitoPool"
        }
      ],
      "Version": "2012-10-17"
    }
    JSON
    )
    error_message = "GOLDEN MASTER: the sandbox-platform dev-apply policy document changed."
  }

}
run "delivery_policy_documents_workload" {
  command = plan

  assert {
    condition = jsondecode(aws_iam_policy.sandbox_workload_plan.policy) == jsondecode(<<-JSON
    {
      "Statement": [
        {
          "Action": "s3:ListBucket",
          "Condition": {
            "StringLike": {
              "s3:prefix": "gitops/sandbox-workload/us-east-2/dev/*"
            }
          },
          "Effect": "Allow",
          "Resource": "arn:aws:s3:::platform-tf-state-shared-f3ddb8cc",
          "Sid": "ListOnlySandboxWorkloadStatePrefix"
        },
        {
          "Action": [
            "s3:GetObject",
            "s3:PutObject"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:s3:::platform-tf-state-shared-f3ddb8cc/gitops/sandbox-workload/us-east-2/dev/*",
          "Sid": "ReadAndWriteOnlySandboxWorkloadStateObject"
        },
        {
          "Action": [
            "kms:Decrypt",
            "kms:DescribeKey",
            "kms:Encrypt",
            "kms:GenerateDataKey"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:kms:us-east-2:448871779014:key/34605b23-fafd-43f8-b708-db4dbe385189",
          "Sid": "UseOnlyTheStateEncryptionKey"
        },
        {
          "Action": [
            "dynamodb:DeleteItem",
            "dynamodb:DescribeTable",
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:UpdateItem"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:dynamodb:us-east-2:448871779014:table/platform-tf-lock-table",
          "Sid": "LockOnlyTheDedicatedStateTable"
        },
        {
          "Action": "s3:ListBucket",
          "Condition": {
            "StringLike": {
              "s3:prefix": "gitops/sandbox-platform/us-east-2/dev/*"
            }
          },
          "Effect": "Allow",
          "Resource": "arn:aws:s3:::platform-tf-state-shared-f3ddb8cc",
          "Sid": "ListSandboxPlatformStateForWorkload"
        },
        {
          "Action": "s3:GetObject",
          "Effect": "Allow",
          "Resource": "arn:aws:s3:::platform-tf-state-shared-f3ddb8cc/gitops/sandbox-platform/us-east-2/dev/*",
          "Sid": "ReadSandboxPlatformStateForWorkload"
        },
        {
          "Action": [
            "application-autoscaling:Describe*",
            "cognito-idp:DescribeUserPool",
            "cognito-idp:DescribeUserPoolClient",
            "cognito-idp:ListUserPoolClients",
            "dynamodb:DescribeTable",
            "dynamodb:ListTagsOfResource",
            "ec2:Describe*",
            "ecs:DescribeClusters",
            "ecs:DescribeServices",
            "ecs:DescribeTaskDefinition",
            "ecs:ListServices",
            "ecs:ListTagsForResource",
            "ecs:ListTaskDefinitions",
            "iam:GetRole",
            "iam:GetRolePolicy",
            "iam:ListAttachedRolePolicies",
            "iam:ListRolePolicies",
            "kms:DescribeKey",
            "kms:ListResourceTags",
            "logs:DescribeLogGroups",
            "logs:ListTagsForResource",
            "tag:GetResources"
          ],
          "Effect": "Allow",
          "Resource": "*",
          "Sid": "ReadSandboxWorkloadResources"
        },
        {
          "Action": "application-autoscaling:ListTagsForResource",
          "Effect": "Allow",
          "Resource": "arn:aws:application-autoscaling:us-east-2:448871779014:scalable-target/*",
          "Sid": "ReadOnlySandboxWorkloadAutoscalingTags"
        }
      ],
      "Version": "2012-10-17"
    }
    JSON
    )
    error_message = "GOLDEN MASTER: the sandbox-workload plan policy document changed."
  }

  assert {
    condition = jsondecode(aws_iam_policy.sandbox_workload_dev_apply.policy) == jsondecode(<<-JSON
    {
      "Statement": [
        {
          "Action": "s3:ListBucket",
          "Condition": {
            "StringLike": {
              "s3:prefix": "gitops/sandbox-workload/us-east-2/dev/*"
            }
          },
          "Effect": "Allow",
          "Resource": "arn:aws:s3:::platform-tf-state-shared-f3ddb8cc",
          "Sid": "ListOnlySandboxWorkloadStatePrefix"
        },
        {
          "Action": [
            "s3:GetObject",
            "s3:PutObject"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:s3:::platform-tf-state-shared-f3ddb8cc/gitops/sandbox-workload/us-east-2/dev/*",
          "Sid": "ReadAndWriteOnlySandboxWorkloadStateObject"
        },
        {
          "Action": [
            "kms:Decrypt",
            "kms:DescribeKey",
            "kms:Encrypt",
            "kms:GenerateDataKey"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:kms:us-east-2:448871779014:key/34605b23-fafd-43f8-b708-db4dbe385189",
          "Sid": "UseOnlyTheStateEncryptionKey"
        },
        {
          "Action": [
            "dynamodb:DeleteItem",
            "dynamodb:DescribeTable",
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:UpdateItem"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:dynamodb:us-east-2:448871779014:table/platform-tf-lock-table",
          "Sid": "LockOnlyTheDedicatedStateTable"
        },
        {
          "Action": "s3:ListBucket",
          "Condition": {
            "StringLike": {
              "s3:prefix": "gitops/sandbox-platform/us-east-2/dev/*"
            }
          },
          "Effect": "Allow",
          "Resource": "arn:aws:s3:::platform-tf-state-shared-f3ddb8cc",
          "Sid": "ListSandboxPlatformStateForWorkload"
        },
        {
          "Action": "s3:GetObject",
          "Effect": "Allow",
          "Resource": "arn:aws:s3:::platform-tf-state-shared-f3ddb8cc/gitops/sandbox-platform/us-east-2/dev/*",
          "Sid": "ReadSandboxPlatformStateForWorkload"
        },
        {
          "Action": [
            "application-autoscaling:Describe*",
            "cognito-idp:DescribeUserPool",
            "cognito-idp:DescribeUserPoolClient",
            "cognito-idp:ListUserPoolClients",
            "dynamodb:DescribeTable",
            "dynamodb:ListTagsOfResource",
            "ec2:Describe*",
            "ecs:DescribeClusters",
            "ecs:DescribeServices",
            "ecs:DescribeTaskDefinition",
            "ecs:ListServices",
            "ecs:ListTagsForResource",
            "ecs:ListTaskDefinitions",
            "iam:GetRole",
            "iam:GetRolePolicy",
            "iam:ListAttachedRolePolicies",
            "iam:ListRolePolicies",
            "kms:DescribeKey",
            "kms:ListResourceTags",
            "logs:DescribeLogGroups",
            "logs:ListTagsForResource",
            "tag:GetResources"
          ],
          "Effect": "Allow",
          "Resource": "*",
          "Sid": "ReadSandboxWorkloadResources"
        },
        {
          "Action": "application-autoscaling:ListTagsForResource",
          "Effect": "Allow",
          "Resource": "arn:aws:application-autoscaling:us-east-2:448871779014:scalable-target/*",
          "Sid": "ReadOnlySandboxWorkloadAutoscalingTags"
        },
        {
          "Action": [
            "ec2:AuthorizeSecurityGroupEgress",
            "ec2:AuthorizeSecurityGroupIngress",
            "ec2:CreateSecurityGroup",
            "ec2:CreateTags",
            "ec2:DeleteSecurityGroup",
            "ec2:DeleteTags",
            "ec2:RevokeSecurityGroupEgress",
            "ec2:RevokeSecurityGroupIngress"
          ],
          "Effect": "Allow",
          "Resource": "*",
          "Sid": "ManagePrivateSandboxWorkloadSecurityGroups"
        },
        {
          "Action": [
            "logs:CreateLogGroup",
            "logs:DeleteLogGroup",
            "logs:PutRetentionPolicy",
            "logs:TagResource",
            "logs:UntagResource"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:logs:us-east-2:448871779014:log-group:/aws/ecs/sandbox-workload-dev/*",
          "Sid": "ManageOnlySandboxWorkloadLogs"
        },
        {
          "Action": [
            "ecs:CreateService",
            "ecs:DeleteService",
            "ecs:DeregisterTaskDefinition",
            "ecs:RegisterTaskDefinition",
            "ecs:TagResource",
            "ecs:UntagResource",
            "ecs:UpdateService"
          ],
          "Effect": "Allow",
          "Resource": "*",
          "Sid": "ManagePrivateSandboxWorkloadTaskDefinitionsAndServices"
        },
        {
          "Action": [
            "application-autoscaling:DeleteScalingPolicy",
            "application-autoscaling:DeregisterScalableTarget",
            "application-autoscaling:PutScalingPolicy",
            "application-autoscaling:RegisterScalableTarget",
            "application-autoscaling:TagResource"
          ],
          "Effect": "Allow",
          "Resource": "*",
          "Sid": "ManageSandboxWorkloadAutoscaling"
        },
        {
          "Action": "iam:CreateServiceLinkedRole",
          "Condition": {
            "StringLike": {
              "iam:AWSServiceName": "ecs.application-autoscaling.amazonaws.com"
            }
          },
          "Effect": "Allow",
          "Resource": "arn:aws:iam::448871779014:role/aws-service-role/ecs.application-autoscaling.amazonaws.com/AWSServiceRoleForApplicationAutoScaling_ECSService",
          "Sid": "CreateOnlyEcsAutoscalingServiceLinkedRole"
        },
        {
          "Action": [
            "iam:AttachRolePolicy",
            "iam:CreateRole",
            "iam:DeleteRole",
            "iam:DeleteRolePolicy",
            "iam:DetachRolePolicy",
            "iam:GetRole",
            "iam:GetRolePolicy",
            "iam:ListAttachedRolePolicies",
            "iam:ListRolePolicies",
            "iam:PutRolePolicy",
            "iam:TagRole",
            "iam:UntagRole"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:iam::448871779014:role/ecs/sandbox-workload-dev-*",
          "Sid": "ManageOnlySandboxWorkloadTaskRoles"
        },
        {
          "Action": "iam:PassRole",
          "Condition": {
            "StringEquals": {
              "iam:PassedToService": "ecs-tasks.amazonaws.com"
            }
          },
          "Effect": "Allow",
          "Resource": "arn:aws:iam::448871779014:role/ecs/sandbox-workload-dev-*",
          "Sid": "PassOnlySandboxWorkloadTaskRolesToEcs"
        },
        {
          "Action": [
            "cognito-idp:CreateUserPoolClient",
            "cognito-idp:DeleteUserPoolClient",
            "cognito-idp:UpdateUserPoolClient"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:cognito-idp:us-east-2:448871779014:userpool/*",
          "Sid": "ManageSandboxWorkloadCognitoClients"
        }
      ],
      "Version": "2012-10-17"
    }
    JSON
    )
    error_message = "GOLDEN MASTER: the sandbox-workload dev-apply policy document changed."
  }

}
run "delivery_policy_documents_identity" {
  command = plan

  assert {
    condition = jsondecode(aws_iam_policy.identity_plan.policy) == jsondecode(<<-JSON
    {
      "Statement": [
        {
          "Action": "s3:ListBucket",
          "Condition": {
            "StringLike": {
              "s3:prefix": "gitops/sandbox-delivery/us-east-2/global/*"
            }
          },
          "Effect": "Allow",
          "Resource": "arn:aws:s3:::platform-tf-state-shared-f3ddb8cc",
          "Sid": "ListOnlySandboxDeliveryIdentityStatePrefix"
        },
        {
          "Action": "s3:GetEncryptionConfiguration",
          "Effect": "Allow",
          "Resource": "arn:aws:s3:::platform-tf-state-shared-f3ddb8cc",
          "Sid": "ReadSandboxDeliveryStateBucketEncryption"
        },
        {
          "Action": [
            "s3:GetObject",
            "s3:PutObject"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:s3:::platform-tf-state-shared-f3ddb8cc/gitops/sandbox-delivery/us-east-2/global/*",
          "Sid": "ReadAndWriteOnlySandboxDeliveryIdentityStateObject"
        },
        {
          "Action": [
            "kms:Decrypt",
            "kms:DescribeKey",
            "kms:Encrypt",
            "kms:GenerateDataKey"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:kms:us-east-2:448871779014:key/34605b23-fafd-43f8-b708-db4dbe385189",
          "Sid": "UseOnlyTheStateEncryptionKey"
        },
        {
          "Action": [
            "dynamodb:DeleteItem",
            "dynamodb:DescribeTable",
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:UpdateItem"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:dynamodb:us-east-2:448871779014:table/platform-tf-lock-table",
          "Sid": "LockOnlyTheDedicatedStateTable"
        },
        {
          "Action": [
            "iam:GetPolicy",
            "iam:GetPolicyVersion",
            "iam:GetRole",
            "iam:GetRolePolicy",
            "iam:ListAttachedRolePolicies",
            "iam:ListEntitiesForPolicy",
            "iam:ListPolicies",
            "iam:ListPolicyTags",
            "iam:ListPolicyVersions",
            "iam:ListRolePolicies",
            "iam:ListRoleTags"
          ],
          "Effect": "Allow",
          "Resource": "*",
          "Sid": "ReadSandboxDeliveryIdentity"
        },
        {
          "Action": [
            "iam:GetOpenIDConnectProvider"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:iam::448871779014:oidc-provider/token.actions.githubusercontent.com",
          "Sid": "ReadSandboxGitHubOidcProvider"
        }
      ],
      "Version": "2012-10-17"
    }
    JSON
    )
    error_message = "GOLDEN MASTER: the identity plan policy document changed."
  }

  assert {
    condition = jsondecode(aws_iam_policy.identity_dev_apply.policy) == jsondecode(<<-JSON
    {
      "Statement": [
        {
          "Action": "s3:ListBucket",
          "Condition": {
            "StringLike": {
              "s3:prefix": "gitops/sandbox-delivery/us-east-2/global/*"
            }
          },
          "Effect": "Allow",
          "Resource": "arn:aws:s3:::platform-tf-state-shared-f3ddb8cc",
          "Sid": "ListOnlySandboxDeliveryIdentityStatePrefix"
        },
        {
          "Action": "s3:GetEncryptionConfiguration",
          "Effect": "Allow",
          "Resource": "arn:aws:s3:::platform-tf-state-shared-f3ddb8cc",
          "Sid": "ReadSandboxDeliveryStateBucketEncryption"
        },
        {
          "Action": [
            "s3:GetObject",
            "s3:PutObject"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:s3:::platform-tf-state-shared-f3ddb8cc/gitops/sandbox-delivery/us-east-2/global/*",
          "Sid": "ReadAndWriteOnlySandboxDeliveryIdentityStateObject"
        },
        {
          "Action": [
            "kms:Decrypt",
            "kms:DescribeKey",
            "kms:Encrypt",
            "kms:GenerateDataKey"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:kms:us-east-2:448871779014:key/34605b23-fafd-43f8-b708-db4dbe385189",
          "Sid": "UseOnlyTheStateEncryptionKey"
        },
        {
          "Action": [
            "dynamodb:DeleteItem",
            "dynamodb:DescribeTable",
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:UpdateItem"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:dynamodb:us-east-2:448871779014:table/platform-tf-lock-table",
          "Sid": "LockOnlyTheDedicatedStateTable"
        },
        {
          "Action": [
            "iam:GetPolicy",
            "iam:GetPolicyVersion",
            "iam:GetRole",
            "iam:GetRolePolicy",
            "iam:ListAttachedRolePolicies",
            "iam:ListEntitiesForPolicy",
            "iam:ListPolicies",
            "iam:ListPolicyTags",
            "iam:ListPolicyVersions",
            "iam:ListRolePolicies",
            "iam:ListRoleTags"
          ],
          "Effect": "Allow",
          "Resource": "*",
          "Sid": "ReadSandboxDeliveryIdentity"
        },
        {
          "Action": [
            "iam:GetOpenIDConnectProvider"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:iam::448871779014:oidc-provider/token.actions.githubusercontent.com",
          "Sid": "ReadSandboxGitHubOidcProvider"
        },
        {
          "Action": [
            "iam:CreatePolicyVersion",
            "iam:DeletePolicyVersion",
            "iam:TagPolicy",
            "iam:UntagPolicy"
          ],
          "Effect": "Allow",
          "Resource": [
            "arn:aws:iam::448871779014:policy/devops-aws-infra-sandbox-sandbox-delivery-identity-dev-apply",
            "arn:aws:iam::448871779014:policy/devops-aws-infra-sandbox-sandbox-delivery-identity-plan",
            "arn:aws:iam::448871779014:policy/devops-aws-infra-sandbox-sandbox-network-dev-apply",
            "arn:aws:iam::448871779014:policy/devops-aws-infra-sandbox-sandbox-network-plan",
            "arn:aws:iam::448871779014:policy/devops-aws-infra-sandbox-sandbox-platform-dev-apply",
            "arn:aws:iam::448871779014:policy/devops-aws-infra-sandbox-sandbox-platform-plan",
            "arn:aws:iam::448871779014:policy/devops-aws-infra-sandbox-sandbox-workload-dev-apply",
            "arn:aws:iam::448871779014:policy/devops-aws-infra-sandbox-sandbox-workload-plan"
          ],
          "Sid": "ManageOnlyTrackedSandboxDeliveryPolicyVersions"
        },
        {
          "Action": "iam:CreatePolicy",
          "Condition": {
            "StringEquals": {
              "iam:PolicyName": [
                "devops-aws-infra-sandbox-sandbox-workload-plan",
                "devops-aws-infra-sandbox-sandbox-workload-dev-apply"
              ]
            }
          },
          "Effect": "Allow",
          "Resource": "*",
          "Sid": "CreateOnlySandboxWorkloadDeliveryPolicies"
        },
        {
          "Action": [
            "iam:AttachRolePolicy",
            "iam:DetachRolePolicy"
          ],
          "Effect": "Allow",
          "Resource": [
            "arn:aws:iam::448871779014:role/github-actions/devops-aws-infra-sandbox-dev-apply",
            "arn:aws:iam::448871779014:role/github-actions/devops-aws-infra-sandbox-drift",
            "arn:aws:iam::448871779014:role/github-actions/devops-aws-infra-sandbox-landing-zone",
            "arn:aws:iam::448871779014:role/github-actions/devops-aws-infra-sandbox-plan",
            "arn:aws:iam::448871779014:role/github-actions/devops-aws-infra-sandbox-prod-apply",
            "arn:aws:iam::448871779014:role/github-actions/devops-aws-infra-sandbox-staging-apply"
          ],
          "Sid": "ManageOnlyReviewedSandboxDeliveryPolicyAttachments"
        },
        {
          "Action": [
            "iam:TagRole",
            "iam:UntagRole",
            "iam:UpdateAssumeRolePolicy",
            "iam:UpdateRole",
            "iam:UpdateRoleDescription"
          ],
          "Effect": "Allow",
          "Resource": [
            "arn:aws:iam::448871779014:role/github-actions/devops-aws-infra-sandbox-dev-apply",
            "arn:aws:iam::448871779014:role/github-actions/devops-aws-infra-sandbox-drift",
            "arn:aws:iam::448871779014:role/github-actions/devops-aws-infra-sandbox-landing-zone",
            "arn:aws:iam::448871779014:role/github-actions/devops-aws-infra-sandbox-plan",
            "arn:aws:iam::448871779014:role/github-actions/devops-aws-infra-sandbox-prod-apply",
            "arn:aws:iam::448871779014:role/github-actions/devops-aws-infra-sandbox-staging-apply"
          ],
          "Sid": "ManageOnlyReviewedSandboxOidcRoles"
        },
        {
          "Action": [
            "iam:AddClientIDToOpenIDConnectProvider",
            "iam:RemoveClientIDFromOpenIDConnectProvider",
            "iam:TagOpenIDConnectProvider",
            "iam:UntagOpenIDConnectProvider",
            "iam:UpdateOpenIDConnectProviderThumbprint"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:iam::448871779014:oidc-provider/token.actions.githubusercontent.com",
          "Sid": "ManageOnlyTheSandboxGitHubOidcProvider"
        },
        {
          "Action": [
            "iam:CreateRole",
            "iam:DeleteRole",
            "iam:DeleteRolePolicy",
            "iam:PutRolePolicy",
            "iam:TagRole",
            "iam:UntagRole",
            "iam:UpdateAssumeRolePolicy",
            "iam:UpdateRole",
            "iam:UpdateRoleDescription"
          ],
          "Effect": "Allow",
          "Resource": [
            "arn:aws:iam::448871779014:role/github-actions/devops-aws-infra-sandbox-auth-demo-ecr-push"
          ],
          "Sid": "ManageOnlyReviewedSandboxImagePublisherRoles"
        }
      ],
      "Version": "2012-10-17"
    }
    JSON
    )
    error_message = "GOLDEN MASTER: the identity dev-apply policy document changed."
  }

}

run "role_policy_attachments" {
  command = plan

  assert {
    condition     = length(aws_iam_role_policy_attachment.delivery) == 12
    error_message = "GOLDEN MASTER: the number of reviewed delivery-policy attachments changed."
  }

  # Attachments whose policy_arn is built from local.policy_arns (account ID
  # and a literal policy name), which is known at plan time.
  assert {
    condition = alltrue([
      aws_iam_role_policy_attachment.delivery["network_plan_to_plan"].role == "devops-aws-infra-sandbox-plan",
      aws_iam_role_policy_attachment.delivery["network_plan_to_plan"].policy_arn == "arn:aws:iam::448871779014:policy/devops-aws-infra-sandbox-sandbox-network-plan",
    ])
    error_message = "GOLDEN MASTER: network_plan_to_plan changed."
  }
  assert {
    condition = alltrue([
      aws_iam_role_policy_attachment.delivery["network_plan_to_drift"].role == "devops-aws-infra-sandbox-drift",
      aws_iam_role_policy_attachment.delivery["network_plan_to_drift"].policy_arn == "arn:aws:iam::448871779014:policy/devops-aws-infra-sandbox-sandbox-network-plan",
    ])
    error_message = "GOLDEN MASTER: network_plan_to_drift changed."
  }
  assert {
    condition = alltrue([
      aws_iam_role_policy_attachment.delivery["network_apply_to_dev_apply"].role == "devops-aws-infra-sandbox-dev-apply",
      aws_iam_role_policy_attachment.delivery["network_apply_to_dev_apply"].policy_arn == "arn:aws:iam::448871779014:policy/devops-aws-infra-sandbox-sandbox-network-dev-apply",
    ])
    error_message = "GOLDEN MASTER: network_apply_to_dev_apply changed."
  }
  assert {
    condition = alltrue([
      aws_iam_role_policy_attachment.delivery["platform_plan_to_plan"].role == "devops-aws-infra-sandbox-plan",
      aws_iam_role_policy_attachment.delivery["platform_plan_to_plan"].policy_arn == "arn:aws:iam::448871779014:policy/devops-aws-infra-sandbox-sandbox-platform-plan",
    ])
    error_message = "GOLDEN MASTER: platform_plan_to_plan changed."
  }
  assert {
    condition = alltrue([
      aws_iam_role_policy_attachment.delivery["platform_plan_to_drift"].role == "devops-aws-infra-sandbox-drift",
      aws_iam_role_policy_attachment.delivery["platform_plan_to_drift"].policy_arn == "arn:aws:iam::448871779014:policy/devops-aws-infra-sandbox-sandbox-platform-plan",
    ])
    error_message = "GOLDEN MASTER: platform_plan_to_drift changed."
  }
  assert {
    condition = alltrue([
      aws_iam_role_policy_attachment.delivery["platform_apply_to_dev_apply"].role == "devops-aws-infra-sandbox-dev-apply",
      aws_iam_role_policy_attachment.delivery["platform_apply_to_dev_apply"].policy_arn == "arn:aws:iam::448871779014:policy/devops-aws-infra-sandbox-sandbox-platform-dev-apply",
    ])
    error_message = "GOLDEN MASTER: platform_apply_to_dev_apply changed."
  }
  assert {
    condition = alltrue([
      aws_iam_role_policy_attachment.delivery["identity_plan_to_plan"].role == "devops-aws-infra-sandbox-plan",
      aws_iam_role_policy_attachment.delivery["identity_plan_to_plan"].policy_arn == "arn:aws:iam::448871779014:policy/devops-aws-infra-sandbox-sandbox-delivery-identity-plan",
    ])
    error_message = "GOLDEN MASTER: identity_plan_to_plan changed."
  }
  assert {
    condition = alltrue([
      aws_iam_role_policy_attachment.delivery["identity_plan_to_drift"].role == "devops-aws-infra-sandbox-drift",
      aws_iam_role_policy_attachment.delivery["identity_plan_to_drift"].policy_arn == "arn:aws:iam::448871779014:policy/devops-aws-infra-sandbox-sandbox-delivery-identity-plan",
    ])
    error_message = "GOLDEN MASTER: identity_plan_to_drift changed."
  }
  assert {
    condition = alltrue([
      aws_iam_role_policy_attachment.delivery["identity_apply_to_dev_apply"].role == "devops-aws-infra-sandbox-dev-apply",
      aws_iam_role_policy_attachment.delivery["identity_apply_to_dev_apply"].policy_arn == "arn:aws:iam::448871779014:policy/devops-aws-infra-sandbox-sandbox-delivery-identity-dev-apply",
    ])
    error_message = "GOLDEN MASTER: identity_apply_to_dev_apply changed."
  }

  # These three attach to aws_iam_policy.sandbox_workload_*.arn directly (not
  # through local.policy_arns), which is a computed value and therefore
  # unknown under `command = plan`; only role is asserted here. The policy
  # side of the pairing is pinned by delivery_policy_names and
  # delivery_policy_documents_workload above, and the pairing itself is
  # unchanged source code in attachments.tf.
  assert {
    condition     = aws_iam_role_policy_attachment.delivery["workload_plan_to_plan"].role == "devops-aws-infra-sandbox-plan"
    error_message = "GOLDEN MASTER: workload_plan_to_plan's role changed."
  }
  assert {
    condition     = aws_iam_role_policy_attachment.delivery["workload_plan_to_drift"].role == "devops-aws-infra-sandbox-drift"
    error_message = "GOLDEN MASTER: workload_plan_to_drift's role changed."
  }
  assert {
    condition     = aws_iam_role_policy_attachment.delivery["workload_apply_to_dev_apply"].role == "devops-aws-infra-sandbox-dev-apply"
    error_message = "GOLDEN MASTER: workload_apply_to_dev_apply's role changed."
  }
}
