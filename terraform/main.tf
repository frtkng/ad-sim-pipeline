############################################
# variables.tf で定義している想定の変数
############################################
# variable "env"        {}   # dev / prod など
# variable "aws_region" {}   # ap-northeast-1 など
# variable "ec2_key"    {}   # ssh キーペア名

############################################
# main.tf
############################################
locals {
  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.private_subnets
}

provider "aws" {
  region = var.aws_region
}

#########################
# S3 (モデル保管用)
#########################
resource "aws_s3_bucket" "model_store" {
  bucket = "e2e-ai-model-store-${var.env}"

  tags = {
    Project = "E2E AI CICT"
  }
}

#########################
# EKS クラスタ
#########################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.21.0"

  cluster_name    = "e2e-ai-cluster-${var.env}"
  cluster_version = "1.33"

  vpc_id     = local.vpc_id
  subnet_ids = local.subnets

  #################################
  # EKS マネージド Node Groups
  #################################
  eks_managed_node_groups = {
    # ── CPU ノード（システム & 軽量ジョブ）
    cpu = {
      instance_types = ["t3.medium"]   # 1 vCPU / 4 GiB
      min_size       = 1
      max_size       = 1
      desired_size   = 1

      labels = {
        role = "cpu"
      }
      # (必要なら) SSH キー
      key_name = var.ec2_key
    }

    # ── GPU ノード（CARLA 専用）
    gpu = {
      instance_types = ["g5.xlarge"]   # A10G ×1 / 4 vCPU
      min_size       = 1
      max_size       = 1
      desired_size   = 1

      labels = {
        role = "gpu"
      }
      taints = [{
        key    = "node.kubernetes.io/gpu"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]

      key_name = var.ec2_key
    }
  }

  tags = {
    Project = "E2E AI CICT"
  }
}
