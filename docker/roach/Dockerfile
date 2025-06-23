# ───────────────────────────────────────────────────────────
#  CARLA 0.9.14  +  Roach (pip インストール版 / CUDA-11.3)
# ───────────────────────────────────────────────────────────
FROM carlasim/carla:0.9.14

USER root

# 1) apt で最低限のツールを入れる
RUN sed -i 's/^deb /#deb /g' /etc/apt/sources.list.d/cuda*.list || true \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
        git python3-pip python3-setuptools python3-wheel build-essential \
 && rm -rf /var/lib/apt/lists/* \
 && pip3 install --no-cache-dir --upgrade pip

# 2) Roach を取得
RUN git clone --recursive https://github.com/zhejz/carla-roach.git /workspace/roach

# environment.yml から tifffile==2020.10.1 の行を削除
RUN sed -i '/^ *- *tifffile==2020\.10\.1/d' /workspace/roach/environment.yml

# 3) Pip セクションだけ抜き出して一括インストール
RUN awk 'p{ if($0~/^ *-/){gsub("^ *- *",""); print}else exit} /pip:/{p=1}' \
      /workspace/roach/environment.yml \
  | xargs -r pip3 install --no-cache-dir

# 4) CUDA-11.3 対応の PyTorch & torchvision を上書きで入れる
RUN pip3 install --no-cache-dir \
      torch==1.10.2+cu113 torchvision==0.11.3+cu113 \
      -f https://download.pytorch.org/whl/torch_stable.html

# # 5) 非 root ユーザーを存在チェックしてから作成、権限合わせ
RUN getent passwd carla >/dev/null 2>&1 || useradd -m -s /bin/bash carla \
 && chown -R carla:carla /workspace
USER carla

WORKDIR /workspace/roach
ENV PYTHONPATH=/workspace/roach:$PYTHONPATH
