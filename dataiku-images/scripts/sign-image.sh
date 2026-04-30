#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:?Usage: scripts/sign-image.sh IMAGE}"

if ! command -v cosign >/dev/null 2>&1; then
  echo "cosign is required to sign ${IMAGE}" >&2
  exit 1
fi

cosign sign "${IMAGE}"

