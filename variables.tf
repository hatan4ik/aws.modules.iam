variable "aws_account_id" {
  description = "AWS account that owns the existing sandbox GitHub OIDC roles and delivery policies."
  type        = string
  nullable    = false
}

variable "aws_region" {
  description = "Region containing the sandbox delivery Terraform state backend."
  type        = string
  nullable    = false
}

variable "role_prefix" {
  description = "Existing GitHub OIDC role-name prefix created by the one-time trust bootstrap."
  type        = string
  nullable    = false
}

variable "github_subject_prefix" {
  description = "Immutable GitHub OIDC repository subject prefix, without the pull-request/ref/environment suffix."
  type        = string
  nullable    = false
}

variable "github_oidc_thumbprints" {
  description = "Current approved SHA-1 thumbprints for GitHub's OIDC provider."
  type        = set(string)
  nullable    = false
}

variable "state_backend" {
  description = "Non-secret, dedicated remote-state configuration for the sandbox delivery IAM root."
  type = object({
    bucket_name     = string
    key_prefix      = string
    kms_key_id      = string
    lock_table_name = string
  })
  nullable = false
}
