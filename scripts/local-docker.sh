#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGES_DIR="${ROOT_DIR}/dataiku-images"

usage() {
  cat <<'USAGE'
Usage: DSS_VERSION=13.3.2 [BUILD_REV=local] [DSS_LOCAL_PORT=10000] scripts/local-docker.sh COMMAND

Commands:
  fetch        Download the official Dataiku DSS kit
  build        Build the local linux/amd64 Docker image
  up           Start the local Dataiku DSS container
  logs         Follow DSS container logs
  status       Show container status
  down         Stop the local container, keeping the Docker volume
  destroy      Stop the container and delete the Docker volume

Optional:
  DATAIKU_DSS_KIT_URL  Override the kit download URL
  DATAIKU_LOCAL_IMAGE  Override local image tag
  DATAIKU_CONTAINER    Override local container name
  DATAIKU_VOLUME       Override local Docker volume name
  DSS_TMP_SIZE         Override /tmp tmpfs size, default 2g
  DSS_HOME_TMP_SIZE    Override /home/dataiku tmpfs size, default 1g
USAGE
}

cmd="${1:-}"
if [[ -z "${cmd}" || "${cmd}" == "--help" || "${cmd}" == "-h" ]]; then
  usage
  exit 0
fi

DSS_VERSION="${DSS_VERSION:-13.3.2}"
BUILD_REV="${BUILD_REV:-local}"
DATAIKU_LOCAL_IMAGE="${DATAIKU_LOCAL_IMAGE:-local/dataiku-dss:${DSS_VERSION}}"
DSS_LOCAL_PORT="${DSS_LOCAL_PORT:-10000}"
DATAIKU_CONTAINER="${DATAIKU_CONTAINER:-dataiku-dss-dev}"
DATAIKU_VOLUME="${DATAIKU_VOLUME:-dataiku_dataiku-dss-data}"
DSS_TMP_SIZE="${DSS_TMP_SIZE:-2g}"
DSS_VAR_TMP_SIZE="${DSS_VAR_TMP_SIZE:-1g}"
DSS_RUN_TMP_SIZE="${DSS_RUN_TMP_SIZE:-256m}"
DSS_HOME_TMP_SIZE="${DSS_HOME_TMP_SIZE:-1g}"
export DSS_VERSION BUILD_REV DATAIKU_LOCAL_IMAGE DSS_LOCAL_PORT DATAIKU_CONTAINER DATAIKU_VOLUME

case "${cmd}" in
  fetch)
    (cd "${IMAGES_DIR}" && DSS_VERSION="${DSS_VERSION}" DATAIKU_DSS_KIT_URL="${DATAIKU_DSS_KIT_URL:-}" ./scripts/fetch-kit.sh)
    ;;
  build)
    (cd "${IMAGES_DIR}" && DSS_VERSION="${DSS_VERSION}" BUILD_REV="${BUILD_REV}" REGISTRY="local" DOCKER_PLATFORM="linux/amd64" ./scripts/build-runtime.sh)
    docker tag "local/dss-runtime:${DSS_VERSION}-${BUILD_REV}" "${DATAIKU_LOCAL_IMAGE}"
    ;;
  up)
    docker volume create "${DATAIKU_VOLUME}" >/dev/null
    if docker container inspect "${DATAIKU_CONTAINER}" >/dev/null 2>&1; then
      docker rm -f "${DATAIKU_CONTAINER}" >/dev/null
    fi
    docker run -d --name "${DATAIKU_CONTAINER}" \
      --platform linux/amd64 \
      --user 1000:1000 \
      --read-only \
      --restart unless-stopped \
      --cap-drop ALL \
      --security-opt no-new-privileges:true \
      -p "${DSS_LOCAL_PORT}:10000" \
      --shm-size=2g \
      --ulimit nofile=65536:65536 \
      --ulimit nproc=65536:65536 \
      --tmpfs "/tmp:rw,nosuid,nodev,size=${DSS_TMP_SIZE},mode=1777" \
      --tmpfs "/var/tmp:rw,nosuid,nodev,size=${DSS_VAR_TMP_SIZE},mode=1777" \
      --tmpfs "/run:rw,nosuid,nodev,size=${DSS_RUN_TMP_SIZE},uid=1000,gid=1000,mode=0755" \
      --tmpfs "/home/dataiku:rw,nosuid,nodev,size=${DSS_HOME_TMP_SIZE},uid=1000,gid=1000,mode=0700" \
      -e "DSS_VERSION=${DSS_VERSION}" \
      -e "DSS_DATADIR=/dataiku/dss" \
      -e "DSS_PORT=10000" \
      -e "DATAIKU_NODE_TYPE=design" \
      -e "INSTALL_R_INTEGRATION=false" \
      -e "INSTALL_GRAPHICS_EXPORT=false" \
      -v "${DATAIKU_VOLUME}:/dataiku/dss" \
      "${DATAIKU_LOCAL_IMAGE}"
    ;;
  logs)
    docker logs -f --tail 200 "${DATAIKU_CONTAINER}"
    ;;
  status)
    docker ps -a --filter "name=^/${DATAIKU_CONTAINER}$"
    ;;
  down)
    docker rm -f "${DATAIKU_CONTAINER}" >/dev/null 2>&1 || true
    ;;
  destroy)
    docker rm -f "${DATAIKU_CONTAINER}" >/dev/null 2>&1 || true
    docker volume rm "${DATAIKU_VOLUME}" >/dev/null 2>&1 || true
    ;;
  *)
    echo "Unknown command: ${cmd}" >&2
    usage >&2
    exit 1
    ;;
esac
