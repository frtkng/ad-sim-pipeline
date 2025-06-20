#!/bin/bash
set -euo pipefail

# デフォルトのAWSプロファイル（必要に応じて上書き）
AWS_PROFILE="${1:-default}"
export AWS_PROFILE
echo "[INFO] Using AWS_PROFILE: $AWS_PROFILE"

# SSHキー名と保存先ディレクトリ
KEY_NAME="e2e-ai-dev-key"
SSH_DIR="$HOME/.ssh"
KEY_PATH="$SSH_DIR/${KEY_NAME}.pem"

# SSHディレクトリの存在と書き込み権限を確認／作成
if [ ! -d "$SSH_DIR" ]; then
  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"
elif [ ! -w "$SSH_DIR" ]; then
  echo "[ERROR] $SSH_DIR is not writable. Please run 'sudo chown -R \"$USER\":\"$USER\" $SSH_DIR' and 'chmod 700 $SSH_DIR'"
  exit 1
fi

# EC2キーペアの存在をチェック、なければ作成
if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region ap-northeast-1 >/dev/null 2>&1; then
  echo "[INFO] Creating EC2 key pair: $KEY_NAME"
  aws ec2 create-key-pair \
    --key-name "$KEY_NAME" \
    --query 'KeyMaterial' \
    --output text \
    --region ap-northeast-1 \
  > "$KEY_PATH"
  chmod 400 "$KEY_PATH"
  echo "[INFO] Private key saved to $KEY_PATH"
else
  echo "[INFO] EC2 key pair '$KEY_NAME' already exists, skipping."
fi

# スクリプトの位置から terraform ディレクトリへ移動
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"
cd "$TERRAFORM_DIR"

# ────────────────────────────────────────────────
# Terraform backend 用 S3 バケット作成（存在しなければ）
# ────────────────────────────────────────────────
echo "[INFO] Ensuring Terraform state S3 bucket exists..."
aws s3api create-bucket \
  --bucket beans-terraform-state-bucket \
  --region ap-northeast-1 \
  --create-bucket-configuration LocationConstraint=ap-northeast-1 \
  && echo "[INFO] S3 bucket 'beans-terraform-state-bucket' created." \
  || echo "[INFO] S3 bucket 'beans-terraform-state-bucket' already exists or creation skipped."

# ────────────────────────────────────────────────
# Terraform リモートバックエンド用 DynamoDB テーブル作成
# ────────────────────────────────────────────────
echo "[INFO] Ensuring Terraform lock table exists..."
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-northeast-1 \
  && echo "[INFO] DynamoDB table 'terraform-locks' created." \
  || echo "[INFO] DynamoDB table 'terraform-locks' already exists or creation skipped."

# ────────────────────────────────────────────────
# Terraform 初期化（バックエンド再設定＋強制状態移行＋モジュールアップグレード）
# ────────────────────────────────────────────────
echo "[INFO] Initializing Terraform backend and migrating state..."
terraform init \
  -reconfigure \
  -force-copy \
  -upgrade \
  -input=false

# Terraform適用（ユーザー確認を省略）
echo "[INFO] Applying Terraform configuration..."
terraform apply -auto-approve

# Terraform出力を表示
echo "[INFO] Terraform outputs:"
terraform output

# 必要なSecretsを目視で確認できるように個別出力
echo ""
echo "🔑 GitHub Secrets に登録すべき値:"
echo "----------------------------------"
echo "MODEL_BUCKET:   $(terraform output -raw model_bucket)"
echo "CLUSTER_NAME:   $(terraform output -raw cluster_name)"
echo "（AWS_ROLE は手動設定が必要です）"
echo "----------------------------------"
