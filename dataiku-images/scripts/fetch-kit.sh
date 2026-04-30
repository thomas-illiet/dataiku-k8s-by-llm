#!/usr/bin/env bash
set -euo pipefail

: "${DSS_VERSION:?Set DSS_VERSION, for example 14.4.2}"

KIT="dataiku-dss-${DSS_VERSION}.tar.gz"
KIT_URL="${DATAIKU_DSS_KIT_URL:-https://cdn.downloads.dataiku.com/public/studio/${DSS_VERSION}/${KIT}}"

if [[ -f "${KIT}" ]]; then
  echo "${KIT} already exists"
  exit 0
fi

curl -fL --retry 3 --retry-delay 5 -o "${KIT}" "${KIT_URL}"
echo "Downloaded ${KIT}"

