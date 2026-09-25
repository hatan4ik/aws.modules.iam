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
  state_backend = {
    bucket_name     = "platform-tf-state-shared-f3ddb8cc"
    key_prefix      = "gitops/sandbox-delivery/us-east-2/global/"
    kms_key_id      = "34605b23-fafd-43f8-b708-db4dbe385189"
    lock_table_name = "platform-tf-lock-table"
  }
}

run "plans_all_sandbox_delivery_policies_and_only_reviewed_attachments" {
  command = plan

  assert {
    condition     = length(aws_iam_role_policy_attachment.delivery) == 12
    error_message = "Terraform must own every sandbox delivery policy attachment, including plan, drift, and protected dev apply."
  }

  assert {
    condition     = aws_iam_policy.sandbox_workload_plan.name == "devops-aws-infra-sandbox-sandbox-workload-plan"
    error_message = "The workload plan policy name must remain stable and independently auditable."
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_policy.sandbox_workload_dev_apply.policy).Statement :
      statement.Sid == "PassOnlySandboxWorkloadTaskRolesToEcs" ? statement.Condition.StringEquals["iam:PassedToService"] == "ecs-tasks.amazonaws.com" : false
    ])
    error_message = "The workload apply role may pass only workload task roles to ECS tasks."
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_policy.sandbox_workload_plan.policy).Statement :
      statement.Sid == "ReadSandboxPlatformStateForWorkload" ? statement.Resource == "arn:aws:s3:::platform-tf-state-shared-f3ddb8cc/gitops/sandbox-platform/us-east-2/dev/*" : false
    ])
    error_message = "The workload plan role must be able to read only the sandbox-platform state required for platform outputs."
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_policy.sandbox_workload_dev_apply.policy).Statement :
      statement.Sid == "ManageSandboxWorkloadAutoscaling" ? contains(statement.Action, "application-autoscaling:TagResource") : false
    ])
    error_message = "The workload apply role must be able to tag scalable targets created by Terraform."
  }

  assert {
    condition = alltrue([
      for policy in [aws_iam_policy.sandbox_workload_plan.policy, aws_iam_policy.sandbox_workload_dev_apply.policy] : anytrue([
        for statement in jsondecode(policy).Statement :
        statement.Sid == "ReadOnlySandboxWorkloadAutoscalingTags" ? statement.Action == "application-autoscaling:ListTagsForResource" && statement.Resource == "arn:aws:application-autoscaling:us-east-2:448871779014:scalable-target/*" : false
      ])
    ])
    error_message = "Workload plan and apply roles must read tags only from scalable targets in the approved account and Region."
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_policy.sandbox_workload_dev_apply.policy).Statement :
      statement.Sid == "CreateOnlyEcsAutoscalingServiceLinkedRole" ? statement.Resource == "arn:aws:iam::448871779014:role/aws-service-role/ecs.application-autoscaling.amazonaws.com/AWSServiceRoleForApplicationAutoScaling_ECSService" && statement.Condition.StringLike["iam:AWSServiceName"] == "ecs.application-autoscaling.amazonaws.com" : false
    ])
    error_message = "The workload apply role may create only the ECS Application Auto Scaling service-linked role when the account lacks it."
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_policy.sandbox_platform_dev_apply.policy).Statement :
      statement.Sid == "ManageDedicatedSandboxPlatformDataKey" ? contains(statement.Action, "kms:DeleteAlias") && statement.Condition.StringEquals["aws:ResourceTag/Root"] == "sandbox-platform" : false
    ])
    error_message = "The platform apply role must have KMS-key authorization to delete only aliases on Terraform-owned sandbox-platform keys."
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_policy.sandbox_platform_dev_apply.policy).Statement :
      statement.Sid == "ManageDedicatedSandboxPlatformDataAlias" ? statement.Resource == "arn:aws:kms:us-east-2:448871779014:alias/sandbox-platform-dev-application-data" : false
    ])
    error_message = "The platform apply role must retain the exact application-data alias scope."
  }

  assert {
    condition     = aws_iam_policy.sandbox_platform_plan.name == "devops-aws-infra-sandbox-sandbox-platform-plan"
    error_message = "The platform plan policy name must remain stable for zero-change CloudFormation adoption."
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_policy.identity_dev_apply.policy).Statement :
      statement.Sid == "ManageOnlyTrackedSandboxDeliveryPolicyVersions" ? contains(statement.Action, "iam:CreatePolicyVersion") : false
    ])
    error_message = "The protected identity apply role must be able to publish only tracked policy revisions."
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_policy.identity_plan.policy).Statement :
      statement.Sid == "ReadSandboxGitHubOidcProvider" ? contains(statement.Action, "iam:GetOpenIDConnectProvider") && statement.Resource == "arn:aws:iam::448871779014:oidc-provider/token.actions.githubusercontent.com" : false
    ])
    error_message = "The plan and drift roles must be able to read the tracked GitHub OIDC provider without receiving broad provider access."
  }

  assert {
    condition     = length(aws_iam_role.github_actions) == 6 && aws_iam_openid_connect_provider.github_actions.url == "https://token.actions.githubusercontent.com"
    error_message = "Terraform must own the GitHub OIDC provider and every sandbox delivery role before CloudFormation is retired."
  }

  assert {
    condition     = length(aws_iam_role.image_publisher) == 0
    error_message = "Image-publisher roles must be opt-in and absent when no application publisher is declared."
  }

  assert {
    condition     = aws_iam_openid_connect_provider.github_actions.tags["IaCOwnership"] == "terraform"
    error_message = "Terraform must persist its ownership tag after CloudFormation stack retirement."
  }
}

run "plans_a_dedicated_ecr_publisher_for_the_declared_repository_only" {
  command = plan

  variables {
    image_publishers = {
      "auth-demo" = {
        github_subject  = "repo:hatan4ik/sandbox-auth-demo:environment:dev"
        repository_name = "sandbox-platform-dev-application"
      }
    }
  }

  assert {
    condition     = local.image_publisher_role_names["auth-demo"] == "devops-aws-infra-sandbox-auth-demo-ecr-push"
    error_message = "The image publisher must have a deterministic, isolated role name."
  }

  assert {
    condition     = length(aws_iam_role.image_publisher) == 1 && length(aws_iam_role_policy.image_publisher) == 1
    error_message = "A declared image publisher must create exactly one role and one inline ECR policy."
  }
}
