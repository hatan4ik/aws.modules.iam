# The reviewed, root-specific delivery policies attached to the roles in
# oidc.tf. Every policy document itself is rendered in policies.tf; this file
# only owns the aws_iam_policy resources and their names.

resource "aws_iam_policy" "sandbox_network_plan" {
  name        = local.policy_names.sandbox_network_plan
  description = "Read and state-lock access required to plan or detect drift for the sandbox-network root."
  policy      = jsonencode(local.sandbox_network_plan_policy)

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_policy" "sandbox_network_dev_apply" {
  name        = local.policy_names.sandbox_network_dev_apply
  description = "Exact create, update, delete, state, and read access for the sandbox-network root."
  policy      = jsonencode(local.sandbox_network_dev_apply_policy)

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_policy" "sandbox_platform_plan" {
  name        = local.policy_names.sandbox_platform_plan
  description = "Read and state-lock access required to plan or detect drift for the sandbox-platform root."
  policy      = jsonencode(local.sandbox_platform_plan_policy)

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_policy" "sandbox_platform_dev_apply" {
  name        = local.policy_names.sandbox_platform_dev_apply
  description = "Root-specific platform provisioning and state access for the protected sandbox dev environment."
  policy      = jsonencode(local.sandbox_platform_dev_apply_policy)

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_policy" "sandbox_workload_plan" {
  name        = local.policy_names.sandbox_workload_plan
  description = "Read and state-lock access required to plan or detect drift for the sandbox-workload root."
  policy      = jsonencode(local.sandbox_workload_plan_policy)

  lifecycle {
    prevent_destroy = true
  }

  # The existing identity apply policy must first gain iam:CreatePolicy before
  # Terraform can create these newly introduced tracked policies.
  depends_on = [aws_iam_policy.identity_dev_apply]
}

resource "aws_iam_policy" "sandbox_workload_dev_apply" {
  name        = local.policy_names.sandbox_workload_dev_apply
  description = "Root-specific private ECS workload provisioning and state access for protected sandbox dev."
  policy      = jsonencode(local.sandbox_workload_dev_apply_policy)

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [aws_iam_policy.identity_dev_apply]
}

resource "aws_iam_policy" "identity_plan" {
  name        = local.policy_names.identity_plan
  description = "Read-only Terraform state and IAM-policy inspection for sandbox delivery identity plans and drift detection."
  policy      = jsonencode(local.identity_plan_policy)

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_policy" "identity_dev_apply" {
  name        = local.policy_names.identity_dev_apply
  description = "Bounded Terraform management of sandbox delivery IAM policy versions and reviewed role attachments."
  policy      = jsonencode(local.identity_dev_apply_policy)

  lifecycle {
    prevent_destroy = true
  }
}
