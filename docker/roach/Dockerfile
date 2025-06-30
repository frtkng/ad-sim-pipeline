# --- 1. ベースイメージは Carla 0.9.15 ---
FROM carlasim/carla:0.9.15

USER root

# --- 2. Python 3.8 + 必要なツールの導入 ---
RUN apt-get update && \
    apt-get install -y python3.8 python3.8-dev python3.8-distutils git curl build-essential && \
    rm -rf /var/lib/apt/lists/*

# --- 3. pip for Python3.8 ---
RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.8

# python3/pip3 コマンドを3.8に揃える
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.8 1 && \
    ln -sf /usr/local/bin/pip3 /usr/bin/pip3 && \
    ln -sf /usr/local/bin/pip3 /usr/bin/pip

# --- 4. Roach をクローン ---
RUN git clone --recursive https://github.com/zhejz/carla-roach.git /workspace/roach

WORKDIR /workspace/roach

# --- 5. pip依存（environment.yml内のpip部分のみ）を一括インストール ---
RUN awk 'p{ if($0~/^ *-/){gsub("^ *- *",""); print}else exit} /pip:/{p=1}' environment.yml | xargs -r pip3 install --no-cache-dir

# --- 6. CUDA-11.3対応 PyTorch（Carlaイメージに合わせる） ---
RUN pip3 install --no-cache-dir torch==1.10.2+cu113 torchvision==0.11.3+cu113 -f https://download.pytorch.org/whl/torch_stable.html

# --- 7. （推奨）Roach用 非rootユーザー作成と権限移譲 ---
RUN getent passwd carla >/dev/null 2>&1 || useradd -m -s /bin/bash carla && \
    chown -R carla:carla /workspace

USER carla
WORKDIR /workspace/roach
ENV PYTHONPATH=/workspace/roach:$PYTHONPATH

# --- 8. 確認（ビルド時のデバッグ用途、不要なら削除可） ---
RUN python3 --version && pip3 --version

# ----（エントリポイントは Roach/Carla 用に必要に応じて設定）----