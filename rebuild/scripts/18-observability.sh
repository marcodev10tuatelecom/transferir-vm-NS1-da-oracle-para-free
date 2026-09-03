#!/usr/bin/env bash
set -Eeuo pipefail
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd); source "$DIR/lib/tps-common.sh"
require_root; new_evidence TPS-R18-OBSERVABILITY
cat > /usr/local/sbin/tps-health-snapshot <<'EOF'
#!/usr/bin/env bash
set -u
OUT=/var/log/tps-rebuild/health-latest.txt; TMP=${OUT}.tmp
{
  printf 'UTC=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  for u in bind9 nginx tps-mediamtx nftables; do printf 'UNIT_%s=%s\n' "$u" "$(systemctl is-active "$u" 2>/dev/null || true)"; done
  printf 'FAILED_UNITS=%s\n' "$(systemctl --failed --no-legend 2>/dev/null | wc -l)"
  printf 'ROOT_USE_PCT=%s\n' "$(df -P / | awk 'NR==2{gsub(/%/,"",$5);print $5}')"
  curl -fsS --max-time 3 http://127.0.0.1:9997/v3/paths/list 2>/dev/null | jq -r '[.items[]|select(.ready==true)]|length|"MEDIAMTX_READY_PATHS=\(.)"' || printf 'MEDIAMTX_READY_PATHS=API_FAIL\n'
} > "$TMP"
mv "$TMP" "$OUT"; chmod 0640 "$OUT"
EOF
chmod 0755 /usr/local/sbin/tps-health-snapshot
install -o root -g root -m 0644 "$DIR/../systemd/tps-health-snapshot.service" /etc/systemd/system/tps-health-snapshot.service
install -o root -g root -m 0644 "$DIR/../systemd/tps-health-snapshot.timer" /etc/systemd/system/tps-health-snapshot.timer
cat > /etc/nginx/tps-canonical/conf.d/40-monitoring-local.conf <<'EOF'
server { listen 127.0.0.1:8080; server_name localhost; location = /nginx_status { stub_status; access_log off; } }
EOF
nginx -t || die NGINX_MONITORING_INVALID
systemctl reload nginx
systemctl enable --now prometheus-node-exporter tps-health-snapshot.timer
systemctl start tps-health-snapshot.service
[[ -s /var/log/tps-rebuild/health-latest.txt ]] || die HEALTH_SNAPSHOT_FAIL
printf 'OBSERVABILITY_LOCAL=PASS\n'
printf 'EXTERNAL_MONITORING=REQUIRES_PROVIDER_OR_CONTROL_PLANE_CONFIGURATION\n'
