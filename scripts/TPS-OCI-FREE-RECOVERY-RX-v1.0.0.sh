#!/usr/bin/env bash
# TPS-OCI-FREE-RECOVERY-RX v1.0.0
# Purpose: READ-ONLY OCI Cloud Shell diagnostic for Free Tier recovery of tuatelecom01/02.
# Scope: inventory only. No create/update/delete/start/stop/terminate/attach/detach operations.

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_NAME="TPS-OCI-FREE-RECOVERY-RX-v1.0.0"
REGION="${OCI_CLI_REGION:-sa-saopaulo-1}"
CONFIG_FILE="${OCI_CLI_CONFIG_FILE:-/etc/oci/config}"
PROFILE="${OCI_CLI_PROFILE:-$REGION}"
RUN_ID="${SCRIPT_NAME}-$(date -u +%Y%m%dT%H%M%SZ)"
REPORT="$HOME/${RUN_ID}.txt"

exec > >(tee "$REPORT") 2>&1

section() {
  printf '\n============================================================\n'
  printf '%s\n' "$1"
  printf '============================================================\n'
}

warn() { printf 'WARN=%s\n' "$*"; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'FATAL=MISSING_COMMAND_%s\n' "$1"
    exit 1
  }
}

oci_json() {
  oci "$@" --region "$REGION" --output json
}

section "00 PRECHECK — CLOUD SHELL / READ ONLY"
printf 'RUN_ID=%s\n' "$RUN_ID"
printf 'REGION=%s\n' "$REGION"
printf 'PROFILE=%s\n' "$PROFILE"
printf 'CONFIG_FILE=%s\n' "$CONFIG_FILE"
printf 'REPORT=%s\n' "$REPORT"
printf 'MUTATIONS=FORBIDDEN\n'

need_cmd oci
need_cmd jq
need_cmd python3
printf 'OCI_CLI_VERSION=%s\n' "$(oci --version 2>&1 | head -1)"
printf 'JQ_VERSION=%s\n' "$(jq --version 2>&1 | head -1)"

TENANCY="$({ python3 - "$CONFIG_FILE" "$PROFILE" <<'PY'
import configparser, os, sys
path, profile = sys.argv[1], sys.argv[2]
cfg = configparser.ConfigParser()
if not cfg.read(path):
    raise SystemExit(f"cannot read OCI config: {path}")
if profile not in cfg:
    if "DEFAULT" in cfg:
        profile = "DEFAULT"
    else:
        raise SystemExit(f"profile not found: {profile}")
print(cfg[profile]["tenancy"].strip())
PY
} 2>/dev/null)" || {
  printf 'FATAL=CANNOT_READ_TENANCY_FROM_CONFIG\n'
  exit 1
}

printf 'TENANCY_OCID=%s\n' "$TENANCY"

section "01 TARGET INSTANCES — EXISTENCE / SHAPE / STATE"

TARGETS=(tuatelecom01 tuatelecom02)
PRIMARY_AD=""
TARGET_BOOT_TOTAL=0

