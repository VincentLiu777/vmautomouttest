#!/bin/bash
# =============================================================================
# test-all-os.sh
#
# Test harness for the VM auto-mount NFS template. Deploys one or more OS
# images, then verifies the NFS share actually mounted on the VM (and whether
# the mount is using TLS / aznfs Encryption in Transit).
#
# USAGE
#   ./test-all-os.sh list                  # show the OS matrix
#   ./test-all-os.sh all                   # deploy + verify every OS, both modes
#   ./test-all-os.sh os RHEL10             # one OS, both network modes
#   ./test-all-os.sh os SLES16 pe          # one OS, Private Endpoint only
#   ./test-all-os.sh os Ubuntu2404 se      # one OS, Service Endpoint only
#   ./test-all-os.sh verify rhel10se       # re-run mount verification only
#   ./test-all-os.sh cleanup               # delete all resources in the RG
#
# CONFIG (override by exporting before running):
#   RESOURCE_GROUP   default: rongpuliumanagedfs
#   LOCATION         default: eastasia
#   TEMPLATE_URI     default: GitHub raw URL
#   ADMIN_PASSWORD   prompted securely if unset (do NOT hardcode secrets)
#   ENABLE_EIT       default: true  (set to "false" to test plain NFS)
#   NO_VERIFY=1      skip the post-deploy mount check
# =============================================================================

set -uo pipefail

RESOURCE_GROUP="${RESOURCE_GROUP:-rongpuliumanagedfs}"
LOCATION="${LOCATION:-eastasia}"
TEMPLATE_URI="${TEMPLATE_URI:-https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/vmmounttemplate-allos.json}"
ENABLE_EIT="${ENABLE_EIT:-true}"

# OS matrix: "osImageValue:resourcePrefixBase"
OS_MATRIX=(
  "Ubuntu2404:u2404"
  "Ubuntu2204:u2204"
  "Ubuntu2004:u2004"
  "RHEL10:rhel10"
  "RHEL9:rhel9"
  "RHEL8:rhel8"
  "SLES16:sles16"
  "SLES15:sles15"
  "OracleLinux8:oracl8"
  "AzureLinux3:azl3"
)

# Network modes: "modeValue:suffix"
MODE_MATRIX=(
  "ServiceEndpoint:se"
  "PrivateEndpoint:pe"
)

C_OK="\033[0;32m"; C_ERR="\033[0;31m"; C_INFO="\033[0;36m"; C_OFF="\033[0m"
log()  { echo -e "${C_INFO}[INFO]${C_OFF} $*"; }
ok()   { echo -e "${C_OK}[PASS]${C_OFF} $*"; }
err()  { echo -e "${C_ERR}[FAIL]${C_OFF} $*"; }

require_password() {
  if [ -z "${ADMIN_PASSWORD:-}" ]; then
    read -rsp "Enter VM admin password to use for all tests: " ADMIN_PASSWORD
    echo
  fi
  [ -n "$ADMIN_PASSWORD" ] || { err "No password provided."; exit 1; }
}

mode_value() { # suffix -> ServiceEndpoint / PrivateEndpoint
  case "$1" in
    se) echo "ServiceEndpoint" ;;
    pe) echo "PrivateEndpoint" ;;
    *)  echo "" ;;
  esac
}

deploy_one() { # osImage prefixBase modeSuffix
  local os="$1" base="$2" suffix="$3"
  local prefix="${base}${suffix}"
  local mode; mode="$(mode_value "$suffix")"
  [ -n "$mode" ] || { err "Unknown mode suffix '$suffix' (use 'se' or 'pe')."; return 1; }
  local depname="test-${prefix}"

  log "Deploying ${os} (${mode}) as '${prefix}' (EiT=${ENABLE_EIT}) ..."
  if az deployment group create \
        --name "$depname" \
        --resource-group "$RESOURCE_GROUP" \
        --template-uri "$TEMPLATE_URI" \
        --parameters resourcePrefix="$prefix" location="$LOCATION" \
                     osImage="$os" networkAccessMode="$mode" \
                     enableEncryptionInTransit="$ENABLE_EIT" \
                     adminPassword="$ADMIN_PASSWORD" \
        --only-show-errors -o none; then
    ok "Deployment '${prefix}' succeeded."
    [ "${NO_VERIFY:-0}" = "1" ] || verify_mount "$prefix"
    return 0
  else
    err "Deployment '${prefix}' FAILED."
    return 1
  fi
}

