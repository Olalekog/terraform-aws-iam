# complete

Deploys the `terraform-aws-iam` module with a managed policy attached, exposing all module outputs. Used as the fixture for the Terratest suite in [`../../test`](../../test).

## Usage

```sh
terraform init
terraform apply
terraform destroy
```

Requires AWS credentials with permission to create/read/delete IAM roles, instance profiles, and policy attachments.
