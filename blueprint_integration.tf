# Opt-in identities for the real-account end-to-end suite of
# aws.modules.blueprint-microservice-private. Each runner trusts one immutable
# GitHub repository/environment subject. Four independently reviewable managed
# policies keep every document below IAM's size limit and isolate networking,
# runtime, identity/encryption, and registry permissions.

locals {
  blueprint_integration_policy_documents = merge([
    for key, runner in var.blueprint_integration_runners : {
      "${key}/network" = {
        Version = "2012-10-17"
        Statement = [
          {
            Sid    = "ReadRegionalNetworkAndLoadBalancerState"
            Effect = "Allow"
            Action = [
              "ec2:Describe*",
              "ec2:GetSecurityGroupsForVpc",
              "ec2:GetVpcResourcesBlockingEncryptionEnforcement",
              "elasticloadbalancing:Describe*",
            ]
            Resource = "*"
            Condition = {
              StringEquals = { "aws:RequestedRegion" = var.aws_region }
            }
          },
          {
            Sid    = "ManageDisposableVpcTopology"
            Effect = "Allow"
            Action = [
              "ec2:AllocateAddress",
              "ec2:AssociateRouteTable",
              "ec2:AttachInternetGateway",
              "ec2:AuthorizeSecurityGroupEgress",
              "ec2:AuthorizeSecurityGroupIngress",
              "ec2:CreateFlowLogs",
              "ec2:CreateInternetGateway",
              "ec2:CreateNatGateway",
              "ec2:CreateRoute",
              "ec2:CreateRouteTable",
              "ec2:CreateSecurityGroup",
              "ec2:CreateSubnet",
              "ec2:CreateTags",
              "ec2:CreateVpc",
              "ec2:CreateVpcEncryptionControl",
              "ec2:CreateVpcEndpoint",
              "ec2:DeleteFlowLogs",
              "ec2:DeleteInternetGateway",
              "ec2:DeleteNatGateway",
              "ec2:DeleteRoute",
              "ec2:DeleteRouteTable",
              "ec2:DeleteSecurityGroup",
              "ec2:DeleteSubnet",
              "ec2:DeleteTags",
              "ec2:DeleteVpc",
              "ec2:DeleteVpcEncryptionControl",
              "ec2:DeleteVpcEndpoints",
              "ec2:DetachInternetGateway",
              "ec2:DisassociateRouteTable",
              "ec2:ModifySecurityGroupRules",
              "ec2:ModifySubnetAttribute",
              "ec2:ModifyVpcAttribute",
              "ec2:ModifyVpcEndpoint",
              "ec2:ReleaseAddress",
              "ec2:ReplaceRoute",
              "ec2:ReplaceRouteTableAssociation",
              "ec2:RevokeSecurityGroupEgress",
              "ec2:RevokeSecurityGroupIngress",
            ]
            Resource = "*"
            Condition = {
              StringEquals = { "aws:RequestedRegion" = var.aws_region }
            }
          },
          {
            Sid    = "ManageDisposableLoadBalancers"
            Effect = "Allow"
            Action = [
              "elasticloadbalancing:AddTags",
              "elasticloadbalancing:CreateListener",
              "elasticloadbalancing:CreateLoadBalancer",
              "elasticloadbalancing:CreateRule",
              "elasticloadbalancing:CreateTargetGroup",
              "elasticloadbalancing:DeleteListener",
              "elasticloadbalancing:DeleteLoadBalancer",
              "elasticloadbalancing:DeleteRule",
              "elasticloadbalancing:DeleteTargetGroup",
              "elasticloadbalancing:DeregisterTargets",
              "elasticloadbalancing:ModifyListener",
              "elasticloadbalancing:ModifyLoadBalancerAttributes",
              "elasticloadbalancing:ModifyRule",
              "elasticloadbalancing:ModifyTargetGroup",
              "elasticloadbalancing:ModifyTargetGroupAttributes",
              "elasticloadbalancing:RegisterTargets",
              "elasticloadbalancing:RemoveTags",
              "elasticloadbalancing:SetRulePriorities",
              "elasticloadbalancing:SetSecurityGroups",
              "elasticloadbalancing:SetSubnets",
            ]
            Resource = "*"
            Condition = {
              StringEquals = { "aws:RequestedRegion" = var.aws_region }
            }
          },
        ]
      }

      "${key}/runtime" = {
        Version = "2012-10-17"
        Statement = [
          {
            Sid    = "ReadDisposableRuntimeState"
            Effect = "Allow"
            Action = [
              "ecs:DescribeClusters",
              "ecs:DescribeServices",
              "ecs:DescribeTaskDefinition",
              "ecs:DescribeTasks",
              "ecs:ListClusters",
              "ecs:ListServices",
              "ecs:ListTagsForResource",
              "ecs:ListTaskDefinitions",
              "ecs:ListTasks",
              "logs:DescribeLogGroups",
              "logs:ListTagsForResource",
            ]
            Resource = "*"
            Condition = {
              StringEquals = { "aws:RequestedRegion" = var.aws_region }
            }
          },
          {
            Sid    = "ManageDisposableEcsRuntime"
            Effect = "Allow"
            Action = [
              "ecs:CreateCluster",
              "ecs:CreateService",
              "ecs:DeleteCluster",
              "ecs:DeleteService",
              "ecs:DeregisterTaskDefinition",
              "ecs:RegisterTaskDefinition",
              "ecs:TagResource",
              "ecs:UntagResource",
              "ecs:UpdateService",
            ]
            Resource = "*"
            Condition = {
              StringEquals = { "aws:RequestedRegion" = var.aws_region }
            }
          },
          {
            Sid    = "ManageOnlyDisposableLogGroups"
            Effect = "Allow"
            Action = [
              "logs:AssociateKmsKey",
              "logs:CreateLogGroup",
              "logs:DeleteLogGroup",
              "logs:DeleteRetentionPolicy",
              "logs:DisassociateKmsKey",
              "logs:PutRetentionPolicy",
              "logs:TagResource",
              "logs:UntagResource",
            ]
            Resource = [
              "arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/ecs/${runner.resource_prefix}*",
              "arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/vpc/${runner.resource_prefix}*/flow-logs",
            ]
          },
        ]
      }

      "${key}/identity" = {
        Version = "2012-10-17"
        Statement = [
          {
            Sid    = "ReadOnlyDisposableRoles"
            Effect = "Allow"
            Action = [
              "iam:GetRole",
              "iam:GetRolePolicy",
              "iam:ListAttachedRolePolicies",
              "iam:ListInstanceProfilesForRole",
              "iam:ListRolePolicies",
              "iam:ListRoleTags",
            ]
            Resource = "arn:${data.aws_partition.current.partition}:iam::${var.aws_account_id}:role/${runner.resource_prefix}*"
          },
          {
            Sid    = "ManageOnlyDisposableRoles"
            Effect = "Allow"
            Action = [
              "iam:DeleteRole",
              "iam:DeleteRolePolicy",
              "iam:DeleteRolePermissionsBoundary",
              "iam:PutRolePolicy",
              "iam:TagRole",
              "iam:UntagRole",
              "iam:UpdateAssumeRolePolicy",
              "iam:UpdateRole",
              "iam:UpdateRoleDescription",
            ]
            Resource = "arn:${data.aws_partition.current.partition}:iam::${var.aws_account_id}:role/${runner.resource_prefix}*"
          },
          {
            Sid      = "CreateDisposableRolesOnlyWithBoundary"
            Effect   = "Allow"
            Action   = ["iam:CreateRole", "iam:PutRolePermissionsBoundary"]
            Resource = "arn:${data.aws_partition.current.partition}:iam::${var.aws_account_id}:role/${runner.resource_prefix}*"
            Condition = {
              ArnEquals = {
                "iam:PermissionsBoundary" = local.blueprint_integration_boundary_policy_arns[key]
              }
            }
          },
          {
            Sid      = "AttachOnlyEcsExecutionManagedPolicy"
            Effect   = "Allow"
            Action   = ["iam:AttachRolePolicy", "iam:DetachRolePolicy"]
            Resource = "arn:${data.aws_partition.current.partition}:iam::${var.aws_account_id}:role/${runner.resource_prefix}*"
            Condition = {
              ArnEquals = {
                "iam:PolicyARN" = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
              }
            }
          },
          {
            Sid      = "PassOnlyDisposableRolesToExpectedServices"
            Effect   = "Allow"
            Action   = "iam:PassRole"
            Resource = "arn:${data.aws_partition.current.partition}:iam::${var.aws_account_id}:role/${runner.resource_prefix}*"
            Condition = {
              StringEquals = {
                "iam:PassedToService" = [
                  "ecs-tasks.amazonaws.com",
                  "vpc-flow-logs.amazonaws.com",
                ]
              }
            }
          },
          {
            Sid    = "ReadDisposableKeys"
            Effect = "Allow"
            Action = [
              "kms:DescribeKey",
              "kms:GetKeyPolicy",
              "kms:GetKeyRotationStatus",
              "kms:ListResourceTags",
            ]
            Resource = "arn:${data.aws_partition.current.partition}:kms:${var.aws_region}:${var.aws_account_id}:key/*"
            Condition = {
              StringEquals = {
                "aws:ResourceTag/IntegrationTest" = "aws.modules.blueprint-microservice-private"
              }
            }
          },
          {
            Sid      = "ListRegionalKeyAliases"
            Effect   = "Allow"
            Action   = "kms:ListAliases"
            Resource = "*"
            Condition = {
              StringEquals = { "aws:RequestedRegion" = var.aws_region }
            }
          },
          {
            Sid      = "CreateOnlyTaggedDisposableKeys"
            Effect   = "Allow"
            Action   = "kms:CreateKey"
            Resource = "*"
            Condition = {
              StringEquals = {
                "aws:RequestTag/IntegrationTest" = "aws.modules.blueprint-microservice-private"
                "aws:RequestTag/Disposable"      = "true"
                "aws:RequestedRegion"            = var.aws_region
              }
            }
          },
          {
            Sid    = "ManageOnlyTaggedDisposableKeys"
            Effect = "Allow"
            Action = [
              "kms:CancelKeyDeletion",
              "kms:EnableKeyRotation",
              "kms:PutKeyPolicy",
              "kms:ScheduleKeyDeletion",
              "kms:TagResource",
              "kms:UntagResource",
            ]
            Resource = "arn:${data.aws_partition.current.partition}:kms:${var.aws_region}:${var.aws_account_id}:key/*"
            Condition = {
              StringEquals = {
                "aws:ResourceTag/IntegrationTest" = "aws.modules.blueprint-microservice-private"
              }
            }
          },
          {
            Sid    = "ManageOnlyDisposableKeyAlias"
            Effect = "Allow"
            Action = [
              "kms:CreateAlias",
              "kms:DeleteAlias",
              "kms:UpdateAlias",
            ]
            Resource = [
              "arn:${data.aws_partition.current.partition}:kms:${var.aws_region}:${var.aws_account_id}:alias/${runner.resource_prefix}*-flow-logs",
              "arn:${data.aws_partition.current.partition}:kms:${var.aws_region}:${var.aws_account_id}:key/*",
            ]
          },
        ]
      }

      "${key}/registry" = {
        Version = "2012-10-17"
        Statement = [
          {
            Sid      = "PullThroughCacheRules"
            Effect   = "Allow"
            Action   = ["ecr:CreatePullThroughCacheRule", "ecr:DeletePullThroughCacheRule", "ecr:DescribePullThroughCacheRules"]
            Resource = "*"
            Condition = {
              StringEquals = { "aws:RequestedRegion" = var.aws_region }
            }
          },
          {
            Sid      = "RegistryLogin"
            Effect   = "Allow"
            Action   = "ecr:GetAuthorizationToken"
            Resource = "*"
            Condition = {
              StringEquals = { "aws:RequestedRegion" = var.aws_region }
            }
          },
          {
            Sid    = "ManageOnlyDisposableCacheRepositories"
            Effect = "Allow"
            Action = [
              "ecr:BatchCheckLayerAvailability",
              "ecr:BatchDeleteImage",
              "ecr:BatchGetImage",
              "ecr:BatchImportUpstreamImage",
              "ecr:CreateRepository",
              "ecr:DeleteRepository",
              "ecr:DescribeImages",
              "ecr:DescribeRepositories",
              "ecr:ListImages",
              "ecr:ListTagsForResource",
              "ecr:TagResource",
              "ecr:UntagResource",
            ]
            Resource = "arn:${data.aws_partition.current.partition}:ecr:${var.aws_region}:${var.aws_account_id}:repository/${runner.resource_prefix}*"
          },
          {
            Sid    = "CreateOnlyRequiredServiceLinkedRoles"
            Effect = "Allow"
            Action = "iam:CreateServiceLinkedRole"
            Resource = [
              "arn:${data.aws_partition.current.partition}:iam::${var.aws_account_id}:role/aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS",
              "arn:${data.aws_partition.current.partition}:iam::${var.aws_account_id}:role/aws-service-role/elasticloadbalancing.amazonaws.com/AWSServiceRoleForElasticLoadBalancing",
              "arn:${data.aws_partition.current.partition}:iam::${var.aws_account_id}:role/aws-service-role/pullthroughcache.ecr.amazonaws.com/AWSServiceRoleForECRPullThroughCache",
            ]
            Condition = {
              StringEquals = {
                "iam:AWSServiceName" = [
                  "ecs.amazonaws.com",
                  "elasticloadbalancing.amazonaws.com",
                  "pullthroughcache.ecr.amazonaws.com",
                ]
              }
            }
          },
        ]
      }
    }
  ]...)
}

