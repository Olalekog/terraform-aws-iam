variable "region" {
  description = "AWS region to deploy the example into."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name to give the example IAM role."
  type        = string
  default     = "terratest-iam-example"
}

variable "environment" {
  description = "Environment tag for the example resources."
  type        = string
  default     = "test"
}
