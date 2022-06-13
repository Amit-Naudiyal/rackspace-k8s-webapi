# Setup our aws provider
variable "region" {
  default = "us-east-1"
}

provider "aws" {
  region = "${var.region}"
}

terraform {
  backend "s3" {
    bucket = "amit-microservice-terraform-infra"
    region = "us-east-1"
    dynamodb_table = "amit-microservice-terraform-locks"
    key = "base/terraform.tfstate"
  }
}
