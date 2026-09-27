variable "aws_account_id" {
  description = "AWS account that owns the existing sandbox GitHub OIDC roles and delivery policies."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be exactly 12 digits, as AWS account IDs always are."
  }
}

variable "aws_region" {
  description = "Region containing the sandbox delivery Terraform state backend."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]+$", var.aws_region))
    error_message = "aws_region must look like an AWS Region code, for example us-east-2 or us-gov-west-1."
  }
}

variable "role_prefix" {
  description = "Existing GitHub OIDC role-name prefix created by the one-time trust bootstrap."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9+=,.@_-]+$", var.role_prefix))
    error_message = "role_prefix becomes part of every IAM role and policy name; it may contain only the characters IAM allows in a name: letters, digits, and + = , . @ _ -."
  }
}

variable "github_subject_prefix" {
  description = "Immutable GitHub OIDC repository subject prefix, without the pull-request/ref/environment suffix."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^repo:.+$", var.github_subject_prefix))
    error_message = "github_subject_prefix must start with \"repo:\" followed by a non-empty repository subject, matching GitHub's OIDC token sub claim shape."
  }
}

variable "github_oidc_thumbprints" {
  description = "Current approved SHA-1 thumbprints for GitHub's OIDC provider."
  type        = set(string)
  nullable    = false

  validation {
    condition = alltrue([
      for thumbprint in var.github_oidc_thumbprints :
      can(regex("^[0-9a-fA-F]{40}$", thumbprint))
    ])
    error_message = "Each github_oidc_thumbprints entry must be a 40-character hexadecimal SHA-1 thumbprint."
  }
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

  validation {
    condition     = can(regex("^[a-z0-9.-]{3,63}$", var.state_backend.bucket_name))
    error_message = "state_backend.bucket_name must be a syntactically valid S3 bucket name (lowercase letters, digits, dots, and hyphens, 3-63 characters)."
  }

  validation {
    condition     = can(regex("/$", var.state_backend.key_prefix))
    error_message = "state_backend.key_prefix must end with \"/\" so it addresses only its own state objects."
  }

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.state_backend.kms_key_id))
    error_message = "state_backend.kms_key_id must be the key's UUID (not an alias or ARN), for example 34605b23-fafd-43f8-b708-db4dbe385189."
  }

  validation {
    condition     = can(regex("^[a-zA-Z0-9_.-]{3,255}$", var.state_backend.lock_table_name))
    error_message = "state_backend.lock_table_name must be a syntactically valid DynamoDB table name (letters, digits, underscores, dots, and hyphens, 3-255 characters)."
  }
}
