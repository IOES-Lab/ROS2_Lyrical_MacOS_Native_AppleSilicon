#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-lyrical-sim:jetty-rdp-no-cache-20260830}"
CONTAINER="${2:-lyrical-no-cache-rdp}"
HOST_PORT="${3:-3399}"
OUT="${4:-.}"
mkdir -p "$OUT"

docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
docker run -d --name "$CONTAINER" \
  -p "127.0.0.1:${HOST_PORT}:3389" "$IMAGE" \
  | tee "$OUT/container_id.txt"

for _ in $(seq 1 90); do
  if nc -z 127.0.0.1 "$HOST_PORT" 2>/dev/null; then
    echo "RDP_PORT_READY=true" | tee "$OUT/port_ready.txt"
    break
  fi
  sleep 1
done
test -s "$OUT/port_ready.txt"

# Use a real RDP client rather than starting Xorg manually. FreeRDP's SDL client
# was used for the retained fresh-build evidence because the Windows App cannot
# be driven through this machine's disabled Accessibility API. The image itself
# deliberately documents docker/docker as its localhost-only validation login.
command -v sdl-freerdp >/dev/null
sdl-freerdp /v:"localhost:${HOST_PORT}" /u:docker /p:docker \
  /cert:ignore /size:1280x900 /dynamic-resolution \
  >"$OUT/rdp_client.log" 2>&1 &
rdp_client_pid=$!
printf 'CLIENT=FreeRDP SDL\nPID=%s\n' "$rdp_client_pid" \
  > "$OUT/rdp_client.txt"

display=""
for _ in $(seq 1 150); do
  display="$(docker exec "$CONTAINER" bash -lc \
    'find /tmp/.X11-unix -maxdepth 1 -type s -name "X*" -print 2>/dev/null | head -1' \
    | sed 's#.*/X##')"
  if [[ -n "$display" ]] && docker exec "$CONTAINER" \
      test -f /home/docker/.Xauthority; then
    break
  fi
  sleep 1
done
test -n "$display"

docker exec "$CONTAINER" bash -lc '
  pgrep -af "xrdp|Xorg|xfce4-session" || true
  ls -l /tmp/.X11-unix /home/docker/.Xauthority
' | tee "$OUT/session_processes.txt"

docker exec -u docker "$CONTAINER" bash -lc \
  "DISPLAY=:${display} XAUTHORITY=/home/docker/.Xauthority \
   xwd -root -silent -out /home/docker/no_cache_rdp_root.xwd && \
   ffmpeg -y -loglevel error -i /home/docker/no_cache_rdp_root.xwd \
     /home/docker/no_cache_rdp_root.png"
docker cp "$CONTAINER":/home/docker/no_cache_rdp_root.png \
  "$OUT/no_cache_rdp_root.png"

docker exec "$CONTAINER" bash -lc '
  tail -200 /var/log/xrdp.log 2>/dev/null || true
' > "$OUT/xrdp.log"
docker exec "$CONTAINER" bash -lc '
  tail -200 /var/log/xrdp-sesman.log 2>/dev/null || true
' > "$OUT/xrdp-sesman.log"

printf 'RDP_LOGIN=true\nDISPLAY=:%s\nFRAMEBUFFER_CAPTURE=true\n' "$display" \
  | tee "$OUT/rendered_rdp_summary.txt"
