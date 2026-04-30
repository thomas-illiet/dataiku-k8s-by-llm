#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/push-image.sh IMAGE

Push an OCI image to the configured registry. Authenticate with docker login
before running this command.

Arguments:
  IMAGE                Image reference to push
USAGE
}

fail() {
  echo "ERROR: $*" >&2
  echo "Usage: run scripts/push-image.sh --help for details." >&2
  exit 1
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

[[ -n "${1:-}" ]] || fail "IMAGE is required"
IMAGE="$1"

docker push "${IMAGE}"
