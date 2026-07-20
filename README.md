# terraform-aws-iam

A reusable module for provisioning an IAM role + instance profile for EC2 workloads, designed to be consumed by `terraform-aws-ec2` (via `create_iam_instance_profile = false` + `iam_instance_profile_name`) instead of letting the EC2 module manage its own role.

## Features

- Trust policy defaults to `ec2.amazonaws.com`, but accepts any list of service principals
- Attach any number of AWS-managed or customer-managed policy ARNs
- Attach inline policy documents by name
- Scoped KMS access: pass `kms_key_arns` (e.g. from a `terraform-aws-kms` module) to grant exactly `Encrypt`/`Decrypt`/`GenerateDataKey*`/`DescribeKey` plus AWS-resource-scoped `CreateGrant`, instead of a broad `kms:*` policy
- Optional permissions boundary
- `use_name_prefix` toggle: default `true` (random-suffixed name, safe for repeated applies); set `false` for a fixed, predictable name when another resource (like a KMS key policy) needs to reference this role's ARN before it exists — see the circular-dependency note below

## Usage

```hcl
module "app_instance_role" {
  source = "../terraform-aws-iam"

  name        = "app"
  environment = "prod"

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
  ]

  kms_key_arns = [module.ebs_kms_key.key_arn]
}

module "app_tier" {
  source = "../terraform-aws-ec2"
  # ...
  create_iam_instance_profile = false
  iam_instance_profile_name   = module.app_instance_role.instance_profile_name
}
```

A full working root module lives in [`examples/complete`](./examples/complete) — it's also the fixture the Go integration tests apply against.

## Examples

### Minimal EC2 role

Only the required inputs. Defaults to an `ec2.amazonaws.com` trust policy, attaches `AmazonSSMManagedInstanceCore`, creates an instance profile, and uses a random-suffixed name.

```hcl
module "web_role" {
  source = "../terraform-aws-iam"

  name        = "web"
  environment = "dev"
}
```

### Multiple managed policies + an inline policy

```hcl
module "app_role" {
  source = "../terraform-aws-iam"

  name        = "app"
  environment = "prod"

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
  ]

  inline_policies = {
    "s3-read-only" = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid      = "ReadAppBucket"
          Effect   = "Allow"
          Action   = ["s3:GetObject", "s3:ListBucket"]
          Resource = ["arn:aws:s3:::my-app-bucket", "arn:aws:s3:::my-app-bucket/*"]
        }
      ]
    })
  }
}
```

### Custom trusted principals (non-EC2 use)

Override `trusted_service_principals` and set `create_instance_profile = false` when the role isn't for an EC2 instance profile — e.g. a Lambda execution role.

```hcl
module "lambda_role" {
  source = "../terraform-aws-iam"

  name        = "processor"
  environment = "prod"

  trusted_service_principals = ["lambda.amazonaws.com"]
  create_instance_profile    = false

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
  ]
}
```

### Scoped KMS access

Grants exactly the encrypt/decrypt/grant permissions needed for the given key ARNs instead of a broad `kms:*` policy. Pair with a `terraform-aws-kms` module's `key_user_arns` input.

```hcl
module "app_role" {
  source = "../terraform-aws-iam"

  name        = "app"
  environment = "prod"

  kms_key_arns = [module.ebs_kms_key.key_arn]
}
```

### Predictable name + permissions boundary

`use_name_prefix = false` makes the role's ARN computable before it's created (needed for the KMS composition pattern below). `permissions_boundary_arn` caps the role's effective permissions regardless of what's attached.

```hcl
module "app_role" {
  source = "../terraform-aws-iam"

  name             = "app-prod"
  environment      = "prod"
  use_name_prefix  = false

  permissions_boundary_arn = "arn:aws:iam::123456789012:policy/OrgPermissionsBoundary"
}
```

## ⚠️ Avoiding circular dependencies with terraform-aws-kms

