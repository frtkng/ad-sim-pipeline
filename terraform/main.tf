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
  # Fargate プロファイル
  fargate_profiles = {
    # デフォルト namespace + role=cpu の Pod を Fargate で動かす
    cpu = {
      name      = "cpu-fargate"
      selectors = [{
        namespace = "default"
        labels    = { role = "cpu" }
      }]
    }
    # もし coredns や kube-proxy を Fargate に載せたいなら、
    # kube-system 用のプロファイルを追加
    system = {
      name      = "kube-system"
      selectors = [{
        namespace = "kube-system"
      }]
    }
  }

  # GPU 用だけ EC2 ノードグループ
  eks_managed_node_groups = {
    gpu = {
      instance_types   = ["g4dn.xlarge"]
      desired_capacity = 1
      max_capacity     = 1
      taints = [{
        key    = "node.kubernetes.io/gpu"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]
      labels = { role = "gpu" }
      key_name = var.ec2_key
    }
  }
    tags = {
    Project = "E2E AI CICT"
  }
}