#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=./lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

usage() {
  cat <<'USAGE'
Usage: [DSS_HOST=dss.dataiku.internal] scripts/test-e2e.sh

Runs post-deployment smoke tests against a test cluster.

Optional:
  NAMESPACE           Kubernetes namespace, default dataiku
  DSS_HOST            DSS Ingress host, default dss.dataiku.internal
  SKIP_INGRESS=true   Skip HTTPS Ingress check
  SKIP_RESTART=true   Skip pod restart persistence check
USAGE
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

need_cmd kubectl

NAMESPACE="${NAMESPACE:-dataiku}"
DSS_HOST="${DSS_HOST:-dss.dataiku.internal}"

if ! kubectl cluster-info >/dev/null 2>&1; then
  fail "kubectl cannot reach a cluster. Select a non-production test context first."
fi

info "Checking bootstrap job status"
kubectl -n "${NAMESPACE}" get jobs -l app.kubernetes.io/component=bootstrap
latest_job="$(kubectl -n "${NAMESPACE}" get jobs -l app.kubernetes.io/component=bootstrap \
  --sort-by=.metadata.creationTimestamp \
  -o jsonpath='{.items[-1:].metadata.name}')"
[[ -n "${latest_job}" ]] || fail "No bootstrap job found"
kubectl -n "${NAMESPACE}" wait --for=condition=complete "job/${latest_job}" --timeout=1s >/dev/null

info "Checking runtime StatefulSet"
kubectl -n "${NAMESPACE}" rollout status statefulset/dataiku-design --timeout=900s

info "Checking services and ports"
kubectl -n "${NAMESPACE}" get service dataiku-design
kubectl -n "${NAMESPACE}" get ingress dataiku-design

info "Checking execution image references in bootstrap logs"
kubectl -n "${NAMESPACE}" logs "job/${latest_job}" -c bootstrap | grep -E 'container-exec|api-deployer'

if [[ "${SKIP_INGRESS:-false}" != "true" ]]; then
  need_cmd curl
  info "Checking HTTPS Ingress"
  curl -kfsS --max-time 30 "https://${DSS_HOST}/" >/dev/null
fi

if [[ "${SKIP_RESTART:-false}" != "true" ]]; then
  info "Restarting runtime pod and checking it becomes ready again"
  before_uid="$(kubectl -n "${NAMESPACE}" get pod -l app.kubernetes.io/component=design -o jsonpath='{.items[0].metadata.uid}')"
  kubectl -n "${NAMESPACE}" delete pod -l app.kubernetes.io/component=design --wait=true
  kubectl -n "${NAMESPACE}" rollout status statefulset/dataiku-design --timeout=900s
  after_uid="$(kubectl -n "${NAMESPACE}" get pod -l app.kubernetes.io/component=design -o jsonpath='{.items[0].metadata.uid}')"
  [[ "${before_uid}" != "${after_uid}" ]] || fail "Runtime pod UID did not change after restart"
fi

info "E2E tests completed"

