output "role_arn" {
  description = "ARN of the IAM role. Pass this into a terraform-aws-kms module's key_user_arns to grant this role key access."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the IAM role."
  value       = aws_iam_role.this.name
}

output "role_id" {
  description = "Unique ID of the IAM role."
  value       = aws_iam_role.this.id
}

output "instance_profile_name" {
  description = "Name of the instance profile. Pass this into the EC2 module's iam_instance_profile_name input (with create_iam_instance_profile = false)."
  value       = try(aws_iam_instance_profile.this[0].name, null)
}

output "instance_profile_arn" {
  description = "ARN of the instance profile, if created."
  value       = try(aws_iam_instance_profile.this[0].arn, null)
}
