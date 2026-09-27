# Every variable validation added in v1.0.0, plus the pre-existing
# image_publishers validation from v0.1.13. Each new validation is proven
# twice: it accepts sandbox-delivery's real, currently-valid input (so v1.0.0
# never rejects what v0.1.13 accepts), and it rejects a genuinely invalid
# shape through expect_failures.

mock_provider "aws" {}

override_data {
  target = data.aws_partition.current
  values = {
    partition = "aws"
  }
}

variables {
  # sandbox-delivery's real, live inputs (see tests/golden_master.tftest.hcl).
  # Every validation in this file must accept this baseline unmodified.
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

run "accepts_the_real_sandbox_delivery_inputs_unmodified" {
  command = plan

  assert {
    condition     = aws_iam_openid_connect_provider.github_actions.url == "https://token.actions.githubusercontent.com"
    error_message = "The baseline (sandbox-delivery's real inputs) must plan cleanly through every new validation."
  }
}

# --- aws_account_id --------------------------------------------------------

run "rejects_an_account_id_that_is_not_twelve_digits" {
  command = plan

  variables {
    aws_account_id = "not-an-account-id"
  }

  expect_failures = [var.aws_account_id]
}

run "rejects_an_account_id_with_the_wrong_digit_count" {
  command = plan

  variables {
    aws_account_id = "12345"
  }

  expect_failures = [var.aws_account_id]
}

# --- aws_region --------------------------------------------------------

run "accepts_a_govcloud_shaped_region" {
  command = plan

  variables {
    aws_region = "us-gov-west-1"
  }

  assert {
    condition     = aws_iam_role.github_actions["plan"].name == "devops-aws-infra-sandbox-plan"
    error_message = "aws_region must accept every real AWS Region shape, including us-gov-*, not only the exact region sandbox-delivery happens to use."
  }
}

run "rejects_a_malformed_region" {
  command = plan

  variables {
    aws_region = "US-EAST-2"
  }

  expect_failures = [var.aws_region]
}

run "rejects_a_region_with_no_digit" {
  command = plan

  variables {
    aws_region = "us-east"
  }

  expect_failures = [var.aws_region]
}

# --- role_prefix --------------------------------------------------------

run "rejects_a_role_prefix_with_a_character_iam_forbids" {
  command = plan

  variables {
    role_prefix = "devops aws infra/sandbox"
  }

  expect_failures = [var.role_prefix]
}

run "rejects_an_empty_role_prefix" {
  command = plan

  variables {
    role_prefix = ""
  }

  expect_failures = [var.role_prefix]
}

run "accepts_a_role_prefix_using_every_iam_allowed_character" {
  command = plan

  variables {
    role_prefix = "Acme+Platform=Sandbox,Delivery.Team@1_ok"
  }

  assert {
    condition     = aws_iam_role.github_actions["plan"].name == "Acme+Platform=Sandbox,Delivery.Team@1_ok-plan"
    error_message = "Every character IAM allows in a name (letters, digits, + = , . @ _ -) must remain accepted."
  }
}

# --- github_subject_prefix --------------------------------------------------------

run "rejects_a_subject_prefix_missing_the_repo_scheme" {
  command = plan

  variables {
    github_subject_prefix = "hatan4ik/devops-aws-infra"
  }

  expect_failures = [var.github_subject_prefix]
}

run "rejects_a_subject_prefix_that_is_only_the_scheme" {
  command = plan

  variables {
    github_subject_prefix = "repo:"
  }

  expect_failures = [var.github_subject_prefix]
}

# --- github_oidc_thumbprints --------------------------------------------------------

run "rejects_a_thumbprint_that_is_not_40_hex_characters" {
  command = plan

  variables {
    github_oidc_thumbprints = ["not-a-thumbprint"]
  }

  expect_failures = [var.github_oidc_thumbprints]
}

run "rejects_a_thumbprint_one_character_short" {
  command = plan

  variables {
    github_oidc_thumbprints = ["ab9d0263244dd0326eb67015705a667e79cfe99"]
  }

  expect_failures = [var.github_oidc_thumbprints]
}

run "accepts_an_uppercase_hex_thumbprint" {
  command = plan

  variables {
    github_oidc_thumbprints = ["AB9D0263244DD0326EB67015705A667E79CFE998"]
  }

  assert {
    condition     = aws_iam_openid_connect_provider.github_actions.url == "https://token.actions.githubusercontent.com"
    error_message = "SHA-1 thumbprints are conventionally lowercase but IAM does not require it; uppercase must not be rejected."
  }
}

run "accepts_multiple_thumbprints_during_rotation" {
  command = plan

  variables {
    github_oidc_thumbprints = [
      "ab9d0263244dd0326eb67015705a667e79cfe998",
      "111111111111111111111111111111111111111a",
    ]
  }

  assert {
    condition     = length(aws_iam_openid_connect_provider.github_actions.thumbprint_list) == 2
    error_message = "A thumbprint rotation window needs more than one approved thumbprint accepted at once."
  }
}

# --- state_backend.bucket_name --------------------------------------------------------

run "rejects_an_uppercase_bucket_name" {
  command = plan

  variables {
    state_backend = {
      bucket_name     = "Platform-TF-State"
      key_prefix      = "gitops/sandbox-delivery/us-east-2/global/"
      kms_key_id      = "34605b23-fafd-43f8-b708-db4dbe385189"
      lock_table_name = "platform-tf-lock-table"
    }
  }

  expect_failures = [var.state_backend]
}

run "rejects_a_bucket_name_that_is_too_short" {
  command = plan

  variables {
    state_backend = {
      bucket_name     = "ab"
      key_prefix      = "gitops/sandbox-delivery/us-east-2/global/"
      kms_key_id      = "34605b23-fafd-43f8-b708-db4dbe385189"
      lock_table_name = "platform-tf-lock-table"
    }
  }

  expect_failures = [var.state_backend]
}

# --- state_backend.key_prefix --------------------------------------------------------

run "rejects_a_key_prefix_missing_its_trailing_slash" {
  command = plan

  variables {
    state_backend = {
      bucket_name     = "platform-tf-state-shared-f3ddb8cc"
      key_prefix      = "gitops/sandbox-delivery/us-east-2/global"
      kms_key_id      = "34605b23-fafd-43f8-b708-db4dbe385189"
      lock_table_name = "platform-tf-lock-table"
    }
  }

  expect_failures = [var.state_backend]
}

# --- state_backend.kms_key_id --------------------------------------------------------

run "rejects_a_kms_key_alias_instead_of_a_uuid" {
  command = plan

  variables {
    state_backend = {
      bucket_name     = "platform-tf-state-shared-f3ddb8cc"
      key_prefix      = "gitops/sandbox-delivery/us-east-2/global/"
      kms_key_id      = "alias/platform-state"
      lock_table_name = "platform-tf-lock-table"
    }
  }

  expect_failures = [var.state_backend]
}

run "rejects_a_kms_key_arn_instead_of_a_uuid" {
  command = plan

  variables {
    state_backend = {
      bucket_name     = "platform-tf-state-shared-f3ddb8cc"
      key_prefix      = "gitops/sandbox-delivery/us-east-2/global/"
      kms_key_id      = "arn:aws:kms:us-east-2:448871779014:key/34605b23-fafd-43f8-b708-db4dbe385189"
      lock_table_name = "platform-tf-lock-table"
    }
  }

  expect_failures = [var.state_backend]
}

# --- state_backend.lock_table_name --------------------------------------------------------

run "rejects_a_lock_table_name_with_a_space" {
  command = plan

  variables {
    state_backend = {
      bucket_name     = "platform-tf-state-shared-f3ddb8cc"
      key_prefix      = "gitops/sandbox-delivery/us-east-2/global/"
      kms_key_id      = "34605b23-fafd-43f8-b708-db4dbe385189"
      lock_table_name = "platform tf lock table"
    }
  }

  expect_failures = [var.state_backend]
}

# --- image_publishers (pre-existing v0.1.13 validation; unchanged, deepened here) ---

run "rejects_an_image_publisher_subject_not_scoped_to_the_dev_environment" {
  command = plan

  variables {
    image_publishers = {
      "auth-demo" = {
        github_subject  = "repo:hatan4ik/sandbox-auth-demo:environment:prod"
        repository_name = "sandbox-platform-dev-application"
      }
    }
  }

  expect_failures = [var.image_publishers]
}

run "rejects_an_image_publisher_key_that_is_too_long" {
  command = plan

  variables {
    image_publishers = {
      "a-key-that-is-far-too-long-for-a-role-name-segment" = {
        github_subject  = "repo:hatan4ik/sandbox-auth-demo:environment:dev"
        repository_name = "sandbox-platform-dev-application"
      }
    }
  }

  expect_failures = [var.image_publishers]
}

run "rejects_an_image_publisher_repository_name_with_uppercase" {
  command = plan

  variables {
    image_publishers = {
      "auth-demo" = {
        github_subject  = "repo:hatan4ik/sandbox-auth-demo:environment:dev"
        repository_name = "Sandbox-Platform-Dev-Application"
      }
    }
  }

  expect_failures = [var.image_publishers]
}
