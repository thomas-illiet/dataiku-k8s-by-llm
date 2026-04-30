#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/sign-image.sh IMAGE

Sign an OCI image with cosign. Configure cosign identity or key material in the
environment before running this script.

Arguments:
  IMAGE                Image reference to sign
USAGE
}

fail() {
  echo "ERROR: $*" >&2
  echo "Usage: run scripts/sign-image.sh --help for details." >&2
  exit 1
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

[[ -n "${1:-}" ]] || fail "IMAGE is required"
IMAGE="$1"

if ! command -v cosign >/dev/null 2>&1; then
  fail "cosign is required to sign ${IMAGE}"
fi

cosign sign "${IMAGE}"
