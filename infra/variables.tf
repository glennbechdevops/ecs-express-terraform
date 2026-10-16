variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "project_name" {
  type    = string
  default = "hello-world"
}

variable "image" {
  type = string

  description = <<-EOT
    Full container image URI (registry + repository + tag) that the ECS task
    will run. The ECR repository is NOT managed by this Terraform stack; it
    must already exist and the tag must already be pushed before `terraform
    apply` runs. CI builds the image, pushes it to ECR with the Git SHA as the
    tag, and passes the resulting URI in via this variable.

    Format: <aws_account_id>.dkr.ecr.<region>.amazonaws.com/<repo>:<tag>

    Example:
      244530008913.dkr.ecr.eu-west-1.amazonaws.com/hello-world:9743409fea4286dc5814e150ae5348cf2d9e07a6
  EOT

  validation {
    condition     = can(regex("^[0-9]{12}\\.dkr\\.ecr\\.[a-z0-9-]+\\.amazonaws\\.com/[a-z0-9][a-z0-9._/-]*:[A-Za-z0-9._-]+$", var.image))
    error_message = "image must look like <account>.dkr.ecr.<region>.amazonaws.com/<repo>:<tag>."
  }
}
