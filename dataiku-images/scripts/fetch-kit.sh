#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: DSS_VERSION=14.x.y [DATAIKU_DSS_KIT_URL=https://...] scripts/fetch-kit.sh

Fetch the official Dataiku DSS kit into the current directory.

Required:
  DSS_VERSION          Dataiku DSS version to fetch

Optional:
  DATAIKU_DSS_KIT_URL  Explicit URL for an internal artifact mirror or vendor URL

No credentials or secrets are printed by this script.
USAGE
}

fail() {
  echo "ERROR: $*" >&2
  echo "Usage: run scripts/fetch-kit.sh --help for details." >&2
  exit 1
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

[[ -n "${DSS_VERSION:-}" ]] || fail "DSS_VERSION is required, for example 14.4.2"

KIT="dataiku-dss-${DSS_VERSION}.tar.gz"
KIT_URL="${DATAIKU_DSS_KIT_URL:-https://cdn.downloads.dataiku.com/public/dss/${DSS_VERSION}/${KIT}}"

if [[ -f "${KIT}" ]]; then
  echo "${KIT} already exists"
  exit 0
fi

curl -fL --retry 3 --retry-delay 5 -o "${KIT}" "${KIT_URL}"
echo "Downloaded ${KIT}"
