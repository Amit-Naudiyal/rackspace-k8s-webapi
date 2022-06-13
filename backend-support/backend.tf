# This file creates S3 bucket to hold terraform states
# and DynamoDB table to keep the state locks.

resource "aws_s3_bucket" "terraform_infra_bucket" {
  bucket = "amit-microservice-terraform-infra"
  force_destroy = true

  tags = {
     Name = "Bucket for terraform states of amit naudiyal"
     createdBy = "microservice/backend-support"
  }
}

resource "aws_s3_bucket_versioning" "terraform_infra_bucket_versioning" {
  bucket = aws_s3_bucket.terraform_infra_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_acl" "terraform_infra_bucket_acl" {
  bucket = aws_s3_bucket.terraform_infra_bucket.id
  acl    = "private"
}


resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_infra_bucket_sse" {
  bucket = aws_s3_bucket.terraform_infra_bucket.id
  rule {
    apply_server_side_encryption_by_default {
    sse_algorithm = "AES256"
    }
  }
}


resource "aws_s3_bucket_public_access_block" "terraform_infra_bucket_access_level" {
  bucket                  = aws_s3_bucket.terraform_infra_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "aws_dynamodb_table" "dynamodb-table" {
  name           = "amit-microservice-terraform-locks"
  # up to 25 per account is free
  billing_mode   = "PROVISIONED"
  read_capacity  = 2
  write_capacity = 2
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
     Name = "Terraform Lock Table"
     createdBy = "microservice/backend-support"
  }
}
