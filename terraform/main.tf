locals {
  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.private_subnets
}

provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "model_store" {
  bucket = "e2e-ai-model-store-${var.env}"
  acl    = "private"

  tags = {
    Project = "E2E AI CICT"
  }
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version = "19.21.0" # 安定しているバージョン

  cluster_name    = "e2e-ai-cluster-${var.env}"
  cluster_version = "1.33" 
  subnet_ids      = local.subnets
  vpc_id  = local.vpc_id
    eks_managed_node_groups = {
        cpu = {
            # kube-system + 軽いジョブ用
            instance_types   = ["t3.medium"] # 1 vCPU / 4GiB
            desired_capacity = 1
            max_capacity     = 1
            labels           = { role = "cpu" }
        }

        gpu = {
            # CARLA 専用
            instance_types   = ["g5.xlarge"]     # A10G 1枚 / 4 vCPU
            desired_capacity = 1
            max_capacity     = 1
            taints = [{
            key    = "node.kubernetes.io/gpu"
            value  = "true"
            effect = "NO_SCHEDULE"
            }]
            labels = { role = "gpu" }
        }
    }

  tags = {
    Project = "E2E AI CICT"
  }
}