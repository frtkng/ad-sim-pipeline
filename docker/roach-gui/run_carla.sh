#!/usr/bin/env bash
# run_carla.sh — CARLA+Roach GUI コンテナ起動スクリプト (WSLg 用)

# 1) WSLg では DISPLAY を :0 に固定
export DISPLAY=:0

# 2) Docker イメージ名
IMAGE="carla-roach-gui-r1"

# 3) コンテナ起動
docker run -it --rm \
  --gpus all \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  $IMAGE \
  bash

# 実行後、コンテナ内で以下を実行:
#   cd ~
#   ./CarlaUE4.sh
#   (必要なら: ./CarlaUE4.sh -opengl)