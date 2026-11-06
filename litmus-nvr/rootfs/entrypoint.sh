#!/bin/bash
# ============================================================================
# Litmus HA add-on entrypoint (mirrors litmus-docker/entrypoint.sh — keep in sync).
# HA add-ons get a persistent /data automatically; everything else lives in the
# container's writable layer and is LOST on add-on update/restart — so all of
# litmus's writable data is redirected onto /data below.
# ============================================================================
set -e

DATA_DIR="${LITMUS_DATA_DIR:-/data}"

# 1) Device identity persistence (stable pairing across recreation/updates)
if [ -s "${DATA_DIR}/machine-id" ]; then
    cp "${DATA_DIR}/machine-id" /etc/machine-id
elif [ ! -s /etc/machine-id ]; then
    cat /proc/sys/kernel/random/uuid | tr -d '-' > /etc/machine-id
    if [ -d "${DATA_DIR}" ] || mkdir -p "${DATA_DIR}" 2>/dev/null; then
        cp /etc/machine-id "${DATA_DIR}/machine-id" 2>/dev/null || true
    fi
fi
echo "[entrypoint] device identity ready"

# 1b) Persist litmus's writable data on /data — for HA add-ons ONLY /data survives
# updates/restarts. Redirect each data dir to a /data subdir via symlink, migrating
# any pre-existing content once. (The standalone Docker image persists these via
# named volumes; add-ons can't add volumes, so /data is the equivalent.)
persist_to_data() {
    real="$1"; store="${DATA_DIR}/$2"
    mkdir -p "$store"
    if [ -e "$real" ] && [ ! -L "$real" ]; then
        cp -an "$real/." "$store/" 2>/dev/null || true
        rm -rf "$real"
    fi
    mkdir -p "$(dirname "$real")"
    ln -sfn "$store" "$real"
}
persist_to_data /etc/litmus            config    # settings + secure/ + zigbee.conf
persist_to_data /usr/share/litmus      share     # AI/speech/LPR models + face DB
persist_to_data /var/litmus            var       # downloads / datalog
persist_to_data /var/lib/.syscache-litmus     syscache  # security key/salt
persist_to_data /usr/lib/litmus/zigbee zigbee    # zigbee runtime + paired-device DB
echo "[entrypoint] persistent dirs linked to ${DATA_DIR} (config/share/var/syscache/zigbee)"

# 1c) Files that belong to the image, not to /data: the local screen (www/spot, port 8128), the message catalogs
#     (locales/<code>.json — read by the controller, src/litmus-common/LocaleCatalog.h) and the edition marker
#     (product.json — Litmus NVR add-on only). persist_to_data uses `cp -an` (never overwrites), so refresh them from
#     the image on every start — otherwise an add-on update never reaches them.
SHARE=/usr/share/litmus
if [ -d /opt/litmus-image ]; then
    rm -rf "$SHARE/www"
    [ -d /opt/litmus-image/www ] && cp -a /opt/litmus-image/www "$SHARE/www"
    rm -rf "$SHARE/locales"
    [ -d /opt/litmus-image/locales ] && cp -a /opt/litmus-image/locales "$SHARE/locales"
    if [ -f /opt/litmus-image/product.json ]; then
        cp -f /opt/litmus-image/product.json "$SHARE/product.json"
    else
        rm -f "$SHARE/product.json"
    fi
fi

# 2) Library cache
ldconfig /usr/lib/litmus 2>/dev/null || true

# 3) Audio — Supervisor (audio: true) injects PulseAudio; PULSE_SERVER is provided.
[ -n "${PULSE_SERVER}" ] && echo "[entrypoint] PULSE_SERVER=${PULSE_SERVER}"

# 4) Remove stale single-instance lock (litmus records PID 1; /run persists across
#    restarts). Harmless once the controller uses flock; safe belt-and-suspenders.
rm -f /run/litmus.pid

# 5) Mirror litmus's file log to stdout so HA add-on logs show it.
if [ "${LITMUS_LOG_STDOUT:-1}" = "1" ]; then
    tail -n0 -F /var/log/litmus/log.txt 2>/dev/null &
fi

# 6) Run litmus as PID 1.
echo "[entrypoint] exec litmus ..."
exec /usr/bin/litmus/litmus
