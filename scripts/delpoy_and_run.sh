#!/usr/bin/env bash
set -euo pipefail

# ────────────────────────────────────────────
# 0) .env を自動ロード  ※スクリプトと同じ階層を想定
# ────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"   # パスは必要に応じて合わせる

if [[ -f "$ENV_FILE" ]]; then
  echo "[INFO] Loading environment variables from $ENV_FILE"
  # set -a で以降の変数読み込みを全て export 扱いに
  set -a
  # シェル変数展開を有効にしたまま読み込む
  source "$ENV_FILE"
  set +a
else
  echo "[WARN] .env file not found at $ENV_FILE — falling back to already-exported vars"
fi

# ────────────────────────────────────────────
# 1) 引数チェック & 必須変数確認
# ────────────────────────────────────────────
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <image-tag>"; exit 1
fi
IMAGE_TAG="$1"

: "${AWS_REGION:?AWS_REGION not set}"        # ↓ .env で読み込まれている想定
: "${AWS_ACCOUNT_ID:?AWS_ACCOUNT_ID not set}"
: "${CLUSTER_NAME:?CLUSTER_NAME not set}"
: "${MODEL_BUCKET:?MODEL_BUCKET not set}"

IMAGE_REPO="${IMAGE_REPO:-e2e-ai-carla-dev}"
ECR_URI="${ECR_URI:-${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com}"
IMAGE="${ECR_URI}/${IMAGE_REPO}:${IMAGE_TAG}"

echo "[INFO] Deploying image: ${IMAGE}"

# ────────────────────────────────
# 1. kubectl / aws cli 前提チェック
# ────────────────────────────────
command -v kubectl >/dev/null || { echo "[ERROR] kubectl not found"; exit 1; }
command -v aws >/dev/null     || { echo "[ERROR] aws CLI not found"; exit 1; }

# ────────────────────────────────
# 2. kubeconfig を更新
# ────────────────────────────────
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}"

# ────────────────────────────────
# 3. Deployment 更新
# ────────────────────────────────
env IMAGE="${IMAGE}" envsubst '$IMAGE' < k8s/roach-deployment.yaml | kubectl apply -f -

# ────────────────────────────────
# 4. Retrain Job 再投入
# ────────────────────────────────
kubectl delete job/roach-retrain --ignore-not-found

env IMAGE="${IMAGE}" MODEL_BUCKET="${MODEL_BUCKET}" \
  envsubst '$IMAGE $MODEL_BUCKET' < k8s/roach-retrain-job.yaml | kubectl apply -f -

echo "[INFO] Waiting for retrain Job to complete …"
kubectl wait --for=condition=complete job/roach-retrain --timeout=1200s

echo "[INFO] Retrain Job logs ↓↓↓"
kubectl logs job/roach-retrain