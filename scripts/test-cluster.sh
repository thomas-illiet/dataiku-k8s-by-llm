#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=./lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

usage() {
  cat <<'USAGE'
Usage: [APPLY_ARGO=true] [SYNC_ARGO=true] scripts/test-cluster.sh

Validates the rendered Kubernetes and Argo CD objects against the current
kubectl context. Run only against a non-production test cluster.

Optional:
  APPLY_ARGO=true      Apply AppProject and root Application
  SYNC_ARGO=true       Sync Argo CD child applications with argocd CLI
  ARGOCD_NAMESPACE     Argo CD namespace, default argocd
USAGE
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

need_cmd kubectl
need_cmd helm

if ! kubectl cluster-info >/dev/null 2>&1; then
  fail "kubectl cannot reach a cluster. Select a non-production test context first."
fi

"${ROOT_DIR}/scripts/test-render.sh"

info "Server-side dry-run for rendered Helm resources"
kubectl -n dataiku apply --dry-run=server -f "${RENDER_DIR}/dataiku-prereqs.yaml"
kubectl -n dataiku apply --dry-run=server -f "${RENDER_DIR}/dataiku-bootstrap.yaml"
kubectl -n dataiku apply --dry-run=server -f "${RENDER_DIR}/dataiku-runtime.yaml"

info "Client-side validation for Argo CD manifests"
kubectl apply --dry-run=client --validate=false \
  -f "${GITOPS_DIR}/argocd/root" \
  -f "${GITOPS_DIR}/argocd/apps"

if [[ "${APPLY_ARGO:-false}" == "true" ]]; then
  info "Applying Argo CD project and root application"
  kubectl apply -f "${GITOPS_DIR}/argocd/root/dataiku-project.yaml"
  kubectl apply -f "${GITOPS_DIR}/argocd/root/onprem-prod.yaml"
fi

if [[ "${SYNC_ARGO:-false}" == "true" ]]; then
  need_cmd argocd
  info "Syncing Argo CD waves"
  argocd app sync external-secrets
  argocd app sync dataiku-secrets
  argocd app sync dataiku-bootstrap
  argocd app sync dataiku-runtime
  argocd app wait dataiku-runtime --health --sync --timeout 1800
fi

info "Checking expected cluster objects when present"
kubectl -n dataiku get externalsecret dataiku-license >/dev/null 2>&1 || true
kubectl -n dataiku get pvc dataiku-design-data >/dev/null 2>&1 || true
kubectl -n dataiku get statefulset dataiku-design >/dev/null 2>&1 || true

info "Cluster tests completed"

