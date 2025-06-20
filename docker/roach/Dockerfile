# --- GPU 対応 CARLA 0.9.13 ----------------------------------------------------
FROM carlasim/carla:0.9.13

# --- 依存パッケージ ----------------------------------------------------------
RUN apt-get update && \
    apt-get install -y git python3-pip && \
    pip3 install --upgrade pip

# --- Roach クローン & インストール -------------------------------------------
RUN git clone --recursive https://github.com/zhejz/carla-roach.git /workspace/roach && \
    pip3 install -r /workspace/roach/requirements.txt

WORKDIR /workspace/roach
ENV PYTHONPATH=/workspace/roach:$PYTHONPATH