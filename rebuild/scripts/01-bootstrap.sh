#!/usr/bin/env bash
set -Eeuo pipefail
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$DIR/lib/tps-common.sh"
require_root
COMMON=${1:-$TPS_REBUILD_ROOT/common.env}; NODE=${2:-$TPS_REBUILD_ROOT/node.env}
load_env "$COMMON"; load_env "$NODE"; require_var HOSTNAME_SHORT
new_evidence TPS-R01-BOOTSTRAP
section 'HOSTNAME'
hostnamectl set-hostname "$HOSTNAME_SHORT"
section 'PACKAGES'
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl wget jq git rsync tar gzip unzip xz-utils openssl dnsutils bind9 bind9-utils nginx certbot ffmpeg shellcheck python3 nftables prometheus-node-exporter
systemctl enable systemd-timesyncd
systemctl restart systemd-timesyncd
section 'DIRECTORIES'
install -d -o root -g root -m 0755 /etc/tpsmedia /etc/tpsmedia/mediamtx /opt/tpsmedia/mediamtx/releases /var/lib/tpsmedia /var/lib/tpsmedia/acme/.well-known/acme-challenge /srv/tpsmedia /srv/tpsmedia/repository /var/log/tps-rebuild
section 'VALIDATION'
for c in named nginx certbot ffmpeg ffprobe shellcheck nft; do need "$c"; done
nginx -v
named -v
ffmpeg -version | head -1
printf 'BOOTSTRAP=PASS\n'
