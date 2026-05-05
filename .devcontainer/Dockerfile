FROM docker.io/zmkfirmware/zmk-build-arm:stable

COPY .bashrc tmp
RUN mv /tmp/.bashrc ~/.bashrc

RUN apt-get update && apt-get install -y --no-install-recommends \
    yq \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# キーマップ可視化ツール (make draw / 全ビルドターゲット末尾で使用)
RUN pip install --break-system-packages --no-cache-dir keymap-drawer