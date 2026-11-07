# Litmus NVR — HA add-on image.
# Built on the HA base (build.yaml) using the same recipe as the standalone image:
# fetch the public release .deb and extract it (install scripts are not run).
ARG BUILD_FROM
FROM ${BUILD_FROM}

ARG LITMUS_VERSION=2.2.1
ENV DEBIAN_FRONTEND=noninteractive \
    LD_LIBRARY_PATH=/usr/lib/litmus \
    GRABLO_CONTAINER=1 \
    S6_KEEP_ENV=1
# S6_KEEP_ENV=1: the HA base image runs the entrypoint under s6-overlay, which by
# default starts services with a BLANK environment. Without this, the Supervisor-
# injected SUPERVISOR_TOKEN never reaches litmus → add-on auto-auth (controller
# 1.20.0+) silently fails. Verified on a real HAOS VM. (s6-overlay README: if
# S6_KEEP_ENV is set, the whole supervision tree sees the original env vars.)

# Runtime dependencies (same set as litmus-docker/Dockerfile — keep in sync).
RUN apt-get update && apt-get install -y --no-install-recommends \
      vlc libvlc5 libxss1 libltdl7 libssh2-1 libcurl4 libatomic1 \
      libusb-1.0-0 libpq5 unixodbc libpulse0 libvulkan1 \
      pulseaudio pulseaudio-utils alsa-utils libharfbuzz0b libxml2 \
      libfreetype6 mosquitto ca-certificates curl \
      libxcursor1 libxinerama1 libxrandr2 libxi6 libwayland-cursor0 \
      libgstreamer1.0-0 libgstreamer-plugins-base1.0-0 \
 && rm -rf /var/lib/apt/lists/*
# ★ libxi6 는 2026-09-22 trixie 전환에서 **명시로 옮긴 것**이다. bullseye 에서는
#   다른 패키지의 전이 의존으로 딸려와 목록에 없어도 됐는데, trixie 에서 그 체인이
#   끊겨 `libXi.so.6 => not found` 가 났다(본체와 미디어 라이브러리 둘 다).
#   배포 중인 1.29.1(bullseye) 이미지는 미해결 0 건이라 이것은 전환이 만든 회귀다.
#   전이 의존에 기대면 베이스가 바뀔 때마다 같은 일이 난다 — 필요한 것은 적어 둔다.

RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    curl -fsSL -o /tmp/litmus.deb "https://downloads.litmusnvr.com/releases/litmus/litmus-nvr_${LITMUS_VERSION}_${arch}.deb"; \
    dpkg-deb -x /tmp/litmus.deb /tmp/litmus-root; \
    cp -a /tmp/litmus-root/usr/bin/litmus /usr/bin/; \
    cp -a /tmp/litmus-root/usr/lib/litmus /usr/lib/; \
    cp -a /tmp/litmus-root/usr/share/litmus /usr/share/; \
    # License and copyright. Outside /data, so they always follow the image.
    cp -a /tmp/litmus-root/usr/share/doc/litmus /usr/share/doc/ 2>/dev/null || true; \
    # Image-owned copy: the entrypoint moves /usr/share/litmus onto /data (models, face DB) with `cp -an`, which never
    # overwrites — the local screen (www/spot), the default sounds (sounds), the message catalogs (locales/<code>.json) and the edition marker
    # (product.json) would stay at the first install's version. The entrypoint refreshes them from here on every start.
    mkdir -p /opt/litmus-image; \
    cp -a /tmp/litmus-root/usr/share/litmus/www /opt/litmus-image/www 2>/dev/null || true; \
    cp -a /tmp/litmus-root/usr/share/litmus/sounds /opt/litmus-image/sounds 2>/dev/null || true; \
    cp -a /tmp/litmus-root/usr/share/litmus/locales /opt/litmus-image/locales 2>/dev/null || true; \
    cp -a /tmp/litmus-root/usr/share/litmus/product.json /opt/litmus-image/product.json 2>/dev/null || true; \
    rm -rf /tmp/litmus.deb /tmp/litmus-root; \
    ldconfig /usr/lib/litmus

COPY rootfs/entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh \
 && chmod +x /entrypoint.sh /usr/bin/litmus/litmus

WORKDIR /usr/bin/litmus
CMD ["/entrypoint.sh"]
