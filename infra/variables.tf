variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "project_name" {
  type    = string
  default = "hello-world"
}

variable "image_tag" {
  type        = string
  description = "ECR image tag to deploy (set by CI from the Git SHA)."
}
