module "iam_role" {
  source = "../.."

  region      = var.region
  name        = var.name
  environment = var.environment

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ]
}
