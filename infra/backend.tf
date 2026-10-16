terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket = "pgr301-terraform-state"
    key    = "ecs-express-terraform/terraform.tfstate"
    region = "eu-west-1"
  }
}
