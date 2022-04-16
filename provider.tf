provider "aws" {
  region = var.AWS_REGION
  assume_role {
    role_arn = var.provider_env_roles[var.profile]
  }
}