resource "aws_iam_role" "blueprint_integration" {
  for_each = var.blueprint_integration_runners

  name                 = local.blueprint_integration_role_names[each.key]
  path                 = "/github-actions/"
  description          = "GitHub OIDC runner for disposable ${each.key} blueprint integration tests."
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
    Purpose = "github-actions-blueprint-integration"
  })

  lifecycle {
    precondition {
      condition     = length(local.blueprint_integration_role_names[each.key]) <= 64
      error_message = "role_prefix and blueprint integration key ${each.key} make the IAM role name exceed 64 characters."
    }
  }
}

resource "aws_iam_policy" "blueprint_integration" {
  for_each = local.blueprint_integration_policy_documents

  name        = local.blueprint_integration_policy_names[each.key]
  description = "${split("/", each.key)[1]} permissions for the disposable ${split("/", each.key)[0]} blueprint integration runner."
  policy      = jsonencode(each.value)
  tags        = local.github_oidc_tags
}

resource "aws_iam_policy" "blueprint_integration_boundary" {
  for_each = var.blueprint_integration_runners

  name        = local.blueprint_integration_boundary_policy_names[each.key]
  description = "Maximum effective permissions for disposable ${each.key} ECS and VPC Flow Logs roles."
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
        Sid    = "PullOnlyDisposablePrivateImages"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
        ]
        Resource = "arn:${data.aws_partition.current.partition}:ecr:${var.aws_region}:${var.aws_account_id}:repository/${each.value.resource_prefix}*"
      },
      {
        Sid    = "WriteOnlyDisposableLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/ecs/${each.value.resource_prefix}*:log-stream:*",
          "arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/vpc/${each.value.resource_prefix}*/flow-logs:log-stream:*",
        ]
      },
    ]
  })
  tags = local.github_oidc_tags
}

resource "aws_iam_role_policy_attachment" "blueprint_integration" {
  for_each = local.blueprint_integration_policy_documents

  role       = aws_iam_role.blueprint_integration[split("/", each.key)[0]].name
  policy_arn = aws_iam_policy.blueprint_integration[each.key].arn
}
