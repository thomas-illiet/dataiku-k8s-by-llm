#!/usr/bin/env bash
set -euo pipefail

: "${DSS_VERSION:?DSS_VERSION is required}"
: "${DSS_INSTALLDIR:=/opt/dataiku/dataiku-dss-${DSS_VERSION}}"
: "${DSS_DATADIR:=/dataiku/dss}"
: "${DSS_PORT:=10000}"
: "${DATAIKU_NODE_TYPE:=design}"

LICENSE_ARGS=()
if [[ -n "${DSS_LICENSE_FILE:-}" && -s "${DSS_LICENSE_FILE}" ]]; then
  LICENSE_ARGS=(-l "${DSS_LICENSE_FILE}")
fi

NODE_ARGS=()
case "${DATAIKU_NODE_TYPE}" in
  design)
    NODE_ARGS=()
    ;;
  automation|deployer|api|govern)
    NODE_ARGS=(-t "${DATAIKU_NODE_TYPE}")
    ;;
  *)
    echo "Unsupported DATAIKU_NODE_TYPE=${DATAIKU_NODE_TYPE}" >&2
    exit 2
    ;;
esac

install_or_upgrade() {
  if [[ ! -f "${DSS_DATADIR}/bin/env-default.sh" ]]; then
    echo "Initializing Dataiku ${DATAIKU_NODE_TYPE} DATA_DIR at ${DSS_DATADIR}"
    "${DSS_INSTALLDIR}/installer.sh" "${NODE_ARGS[@]}" -d "${DSS_DATADIR}" -p "${DSS_PORT}" "${LICENSE_ARGS[@]}"
    if [[ -x "${DSS_DATADIR}/bin/dssadmin" ]]; then
      "${DSS_DATADIR}/bin/dssadmin" install-R-integration || true
      "${DSS_DATADIR}/bin/dssadmin" install-graphics-export || true
    fi
    {
      echo "dku.registration.channel=kubernetes-helm"
      echo "dku.exports.chrome.sandbox=false"
    } >> "${DSS_DATADIR}/config/dip.properties"
    return
  fi

  # shellcheck disable=SC1091
  source "${DSS_DATADIR}/bin/env-default.sh"
  if [[ "${DKUINSTALLDIR:-}" != "${DSS_INSTALLDIR}" ]]; then
    echo "Upgrading Dataiku DATA_DIR from ${DKUINSTALLDIR:-unknown} to ${DSS_INSTALLDIR}"
    rm -rf "${DSS_DATADIR}/pyenv"
    "${DSS_INSTALLDIR}/installer.sh" -d "${DSS_DATADIR}" -u -y "${LICENSE_ARGS[@]}"
    if [[ -x "${DSS_DATADIR}/bin/dssadmin" ]]; then
      "${DSS_DATADIR}/bin/dssadmin" install-R-integration || true
      "${DSS_DATADIR}/bin/dssadmin" install-graphics-export || true
    fi
  fi
}

configure_govern() {
  if [[ "${DATAIKU_NODE_TYPE}" != "govern" ]]; then
    return
  fi

  local dip="${DSS_DATADIR}/config/dip.properties"
  if [[ -n "${GOVERN_PSQL_JDBC_URL:-}" ]]; then
    grep -v '^psql.jdbc.url=' "${dip}" > "${dip}.tmp" || true
    mv "${dip}.tmp" "${dip}"
    echo "psql.jdbc.url=${GOVERN_PSQL_JDBC_URL}" >> "${dip}"
  fi
  if [[ -n "${GOVERN_PSQL_USER:-}" ]]; then
    grep -v '^psql.jdbc.user=' "${dip}" > "${dip}.tmp" || true
    mv "${dip}.tmp" "${dip}"
    echo "psql.jdbc.user=${GOVERN_PSQL_USER}" >> "${dip}"
  fi
  if [[ -n "${GOVERN_PSQL_PASSWORD_ENCRYPTED:-}" ]]; then
    grep -v '^psql.jdbc.password=' "${dip}" > "${dip}.tmp" || true
    mv "${dip}.tmp" "${dip}"
    echo "psql.jdbc.password=${GOVERN_PSQL_PASSWORD_ENCRYPTED}" >> "${dip}"
  fi

  if [[ "${GOVERN_INIT_DB:-false}" == "true" && ! -f "${DSS_DATADIR}/.govern-db-initialized" ]]; then
    "${DSS_DATADIR}/bin/govern-admin" init-db
    touch "${DSS_DATADIR}/.govern-db-initialized"
  fi
}

install_or_upgrade
configure_govern

exec "${DSS_DATADIR}/bin/dss" run

