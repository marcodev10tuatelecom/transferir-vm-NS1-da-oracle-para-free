#!/usr/bin/env bash
set -Eeuo pipefail

REGION="sa-saopaulo-1"
AD="PjZm:SA-SAOPAULO-1-AD-1"
TENANCY="ocid1.tenancy.oc1..aaaaaaaa6tfzkm6woefrr5ynftu5cdlz4kslylpiy3ywvg2jiubywu5gct4a"

INTERVAL="${INTERVAL:-60}"
MAX_CHECKS="${MAX_CHECKS:-180}"

report() {
  local ocpu="$1" mem="$2"
  local cfg
  cfg="$(printf '[{"instanceShape":"VM.Standard.A1.Flex","instanceShapeConfig":{"ocpus":%s,"memoryInGBs":%s}}]' "$ocpu" "$mem")"
  oci compute compute-capacity-report create \
    --availability-domain "$AD" \
    --compartment-id "$TENANCY" \
    --shape-availabilities "$cfg" \
    --region "$REGION" \
    --output json
}

echo "============================================================"
echo "TPS OCI A1 CAPACITY WATCH — READ-ONLY CAPACITY REPORTS"
echo "============================================================"
echo "REGION=$REGION"
echo "AD=$AD"
echo "INTERVAL_SECONDS=$INTERVAL"
echo "MAX_CHECKS=$MAX_CHECKS"
echo "COMPUTE_MUTATIONS=0"
echo "INSTANCE_TERMINATE=0"
echo "INSTANCE_LAUNCH=0"
echo

for i in $(seq 1 "$MAX_CHECKS"); do
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "---- CHECK=$i UTC=$now ----"

  j2="$(report 2 12)"
  s2="$(jq -r '.data["shape-availabilities"][0]["availability-status"] // "UNKNOWN"' <<<"$j2")"
  c2="$(jq -r '.data["shape-availabilities"][0]["available-count"] // 0' <<<"$j2")"
  echo "A1_2OCPU_12GB_STATUS=$s2"
  echo "A1_2OCPU_12GB_AVAILABLE_COUNT=$c2"

  if [[ "$s2" == "AVAILABLE" ]] && awk -v x="$c2" 'BEGIN{exit !(x>=1)}'; then
    printf '\a'
    echo "RESULT=FULL_2OCPU_12GB_AVAILABLE"
    exit 0
  fi

  j1="$(report 1 6)"
  s1="$(jq -r '.data["shape-availabilities"][0]["availability-status"] // "UNKNOWN"' <<<"$j1")"
  c1="$(jq -r '.data["shape-availabilities"][0]["available-count"] // 0' <<<"$j1")"
  echo "A1_1OCPU_6GB_STATUS=$s1"
  echo "A1_1OCPU_6GB_AVAILABLE_COUNT=$c1"

  if [[ "$s1" == "AVAILABLE" ]] && awk -v x="$c1" 'BEGIN{exit !(x>=1)}'; then
    printf '\a'
    echo "RESULT=EMERGENCY_1OCPU_6GB_AVAILABLE"
    exit 10
  fi

  if [[ "$i" -lt "$MAX_CHECKS" ]]; then
    echo "RESULT=NO_A1_CAPACITY_YET_WAIT_${INTERVAL}s"
    sleep "$INTERVAL"
  fi
done

echo "RESULT=NO_A1_CAPACITY_WITHIN_WATCH_WINDOW"
exit 20
