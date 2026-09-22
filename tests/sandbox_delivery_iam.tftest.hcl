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
    condition     = length(aws_iam_role_policy_attachment.delivery) == 9
    error_message = "Terraform must own every sandbox delivery policy attachment, including plan, drift, and protected dev apply."
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
    condition     = aws_iam_openid_connect_provider.github_actions.tags["IaCOwnership"] == "terraform"
    error_message = "Terraform must persist its ownership tag after CloudFormation stack retirement."
  }
}
