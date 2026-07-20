variable "region" {
  description = "AWS region to deploy resources into."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Base name for the IAM role and instance profile."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]{1,64}$", var.name))
    error_message = "name must be 1-64 characters and contain only letters, numbers, hyphens, and underscores."
  }
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod). Used in tags."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod", "sandbox", "test", "shared"], var.environment)
    error_message = "environment must be one of: dev, staging, prod, sandbox, test, shared."
  }
}

variable "tags" {
  description = "A map of tags to apply to the role and instance profile."
  type        = map(string)
  default     = {}
}

variable "trusted_service_principals" {
  description = "AWS service principals allowed to assume this role. Defaults to EC2, making this role usable directly as an EC2 instance profile."
  type        = list(string)
  default     = ["ec2.amazonaws.com"]
}

variable "create_instance_profile" {
  description = "Whether to create an instance profile wrapping the role, for direct use by the EC2 module's iam_instance_profile_name input."
  type        = bool
  default     = true
}

variable "managed_policy_arns" {
  description = "List of AWS-managed or customer-managed IAM policy ARNs to attach to the role."
  type        = list(string)
  default = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}

variable "inline_policies" {
  description = "Map of inline policy name to IAM policy document (JSON string) to attach to the role."
  type        = map(string)
  default     = {}
}

variable "kms_key_arns" {
  description = <<-EOT
    ARNs of KMS keys (e.g. from a terraform-aws-kms module instance) this
    role should be able to use for encrypt/decrypt/CreateGrant operations.
    Use this instead of a broad "kms:*" inline policy to grant an EC2 role
    exactly the key access it needs (root/EBS volume encryption, S3 SSE-KMS,
    Secrets Manager, etc). This only grants IAM-side permissions; the KMS
    key's own key policy must also allow this role's ARN (see the
    terraform-aws-kms module's key_user_arns input).
  EOT
  type        = list(string)
  default     = []
}

variable "permissions_boundary_arn" {
  description = "ARN of the IAM policy to use as a permissions boundary for the role."
  type        = string
  default     = null
}

variable "path" {
  description = "IAM path for the role and instance profile."
  type        = string
  default     = "/"
}

variable "use_name_prefix" {
  description = <<-EOT
    If true (default), the role/profile are named using name_prefix (AWS
    appends a random suffix), avoiding naming collisions across applies.
    Set to false to use `name` verbatim, which makes the role's ARN
    predictable before creation — required if you need to reference the
    role's ARN from another resource/module (e.g. a KMS key policy) without
    creating a circular module dependency.
  EOT
  type        = bool
  default     = true
}

variable "max_session_duration" {
  description = "Maximum session duration (in seconds) that can be requested when assuming the role."
  type        = number
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "max_session_duration must be between 3600 (1h) and 43200 (12h) seconds."
  }
}
