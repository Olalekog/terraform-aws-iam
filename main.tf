locals {
  common_tags = merge(
    {
      Name        = var.name
      Environment = var.environment
      ManagedBy   = "terraform"
      Module      = "terraform-aws-iam"
    },
    var.tags
  )
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    sid     = "TrustedServiceAssumeRole"
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = var.trusted_service_principals
    }
  }
}

resource "aws_iam_role" "this" {
  name                 = var.use_name_prefix ? null : var.name
  name_prefix          = var.use_name_prefix ? "${var.name}-" : null
  path                 = var.path
  assume_role_policy   = data.aws_iam_policy_document.assume_role.json
  permissions_boundary = var.permissions_boundary_arn
  max_session_duration = var.max_session_duration

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = toset(var.managed_policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "inline" {
  for_each = var.inline_policies
  name     = each.key
  role     = aws_iam_role.this.id
  policy   = each.value
}

# Scoped KMS access, granted only for the specific key ARNs supplied — not a
# blanket kms:* policy. Pair with the terraform-aws-kms module's
# key_user_arns input (set to this role's ARN) so both the IAM side and the
# KMS key policy side agree.
data "aws_iam_policy_document" "kms_access" {
  count = length(var.kms_key_arns) > 0 ? 1 : 0

  statement {
    sid = "UseKmsKeysForEncryptedResources"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = var.kms_key_arns
  }

  statement {
    sid = "CreateGrantsForAWSResources"
    actions = [
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant",
    ]
    resources = var.kms_key_arns

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}

resource "aws_iam_role_policy" "kms_access" {
  count  = length(var.kms_key_arns) > 0 ? 1 : 0
  name   = "${var.name}-kms-access"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.kms_access[0].json
}


resource "aws_iam_instance_profile" "this" {
  count       = var.create_instance_profile ? 1 : 0
  name        = var.use_name_prefix ? null : var.name
  name_prefix = var.use_name_prefix ? "${var.name}-" : null
  path        = var.path
  role        = aws_iam_role.this.name

  tags = local.common_tags
}
