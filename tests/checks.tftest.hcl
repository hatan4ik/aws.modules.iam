# checks.tf's advisory check: it warns without failing a real
# terraform plan or apply. Under `terraform test`, a failing check fails the
# run unless the run lists it in expect_failures (see
# _common-v1-uplift-rules.md's known traps), so the "should warn" scenario
# below is written that way; the baseline run proves the check does not fire for
# sandbox-delivery's real inputs.

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

run "check_does_not_fire_for_the_real_sandbox_delivery_inputs" {
  command = plan

  assert {
    condition     = aws_iam_openid_connect_provider.github_actions.url == "https://token.actions.githubusercontent.com"
    error_message = "The real inputs (one thumbprint) must satisfy the advisory check without a warning."
  }
}

run "github_oidc_thumbprints_present_warns_when_the_set_is_empty" {
  command = plan

  variables {
    github_oidc_thumbprints = []
  }

  expect_failures = [check.github_oidc_thumbprints_present]
}
