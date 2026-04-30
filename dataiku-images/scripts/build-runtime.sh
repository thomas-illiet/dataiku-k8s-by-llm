#!/usr/bin/env bash
set -euo pipefail

: "${DSS_VERSION:?Set DSS_VERSION, for example 14.4.2}"
: "${BUILD_REV:?Set BUILD_REV, for example 1}"
: "${REGISTRY:=registry.internal/dataiku}"
: "${BASE_IMAGE:=almalinux:9}"
: "${KUBECTL_VERSION:=v1.30.8}"

IMAGE="${REGISTRY}/dss-runtime:${DSS_VERSION}-${BUILD_REV}"
KIT="dataiku-dss-${DSS_VERSION}.tar.gz"

if [[ ! -f "${KIT}" ]]; then
  echo "Missing ${KIT}. Place the official Dataiku DSS kit in this directory." >&2
  exit 1
fi

mkdir -p assets/ca assets/jdbc assets/odbc assets/plugins assets/spark

docker build \
  --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
  --build-arg "DSS_VERSION=${DSS_VERSION}" \
  --build-arg "KUBECTL_VERSION=${KUBECTL_VERSION}" \
  --build-arg "DSS_KIT=${KIT}" \
  -f Dockerfile.runtime \
  -t "${IMAGE}" \
  .

echo "${IMAGE}"

