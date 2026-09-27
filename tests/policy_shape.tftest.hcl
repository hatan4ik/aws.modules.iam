# Structural proof that every rendered policy document stays within this
# module's whole reason to exist: bounded, reviewable IAM grants. Unlike the
# other test files, this one does not pin specific values; it holds for any
# valid input, including sandbox-delivery's real one.
#
# Two invariants, checked by decoding every policy document this module can
# render and inspecting its Statement list directly (not by reading the HCL):
#
#   1. No statement's Action is a bare "*" or a full-service wildcard such as
#      "iam:*" or "*:*" (matched as any action string ending in the literal
#      ":*", which "ec2:Describe*" and similar prefix wildcards do not; only
#      "<service-or-*>:*" does). A full-service or global wildcard action is
#      never required by anything this module does today.
#   2. No statement grants a mutating (non-Get/List) "iam:" action against an
#      unscoped Resource = "*" without a Condition narrowing it. Every
#      mutating iam: statement in this module's policies today either targets
#      specific role/policy ARNs (including a wildcard *path*, which is a
#      scoped resource pattern, not Resource = "*" itself) or, for the one
#      exception that has no resource-level support in IAM
#      (CreateOnlySandboxWorkloadDeliveryPolicies's iam:CreatePolicy), carries
#      a Condition that pins it to two named policy names. This check is
#      deliberately scoped to iam: actions: several non-IAM statements
#      (for example ManageOnlyTheSandboxNetworkVpcResources's EC2 grants) use
#      Resource = "*" for actions that AWS itself gives no resource-level
#      permission for, which is normal, existing, frozen behavior, not
#      something this test should ever flag.
#
# Both invariants are asserted with `command = plan` against every one of the
# eight delivery policies and, when declared, the image-publisher inline
# policy, using generic (non-production) inputs, so a future change to any
# policy document is caught here regardless of which caller happens to be
# exercised elsewhere.

mock_provider "aws" {}

override_data {
  target = data.aws_partition.current
  values = {
    partition = "aws"
  }
}

variables {
  aws_account_id        = "111122223333"
  aws_region            = "eu-west-1"
  role_prefix           = "acme-platform"
  github_subject_prefix = "repo:acme-corp/platform-infra"
  github_oidc_thumbprints = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
  ]
  image_publishers = {
    "auth-demo" = {
      github_subject  = "repo:acme-corp/sandbox-auth-demo:environment:dev"
      repository_name = "acme-platform-dev-application"
    }
  }
  state_backend = {
    bucket_name     = "acme-tf-state"
    key_prefix      = "gitops/identity/eu-west-1/global/"
    kms_key_id      = "11112222-3333-4444-5555-666677778888"
    lock_table_name = "acme-tf-lock"
  }
}

run "no_statement_grants_a_full_service_or_global_wildcard_action" {
  command = plan

  assert {
    condition = alltrue(flatten([
      for policy_json in [
        aws_iam_policy.sandbox_network_plan.policy,
        aws_iam_policy.sandbox_network_dev_apply.policy,
        aws_iam_policy.sandbox_platform_plan.policy,
        aws_iam_policy.sandbox_platform_dev_apply.policy,
        aws_iam_policy.sandbox_workload_plan.policy,
        aws_iam_policy.sandbox_workload_dev_apply.policy,
        aws_iam_policy.identity_plan.policy,
        aws_iam_policy.identity_dev_apply.policy,
        aws_iam_role_policy.image_publisher["auth-demo"].policy,
        ] : [
        for statement in jsondecode(policy_json).Statement : [
          for action in try(tolist(statement.Action), [statement.Action]) :
          action != "*" && !can(regex(":\\*$", action))
        ]
      ]
    ]))
    error_message = "GOLDEN INVARIANT: a policy statement grants a bare \"*\" or a full-service/global wildcard action (matching \"...:*\", e.g. \"iam:*\" or \"*:*\"). This module's whole purpose is bounded, reviewable delivery permissions; no such wildcard is ever required."
  }
}

run "no_mutating_iam_action_gets_an_unscoped_resource_without_a_condition" {
  command = plan

  assert {
    condition = alltrue(flatten([
      for policy_json in [
        aws_iam_policy.sandbox_network_plan.policy,
        aws_iam_policy.sandbox_network_dev_apply.policy,
        aws_iam_policy.sandbox_platform_plan.policy,
        aws_iam_policy.sandbox_platform_dev_apply.policy,
        aws_iam_policy.sandbox_workload_plan.policy,
        aws_iam_policy.sandbox_workload_dev_apply.policy,
        aws_iam_policy.identity_plan.policy,
        aws_iam_policy.identity_dev_apply.policy,
        aws_iam_role_policy.image_publisher["auth-demo"].policy,
        ] : [
        for statement in jsondecode(policy_json).Statement :
        anytrue([
          for action in try(tolist(statement.Action), [statement.Action]) :
          can(regex("^iam:", action)) && !can(regex("^iam:(Get|List)", action))
          ]) ? (
          try(statement.Resource, null) == "*" ? contains(keys(statement), "Condition") : true
        ) : true
      ]
    ]))
    error_message = "GOLDEN INVARIANT: a statement grants a mutating iam: action (anything other than iam:Get*/iam:List*) against an unscoped Resource = \"*\" with no Condition narrowing it. Every mutating iam: grant in this module must target specific role/policy ARNs or, where IAM has no resource-level support, carry a Condition that pins it down (see CreateOnlySandboxWorkloadDeliveryPolicies's iam:PolicyName condition)."
  }
}
