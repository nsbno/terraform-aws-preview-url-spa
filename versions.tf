terraform {
  required_version = ">= 1.14.9"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 6.42.0"
      configuration_aliases = [aws.us_east_1]
    }
  }
}
