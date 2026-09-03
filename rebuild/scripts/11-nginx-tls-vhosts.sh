#!/usr/bin/env bash
set -Eeuo pipefail
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd); source "$DIR/lib/tps-common.sh"
require_root; COMMON=${1:-$TPS_REBUILD_ROOT/common.env}; NODE=${2:-$TPS_REBUILD_ROOT/node.env}
load_env "$COMMON"; load_env "$NODE"; new_evidence TPS-R11-NGINX-TLS
NODE_FQDN=$([[ $ROLE == ns1 ]] && printf '%s' "$NS1_FQDN" || printf '%s' "$NS2_FQDN")
[[ -s /etc/letsencrypt/live/$NODE_FQDN/fullchain.pem ]] || die NODE_CERT_MISSING
cat > /etc/nginx/tps-canonical/conf.d/06-node-https.conf <<EOF
server {
 listen 443 ssl; server_name ${NODE_FQDN}; server_tokens off;
 ssl_certificate /etc/letsencrypt/live/${NODE_FQDN}/fullchain.pem;
 ssl_certificate_key /etc/letsencrypt/live/${NODE_FQDN}/privkey.pem;
 include /etc/nginx/snippets/tps-ssl-params.conf;
 add_header X-Content-Type-Options nosniff always;
 location = /healthz { default_type text/plain; return 200 "TPS_${ROLE^^}_OK\\n"; }
 location / { default_type text/plain; return 200 "Tech Pro Solutions - ${ROLE^^}\\n"; }
}
EOF
write_media(){
  local h=$1 path=$2 root=$3; [[ -s /etc/letsencrypt/live/$h/fullchain.pem ]] || die "CERT_MISSING:$h"
  safe=${h//./_}; install -d -o root -g www-data -m 0755 "$root"
  [[ -f $root/index.html ]] || printf '<!doctype html><meta charset="utf-8"><title>StudioSat</title><h1>StudioSat</h1>\n' > "$root/index.html"
  cat > "/etc/nginx/tps-canonical/conf.d/30-${safe}-https.conf" <<EOF
server {
 listen 443 ssl; server_name ${h}; server_tokens off;
 ssl_certificate /etc/letsencrypt/live/${h}/fullchain.pem;
 ssl_certificate_key /etc/letsencrypt/live/${h}/privkey.pem;
 include /etc/nginx/snippets/tps-ssl-params.conf;
 root ${root}; index index.html;
 add_header X-Content-Type-Options nosniff always;
 location = /healthz { default_type text/plain; return 200 "TPS_MEDIA_OK\\n"; }
 location ^~ /stream/ { rewrite ^/stream/(.*)$ /${path}/\$1 break; proxy_pass http://127.0.0.1:8888; proxy_buffering off; proxy_read_timeout 30s; }
 location ^~ /webrtc/ { rewrite ^/webrtc/(.*)$ /\$1 break; proxy_pass http://127.0.0.1:8889; proxy_http_version 1.1; proxy_set_header Host \$host; proxy_set_header X-Forwarded-Proto https; proxy_buffering off; }
 location / { try_files \$uri \$uri/ /index.html; }
}
EOF
}
if [[ $ROLE == ns1 ]]; then
  for h in $MEDIA_TLS_HOSTS; do
    case "$h" in
      radio.$MEDIA_DOMAIN) p=radio-main; r=/srv/tpsmedia/www/radio ;;
      pop.radio.$MEDIA_DOMAIN) p=radio-pop; r=/srv/tpsmedia/www/radio-pop ;;
      rock.radio.$MEDIA_DOMAIN) p=radio-rock; r=/srv/tpsmedia/www/radio-rock ;;
      classicas.radio.$MEDIA_DOMAIN) p=radio-classicas; r=/srv/tpsmedia/www/radio-classicas ;;
      country.radio.$MEDIA_DOMAIN) p=radio-country; r=/srv/tpsmedia/www/radio-country ;;
      radiotv.$MEDIA_DOMAIN) p=tv-main; r=/srv/tpsmedia/www/radiotv ;;
      tvkidsweb.$MEDIA_DOMAIN) p=tvkids-main; r=/srv/tpsmedia/www/tvkidsweb ;;
      tvteensweb.$MEDIA_DOMAIN) p=tvteens-main; r=/srv/tpsmedia/www/tvteensweb ;;
      tvvivaweb.$MEDIA_DOMAIN) p=tvviva-main; r=/srv/tpsmedia/www/tvvivaweb ;;
      tvmaisjovemweb.$MEDIA_DOMAIN) p=tvmaisjovem-main; r=/srv/tpsmedia/www/tvmaisjovemweb ;;
      *) die "UNMAPPED_MEDIA_HOST:$h" ;;
    esac
    write_media "$h" "$p" "$r"
  done
fi
nginx -t || die NGINX_TLS_INVALID
systemctl reload nginx
printf 'NGINX_TLS=PASS\n'
