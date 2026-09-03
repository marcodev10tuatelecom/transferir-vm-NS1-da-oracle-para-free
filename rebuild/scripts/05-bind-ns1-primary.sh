#!/usr/bin/env bash
set -Eeuo pipefail
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd); source "$DIR/lib/tps-common.sh"
require_root; COMMON=${1:-$TPS_REBUILD_ROOT/common.env}; NODE=${2:-$TPS_REBUILD_ROOT/node.env}
load_env "$COMMON"; load_env "$NODE"; assert_role ns1; assert_hostname; require_var PEER_PRIVATE_IPV4; new_evidence TPS-R05-BIND-NS1
KEY=/etc/bind/keys/tpsolutions-ns1-ns2.key; [[ -s $KEY ]] || die TSIG_MISSING
: "${PRIMARY_ZONES:?}"; : "${ZONE_SOURCE_DIR:?}"
backup_path /etc/bind/named.conf.local
install -d -o root -g bind -m 0750 /etc/bind/zones
for z in $PRIMARY_ZONES; do
  src="$ZONE_SOURCE_DIR/db.$z"; dst="/etc/bind/zones/db.$z"
  [[ -f $src && ! -L $src ]] || die "ZONE_SOURCE_MISSING:$src"
  named-checkzone "$z" "$src" || die "ZONE_SOURCE_INVALID:$z"
  install -o root -g bind -m 0640 "$src" "$dst"
done
{
  printf 'include "/etc/bind/keys/tpsolutions-ns1-ns2.key";\n'
  for z in $PRIMARY_ZONES; do
    printf 'zone "%s" IN {\n  type primary;\n  file "/etc/bind/zones/db.%s";\n  allow-query { any; };\n  allow-transfer { key "tpsolutions-ns1-ns2"; };\n  notify yes;\n  also-notify { %s key "tpsolutions-ns1-ns2"; };\n' "$z" "$z" "$PEER_PRIVATE_IPV4"
    if grep -qw "$z" <<<" ${DNSSEC_ZONES:-} "; then
      install -d -o bind -g bind -m 0770 "/var/cache/bind/tps-dnssec/$z"
      printf '  dnssec-policy default;\n  inline-signing yes;\n  key-directory "/var/cache/bind/tps-dnssec/%s";\n' "$z"
    fi
    printf '};\n'
  done
} > /etc/bind/named.conf.local
chown root:bind /etc/bind/named.conf.local; chmod 0640 /etc/bind/named.conf.local
named-checkconf -z || die NAMED_NS1_INVALID
systemctl restart bind9
systemctl is-active --quiet bind9 || die BIND_NOT_ACTIVE
for z in $PRIMARY_ZONES; do dig @127.0.0.1 "$z" SOA +norecurse +comments | grep -q ' aa' || die "LOCAL_AA_FAIL:$z"; done
printf 'BIND_NS1_PRIMARY=PASS\n'
