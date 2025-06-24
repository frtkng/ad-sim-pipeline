#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────
# 変数（★ここだけ自分の環境に合わせて書き換え）
AWS_REGION="ap-northeast-1"
CLUSTER_NAME="e2e-ai-cluster-dev"
TF_DIR="infra"            # Terraform の *.tf が置いてあるディレクトリ
# ──────────────────────────────────────────────────────────────

echo "==> 0) kubeconfig を更新"
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"

echo "==> 1) Terraform 初期化"
cd "$TF_DIR"
terraform init -upgrade -input=false

echo "==> 2) aws-auth ConfigMap を state に取り込む"
terraform import \
  kubernetes_config_map.aws_auth \
  kube-system/aws-auth

echo "==> 3) 差分確認"
terraform plan
