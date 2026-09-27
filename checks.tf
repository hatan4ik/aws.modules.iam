# Advisory posture checks. Each one warns without failing terraform plan or
# apply: a check block's condition failing never blocks a real run, it only
# prints a warning (terraform test treats a failing check as a run failure
# unless the run lists it in expect_failures, which tests/checks.tftest.hcl
# does for the scenarios that are supposed to warn).

check "github_oidc_thumbprints_present" {
  assert {
    condition     = length(var.github_oidc_thumbprints) > 0
    error_message = "github_oidc_thumbprints is empty. The GitHub Actions OIDC provider has no thumbprint to validate GitHub's TLS certificate chain against; confirm this is intentional before relying on it."
  }
}

check "oidc_role_session_durations_stay_short" {
  assert {
    condition = alltrue(concat(
      [for role in aws_iam_role.github_actions : role.max_session_duration <= 3600],
      [for role in aws_iam_role.image_publisher : role.max_session_duration <= 3600],
    ))
    error_message = "A GitHub Actions delivery role's max_session_duration exceeds the platform's 1-hour ceiling. A short-lived OIDC credential does not need a long session; confirm this widening was deliberate."
  }
}
