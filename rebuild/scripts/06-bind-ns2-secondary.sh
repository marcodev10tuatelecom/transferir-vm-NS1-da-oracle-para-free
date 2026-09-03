#!/usr/bin/env bash
set -Eeuo pipefail
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd); source "$DIR/lib/tps-common.sh"
require_root; COMMON=${1:-$TPS_REBUILD_ROOT/common.env}; NODE=${2:-$TPS_REBUILD_ROOT/node.env}
load_env "$COMMON"; load_env "$NODE"; assert_role ns2; assert_hostname; require_var PEER_PRIVATE_IPV4; new_evidence TPS-R06-BIND-NS2
KEY=/etc/bind/keys/tpsolutions-ns1-ns2.key; [[ -s $KEY ]] || die TSIG_MISSING
chown root:bind "$KEY"; chmod 0640 "$KEY"
backup_path /etc/bind/named.conf.local
{
  printf 'include "/etc/bind/keys/tpsolutions-ns1-ns2.key";\n'
  for z in $PRIMARY_ZONES; do
    printf 'zone "%s" IN {\n  type secondary;\n  file "/var/cache/bind/slaves/db.%s";\n  primaries { %s key "tpsolutions-ns1-ns2"; };\n  allow-query { any; };\n  allow-transfer { none; };\n  notify no;\n};\n' "$z" "$z" "$PEER_PRIVATE_IPV4"
  done
} > /etc/bind/named.conf.local
chown root:bind /etc/bind/named.conf.local; chmod 0640 /etc/bind/named.conf.local
named-checkconf || die NAMED_NS2_INVALID
systemctl restart bind9
systemctl is-active --quiet bind9 || die BIND_NOT_ACTIVE
for z in $PRIMARY_ZONES; do rndc retransfer "$z" || true; done
for i in {1..30}; do ok=1; for z in $PRIMARY_ZONES; do dig @127.0.0.1 "$z" SOA +short | grep -q . || ok=0; done; [[ $ok -eq 1 ]] && break; sleep 2; done
named-checkconf -z || die SECONDARY_ZONE_LOAD_FAIL
printf 'BIND_NS2_SECONDARY=PASS\n'
