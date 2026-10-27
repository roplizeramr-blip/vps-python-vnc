#!/bin/bash
# Lightest possible desktop front end: nginx + websockify, nothing else.
#
#   nginx      -> the only public listener (Basic Auth, status page, WS upgrade)
#   websockify -> serves the noVNC client and bridges the WebSocket
#
# No supervisor, no X server, no XFCE, no systemd facade: two processes.

set -Eeuo pipefail

PORT="${PORT:-3000}"
WS_PORT="${WS_PORT:-6080}"
VNC_USER="${VNC_USER:-admin}"
VNC_PW="${VNC_PW:-}"
PUBLIC_DESKTOP="${PUBLIC_DESKTOP:-1}"

log() { printf '[entrypoint] %s\n' "$*"; }

if [ -n "$VNC_PW" ]; then
    # Basic Auth for the public URL. The password never touches the image.
    install -m 0640 -o www-data -g www-data /dev/null /etc/nginx/.htpasswd
    printf '%s:%s\n' "$VNC_USER" "$(openssl passwd -apr1 "$VNC_PW")" > /etc/nginx/.htpasswd
    log "basic auth enabled for user '$VNC_USER'"
else
    log "WARNING: VNC_PW is empty, the desktop is reachable without a password"
fi

sed -i "s/__PORT__/${PORT}/g; s/__WS_PORT__/${WS_PORT}/g" /etc/nginx/nginx.conf
nginx -t

log "starting websockify on 127.0.0.1:${WS_PORT}"
websockify --web=/opt/novnc --heartbeat=20 "127.0.0.1:${WS_PORT}" "127.0.0.1:5901" &
WS_PID=$!

# Give websockify a moment to bind before nginx starts serving.
for _ in $(seq 1 20); do
    if (exec 3<>"/dev/tcp/127.0.0.1/${WS_PORT}") 2>/dev/null; then
        exec 3<&- 3>&-
        break
    fi
    sleep 0.25
done

cleanup() {
    log "stopping websockify"
    kill "$WS_PID" 2>/dev/null || true
}
trap cleanup EXIT

log "starting nginx on :${PORT}"
nginx -g 'daemon off;'
