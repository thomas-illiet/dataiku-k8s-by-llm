#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:?Usage: scripts/scan-image.sh IMAGE}"

if command -v trivy >/dev/null 2>&1; then
  trivy image --exit-code 1 --severity HIGH,CRITICAL "${IMAGE}"
elif command -v grype >/dev/null 2>&1; then
  grype "${IMAGE}"
else
  echo "No scanner found. Install trivy or grype in CI." >&2
  exit 1
fi

