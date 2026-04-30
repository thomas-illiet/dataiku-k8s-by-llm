#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GITOPS_DIR="${ROOT_DIR}/dataiku-gitops"
IMAGES_DIR="${ROOT_DIR}/dataiku-images"
RENDER_DIR="${RENDER_DIR:-${ROOT_DIR}/.rendered}"

info() {
  printf '==> %s\n' "$*"
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  local cmd="$1"
  command -v "${cmd}" >/dev/null 2>&1 || fail "Missing required command: ${cmd}"
}

parse_yaml() {
  local file="$1"
  ruby -e 'require "yaml"; YAML.load_stream(File.read(ARGV[0])); puts "ok #{ARGV[0]}"' "${file}" >/dev/null
}

parse_yaml_many() {
  ruby -e 'require "yaml"; ARGV.each { |f| YAML.load_stream(File.read(f)); puts "ok #{f}" }' "$@"
}

render_platform_wave() {
  local release="$1"
  local output="$2"
  local prereqs="$3"
  local bootstrap="$4"
  local runtime="$5"

  helm template "${release}" "${GITOPS_DIR}/charts/dataiku-platform" \
    -n dataiku \
    -f "${GITOPS_DIR}/envs/onprem/prod/values.yaml" \
    --set "components.prereqs=${prereqs}" \
    --set "components.bootstrap=${bootstrap}" \
    --set "components.runtime=${runtime}" \
    > "${output}"
}

