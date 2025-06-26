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

provider "kubernetes" {
  alias = "eks"

  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# 現在の AWS アカウント番号を取得
data "aws_caller_identity" "current" {}

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
  version = "20.13.0"

  cluster_name    = "e2e-ai-cluster-${var.env}"
  cluster_version = "1.33"

  vpc_id     = local.vpc_id
  subnet_ids = local.subnets

  # --- API エンドポイント公開設定 ------------------
  cluster_endpoint_public_access         = true
  cluster_endpoint_public_access_cidrs   = ["0.0.0.0/0"] # ← 会社 or 自宅の固定 IP があれば絞る
  cluster_endpoint_private_access        = true          # 既定 true のままで OK

  #################################
  # EKS マネージド Node Groups
  #################################
  eks_managed_node_groups = {
    # ── CPU ノード（システム & 軽量ジョブ）
    cpu = {
      node_group_name = "cpu" 
      instance_types = ["t3.small"]   # 1 vCPU / 4 GiB
      ami_type       = "AL2023_x86_64_STANDARD"
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
      node_group_name = "gpu"
      subnet_ids     = [local.subnets[0]] 
      instance_types = ["g4dn.xlarge"]   # A10G ×1 / 4 vCPU
      ami_type       = "AL2023_x86_64_NVIDIA"
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

###############################################################################
# 2)  aws-auth ConfigMap を管理するサブモジュール
###############################################################################

module "aws_auth" {
  # サブディレクトリ指定は OK
  source  = "terraform-aws-modules/eks/aws//modules/aws-auth"
  version = "20.13.0"

  # 1️⃣ 変数名を修正
  #cluster_name = module.eks.cluster_name   # ← これも不要なので消す
  map_roles = [                            # ← こちらだけ残す
    {
      rolearn  = data.aws_iam_role.cpu_node.arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = ["system:bootstrappers","system:nodes"]
    },
    {
      rolearn  = data.aws_iam_role.gpu_node.arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = ["system:bootstrappers","system:nodes"]
    },
    {
      rolearn  = aws_iam_role.github_actions.arn
      username = "github-actions"
      groups   = ["system:masters"]
    },
  ]

  # map_users / map_accounts は不要なら書かなくて OK
}



###############################################################################
# 既存ノードロールは data で参照
###############################################################################
data "aws_iam_role" "cpu_node" {
  name = "cpu-eks-node-group-20250617233425319200000001"
}

data "aws_iam_role" "gpu_node" {
  name = "gpu-eks-node-group-20250617035606257100000001"
}