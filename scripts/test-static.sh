#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=./lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

need_cmd bash
need_cmd helm
need_cmd ruby

info "Checking shell syntax"
bash -n "${IMAGES_DIR}/entrypoint.sh" "${IMAGES_DIR}"/scripts/*.sh
bash -n "${ROOT_DIR}"/scripts/*.sh

info "Linting Helm charts"
helm lint "${GITOPS_DIR}/charts/dataiku-platform" \
  -f "${GITOPS_DIR}/envs/onprem/prod/values.yaml"
helm lint "${GITOPS_DIR}/charts/dataiku-node"

info "Parsing checked-in YAML"
parse_yaml_many \
  "${GITOPS_DIR}"/argocd/root/*.yaml \
  "${GITOPS_DIR}"/argocd/apps/*.yaml \
  "${GITOPS_DIR}"/envs/onprem/prod/*.yaml \
  "${IMAGES_DIR}/.github/workflows/build-runtime.yaml"

info "Checking for committed obvious secret placeholders"
if rg -n --hidden --glob '!*.git/*' --glob '!*.DS_Store' \
  '(^|[[:space:]])(password|token|secret|private_key|client_secret):\s*["'\'']?[^<{$\s][^#\n]+' \
  "${GITOPS_DIR}" "${IMAGES_DIR}"; then
  fail "Potential literal secret found. Review matches above."
fi

info "Static tests passed"
