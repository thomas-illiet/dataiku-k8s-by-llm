#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=./lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

need_cmd bash

scripts=(
  "${IMAGES_DIR}/scripts/build-runtime.sh"
  "${IMAGES_DIR}/scripts/fetch-kit.sh"
  "${IMAGES_DIR}/scripts/push-image.sh"
  "${IMAGES_DIR}/scripts/scan-image.sh"
  "${IMAGES_DIR}/scripts/sign-image.sh"
)

info "Checking --help output"
for script in "${scripts[@]}"; do
  output="$("${script}" --help)"
  [[ -n "${output}" ]] || fail "${script} --help produced no output"
  grep -qi 'usage:' <<<"${output}" || fail "${script} --help does not include Usage"
done

info "Checking missing environment failures"
set +e
output="$(env -i PATH="${PATH}" bash "${IMAGES_DIR}/scripts/build-runtime.sh" 2>&1)"
status=$?
set -e
[[ ${status} -ne 0 ]] || fail "build-runtime.sh succeeded without required env"
grep -q 'DSS_VERSION' <<<"${output}" || fail "build-runtime.sh missing-env output should mention DSS_VERSION"

set +e
output="$(env -i PATH="${PATH}" bash "${IMAGES_DIR}/scripts/fetch-kit.sh" 2>&1)"
status=$?
set -e
[[ ${status} -ne 0 ]] || fail "fetch-kit.sh succeeded without required env"
grep -q 'DSS_VERSION' <<<"${output}" || fail "fetch-kit.sh missing-env output should mention DSS_VERSION"

info "Checking required positional argument failures"
for script in push-image.sh scan-image.sh sign-image.sh; do
  set +e
  output="$(bash "${IMAGES_DIR}/scripts/${script}" 2>&1)"
  status=$?
  set -e
  [[ ${status} -ne 0 ]] || fail "${script} succeeded without IMAGE"
  grep -qi 'usage:' <<<"${output}" || fail "${script} missing-arg output should include Usage"
done

info "Help tests passed"

