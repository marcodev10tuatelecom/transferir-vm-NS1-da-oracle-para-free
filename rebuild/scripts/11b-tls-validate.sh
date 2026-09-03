#!/usr/bin/env bash
set -Eeuo pipefail
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd); source "$DIR/lib/tps-common.sh"
require_root; COMMON=${1:-$TPS_REBUILD_ROOT/common.env}; NODE=${2:-$TPS_REBUILD_ROOT/node.env}
load_env "$COMMON"; load_env "$NODE"; new_evidence TPS-R11B-TLS-VALIDATE
NODE_FQDN=$([[ $ROLE == ns1 ]] && printf '%s' "$NS1_FQDN" || printf '%s' "$NS2_FQDN")
hosts="$NODE_FQDN"; [[ $ROLE == ns1 ]] && hosts="$hosts $MEDIA_TLS_HOSTS"
nginx -t || die NGINX_TEST_FAIL
for h in $hosts; do
  cert=/etc/letsencrypt/live/$h/fullchain.pem; [[ -s $cert ]] || die "CERT_MISSING:$h"
  openssl x509 -in "$cert" -noout -checkend 604800 >/dev/null || die "CERT_EXPIRES_LT_7D:$h"
  openssl x509 -in "$cert" -noout -subject -issuer -dates | tee "$EVIDENCE_DIR/${h}.txt"
  curl -kfsS --resolve "$h:443:127.0.0.1" "https://$h/healthz" >/dev/null || die "HTTPS_HEALTH_FAIL:$h"
done
systemctl is-enabled --quiet certbot.timer || die CERTBOT_TIMER_NOT_ENABLED
certbot renew --dry-run || die CERTBOT_DRY_RUN_FAIL
printf 'TLS_VALIDATION=PASS\n'
