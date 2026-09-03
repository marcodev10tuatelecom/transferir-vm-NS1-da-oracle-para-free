#!/usr/bin/env bash
set -Eeuo pipefail
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd); source "$DIR/lib/tps-common.sh"
require_root; COMMON=${1:-$TPS_REBUILD_ROOT/common.env}; NODE=${2:-$TPS_REBUILD_ROOT/node.env}
load_env "$COMMON"; load_env "$NODE"; require_var PRIVATE_IPV4; new_evidence TPS-R04-BIND-COMMON
install -d -o root -g bind -m 0750 /etc/bind/keys /etc/bind/zones
install -d -o bind -g bind -m 0770 /var/cache/bind/slaves /var/cache/bind/tps-dnssec
backup_path /etc/bind/named.conf.options
cat > /etc/bind/named.conf.options <<EOF
options {
  directory "/var/cache/bind";
  listen-on port 53 { 127.0.0.1; ${PRIVATE_IPV4}; };
  listen-on-v6 port 53 { ::1; };
  allow-query { any; };
  recursion no;
  allow-recursion { none; };
  allow-query-cache { none; };
  allow-transfer { none; };
  auth-nxdomain no;
  minimal-responses yes;
  minimal-any yes;
  version "not disclosed";
  hostname none;
  server-id none;
  dnssec-validation no;
  edns-udp-size 1232;
  max-udp-size 1232;
  rate-limit { responses-per-second 20; errors-per-second 5; nxdomains-per-second 5; referrals-per-second 5; all-per-second 100; window 5; slip 2; };
  notify-rate 20;
  startup-notify-rate 20;
  serial-query-rate 20;
  transfer-format many-answers;
  provide-ixfr yes;
  request-ixfr yes;
  tcp-clients 100;
};
EOF
named-checkconf || die NAMED_COMMON_INVALID
systemctl enable bind9
printf 'BIND_COMMON=PASS\n'
