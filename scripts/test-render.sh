#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=./lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

need_cmd helm
need_cmd ruby

mkdir -p "${RENDER_DIR}"

info "Rendering dataiku-platform prereqs wave"
render_platform_wave "dataiku-prereqs" "${RENDER_DIR}/dataiku-prereqs.yaml" true false false

info "Rendering dataiku-platform bootstrap wave"
render_platform_wave "dataiku-bootstrap" "${RENDER_DIR}/dataiku-bootstrap.yaml" false true false

info "Rendering dataiku-platform runtime wave"
render_platform_wave "dataiku-runtime" "${RENDER_DIR}/dataiku-runtime.yaml" false false true

info "Rendering dataiku-node chart"
helm template dataiku-node "${GITOPS_DIR}/charts/dataiku-node" \
  -n dataiku \
  > "${RENDER_DIR}/dataiku-node.yaml"

info "Parsing rendered YAML"
parse_yaml_many \
  "${RENDER_DIR}/dataiku-prereqs.yaml" \
  "${RENDER_DIR}/dataiku-bootstrap.yaml" \
  "${RENDER_DIR}/dataiku-runtime.yaml" \
  "${RENDER_DIR}/dataiku-node.yaml"

info "Checking expected rendered resources"
grep -q 'kind: SecretStore' "${RENDER_DIR}/dataiku-prereqs.yaml" || fail "SecretStore missing from prereqs render"
grep -q 'kind: ExternalSecret' "${RENDER_DIR}/dataiku-prereqs.yaml" || fail "ExternalSecret missing from prereqs render"
grep -q 'kind: Job' "${RENDER_DIR}/dataiku-bootstrap.yaml" || fail "Bootstrap Job missing from bootstrap render"
grep -q 'kind: StatefulSet' "${RENDER_DIR}/dataiku-runtime.yaml" || fail "StatefulSet missing from runtime render"
grep -q 'kind: Ingress' "${RENDER_DIR}/dataiku-runtime.yaml" || fail "Ingress missing from runtime render"

info "Checking hardened pod security settings"
grep -q 'runAsNonRoot: true' "${RENDER_DIR}/dataiku-runtime.yaml" || fail "runtime runAsNonRoot missing"
grep -q 'readOnlyRootFilesystem: true' "${RENDER_DIR}/dataiku-runtime.yaml" || fail "runtime readOnlyRootFilesystem missing"
grep -q 'allowPrivilegeEscalation: false' "${RENDER_DIR}/dataiku-runtime.yaml" || fail "runtime allowPrivilegeEscalation=false missing"
grep -q 'drop:' "${RENDER_DIR}/dataiku-runtime.yaml" || fail "runtime dropped capabilities missing"
grep -q 'mountPath: "/tmp"' "${RENDER_DIR}/dataiku-runtime.yaml" || fail "runtime /tmp tmpfs missing"
grep -q 'mountPath: "/var/tmp"' "${RENDER_DIR}/dataiku-runtime.yaml" || fail "runtime /var/tmp tmpfs missing"
grep -q 'mountPath: "/run"' "${RENDER_DIR}/dataiku-runtime.yaml" || fail "runtime /run tmpfs missing"
grep -q 'mountPath: "/home/dataiku"' "${RENDER_DIR}/dataiku-runtime.yaml" || fail "runtime /home/dataiku tmpfs missing"
grep -q 'medium: Memory' "${RENDER_DIR}/dataiku-runtime.yaml" || fail "runtime memory-backed tmpfs volumes missing"
grep -q '/run/secrets/dataiku/license/license.json' "${RENDER_DIR}/dataiku-runtime.yaml" || fail "runtime license path must use /run/secrets"

grep -q 'readOnlyRootFilesystem: true' "${RENDER_DIR}/dataiku-bootstrap.yaml" || fail "bootstrap readOnlyRootFilesystem missing"
grep -q 'mountPath: "/tmp"' "${RENDER_DIR}/dataiku-bootstrap.yaml" || fail "bootstrap /tmp tmpfs missing"
grep -q 'readOnlyRootFilesystem: true' "${RENDER_DIR}/dataiku-node.yaml" || fail "dataiku-node readOnlyRootFilesystem missing"

info "Render tests passed"
