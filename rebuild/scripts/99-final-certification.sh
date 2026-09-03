#!/usr/bin/env bash
set -Eeuo pipefail
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd); source "$DIR/lib/tps-common.sh"
require_root; COMMON=${1:-$TPS_REBUILD_ROOT/common.env}; NODE=${2:-$TPS_REBUILD_ROOT/node.env}
load_env "$COMMON"; load_env "$NODE"; new_evidence TPS-R99-FINAL-CERTIFICATION
assert_hostname
section 'CRITICAL UNITS'
for u in bind9 nginx nftables tps-mediamtx; do systemctl is-active --quiet "$u" || die "UNIT_NOT_ACTIVE:$u"; printf '%s=active\n' "$u"; done
systemctl is-active --quiet prometheus-node-exporter || die NODE_EXPORTER_NOT_ACTIVE
systemctl is-enabled --quiet certbot.timer || die CERTBOT_TIMER_DISABLED
section 'STATIC CONFIG'
named-checkconf -z || die NAMED_INVALID
nginx -t || die NGINX_INVALID
section 'DNS LOCAL/PEER'
for z in $PRIMARY_ZONES; do
  dig @127.0.0.1 "$z" SOA +norecurse +comments | grep -q ' aa' || die "LOCAL_DNS_AA_FAIL:$z"
  a=$(dig @127.0.0.1 "$z" SOA +short); b=$(dig @"$PEER_PRIVATE_IPV4" "$z" SOA +short); [[ -n $a && "$a" == "$b" ]] || die "SOA_PARITY_FAIL:$z"
done
section 'TLS'
NODE_FQDN=$([[ $ROLE == ns1 ]] && printf '%s' "$NS1_FQDN" || printf '%s' "$NS2_FQDN")
hosts="$NODE_FQDN"; [[ $ROLE == ns1 ]] && hosts="$hosts $MEDIA_TLS_HOSTS"
for h in $hosts; do cert=/etc/letsencrypt/live/$h/fullchain.pem; [[ -s $cert ]] || die "CERT_MISSING:$h"; openssl x509 -in "$cert" -noout -checkend 604800 >/dev/null || die "CERT_LT_7D:$h"; curl -kfsS --resolve "$h:443:127.0.0.1" "https://$h/healthz" >/dev/null || die "HTTPS_LOCAL_FAIL:$h"; done
section 'MEDIAMTX AUTHORITY'
PID=$(systemctl show tps-mediamtx.service -p MainPID --value); [[ $PID =~ ^[0-9]+$ && $PID -gt 1 ]] || die MEDIAMTX_PID_INVALID
mapfile -t mpids < <(pgrep -x mediamtx || true); [[ ${#mpids[@]} -eq 1 && ${mpids[0]} == "$PID" ]] || die "MEDIAMTX_ORPHAN_OR_DUPLICATE:${mpids[*]-none}"
curl -fsS http://127.0.0.1:9997/v3/info | jq . > "$EVIDENCE_DIR/mediamtx-info.json" || die MEDIAMTX_API_FAIL
curl -fsS http://127.0.0.1:9998/metrics >/dev/null || die MEDIAMTX_METRICS_FAIL
section 'LISTENERS'
ss -lntup | tee "$EVIDENCE_DIR/listeners.txt"
for p in 53 80 443 1935; do grep -Eq ":$p[[:space:]]" "$EVIDENCE_DIR/listeners.txt" || die "PUBLIC_LISTENER_MISSING:$p"; done
for p in 8554 8888 8889 9997 9998; do grep -E '127\.0\.0\.1:'"$p"'[[:space:]]' "$EVIDENCE_DIR/listeners.txt" >/dev/null || die "LOOPBACK_LISTENER_FAIL:$p"; done
section 'REPOSITORY'
[[ -s /srv/tpsmedia/repository/.tps-canonical-repository ]] || die REPOSITORY_MARKER_MISSING
[[ ! -e /srv/tpsmedia/content ]] || die LEGACY_CONTENT_ROOT_PRESENT
[[ ! -e /srv/tpsmedia/filler ]] || die LEGACY_FILLER_ROOT_PRESENT
section 'LEGACY REFERENCES'
if grep -R -n -E '/etc/studiosat|/etc/mediamtx|\.tps-r07-stage' /etc/nginx/tps-canonical /etc/systemd/system/tps-* /etc/tpsmedia 2>/dev/null; then die LEGACY_REFERENCE_FOUND; fi
section 'TIME DISK'
[[ $(timedatectl show -p NTPSynchronized --value) == yes ]] || die NTP_NOT_SYNCED
use=$(df -P / | awk 'NR==2{gsub(/%/,"",$5);print $5}'); ((use < 90)) || die "ROOT_DISK_GE_90:$use"
section 'BACKUP'
latest=$(find /root/tps-backups -maxdepth 1 -type f -name 'TPS-*-CONFIG-BACKUP-*.tar.gz' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2- || true)
[[ -n $latest && -f $latest.sha256 ]] || die BACKUP_NOT_FOUND
(cd "$(dirname "$latest")" && sha256sum -c "$(basename "$latest").sha256") || die BACKUP_HASH_FAIL
section 'RESULT'
printf 'LOCAL_CERTIFICATION=PASS\nPUBLIC_CERTIFICATION=REQUIRES_21_PUBLIC_VALIDATE_FROM_THIRD_HOST\nREBOOT_CERTIFICATION=REQUIRES_REPEAT_AFTER_CONTROLLED_REBOOT\nTPS_CANONICAL_LOCAL=PASS\n'
