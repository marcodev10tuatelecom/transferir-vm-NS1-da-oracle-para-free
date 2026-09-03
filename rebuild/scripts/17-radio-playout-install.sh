#!/usr/bin/env bash
set -Eeuo pipefail
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd); source "$DIR/lib/tps-common.sh"
require_root; COMMON=${1:-$TPS_REBUILD_ROOT/common.env}; load_env "$COMMON"; new_evidence TPS-R17-RADIO-PLAYOUT
cat > /usr/local/sbin/tps-radio-playout <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
CHANNEL=${1:?}; PLAYLIST=/srv/tpsmedia/repository/channels/$CHANNEL/playlists/playlist.txt; RUNTIME=/run/tps-radio-playout-$CHANNEL; OUT=$RUNTIME/repeated.ffconcat
[[ -s $PLAYLIST ]] || exit 20
while true; do
  { printf 'ffconcat version 1.0\n'; for _ in {1..200}; do sed -n '2,$p' "$PLAYLIST"; done; } > "$OUT.tmp"; mv "$OUT.tmp" "$OUT"
  /usr/bin/ffmpeg -hide_banner -loglevel warning -nostdin -re -f concat -safe 0 -i "$OUT" -map 0:a:0 -vn -c:a aac -b:a 128k -ar 44100 -ac 2 -af 'loudnorm=I=-16:TP=-1.5:LRA=11' -flvflags no_duration_filesize -f flv "rtmp://127.0.0.1:1935/$CHANNEL" || true
  sleep 1
done
EOF
chmod 0755 /usr/local/sbin/tps-radio-playout; chown root:root /usr/local/sbin/tps-radio-playout
install -o root -g root -m 0644 "$DIR/../systemd/tps-radio-playout@.service" /etc/systemd/system/tps-radio-playout@.service
systemctl daemon-reload
printf 'RADIO_PLAYOUT_ENGINE=PASS\n'
printf 'ACTION=Enable one station only after its playlist has been generated and validated.\n'
