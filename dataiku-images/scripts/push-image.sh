#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:?Usage: scripts/push-image.sh IMAGE}"

docker push "${IMAGE}"

