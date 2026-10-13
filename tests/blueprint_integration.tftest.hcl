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
  blueprint_integration_runners = {
    "blueprint-private" = {
      github_subject  = "repo:hatan4ik@12816536/aws.modules.blueprint-microservice-private@1406835455:environment:integration"
      resource_prefix = "bp-e2e-"
    }
  }
  state_backend = {
    bucket_name     = "platform-tf-state-shared-f3ddb8cc"
    key_prefix      = "gitops/sandbox-delivery/us-east-2/global/"
    kms_key_id      = "34605b23-fafd-43f8-b708-db4dbe385189"
    lock_table_name = "platform-tf-lock-table"
  }
}

run "creates_one_isolated_runner_with_four_reviewable_policies" {
  command = plan

  assert {
    condition     = length(aws_iam_role.blueprint_integration) == 1 && length(aws_iam_policy.blueprint_integration) == 4 && length(aws_iam_policy.blueprint_integration_boundary) == 1 && length(aws_iam_role_policy_attachment.blueprint_integration) == 4
    error_message = "One declared integration runner must create one role, four runner policies, one permissions boundary, and four attachments."
  }

  assert {
    condition     = aws_iam_role.blueprint_integration["blueprint-private"].name == "devops-aws-infra-sandbox-blueprint-private-integration"
    error_message = "The integration runner role name must be deterministic."
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_policy.blueprint_integration["blueprint-private/identity"].policy).Statement :
      statement.Sid == "CreateDisposableRolesOnlyWithBoundary" ? statement.Condition.ArnEquals["iam:PermissionsBoundary"] == "arn:aws:iam::448871779014:policy/devops-aws-infra-sandbox-blueprint-private-integration-boundary" : false
    ])
    error_message = "The runner must be unable to create a disposable role without the Terraform-owned permissions boundary."
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_policy.blueprint_integration["blueprint-private/identity"].policy).Statement :
      statement.Sid == "AttachOnlyEcsExecutionManagedPolicy" ? statement.Condition.ArnEquals["iam:PolicyARN"] == "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy" : false
    ])
    error_message = "The runner may attach only the AWS-managed ECS task execution policy to disposable roles."
  }

  assert {
    condition = alltrue([
      for policy in values(aws_iam_policy.blueprint_integration) :
      alltrue(flatten([
        for statement in jsondecode(policy.policy).Statement : [
          for action in try(tolist(statement.Action), [statement.Action]) :
          action != "*" && !endswith(action, ":*")
        ]
      ]))
    ])
    error_message = "Integration policies must never grant a global or full-service wildcard action."
  }
}

run "scopes_registry_identity_and_log_permissions_to_disposable_names" {
  command = plan

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_policy.blueprint_integration["blueprint-private/registry"].policy).Statement :
      statement.Sid == "ManageOnlyDisposableCacheRepositories" ? statement.Resource == "arn:aws:ecr:us-east-2:448871779014:repository/bp-e2e-*" : false
    ])
    error_message = "The registry policy may manage only bp-e2e repositories in the approved account and Region."
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_policy.blueprint_integration["blueprint-private/identity"].policy).Statement :
      statement.Sid == "PassOnlyDisposableRolesToExpectedServices" ? statement.Resource == "arn:aws:iam::448871779014:role/bp-e2e-*" && toset(statement.Condition.StringEquals["iam:PassedToService"]) == toset(["ecs-tasks.amazonaws.com", "vpc-flow-logs.amazonaws.com"]) : false
    ])
    error_message = "PassRole must be limited to disposable roles and the two services that consume them."
  }

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_policy.blueprint_integration["blueprint-private/runtime"].policy).Statement :
      statement.Sid == "ManageOnlyDisposableLogGroups" ? toset(statement.Resource) == toset([
        "arn:aws:logs:us-east-2:448871779014:log-group:/aws/ecs/bp-e2e-*",
        "arn:aws:logs:us-east-2:448871779014:log-group:/aws/vpc/bp-e2e-*/flow-logs",
      ]) : false
    ])
    error_message = "CloudWatch Logs writes must be restricted to the disposable integration log groups."
  }
}

run "lets_the_delivery_root_manage_only_the_declared_runner_identity" {
  command = plan

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_iam_policy.identity_dev_apply.policy).Statement :
      statement.Sid == "AttachOnlyReviewedBlueprintIntegrationPolicies" ? statement.Resource == ["arn:aws:iam::448871779014:role/github-actions/devops-aws-infra-sandbox-blueprint-private-integration"] && toset(statement.Condition.ArnEquals["iam:PolicyARN"]) == toset(values(local.blueprint_integration_policy_arns)) : false
    ])
    error_message = "The delivery apply role may attach only the four reviewed policies to the one declared integration role."
  }
}
