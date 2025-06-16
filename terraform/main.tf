provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "model_store" {
  bucket = "e2e-ai-model-store-${var.env}"
  acl    = "private"
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "e2e-ai-cluster-${var.env}"
  cluster_version = "1.24"
  subnets         = var.subnets
  vpc_id          = var.vpc_id
  node_groups = {
    gpu_nodes = {
      desired_capacity = 1
      instance_types   = ["p3.2xlarge"]
      key_name         = var.ec2_key
    }
  }
}