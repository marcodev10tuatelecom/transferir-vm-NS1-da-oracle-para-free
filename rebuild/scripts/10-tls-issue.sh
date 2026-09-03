#!/usr/bin/env bash
set -Eeuo pipefail
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd); source "$DIR/lib/tps-common.sh"
require_root; COMMON=${1:-$TPS_REBUILD_ROOT/common.env}; NODE=${2:-$TPS_REBUILD_ROOT/node.env}
load_env "$COMMON"; load_env "$NODE"; require_var ACME_EMAIL; require_var PUBLIC_IPV4; new_evidence TPS-R10-TLS-ISSUE
NODE_FQDN=$([[ $ROLE == ns1 ]] && printf '%s' "$NS1_FQDN" || printf '%s' "$NS2_FQDN")
check_dns(){
  local h=$1
  dig +short A "$h" | grep -Fxq "$PUBLIC_IPV4" || die "DNS_NOT_POINTING_HERE:$h:$PUBLIC_IPV4"
}
issue(){
  local h=$1; shift
  check_dns "$h"
  certbot certonly --non-interactive --agree-tos --email "$ACME_EMAIL" --webroot -w /var/lib/tpsmedia/acme --cert-name "$h" -d "$h" "$@"
}
issue "$NODE_FQDN"
if [[ $ROLE == ns1 ]]; then
  for h in $MEDIA_TLS_HOSTS; do
    check_dns "$h"
    # www alias is included only when it independently resolves to this node.
    args=(); if dig +short A "www.$h" | grep -Fxq "$PUBLIC_IPV4"; then args=(-d "www.$h"); fi
    issue "$h" "${args[@]}"
  done
fi
install -d -m 0755 /etc/letsencrypt/renewal-hooks/deploy
cat > /etc/letsencrypt/renewal-hooks/deploy/001-tps-reload-nginx.sh <<'EOF'
#!/usr/bin/env bash
set -e
if nginx -t >/var/log/tps-certbot-nginx-test.log 2>&1; then systemctl reload nginx; else exit 1; fi
EOF
chmod 0755 /etc/letsencrypt/renewal-hooks/deploy/001-tps-reload-nginx.sh
systemctl enable --now certbot.timer
printf 'TLS_ISSUE=PASS\n'
