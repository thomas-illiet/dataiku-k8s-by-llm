#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=./lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

usage() {
  cat <<'USAGE'
Usage: DSS_VERSION=14.x.y BUILD_REV=1 [REGISTRY=registry.internal/dataiku] scripts/test-build.sh

Builds the Dataiku runtime image from dataiku-images, inspects it, verifies key
tools inside the image, scans it, and optionally pushes it.

Required:
  DSS_VERSION          Dataiku DSS version matching dataiku-dss-<version>.tar.gz
  BUILD_REV            Internal image build revision

Optional:
  REGISTRY             OCI repository prefix, default registry.internal/dataiku
  DOCKER_PLATFORM      Docker target/run platform, default linux/amd64
  PUSH_IMAGE=true      Push the image after successful checks
  SKIP_SCAN=true       Skip trivy/grype scan

The DSS kit must already exist in dataiku-images/ or be fetched beforehand with
dataiku-images/scripts/fetch-kit.sh.
USAGE
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

need_cmd docker

: "${DSS_VERSION:?Set DSS_VERSION, for example 14.4.2}"
: "${BUILD_REV:?Set BUILD_REV, for example 1}"
: "${REGISTRY:=registry.internal/dataiku}"
: "${DOCKER_PLATFORM:=linux/amd64}"

IMAGE="${REGISTRY}/dss-runtime:${DSS_VERSION}-${BUILD_REV}"

info "Building ${IMAGE}"
(
  cd "${IMAGES_DIR}"
  ./scripts/build-runtime.sh
)

info "Inspecting image metadata"
docker image inspect "${IMAGE}" >/dev/null
[[ "$(docker image inspect "${IMAGE}" --format '{{.Config.User}}')" == "1000:1000" ]] \
  || fail "Image must run as USER 1000:1000"

info "Checking required runtime tools inside image"
docker run --rm \
  --platform "${DOCKER_PLATFORM}" \
  --user 1000:1000 \
  --read-only \
  --cap-drop ALL \
  --security-opt no-new-privileges:true \
  --tmpfs /tmp:rw,nosuid,nodev,size=2g,mode=1777 \
  --tmpfs /var/tmp:rw,nosuid,nodev,size=1g,mode=1777 \
  --tmpfs /run:rw,nosuid,nodev,size=256m,uid=1000,gid=1000,mode=0755 \
  --tmpfs /home/dataiku:rw,nosuid,nodev,size=1g,uid=1000,gid=1000,mode=0700 \
  --entrypoint /bin/bash \
  "${IMAGE}" -lc "
  test \"\$(id -u):\$(id -g)\" = \"1000:1000\"
  test ! -w /opt/dataiku
  test -d /opt/dataiku/dataiku-dss-${DSS_VERSION}
  command -v kubectl
  command -v docker
  command -v java
  command -v python3
  command -v R
"

if [[ "${SKIP_SCAN:-false}" != "true" ]]; then
  info "Scanning image"
  "${IMAGES_DIR}/scripts/scan-image.sh" "${IMAGE}"
fi

if [[ "${PUSH_IMAGE:-false}" == "true" ]]; then
  info "Pushing image"
  "${IMAGES_DIR}/scripts/push-image.sh" "${IMAGE}"
else
  info "Skipping push because PUSH_IMAGE=true is not set"
fi

info "Build tests passed"
