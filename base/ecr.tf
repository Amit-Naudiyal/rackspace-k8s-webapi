resource "aws_ecr_repository" "testapp" {
  name = local.ecr_repo_name

  image_scanning_configuration {
    scan_on_push = true
  } 
}

data "aws_caller_identity" "current" {}

locals {
  ecr_url = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.prefix}-"
}

output "repository_base_url" {
  value = local.ecr_url
}
