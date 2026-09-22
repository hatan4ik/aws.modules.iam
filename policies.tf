locals {
  sandbox_network_state_prefix  = "gitops/sandbox-network/us-east-2/dev/"
  sandbox_platform_state_prefix = "gitops/sandbox-platform/us-east-2/dev/"
  sandbox_workload_state_prefix = "gitops/sandbox-workload/us-east-2/dev/"

  sandbox_network_state_statements = [
    {
      Sid      = "ListOnlyTheSandboxNetworkStatePrefix"
      Effect   = "Allow"
      Action   = "s3:ListBucket"
      Resource = local.state_bucket_arn
      Condition = {
        StringLike = {
          "s3:prefix" = "${local.sandbox_network_state_prefix}*"
        }
      }
    },
    {
      Sid      = "ReadAndWriteOnlyTheSandboxNetworkStateObject"
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject"]
      Resource = "${local.state_bucket_arn}/${local.sandbox_network_state_prefix}*"
    },
    {
      Sid      = "UseOnlyTheStateEncryptionKey"
      Effect   = "Allow"
      Action   = ["kms:Decrypt", "kms:DescribeKey", "kms:Encrypt", "kms:GenerateDataKey"]
      Resource = local.state_kms_key_arn
    },
    {
      Sid      = "LockOnlyTheDedicatedStateTable"
      Effect   = "Allow"
      Action   = ["dynamodb:DeleteItem", "dynamodb:DescribeTable", "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"]
      Resource = local.state_lock_table_arn
    },
  ]

  sandbox_platform_state_statements = [
    {
      Sid      = "ListOnlySandboxPlatformStatePrefix"
      Effect   = "Allow"
      Action   = "s3:ListBucket"
      Resource = local.state_bucket_arn
      Condition = {
        StringLike = {
          "s3:prefix" = "${local.sandbox_platform_state_prefix}*"
        }
      }
    },
    {
      Sid      = "ReadAndWriteOnlySandboxPlatformStateObject"
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject"]
      Resource = "${local.state_bucket_arn}/${local.sandbox_platform_state_prefix}*"
    },
    {
      Sid      = "UseOnlyTheStateEncryptionKey"
      Effect   = "Allow"
      Action   = ["kms:Decrypt", "kms:DescribeKey", "kms:Encrypt", "kms:GenerateDataKey"]
      Resource = local.state_kms_key_arn
    },
    {
      Sid      = "LockOnlyTheDedicatedStateTable"
      Effect   = "Allow"
      Action   = ["dynamodb:DeleteItem", "dynamodb:DescribeTable", "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"]
      Resource = local.state_lock_table_arn
    },
  ]

  sandbox_workload_state_statements = [
    {
      Sid      = "ListOnlySandboxWorkloadStatePrefix"
      Effect   = "Allow"
      Action   = "s3:ListBucket"
      Resource = local.state_bucket_arn
      Condition = {
        StringLike = {
          "s3:prefix" = "${local.sandbox_workload_state_prefix}*"
        }
      }
    },
    {
      Sid      = "ReadAndWriteOnlySandboxWorkloadStateObject"
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject"]
      Resource = "${local.state_bucket_arn}/${local.sandbox_workload_state_prefix}*"
    },
    {
      Sid      = "UseOnlyTheStateEncryptionKey"
      Effect   = "Allow"
      Action   = ["kms:Decrypt", "kms:DescribeKey", "kms:Encrypt", "kms:GenerateDataKey"]
      Resource = local.state_kms_key_arn
    },
    {
      Sid      = "LockOnlyTheDedicatedStateTable"
      Effect   = "Allow"
      Action   = ["dynamodb:DeleteItem", "dynamodb:DescribeTable", "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"]
      Resource = local.state_lock_table_arn
    },
  ]

  sandbox_network_read_statement = {
    Sid    = "ReadSandboxNetworkResources"
    Effect = "Allow"
    Action = [
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
      "tag:GetResources",
    ]
    Resource = "*"
  }

  sandbox_platform_read_statement = {
    Sid    = "ReadSandboxPlatformResources"
    Effect = "Allow"
    Action = [
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
      "tag:GetResources",
    ]
    Resource = "*"
  }

  sandbox_workload_read_statement = {
    Sid    = "ReadSandboxWorkloadResources"
    Effect = "Allow"
    Action = [
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
      "tag:GetResources",
    ]
    Resource = "*"
  }

  sandbox_network_plan_policy = {
    Version   = "2012-10-17"
    Statement = concat(local.sandbox_network_state_statements, [local.sandbox_network_read_statement])
  }

  sandbox_network_dev_apply_policy = {
    Version = "2012-10-17"
    Statement = concat(local.sandbox_network_state_statements, [
      local.sandbox_network_read_statement,
      {
        Sid    = "ManageOnlyTheSandboxNetworkVpcResources"
        Effect = "Allow"
        Action = [
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
          "ec2:RevokeSecurityGroupIngress",
        ]
        Resource = "*"
      },
      {
        Sid      = "ManageSandboxNetworkFlowLogGroup"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:PutRetentionPolicy", "logs:TagResource", "logs:UntagResource"]
        Resource = "arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/vpc/sandbox-network-dev/flow-logs*"
      },
      {
        Sid      = "CreateDedicatedSandboxNetworkFlowLogKey"
        Effect   = "Allow"
        Action   = ["kms:CreateKey"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Root" = "sandbox-network"
          }
        }
      },
      {
        Sid      = "ManageOnlyTheDedicatedSandboxNetworkFlowLogAlias"
        Effect   = "Allow"
        Action   = ["kms:CreateAlias", "kms:DeleteAlias"]
        Resource = "arn:${data.aws_partition.current.partition}:kms:${var.aws_region}:${var.aws_account_id}:alias/sandbox-network-dev-flow-logs"
      },
      {
        Sid    = "ManageDedicatedSandboxNetworkFlowLogKey"
        Effect = "Allow"
        Action = [
          "kms:CreateAlias",
          "kms:DescribeKey",
          "kms:EnableKeyRotation",
          "kms:GetKeyPolicy",
          "kms:GetKeyRotationStatus",
          "kms:ListAliases",
          "kms:ListResourceTags",
          "kms:PutKeyPolicy",
          "kms:ScheduleKeyDeletion",
          "kms:TagResource",
          "kms:UntagResource",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Root" = "sandbox-network"
          }
        }
      },
      {
        Sid    = "CreateAndPassOnlyTheSandboxNetworkFlowLogRole"
        Effect = "Allow"
        Action = [
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
          "iam:UntagRole",
        ]
        Resource = "arn:${data.aws_partition.current.partition}:iam::${var.aws_account_id}:role/sandbox-network-dev-vpc-flow-logs"
      },
    ])
  }

  sandbox_platform_plan_policy = {
    Version   = "2012-10-17"
    Statement = concat(local.sandbox_platform_state_statements, [local.sandbox_platform_read_statement])
  }

  sandbox_platform_dev_apply_policy = {
    Version = "2012-10-17"
    Statement = concat(local.sandbox_platform_state_statements, [
      local.sandbox_platform_read_statement,
      {
        Sid    = "ManageSandboxPrivateConnectivity"
        Effect = "Allow"
        Action = [
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
          "ec2:RevokeSecurityGroupIngress",
        ]
        Resource = "*"
      },
      {
        Sid      = "ManageSandboxContainerRegistry"
        Effect   = "Allow"
        Action   = ["ecr:CreateRepository", "ecr:DeleteLifecyclePolicy", "ecr:DeleteRepository", "ecr:PutImageScanningConfiguration", "ecr:PutImageTagMutability", "ecr:PutLifecyclePolicy", "ecr:TagResource", "ecr:UntagResource"]
        Resource = "*"
      },
      {
        Sid      = "ManageSandboxEcsCluster"
        Effect   = "Allow"
        Action   = ["ecs:CreateCluster", "ecs:DeleteCluster", "ecs:TagResource", "ecs:UntagResource", "ecs:UpdateCluster"]
        Resource = "*"
      },
      {
        Sid      = "ManageSandboxApplicationLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:PutRetentionPolicy", "logs:TagResource", "logs:UntagResource"]
        Resource = "arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/ecs/sandbox-platform-dev/*"
      },
      {
        Sid      = "CreateDedicatedSandboxPlatformDataKey"
        Effect   = "Allow"
        Action   = ["kms:CreateKey"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Root" = "sandbox-platform"
          }
        }
      },
      {
        Sid    = "ManageDedicatedSandboxPlatformDataKey"
        Effect = "Allow"
        Action = [
          "kms:CreateAlias",
          "kms:CreateGrant",
          "kms:Decrypt",
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
          "kms:UntagResource",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Root" = "sandbox-platform"
          }
        }
      },
      {
        Sid      = "ManageDedicatedSandboxPlatformDataAlias"
        Effect   = "Allow"
        Action   = ["kms:CreateAlias", "kms:DeleteAlias"]
        Resource = "arn:${data.aws_partition.current.partition}:kms:${var.aws_region}:${var.aws_account_id}:alias/sandbox-platform-dev-application-data"
      },
      {
        Sid      = "ManageSandboxSessionTable"
        Effect   = "Allow"
        Action   = ["dynamodb:CreateTable", "dynamodb:DeleteTable", "dynamodb:TagResource", "dynamodb:UntagResource", "dynamodb:UpdateContinuousBackups", "dynamodb:UpdateTable", "dynamodb:UpdateTimeToLive"]
        Resource = "*"
      },
      {
        Sid      = "ManageSandboxCognitoPool"
        Effect   = "Allow"
        Action   = ["cognito-idp:CreateUserPool", "cognito-idp:DeleteUserPool", "cognito-idp:SetUserPoolMfaConfig", "cognito-idp:TagResource", "cognito-idp:UntagResource", "cognito-idp:UpdateUserPool"]
        Resource = "*"
      },
    ])
  }

  sandbox_workload_plan_policy = {
    Version   = "2012-10-17"
    Statement = concat(local.sandbox_workload_state_statements, [local.sandbox_workload_read_statement])
  }

  sandbox_workload_dev_apply_policy = {
    Version = "2012-10-17"
    Statement = concat(local.sandbox_workload_state_statements, [
      local.sandbox_workload_read_statement,
      {
        Sid    = "ManagePrivateSandboxWorkloadSecurityGroups"
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:CreateSecurityGroup",
          "ec2:CreateTags",
          "ec2:DeleteSecurityGroup",
          "ec2:DeleteTags",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
        ]
        Resource = "*"
      },
      {
        Sid      = "ManageOnlySandboxWorkloadLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:PutRetentionPolicy", "logs:TagResource", "logs:UntagResource"]
        Resource = "arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/ecs/sandbox-workload-dev/*"
      },
      {
        Sid    = "ManagePrivateSandboxWorkloadTaskDefinitionsAndServices"
        Effect = "Allow"
        Action = [
          "ecs:CreateService",
          "ecs:DeleteService",
          "ecs:DeregisterTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "ecs:TagResource",
          "ecs:UntagResource",
          "ecs:UpdateService",
        ]
        Resource = "*"
      },
      {
        Sid    = "ManageSandboxWorkloadAutoscaling"
        Effect = "Allow"
        Action = [
          "application-autoscaling:DeleteScalingPolicy",
          "application-autoscaling:DeregisterScalableTarget",
          "application-autoscaling:PutScalingPolicy",
          "application-autoscaling:RegisterScalableTarget",
        ]
        Resource = "*"
      },
      {
        Sid    = "ManageOnlySandboxWorkloadTaskRoles"
        Effect = "Allow"
        Action = [
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
          "iam:UntagRole",
        ]
        Resource = "arn:${data.aws_partition.current.partition}:iam::${var.aws_account_id}:role/ecs/sandbox-workload-dev-*"
      },
      {
        Sid      = "PassOnlySandboxWorkloadTaskRolesToEcs"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "arn:${data.aws_partition.current.partition}:iam::${var.aws_account_id}:role/ecs/sandbox-workload-dev-*"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
      },
      {
        Sid    = "ManageSandboxWorkloadCognitoClients"
        Effect = "Allow"
        Action = [
          "cognito-idp:CreateUserPoolClient",
          "cognito-idp:DeleteUserPoolClient",
          "cognito-idp:UpdateUserPoolClient",
        ]
        Resource = "arn:${data.aws_partition.current.partition}:cognito-idp:${var.aws_region}:${var.aws_account_id}:userpool/*"
      },
    ])
  }

  identity_state_statements = [
    {
      Sid      = "ListOnlySandboxDeliveryIdentityStatePrefix"
      Effect   = "Allow"
      Action   = "s3:ListBucket"
      Resource = local.state_bucket_arn
      Condition = {
        StringLike = {
          "s3:prefix" = "${var.state_backend.key_prefix}*"
        }
      }
    },
    {
      Sid      = "ReadSandboxDeliveryStateBucketEncryption"
      Effect   = "Allow"
      Action   = "s3:GetEncryptionConfiguration"
      Resource = local.state_bucket_arn
    },
    {
      Sid      = "ReadAndWriteOnlySandboxDeliveryIdentityStateObject"
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject"]
      Resource = local.state_object_arn
    },
    {
      Sid      = "UseOnlyTheStateEncryptionKey"
      Effect   = "Allow"
      Action   = ["kms:Decrypt", "kms:DescribeKey", "kms:Encrypt", "kms:GenerateDataKey"]
      Resource = local.state_kms_key_arn
    },
    {
      Sid      = "LockOnlyTheDedicatedStateTable"
      Effect   = "Allow"
      Action   = ["dynamodb:DeleteItem", "dynamodb:DescribeTable", "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"]
      Resource = local.state_lock_table_arn
    },
  ]

  identity_read_statement = {
    Sid    = "ReadSandboxDeliveryIdentity"
    Effect = "Allow"
    Action = [
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
      "iam:ListRoleTags",
    ]
    Resource = "*"
  }

  identity_oidc_provider_read_statement = {
    Sid      = "ReadSandboxGitHubOidcProvider"
    Effect   = "Allow"
    Action   = ["iam:GetOpenIDConnectProvider"]
    Resource = local.github_oidc_provider_arn
  }

  identity_plan_policy = {
    Version   = "2012-10-17"
    Statement = concat(local.identity_state_statements, [local.identity_read_statement, local.identity_oidc_provider_read_statement])
  }

  identity_dev_apply_policy = {
    Version = "2012-10-17"
    Statement = concat(local.identity_state_statements, [
      local.identity_read_statement,
      local.identity_oidc_provider_read_statement,
      {
        Sid      = "ManageOnlyTrackedSandboxDeliveryPolicyVersions"
        Effect   = "Allow"
        Action   = ["iam:CreatePolicyVersion", "iam:DeletePolicyVersion", "iam:TagPolicy", "iam:UntagPolicy"]
        Resource = values(local.policy_arns)
      },
      {
        Sid      = "CreateOnlySandboxWorkloadDeliveryPolicies"
        Effect   = "Allow"
        Action   = "iam:CreatePolicy"
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:PolicyName" = [
              local.policy_names.sandbox_workload_plan,
              local.policy_names.sandbox_workload_dev_apply,
            ]
          }
        }
      },
      {
        Sid      = "ManageOnlyReviewedSandboxDeliveryPolicyAttachments"
        Effect   = "Allow"
        Action   = ["iam:AttachRolePolicy", "iam:DetachRolePolicy"]
        Resource = values(local.github_role_arns)
      },
      {
        Sid      = "ManageOnlyReviewedSandboxOidcRoles"
        Effect   = "Allow"
        Action   = ["iam:TagRole", "iam:UntagRole", "iam:UpdateAssumeRolePolicy", "iam:UpdateRole", "iam:UpdateRoleDescription"]
        Resource = values(local.github_role_arns)
      },
      {
        Sid      = "ManageOnlyTheSandboxGitHubOidcProvider"
        Effect   = "Allow"
        Action   = ["iam:AddClientIDToOpenIDConnectProvider", "iam:RemoveClientIDFromOpenIDConnectProvider", "iam:TagOpenIDConnectProvider", "iam:UntagOpenIDConnectProvider", "iam:UpdateOpenIDConnectProviderThumbprint"]
        Resource = local.github_oidc_provider_arn
      },
      ], length(local.image_publisher_role_arns) == 0 ? [] : [
      {
        Sid    = "ManageOnlyReviewedSandboxImagePublisherRoles"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:DeleteRolePolicy",
          "iam:PutRolePolicy",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:UpdateRole",
          "iam:UpdateRoleDescription",
        ]
        Resource = values(local.image_publisher_role_arns)
      },
    ])
  }
}
