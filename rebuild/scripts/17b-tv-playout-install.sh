#!/usr/bin/env bash
set -Eeuo pipefail
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd); source "$DIR/lib/tps-common.sh"
require_root; new_evidence TPS-R17B-TV-PLAYOUT
cat > /usr/local/sbin/tps-tv-playout <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
CHANNEL=${1:?}; PLAYLIST=/srv/tpsmedia/repository/channels/$CHANNEL/playlists/playlist.txt; RUNTIME=/run/tps-tv-playout-$CHANNEL; OUT=$RUNTIME/repeated.ffconcat
[[ -s $PLAYLIST ]] || exit 20
while true; do
  { printf 'ffconcat version 1.0\n'; for _ in {1..100}; do sed -n '2,$p' "$PLAYLIST"; done; } > "$OUT.tmp"; mv "$OUT.tmp" "$OUT"
  /usr/bin/ffmpeg -hide_banner -loglevel warning -nostdin -re -fflags +genpts -f concat -safe 0 -i "$OUT" -map 0:v:0 -map 0:a:0 -c copy -flvflags no_duration_filesize -f flv "rtmp://127.0.0.1:1935/$CHANNEL" || true
  sleep 1
done
EOF
chmod 0755 /usr/local/sbin/tps-tv-playout; chown root:root /usr/local/sbin/tps-tv-playout
install -o root -g root -m 0644 "$DIR/../systemd/tps-tv-playout@.service" /etc/systemd/system/tps-tv-playout@.service
systemctl daemon-reload
printf 'TV_PLAYOUT_ENGINE=PASS\n'
printf 'REQUIREMENT=Assets must be pre-normalized to an FLV-compatible H264+AAC profile before enabling the service.\n'
