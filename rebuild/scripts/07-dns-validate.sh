#!/usr/bin/env bash
set -Eeuo pipefail
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd); source "$DIR/lib/tps-common.sh"
require_root; COMMON=${1:-$TPS_REBUILD_ROOT/common.env}; NODE=${2:-$TPS_REBUILD_ROOT/node.env}
load_env "$COMMON"; load_env "$NODE"; require_var PEER_PRIVATE_IPV4; new_evidence TPS-R07-DNS-VALIDATE
named-checkconf -z || die NAMED_CHECKCONF_FAIL
for z in $PRIMARY_ZONES; do
  section "ZONE $z"
  u=$(dig @127.0.0.1 "$z" SOA +norecurse +comments); grep -q ' aa' <<<"$u" || die "LOCAL_UDP_AA_FAIL:$z"
  t=$(dig @127.0.0.1 "$z" SOA +tcp +norecurse +comments); grep -q ' aa' <<<"$t" || die "LOCAL_TCP_AA_FAIL:$z"
  localsoa=$(dig @127.0.0.1 "$z" SOA +short)
  peersoa=$(dig @"$PEER_PRIVATE_IPV4" "$z" SOA +short)
  printf 'LOCAL=%s\nPEER=%s\n' "$localsoa" "$peersoa"
  [[ -n $peersoa && "$localsoa" == "$peersoa" ]] || die "SOA_PARITY_FAIL:$z"
  if dig @127.0.0.1 "$z" AXFR +time=3 +tries=1 2>&1 | grep -q 'Transfer failed'; then :; else
    # localhost may be permitted by implementation policy; public denial is validated separately.
    log "INFO=LOCAL_AXFR_RESULT_REVIEW:$z"
  fi
done
printf 'DNS_LOCAL_AND_PEER=PASS\n'
printf 'PUBLIC_AA_AND_AXFR=REQUIRES_EXTERNAL_VALIDATION\n'
