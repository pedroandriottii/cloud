terraform {
    backend "s3" {}
  
    required_version = ">= 1.8.0"
  
    required_providers {
      aws = {
        source  = "hashicorp/aws"
        version = "~> 6.22"
      }
    }
  }
  