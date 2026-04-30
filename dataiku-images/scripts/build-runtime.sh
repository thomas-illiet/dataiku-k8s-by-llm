#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: DSS_VERSION=14.x.y BUILD_REV=1 [REGISTRY=registry.internal/dataiku] scripts/build-runtime.sh

Build the internal Dataiku runtime image from an official DSS kit archive.

Required:
  DSS_VERSION          Dataiku DSS version matching dataiku-dss-<version>.tar.gz
  BUILD_REV            Internal image build revision

Optional:
  REGISTRY             OCI repository prefix, default registry.internal/dataiku
  BASE_IMAGE           Base Linux image, default almalinux:9
  KUBECTL_VERSION      kubectl version to install, default v1.30.8
  DOCKER_PLATFORM      Docker target platform, default linux/amd64

The DSS kit must be present in the current directory. This script does not read
or print secrets.
USAGE
}

fail() {
  echo "ERROR: $*" >&2
  echo "Usage: run scripts/build-runtime.sh --help for details." >&2
  exit 1
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

[[ -n "${DSS_VERSION:-}" ]] || fail "DSS_VERSION is required, for example 14.4.2"
[[ -n "${BUILD_REV:-}" ]] || fail "BUILD_REV is required, for example 1"
: "${REGISTRY:=registry.internal/dataiku}"
: "${BASE_IMAGE:=almalinux:9}"
: "${KUBECTL_VERSION:=v1.30.8}"
: "${DOCKER_PLATFORM:=linux/amd64}"

IMAGE="${REGISTRY}/dss-runtime:${DSS_VERSION}-${BUILD_REV}"
KIT="dataiku-dss-${DSS_VERSION}.tar.gz"

if [[ ! -f "${KIT}" ]]; then
  fail "Missing ${KIT}. Place the official Dataiku DSS kit in this directory."
fi

mkdir -p assets/ca assets/jdbc assets/odbc assets/plugins assets/spark

docker build \
  --platform "${DOCKER_PLATFORM}" \
  --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
  --build-arg "DSS_VERSION=${DSS_VERSION}" \
  --build-arg "KUBECTL_VERSION=${KUBECTL_VERSION}" \
  --build-arg "DSS_KIT=${KIT}" \
  -f Dockerfile.runtime \
  -t "${IMAGE}" \
  .

echo "${IMAGE}"
