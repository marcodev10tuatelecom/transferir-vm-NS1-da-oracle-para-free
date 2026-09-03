#!/usr/bin/env bash
set -Eeuo pipefail
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd); source "$DIR/lib/tps-common.sh"
require_root; COMMON=${1:-$TPS_REBUILD_ROOT/common.env}; NODE=${2:-$TPS_REBUILD_ROOT/node.env}
load_env "$COMMON"; load_env "$NODE"; new_evidence TPS-R09-NGINX-HTTP
NODE_FQDN=$([[ $ROLE == ns1 ]] && printf '%s' "$NS1_FQDN" || printf '%s' "$NS2_FQDN")
cat > /etc/nginx/tps-canonical/conf.d/05-node-http.conf <<EOF
server {
 listen 80; server_name ${NODE_FQDN}; server_tokens off;
 location ^~ /.well-known/acme-challenge/ { root /var/lib/tpsmedia/acme; default_type text/plain; try_files \$uri =404; }
 location = /healthz { default_type text/plain; add_header Cache-Control "no-store" always; return 200 "TPS_${ROLE^^}_OK\\n"; }
 location / { default_type text/plain; return 200 "Tech Pro Solutions - ${ROLE^^}\\n"; }
}
EOF
if [[ $ROLE == ns1 ]]; then
  for host in $MEDIA_TLS_HOSTS; do
    safe=${host//./_}
    cat > "/etc/nginx/tps-canonical/conf.d/20-${safe}-http.conf" <<EOF
server {
 listen 80; server_name ${host} www.${host}; server_tokens off;
 location ^~ /.well-known/acme-challenge/ { root /var/lib/tpsmedia/acme; default_type text/plain; try_files \$uri =404; }
 location = /healthz { default_type text/plain; return 200 "TPS_MEDIA_OK\\n"; }
 location / { return 308 https://\$host\$request_uri; }
}
EOF
  done
fi
nginx -t || die NGINX_HTTP_INVALID
systemctl reload nginx
printf 'NGINX_HTTP_VHOSTS=PASS\n'
