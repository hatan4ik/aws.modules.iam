# Advisory posture check. It warns without failing terraform plan or
# apply: a check block's condition failing never blocks a real run, it only
# prints a warning (terraform test treats a failing check as a run failure
# unless the run lists it in expect_failures, which tests/checks.tftest.hcl
# does for the scenario that is supposed to warn).
#
# There is deliberately no session-duration check: max_session_duration is a
# literal 3600 in oidc.tf and image_publishers.tf, not an input, so no caller
# can ever widen it and a check could never fire. The literal is pinned by a
# plain assertion in tests/oidc.tftest.hcl instead.

check "github_oidc_thumbprints_present" {
  assert {
    condition     = length(var.github_oidc_thumbprints) > 0
    error_message = "github_oidc_thumbprints is empty. The GitHub Actions OIDC provider has no thumbprint to validate GitHub's TLS certificate chain against; confirm this is intentional before relying on it."
  }
}
