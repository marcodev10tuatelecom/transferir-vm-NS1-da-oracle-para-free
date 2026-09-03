#!/usr/bin/env bash
set -Eeuo pipefail
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd); source "$DIR/lib/tps-common.sh"
require_root; COMMON=${1:-$TPS_REBUILD_ROOT/common.env}; NODE=${2:-$TPS_REBUILD_ROOT/node.env}
load_env "$COMMON"; load_env "$NODE"; require_var SSH_ADMIN_CIDR; new_evidence TPS-R03-FIREWALL
need nft; need python3
if [[ -n ${SSH_CONNECTION:-} ]]; then
  REMOTE=${SSH_CONNECTION%% *}
  python3 - "$REMOTE" "$SSH_ADMIN_CIDR" <<'PY' || die SSH_SOURCE_OUTSIDE_ADMIN_CIDR
import ipaddress,sys
ip=ipaddress.ip_address(sys.argv[1]); net=ipaddress.ip_network(sys.argv[2], strict=False)
raise SystemExit(0 if ip in net else 1)
PY
fi
backup_path /etc/nftables.conf
SRT_RULE=''
[[ ${ENABLE_SRT:-no} == yes ]] && SRT_RULE='udp dport 8890 accept'
cat > /etc/nftables.conf <<EOF
#!/usr/sbin/nft -f
flush ruleset
table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;
    ct state established,related accept
    ct state invalid drop
    iifname "lo" accept
    ip protocol icmp accept
    ip6 nexthdr ipv6-icmp accept
    ip saddr ${SSH_ADMIN_CIDR} tcp dport 22 accept
    udp dport 53 accept
    tcp dport 53 accept
    tcp dport {80,443} accept
    tcp dport 1935 accept
    udp dport 8189 accept
    ${SRT_RULE}
  }
  chain forward { type filter hook forward priority 0; policy drop; }
  chain output { type filter hook output priority 0; policy accept; }
}
EOF
nft -c -f /etc/nftables.conf || die NFT_SYNTAX_FAIL
systemctl enable nftables
nft -f /etc/nftables.conf
systemctl restart nftables
nft list ruleset | tee "$EVIDENCE_DIR/nftables.txt"
printf 'FIREWALL_GUEST=PASS\n'
printf 'CLOUD_FIREWALL=REQUIRES_SEPARATE_VALIDATION\n'
