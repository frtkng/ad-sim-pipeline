#!/usr/bin/env bash
set -eu
AWS_REGION=ap-northeast-1
REPO=676206918971.dkr.ecr.${AWS_REGION}.amazonaws.com/e2e-ai-carla-dev
TAG=roach-0.1

aws ecr get-login-password --region $AWS_REGION \
  | docker login --username AWS --password-stdin $REPO

docker build -t ${REPO}:${TAG} -f docker/roach/Dockerfile .
docker push ${REPO}:${TAG}