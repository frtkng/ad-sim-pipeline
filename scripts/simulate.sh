#!/bin/bash
set -e
RUN_ID=$1
OUT_DIR="/tmp/carla_results/${RUN_ID}"
MODEL_FILE="model_${RUN_ID}.pth"
mkdir -p $OUT_DIR/scenario_data

# モデル取得\aws s3 cp s3://$MODEL_BUCKET/${MODEL_FILE} ./model.pth

# CARLAサーバ起動
docker run -d --name carla-server -p 2000:2000 carlasim/carla:0.9.13 \
  /bin/bash -c "CarlaUE4.sh -quality-level=Low -carla-server"
sleep 15

# 推論 + Pedestrianスポーン
python scripts/inference_client.py \
  --host localhost --port 2000 \
  --model ./model.pth \
  --output-dir $OUT_DIR \
  --pedestrian

docker rm -f carla-server