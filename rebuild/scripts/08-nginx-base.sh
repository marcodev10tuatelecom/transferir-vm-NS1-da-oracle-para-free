#!/usr/bin/env bash
set -Eeuo pipefail
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd); source "$DIR/lib/tps-common.sh"
require_root; COMMON=${1:-$TPS_REBUILD_ROOT/common.env}; NODE=${2:-$TPS_REBUILD_ROOT/node.env}
load_env "$COMMON"; load_env "$NODE"; new_evidence TPS-R08-NGINX-BASE
backup_path /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-enabled/default
install -d -o root -g root -m 0755 /etc/nginx/snippets /etc/nginx/tps-canonical/conf.d
cat > /etc/nginx/snippets/tps-ssl-params.conf <<'EOF'
ssl_session_cache shared:TPSMediaTLS:20m;
ssl_session_timeout 1d;
ssl_session_tickets off;
resolver 8.8.8.8 1.1.1.1 valid=300s;
resolver_timeout 5s;
EOF
cat > /etc/nginx/conf.d/00-tps-canonical-loader.conf <<'EOF'
include /etc/nginx/tps-canonical/conf.d/*.conf;
EOF
nginx -t || die NGINX_BASE_INVALID
systemctl enable nginx
systemctl restart nginx
printf 'NGINX_BASE=PASS\n'
