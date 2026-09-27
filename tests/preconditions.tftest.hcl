# The two length preconditions added in v1.0.0 (oidc.tf, image_publishers.tf):
# IAM rejects a role name over 64 characters, and role_prefix (plus, for a
# publisher, the image_publishers key) is caller input long enough to exceed
# that limit without either variable's own validation catching it. These
# preconditions turn that into a plan-time message instead of a raw apply-time
# AWS API error. Neither changes any name for a role_prefix that fits, which
# every value used in tests/golden_master.tftest.hcl and tests/validation.tftest.hcl does.

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

run "sixty_character_role_prefix_overflows_even_the_shortest_suffix" {
  command = plan

  variables {
    # 60 chars + "-drift" (6, the shortest of the six suffixes) = 66 > 64: a
    # role_prefix this long overflows every one of the six fixed roles.
    role_prefix = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }

  expect_failures = [aws_iam_role.github_actions]
}

run "role_prefix_at_the_exact_staging_apply_boundary_is_accepted" {
  command = plan

  variables {
    # "-staging-apply" (14 chars) is the longest of the six fixed suffixes,
    # longer than "-landing-zone" (13). 50 chars + 14 = 64 exactly: the
    # boundary must pass, not just values comfortably under it.
    role_prefix = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }

  assert {
    condition     = length(aws_iam_role.github_actions["staging_apply"].name) == 64
    error_message = "A role name of exactly 64 characters, IAM's limit, must be accepted, not just names comfortably under it."
  }
}

run "role_prefix_one_character_past_the_staging_apply_boundary_fails" {
  command = plan

  variables {
    # 51 chars + "-staging-apply" (14) = 65: one character past the boundary.
    role_prefix = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }

  expect_failures = [aws_iam_role.github_actions]
}

run "image_publisher_role_name_overflow_needs_both_a_long_prefix_and_a_long_key" {
  command = plan

  variables {
    # image_publishers' own v0.1.13 validation already caps a key at 26
    # characters, so a 24-character role_prefix (sandbox-delivery's real
    # value) can never overflow a publisher role name (24+1+26+9=60). A
    # 30-character role_prefix combined with the longest allowed key does:
    # 30+1+26+9=66.
    role_prefix = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    image_publishers = {
      "aaaaaaaaaaaaaaaaaaaaaaaaaa" = {
        github_subject  = "repo:hatan4ik/sandbox-auth-demo:environment:dev"
        repository_name = "sandbox-platform-dev-application"
      }
    }
  }

  expect_failures = [aws_iam_role.image_publisher]
}

run "image_publisher_role_name_at_the_sixty_four_character_boundary_is_accepted" {
  command = plan

  variables {
    # 29 chars + "-" + 26-char key + "-ecr-push" (9) = 65... adjust to hit
    # exactly 64: 28 + 1 + 26 + 9 = 64.
    role_prefix = "aaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    image_publishers = {
      "aaaaaaaaaaaaaaaaaaaaaaaaaa" = {
        github_subject  = "repo:hatan4ik/sandbox-auth-demo:environment:dev"
        repository_name = "sandbox-platform-dev-application"
      }
    }
  }

  assert {
    condition     = length(aws_iam_role.image_publisher["aaaaaaaaaaaaaaaaaaaaaaaaaa"].name) == 64
    error_message = "A publisher role name of exactly 64 characters must be accepted."
  }
}
