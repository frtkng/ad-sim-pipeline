terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40.0, < 6.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.29.0"
    }
  }
}