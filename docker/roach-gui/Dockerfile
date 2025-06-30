FROM carlasim/carla:0.9.14

# Rootユーザーに切り替え
USER root

# 1) aptで最低限のツールとGUI表示/LibrariesおよびX11アプリをインストール
RUN sed -i 's/^deb /#deb /g' /etc/apt/sources.list.d/cuda*.list || true \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
        git python3-pip python3-setuptools python3-wheel build-essential \
        x11-xserver-utils x11-apps libxrandr2 libxinerama1 libxcursor1 libxi6 libglu1-mesa \
        dbus-x11 xdg-utils xdg-user-dirs libgtk2.0-0 libgtk-3-0 \
        libxcomposite1 libxdamage1 libxext6 libxrender1 libxss1 \
        libasound2 libpulse0 libsdl2-2.0-0 fonts-liberation fontconfig \
        libvulkan1 vulkan-utils mesa-vulkan-drivers \
 && rm -rf /var/lib/apt/lists/*

# Pipを最新版にアップグレード
RUN pip3 install --no-cache-dir --upgrade pip

# GUI表示用DISPLAY環境変数
ENV DISPLAY=:0

# 2) Roach を取得
RUN git clone --recursive https://github.com/zhejz/carla-roach.git /workspace/roach

# 3) environment.yml から非互換パッケージ行を削除
RUN sed -i '/^ *- *tifffile==2020\.10\.1/d' /workspace/roach/environment.yml

# 4) Pipセクションだけ抜き出して一括インストール
RUN awk 'p{ if($0~/^ *-/){gsub("^ *- *","" ); print}else exit} /pip:/{p=1}' \
      /workspace/roach/environment.yml \
  | xargs -r pip3 install --no-cache-dir

# 5) CUDA-11.3対応のPyTorch & torchvisionをインストール
RUN pip3 install --no-cache-dir \
      torch==1.10.2+cu113 torchvision==0.11.3+cu113 \
      -f https://download.pytorch.org/whl/torch_stable.html

# 6) carlaユーザーが存在しなければ作成し、所有権を付与
RUN getent passwd carla >/dev/null 2>&1 || useradd -m -s /bin/bash carla \
 && chown -R carla:carla /workspace

# carlaユーザーに切り替え
USER carla
WORKDIR /workspace/roach

# Pythonパス設定
ENV PYTHONPATH=/workspace/roach
