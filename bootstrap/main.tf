provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "github_session_terraform_state" {
  bucket = "github-session-my-org-terraform-state"

  lifecycle {
    prevent_destroy = true    # Protects against accidental deletion of all state
  }
}

resource "aws_s3_bucket_versioning" "github_session_terraform_state" {
  bucket = aws_s3_bucket.github_session_terraform_state.id
  versioning_configuration {
    status = "Enabled"    # Versioning lets you recover from accidental state corruption
  }
}

resource "aws_dynamodb_table" "github_session_terraform_locks" {
  name         = "github-session-my-org-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}