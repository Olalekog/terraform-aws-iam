output "role_arn" {
  description = "ARN of the IAM role created by the module."
  value       = module.iam_role.role_arn
}

output "role_name" {
  description = "Name of the IAM role created by the module."
  value       = module.iam_role.role_name
}

output "role_id" {
  description = "Unique ID of the IAM role created by the module."
  value       = module.iam_role.role_id
}

output "instance_profile_name" {
  description = "Name of the instance profile created by the module."
  value       = module.iam_role.instance_profile_name
}

output "instance_profile_arn" {
  description = "ARN of the instance profile created by the module."
  value       = module.iam_role.instance_profile_arn
}