verify_mount() { # prefix
  local prefix="$1"
  local vm="${prefix}-vm"
  log "Verifying mount on VM '${vm}' (via az vm run-command) ..."

  local script='echo "=== findmnt ==="; findmnt -t nfs,nfs4,aznfs || true; \
echo "=== df ==="; df -Th | grep -Ei "nfs|aznfs" || true; \
echo "=== fstab ==="; grep -Ei "nfs|aznfs" /etc/fstab || true; \
echo "=== aznfs watchdog ==="; systemctl is-active aznfswatchdog 2>/dev/null || echo "aznfs-not-installed"'

  local out
  out="$(az vm run-command invoke \
            --resource-group "$RESOURCE_GROUP" \
            --name "$vm" \
            --command-id RunShellScript \
            --scripts "$script" \
            --query "value[0].message" -o tsv 2>/dev/null)"

  if echo "$out" | grep -Eqi "aznfs|:/[^ ]*nfs|\.file\.core\.windows\.net"; then
    ok "Mount verified on '${vm}'."
    if echo "$out" | grep -qi "aznfs"; then
      log "  -> Encryption in Transit (aznfs/TLS) detected."
    else
      log "  -> Plain NFS mount detected (no EiT)."
    fi
  else
    err "No NFS mount found on '${vm}'. Raw output below:"
  fi
  echo "$out" | sed 's/^/      /'
}

print_matrix() {
  echo "OS images:"
  for entry in "${OS_MATRIX[@]}"; do echo "  - ${entry%%:*}"; done
  echo "Network modes: ServiceEndpoint (se), PrivateEndpoint (pe)"
  echo "Resource group: $RESOURCE_GROUP  |  Location: $LOCATION  |  EiT: $ENABLE_EIT"
}

run_all() {
  require_password
  local pass=0 fail=0
  for entry in "${OS_MATRIX[@]}"; do
    local os="${entry%%:*}" base="${entry##*:}"
    for m in "${MODE_MATRIX[@]}"; do
      if deploy_one "$os" "$base" "${m##*:}"; then pass=$((pass+1)); else fail=$((fail+1)); fi
    done
  done
  echo
  log "Summary: ${pass} passed, ${fail} failed."
  [ "$fail" -eq 0 ]
}

run_one_os() { # osImage [modeSuffix]
  local target="${1:-}" only_mode="${2:-}"
  [ -n "$target" ] || { err "Usage: ./test-all-os.sh os <osImage> [se|pe]"; exit 1; }
  local base=""
  for entry in "${OS_MATRIX[@]}"; do
    [ "${entry%%:*}" = "$target" ] && base="${entry##*:}"
  done
  [ -n "$base" ] || { err "Unknown OS '$target'. Run './test-all-os.sh list'."; exit 1; }

  require_password
  if [ -n "$only_mode" ]; then
    deploy_one "$target" "$base" "$only_mode"
  else
    for m in "${MODE_MATRIX[@]}"; do deploy_one "$target" "$base" "${m##*:}"; done
  fi
}

cleanup() {
  read -rp "Delete ALL resources in resource group '$RESOURCE_GROUP'? [y/N] " ans
  case "$ans" in
    y|Y) az group delete --name "$RESOURCE_GROUP" --yes --no-wait \
           && log "Delete started in the background." ;;
    *)   log "Cleanup cancelled." ;;
  esac
}

usage() { sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; }

# --- entrypoint ---
case "${1:-help}" in
  list)    print_matrix ;;
  all)     run_all ;;
  os)      run_one_os "${2:-}" "${3:-}" ;;
  verify)  verify_mount "${2:?Usage: ./test-all-os.sh verify <prefix>}" ;;
  cleanup) cleanup ;;
  help|-h|--help|*) usage ;;
esac
