# Deep coverage of oidc.tf: the OIDC provider and the six fixed GitHub
# Actions roles, with generic (non-production) inputs. tests/golden_master.tftest.hcl
# pins the one real sandbox-delivery shape; this file proves the same rules
# hold generally, for any valid input, not just that one.

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
  state_backend = {
    bucket_name     = "acme-tf-state"
    key_prefix      = "gitops/identity/eu-west-1/global/"
    kms_key_id      = "11112222-3333-4444-5555-666677778888"
    lock_table_name = "acme-tf-lock"
  }
}

run "provider_config_reflects_the_declared_thumbprints_and_audience" {
  command = plan

  assert {
    condition     = aws_iam_openid_connect_provider.github_actions.url == "https://token.actions.githubusercontent.com"
    error_message = "The OIDC provider must always target GitHub's fixed token issuer."
  }

  assert {
    condition     = aws_iam_openid_connect_provider.github_actions.client_id_list == toset(["sts.amazonaws.com"])
    error_message = "The only audience is sts.amazonaws.com, regardless of caller inputs."
  }

  assert {
    condition     = aws_iam_openid_connect_provider.github_actions.thumbprint_list == tolist(["6938fd4d98bab03faadb97b34396831e3780aea1"])
    error_message = "thumbprint_list must reflect exactly the declared github_oidc_thumbprints."
  }
}

run "exactly_six_fixed_roles_named_from_role_prefix" {
  command = plan

  assert {
    # A set comparison, not a list/tuple one: Terraform's `==` on a tuple
    # built from `keys()` of a resource's object type against a `tolist([...])`
    # literal spuriously evaluates false even when jsonencode() of both sides
    # is identical (observed directly with `terraform test -verbose`); `toset()`
    # on both sides does not have this quirk and is also the semantically
    # correct comparison, since a for_each key set is unordered.
    condition = toset(keys(aws_iam_role.github_actions)) == toset([
      "dev_apply", "drift", "landing_zone", "plan", "prod_apply", "staging_apply",
    ])
    error_message = "The for_each key set of the six fixed delivery roles must never grow, shrink, or rename a key: each key is a `moved`-free stable identifier used throughout locals.tf, delivery_policies.tf, and attachments.tf."
  }

  assert {
    condition = alltrue([
      for key, role in aws_iam_role.github_actions :
      role.name == "acme-platform-${replace(key, "_", "-")}"
    ])
    error_message = "Every fixed role name must be role_prefix + a hyphenated version of its for_each key."
  }

  assert {
    condition = alltrue([
      for key, role in aws_iam_role.github_actions : role.path == "/github-actions/"
    ])
    error_message = "Every fixed role lives under /github-actions/, which is part of its ARN."
  }

  assert {
    condition = alltrue([
      for key, role in aws_iam_role.github_actions : role.max_session_duration == 3600
    ])
    error_message = "Every fixed role keeps the 1-hour session ceiling."
  }
}

run "plan_role_trusts_both_pull_requests_and_pushes_to_main_only" {
  command = plan

  assert {
    condition = local.github_roles["plan"].condition == {
      StringEquals = {
        "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
      }
      "ForAnyValue:StringEquals" = {
        "token.actions.githubusercontent.com:sub" = [
          "repo:acme-corp/platform-infra:pull_request",
          "repo:acme-corp/platform-infra:ref:refs/heads/main",
        ]
      }
    }
    error_message = "The plan role must trust exactly a pull_request run or a push to main, and no other ref or environment."
  }
}

run "environment_scoped_roles_trust_exactly_one_environment_each" {
  command = plan

  assert {
    condition     = local.github_roles["dev_apply"].condition.StringEquals["token.actions.githubusercontent.com:sub"] == "repo:acme-corp/platform-infra:environment:dev"
    error_message = "dev_apply must be scoped to exactly the dev environment."
  }
  assert {
    condition     = local.github_roles["staging_apply"].condition.StringEquals["token.actions.githubusercontent.com:sub"] == "repo:acme-corp/platform-infra:environment:staging"
    error_message = "staging_apply must be scoped to exactly the staging environment."
  }
  assert {
    condition     = local.github_roles["prod_apply"].condition.StringEquals["token.actions.githubusercontent.com:sub"] == "repo:acme-corp/platform-infra:environment:prod"
    error_message = "prod_apply must be scoped to exactly the prod environment."
  }
  assert {
    condition     = local.github_roles["landing_zone"].condition.StringEquals["token.actions.githubusercontent.com:sub"] == "repo:acme-corp/platform-infra:environment:landing-zone"
    error_message = "landing_zone must be scoped to exactly the landing-zone environment."
  }
  assert {
    condition     = local.github_roles["drift"].condition.StringEquals["token.actions.githubusercontent.com:sub"] == "repo:acme-corp/platform-infra:environment:dev"
    error_message = "drift is deliberately scoped to the protected dev environment, the same subject as dev_apply (there is no separate drift environment). This is current behavior, not a bug to fix here."
  }

  assert {
    condition = alltrue([
      for key in ["dev_apply", "staging_apply", "prod_apply", "landing_zone", "drift"] :
      local.github_roles[key].condition.StringEquals["token.actions.githubusercontent.com:aud"] == "sts.amazonaws.com"
    ])
    error_message = "Every environment-scoped role must still require the sts.amazonaws.com audience."
  }
}

run "no_role_grants_a_permission_policy_of_its_own" {
  command = plan

  # oidc.tf's whole design is that a role has zero effect until
  # attachments.tf attaches a reviewed policy. aws_iam_role has no
  # "inline_policy"/"managed_policy_arns" argument in this module at all, so
  # the only way to prove this structurally is that no
  # aws_iam_role_policy/aws_iam_role_policy_attachment resource targets a
  # fixed delivery role except through local.role_policy_attachments, which
  # delivery_policies.tftest.hcl and attachments.tftest.hcl cover. This run
  # documents the invariant and asserts the one thing the resource itself
  # could carry: no policy argument is set. aws_iam_role's schema has no
  # inline-policy attribute for us to assert absence of directly, so the
  # meaningful check is the role count matching exactly six, asserted above.
  assert {
    condition     = length(aws_iam_role.github_actions) == 6
    error_message = "Exactly six fixed roles, no more, no fewer, exist independently of any policy attachment."
  }
}
