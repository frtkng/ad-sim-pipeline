#!/usr/bin/env bash
# run_build.sh — CARLA+Roach GUI Docker イメージのビルドスクリプト

# イメージビルド
# カレントディレクトリに Dockerfile があることを前提とします
docker build -t carla-roach-gui-r1 .

echo "Docker image 'carla-roach-gui' がビルドされました。"