for NAME in "${TARGETS[@]}"; do
  printf '\n--- INSTANCE %s ---\n' "$NAME"

  if ! INST_JSON="$(oci_json compute instance list \
      --compartment-id "$TENANCY" \
      --display-name "$NAME" \
      --all)"; then
    warn "$NAME INSTANCE_LIST_FAILED"
    continue
  fi

  COUNT="$(jq '.data | length' <<<"$INST_JSON")"
  printf 'MATCHES=%s\n' "$COUNT"
  if [[ "$COUNT" -ne 1 ]]; then
    warn "$NAME EXPECTED_ONE_INSTANCE_FOUND_$COUNT"
    continue
  fi

  ID="$(jq -r '.data[0].id' <<<"$INST_JSON")"
  AD="$(jq -r '.data[0]["availability-domain"]' <<<"$INST_JSON")"
  IMAGE="$(jq -r '.data[0]["image-id"]' <<<"$INST_JSON")"
  [[ -z "$PRIMARY_AD" ]] && PRIMARY_AD="$AD"

  jq -r '.data[0] | {
    name: .["display-name"],
    lifecycle_state: .["lifecycle-state"],
    shape: .shape,
    ocpus: .["shape-config"].ocpus,
    memory_gb: .["shape-config"]["memory-in-gbs"],
    availability_domain: .["availability-domain"],
    fault_domain: .["fault-domain"],
    instance_id: .id,
    image_id: .["image-id"]
  }' <<<"$INST_JSON"

  printf '%s\n' '--- PRIMARY VNIC ---'
  if VNIC_ATTACH_JSON="$(oci_json compute vnic-attachment list \
      --compartment-id "$TENANCY" \
      --instance-id "$ID" \
      --all)"; then
    VNIC_ID="$(jq -r '.data | map(select(.["nic-index"] == 0)) | .[0]["vnic-id"] // empty' <<<"$VNIC_ATTACH_JSON")"
    if [[ -n "$VNIC_ID" ]]; then
      if VNIC_JSON="$(oci_json network vnic get --vnic-id "$VNIC_ID")"; then
        jq -r '.data | {
          vnic_id: .id,
          lifecycle_state: .["lifecycle-state"],
          private_ip: .["private-ip"],
          public_ip: .["public-ip"],
          subnet_id: .["subnet-id"],
          nsg_ids: .["nsg-ids"]
        }' <<<"$VNIC_JSON"
      else
        warn "$NAME VNIC_GET_FAILED"
      fi
    else
      warn "$NAME PRIMARY_VNIC_NOT_FOUND"
    fi
  else
    warn "$NAME VNIC_ATTACHMENT_LIST_FAILED"
  fi

  printf '%s\n' '--- BOOT VOLUME ---'
  if BVA_JSON="$(oci_json compute boot-volume-attachment list \
      --availability-domain "$AD" \
      --compartment-id "$TENANCY" \
      --instance-id "$ID" \
      --all)"; then
    BVID="$(jq -r '.data[0]["boot-volume-id"] // empty' <<<"$BVA_JSON")"
    if [[ -n "$BVID" ]] && BV_JSON="$(oci_json bv boot-volume get --boot-volume-id "$BVID")"; then
      SIZE="$(jq -r '.data["size-in-gbs"] // 0' <<<"$BV_JSON")"
      TARGET_BOOT_TOTAL=$(( TARGET_BOOT_TOTAL + SIZE ))
      jq -r '.data | {
        display_name: .["display-name"],
        lifecycle_state: .["lifecycle-state"],
        size_gb: .["size-in-gbs"],
        vpus_per_gb: .["vpus-per-gb"],
        boot_volume_id: .id,
        free_tier_retained: (.["system-tags"]["orcl-cloud"]["free-tier-retained"] // null)
      }' <<<"$BV_JSON"
    else
      warn "$NAME BOOT_VOLUME_NOT_FOUND_OR_GET_FAILED"
    fi
  else
    warn "$NAME BOOT_VOLUME_ATTACHMENT_LIST_FAILED"
  fi

  printf '%s\n' '--- IMAGE / A1 COMPATIBILITY ---'
  if SHAPES_JSON="$(oci_json compute shape list \
      --compartment-id "$TENANCY" \
      --availability-domain "$AD" \
      --image-id "$IMAGE" \
      --all)"; then
    jq -r '.data[] | select(.shape == "VM.Standard.A1.Flex" or .shape == "VM.Standard.A2.Flex") | {
      shape: .shape,
      is_flexible: .["is-flexible"],
      min_ocpu: (.["ocpu-options"].min // null),
      max_ocpu: (.["ocpu-options"].max // null),
      min_memory_gb: (.["memory-options"]["min-in-gbs"] // null),
      max_memory_gb: (.["memory-options"]["max-in-gbs"] // null),
      resize_compatible_shapes: (.["resize-compatible-shapes"] // null)
    }' <<<"$SHAPES_JSON"
  else
    warn "$NAME SHAPE_LIST_FAILED"
  fi

done

printf '\nTARGET_BOOT_VOLUMES_COMBINED_GB=%s\n' "$TARGET_BOOT_TOTAL"

if [[ -z "$PRIMARY_AD" ]]; then
  printf 'FATAL=NO_TARGET_AVAILABILITY_DOMAIN_DETECTED\n'
  exit 1
fi
printf 'PRIMARY_AD=%s\n' "$PRIMARY_AD"

section "02 A1 SERVICE LIMITS — CURRENT TENANCY"
for LIMIT in standard-a1-core-count standard-a1-memory-count; do
  printf '\nLIMIT=%s\n' "$LIMIT"
  if OUT="$(oci_json limits resource-availability get \
      --service-name compute \
      --limit-name "$LIMIT" \
      --compartment-id "$TENANCY" \
      --availability-domain "$PRIMARY_AD")"; then
    jq -r '.data | {
      effective_quota_value: .["effective-quota-value"],
      used: .used,
      available: .available,
      fractional_used: .["fractional-used"],
      fractional_available: .["fractional-available"]
    }' <<<"$OUT"
  else
    warn "LIMIT_QUERY_FAILED_$LIMIT"
  fi
done

for LIMIT in standard-a1-core-regional-count standard-a1-memory-regional-count; do
  printf '\nLIMIT=%s\n' "$LIMIT"
  if OUT="$(oci_json limits resource-availability get \
      --service-name compute \
      --limit-name "$LIMIT" \
      --compartment-id "$TENANCY")"; then
    jq -r '.data | {
      effective_quota_value: .["effective-quota-value"],
      used: .used,
      available: .available,
      fractional_used: .["fractional-used"],
      fractional_available: .["fractional-available"]
    }' <<<"$OUT"
  else
    warn "LIMIT_QUERY_FAILED_$LIMIT"
  fi
done

section "03 BLOCK STORAGE LIMIT — BOOT + BLOCK VOLUMES"
printf 'ORACLE_ALWAYS_FREE_BLOCK_STORAGE_REFERENCE_GB=200\n'

BLOCK_LIMIT_OK=0
if OUT="$(oci_json limits resource-availability get \
    --service-name block-storage \
    --limit-name total-storage-gb \
    --compartment-id "$TENANCY" \
    --availability-domain "$PRIMARY_AD" 2>/dev/null)"; then
  BLOCK_LIMIT_OK=1
  jq -r '.data | {
    effective_quota_value: .["effective-quota-value"],
    used: .used,
    available: .available,
    fractional_used: .["fractional-used"],
    fractional_available: .["fractional-available"]
  }' <<<"$OUT"
else
  warn "BLOCK_STORAGE_RESOURCE_AVAILABILITY_QUERY_FAILED"
fi
printf 'BLOCK_LIMIT_QUERY_OK=%s\n' "$BLOCK_LIMIT_OK"

section "04 STORAGE INVENTORY — ALL ACCESSIBLE COMPARTMENTS IN AD"
TMP_COMPS="$(mktemp)"
trap 'rm -f "$TMP_COMPS"' EXIT
printf '%s\t%s\n' "$TENANCY" 'ROOT' > "$TMP_COMPS"

if COMP_JSON="$(oci_json iam compartment list \
    --compartment-id "$TENANCY" \
    --compartment-id-in-subtree true \
    --access-level ACCESSIBLE \
    --all)"; then
  jq -r '.data[] | select(.["lifecycle-state"] == "ACTIVE") | [.id, .name] | @tsv' <<<"$COMP_JSON" >> "$TMP_COMPS"
else
  warn "COMPARTMENT_LIST_FAILED_ONLY_ROOT_WILL_BE_SCANNED"
fi

TOTAL_BOOT_GB=0
TOTAL_BLOCK_GB=0
TOTAL_FREE_TAGGED_BOOT_GB=0
TOTAL_FREE_TAGGED_BLOCK_GB=0

while IFS=$'\t' read -r CID CNAME; do
  printf '\n--- COMPARTMENT: %s ---\n' "$CNAME"

  if BOOTS="$(oci_json bv boot-volume list \
      --availability-domain "$PRIMARY_AD" \
      --compartment-id "$CID" \
      --all 2>/dev/null)"; then
    BOOT_COUNT="$(jq '.data | length' <<<"$BOOTS")"
    BOOT_GB="$(jq '[.data[] | (.["size-in-gbs"] // 0)] | add // 0' <<<"$BOOTS")"
    FREE_BOOT_GB="$(jq '[.data[] | select((.["system-tags"]["orcl-cloud"]["free-tier-retained"] // false) == true or (.["system-tags"]["orcl-cloud"]["free-tier-retained"] // "") == "true") | (.["size-in-gbs"] // 0)] | add // 0' <<<"$BOOTS")"
    TOTAL_BOOT_GB=$(( TOTAL_BOOT_GB + BOOT_GB ))
    TOTAL_FREE_TAGGED_BOOT_GB=$(( TOTAL_FREE_TAGGED_BOOT_GB + FREE_BOOT_GB ))
    printf 'BOOT_VOLUME_COUNT=%s BOOT_VOLUME_GB=%s FREE_TAGGED_BOOT_GB=%s\n' "$BOOT_COUNT" "$BOOT_GB" "$FREE_BOOT_GB"
    jq -r '.data[] | [.["display-name"], .["size-in-gbs"], .["lifecycle-state"], (.["system-tags"]["orcl-cloud"]["free-tier-retained"] // "UNSET")] | @tsv' <<<"$BOOTS"
  else
    printf 'BOOT_VOLUME_LIST=UNAVAILABLE\n'
  fi

  if VOLS="$(oci_json bv volume list \
      --availability-domain "$PRIMARY_AD" \
      --compartment-id "$CID" \
      --all 2>/dev/null)"; then
    VOL_COUNT="$(jq '.data | length' <<<"$VOLS")"
    VOL_GB="$(jq '[.data[] | (.["size-in-gbs"] // 0)] | add // 0' <<<"$VOLS")"
    FREE_VOL_GB="$(jq '[.data[] | select((.["system-tags"]["orcl-cloud"]["free-tier-retained"] // false) == true or (.["system-tags"]["orcl-cloud"]["free-tier-retained"] // "") == "true") | (.["size-in-gbs"] // 0)] | add // 0' <<<"$VOLS")"
    TOTAL_BLOCK_GB=$(( TOTAL_BLOCK_GB + VOL_GB ))
    TOTAL_FREE_TAGGED_BLOCK_GB=$(( TOTAL_FREE_TAGGED_BLOCK_GB + FREE_VOL_GB ))
    printf 'BLOCK_VOLUME_COUNT=%s BLOCK_VOLUME_GB=%s FREE_TAGGED_BLOCK_GB=%s\n' "$VOL_COUNT" "$VOL_GB" "$FREE_VOL_GB"
    jq -r '.data[] | [.["display-name"], .["size-in-gbs"], .["lifecycle-state"], (.["system-tags"]["orcl-cloud"]["free-tier-retained"] // "UNSET")] | @tsv' <<<"$VOLS"
  else
    printf 'BLOCK_VOLUME_LIST=UNAVAILABLE\n'
  fi

done < "$TMP_COMPS"

TOTAL_STORAGE_GB=$(( TOTAL_BOOT_GB + TOTAL_BLOCK_GB ))
TOTAL_FREE_TAGGED_GB=$(( TOTAL_FREE_TAGGED_BOOT_GB + TOTAL_FREE_TAGGED_BLOCK_GB ))

section "05 STORAGE SUMMARY / FREE-TIER FIT"
printf 'TOTAL_BOOT_VOLUME_GB=%s\n' "$TOTAL_BOOT_GB"
printf 'TOTAL_BLOCK_VOLUME_GB=%s\n' "$TOTAL_BLOCK_GB"
printf 'TOTAL_BOOT_PLUS_BLOCK_GB=%s\n' "$TOTAL_STORAGE_GB"
printf 'TOTAL_FREE_TIER_RETAINED_TAGGED_GB=%s\n' "$TOTAL_FREE_TAGGED_GB"
printf 'TARGET_NS1_NS2_BOOT_GB=%s\n' "$TARGET_BOOT_TOTAL"
printf 'ALWAYS_FREE_REFERENCE_GB=200\n'

if (( TOTAL_STORAGE_GB <= 200 )); then
  printf 'ALL_EXISTING_STORAGE_FITS_200GB_REFERENCE=YES\n'
else
  printf 'ALL_EXISTING_STORAGE_FITS_200GB_REFERENCE=NO\n'
fi

if (( TARGET_BOOT_TOTAL <= 200 )); then
  printf 'NS1_NS2_BOOT_VOLUMES_FIT_200GB_REFERENCE=YES\n'
else
  printf 'NS1_NS2_BOOT_VOLUMES_FIT_200GB_REFERENCE=NO\n'
fi

section "06 FREE-TIER RESOURCE SEARCH — CONTROL"
if SEARCH_JSON="$(oci_json search resource structured-search \
    --query-text "query all resources where systemTags.namespace = 'orcl-cloud' && systemTags.key = 'free-tier-retained' && systemTags.value = 'true'" \
    --limit 1000 2>/dev/null)"; then
  jq -r '.data.items[]? | [.["display-name"], .["resource-type"], .["lifecycle-state"], .identifier] | @tsv' <<<"$SEARCH_JSON" || true
else
  warn "FREE_TIER_RESOURCE_SEARCH_FAILED"
fi

section "07 FINAL READ-ONLY CERTIFICATION"
printf 'OCI_RESOURCE_MUTATIONS_EXECUTED=0\n'
printf 'READ_ONLY=PASS\n'
printf 'REPORT_FILE=%s\n' "$REPORT"
printf 'RESULT=READY_FOR_ENGINEERING_DECISION\n'
