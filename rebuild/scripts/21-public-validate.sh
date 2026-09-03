#!/usr/bin/env bash
set -Eeuo pipefail
# Execute preferencialmente de um terceiro host/Cloud Shell, não do próprio edge.
COMMON=${1:?common.env}; NS1=${2:?ns1.env}; NS2=${3:?ns2.env}
set -a; source "$COMMON"; set +a
load_node(){ set -a; source "$1"; set +a; }
fail(){ printf 'FAIL=%s\n' "$*"; exit 1; }
for c in dig curl openssl; do command -v "$c" >/dev/null || fail "MISSING:$c"; done
for f in "$NS1" "$NS2"; do
  load_node "$f"; ip=$PUBLIC_IPV4; role=$ROLE
  printf '\n=== %s %s ===\n' "$role" "$ip"
  for z in $PRIMARY_ZONES; do
    u=$(dig +time=4 +tries=1 @"$ip" "$z" SOA +norecurse +comments) || fail "$role:$z:UDP"
    grep -q ' aa' <<<"$u" || fail "$role:$z:UDP_AA"
    t=$(dig +time=4 +tries=1 @"$ip" "$z" SOA +tcp +norecurse +comments) || fail "$role:$z:TCP"
    grep -q ' aa' <<<"$t" || fail "$role:$z:TCP_AA"
    if dig +time=4 +tries=1 @"$ip" "$z" AXFR 2>&1 | grep -Eq 'Transfer failed|failed|REFUSED'; then :; else fail "$role:$z:PUBLIC_AXFR_OPEN"; fi
  done
  fqdn=$([[ $role == ns1 ]] && printf '%s' "$NS1_FQDN" || printf '%s' "$NS2_FQDN")
  curl -fsS --resolve "$fqdn:443:$ip" "https://$fqdn/healthz" >/dev/null || fail "$role:HTTPS"
done
# SOA parity using public edges.
set -a; source "$NS1"; set +a; IP1=$PUBLIC_IPV4
set -a; source "$NS2"; set +a; IP2=$PUBLIC_IPV4
for z in $PRIMARY_ZONES; do
  s1=$(dig +short @"$IP1" "$z" SOA); s2=$(dig +short @"$IP2" "$z" SOA); [[ -n $s1 && $s1 == "$s2" ]] || fail "SOA_PARITY:$z"
done
printf 'PUBLIC_VALIDATION=PASS\n'
