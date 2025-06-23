#!/bin/bash
set -e
RUN_ID=$1
RETRAIN=$2   # 'true' or 'false'
DATA_DIR="data"
MODEL_OUT="output/model_${RUN_ID}.pth"

# 再学習時は ng_data をマージ
if [ "$RETRAIN" = "true" ]; then
  mkdir -p $DATA_DIR
  cp -r ng_data/* $DATA_DIR/
fi

# CARLA E2E 用 CIL リポジトリ学習
# imitation-learning リポジトリ内の学習スクリプトを利用
python run_CIL.py \
  --train-data ../../../../$DATA_DIR \
  --model-out ../../../../$MODEL_OUT

# S3アップロード
aws s3 cp $MODEL_OUT s3://$MODEL_BUCKET/model_${RUN_ID}.pth