Granting this role KMS access (`kms_key_arns`) and granting the KMS key's policy access to this role (`key_user_arns` in `terraform-aws-kms`) both reference the *other* module's output — a genuine cycle if both sides use module outputs. Fix: set `use_name_prefix = false`, give the role a fixed `name`, and compute its ARN in the root module from `data.aws_caller_identity`/`data.aws_partition` instead of `module.app_instance_role.role_arn`. Pass that computed ARN into the KMS module's `key_user_arns`. This keeps the dependency graph a DAG: `kms` has no dependency on `iam`; `iam` depends on `kms`'s output; `ec2` depends on both. Full example: [`terraform-aws-ec2/examples/integrated`](../terraform-aws-ec2/examples/integrated).

## Testing

Native Terraform tests live in [`tests/iam.tftest.hcl`](./tests/iam.tftest.hcl) and run with mocked AWS resources (Terraform >= 1.7.0), no credentials needed:

```sh
terraform init
terraform test
```

Coverage: default role/profile creation, the `use_name_prefix` toggle (the predictable-naming path required for KMS composition), the instance-profile toggle, scoped KMS policy creation driven by `kms_key_arns`, managed/inline policy fan-out, and variable validation rules (name, environment, `max_session_duration` bounds).

Go integration tests using [Terratest](https://terratest.gruntwork.io/) live in [`test/iam_test.go`](./test/iam_test.go) and exercise the [`examples/complete`](./examples/complete) fixture against a real AWS account (apply, assert against the live IAM API, then destroy). Requires AWS credentials with IAM permissions:

```sh
cd test
go mod tidy
go test -v -timeout 30m
```

## Inputs

### Required

| Name | Type | Description |
|------|------|-------------|
| `name` | `string` | Base name for the IAM role and instance profile. 1-64 characters; letters, numbers, hyphens, and underscores only. |
| `environment` | `string` | Environment name, used in tags. Must be one of: `dev`, `staging`, `prod`, `sandbox`, `test`, `shared`. |

### Optional

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `region` | `string` | `"us-east-1"` | AWS region to deploy resources into. |
| `tags` | `map(string)` | `{}` | Additional tags applied to the role and instance profile (merged with `Name`, `Environment`, `ManagedBy`, `Module`). |
| `trusted_service_principals` | `list(string)` | `["ec2.amazonaws.com"]` | AWS service principals allowed to assume this role. |
| `create_instance_profile` | `bool` | `true` | Whether to create an instance profile wrapping the role. |
| `managed_policy_arns` | `list(string)` | `["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]` | AWS-managed or customer-managed IAM policy ARNs to attach to the role. |
| `inline_policies` | `map(string)` | `{}` | Map of inline policy name to IAM policy document (JSON string) to attach to the role. |
| `kms_key_arns` | `list(string)` | `[]` | KMS key ARNs the role should be able to use for encrypt/decrypt/`CreateGrant`. Grants scoped access instead of a broad `kms:*` policy; the key's own policy must separately allow this role (see `terraform-aws-kms`'s `key_user_arns`). |
| `permissions_boundary_arn` | `string` | `null` | ARN of the IAM policy to use as a permissions boundary for the role. |
| `path` | `string` | `"/"` | IAM path for the role and instance profile. |
| `use_name_prefix` | `bool` | `true` | If `true`, the role/profile use `name_prefix` (random suffix, safe for repeated applies). If `false`, use `name` verbatim for a predictable ARN — required to avoid circular dependencies with modules that need this role's ARN before it's created. |
| `max_session_duration` | `number` | `3600` | Maximum session duration (seconds) requestable when assuming the role. Must be between `3600` (1h) and `43200` (12h). |

## Outputs

| Name | Description |
|------|-------------|
| `role_arn` | ARN of the IAM role. Pass this into a `terraform-aws-kms` module's `key_user_arns` to grant this role key access. |
| `role_name` | Name of the IAM role. |
| `role_id` | Unique ID of the IAM role. |
| `instance_profile_name` | Name of the instance profile, or `null` if `create_instance_profile = false`. Pass this into the EC2 module's `iam_instance_profile_name` input (with `create_iam_instance_profile = false`). |
| `instance_profile_arn` | ARN of the instance profile, or `null` if `create_instance_profile = false`. |
