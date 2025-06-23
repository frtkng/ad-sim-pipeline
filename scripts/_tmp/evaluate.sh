#!/bin/bash
set -e
RUN_ID=$1
OUT_DIR="/tmp/carla_results/${RUN_ID}"

NG_TOTAL=0
mkdir -p ng_data/${RUN_ID}
for f in $OUT_DIR/metrics_*.json; do
  cnt=$(jq .NG $f)
  NG_TOTAL=$((NG_TOTAL + cnt))
  if [ "$cnt" -gt 0 ]; then
    cp $OUT_DIR/scenario_data/* ng_data/${RUN_ID}/
  fi
done

echo $NG_TOTAL