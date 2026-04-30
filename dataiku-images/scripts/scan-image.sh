#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/scan-image.sh IMAGE

Scan an OCI image with trivy or grype. The script fails if neither scanner is
installed.

Arguments:
  IMAGE                Image reference to scan
USAGE
}

fail() {
  echo "ERROR: $*" >&2
  echo "Usage: run scripts/scan-image.sh --help for details." >&2
  exit 1
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

[[ -n "${1:-}" ]] || fail "IMAGE is required"
IMAGE="$1"

if command -v trivy >/dev/null 2>&1; then
  trivy image --exit-code 1 --severity HIGH,CRITICAL "${IMAGE}"
elif command -v grype >/dev/null 2>&1; then
  grype "${IMAGE}"
else
  fail "No scanner found. Install trivy or grype in CI."
fi
