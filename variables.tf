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

variable "image_publishers" {
  description = "Dedicated GitHub OIDC image-publisher roles. Each role can push only immutable images to its declared ECR repository."
  type = map(object({
    github_subject  = string
    repository_name = string
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for key, publisher in var.image_publishers :
      can(regex("^[a-z][a-z0-9-]{1,25}$", key)) &&
      can(regex("^repo:.+:environment:dev$", publisher.github_subject)) &&
      can(regex("^[a-z0-9][a-z0-9._/-]{0,255}$", publisher.repository_name))
    ])
    error_message = "Each image publisher needs a short lowercase key, a dev-environment GitHub OIDC subject, and a valid ECR repository name."
  }
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
