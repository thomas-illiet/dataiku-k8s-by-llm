# Security Runbook

## Secrets

Secrets live in Vault. Git contains only `ExternalSecret` definitions and
metadata.

Required Vault paths:

```text
kv/dataiku/prod/license
kv/dataiku/prod/registry
kv/dataiku/prod/govern-postgres
```

## Docker-in-Docker

The default POC uses a privileged `docker:dind` sidecar. This is operationally
simple and compatible with Dataiku `dssadmin build-base-image`, but it expands
the pod privilege boundary.

Production hardening path:

1. Move image building to a dedicated remote Docker or BuildKit service.
2. Set `builder.mode=remote`.
3. Set `builder.remoteHost=tcp://docker-builder.dataiku.svc:2375`.
4. Disable privileged sidecars.

## DSS Runtime Pod Hardening

The `dss` container runs rootless and with a read-only root filesystem:

```yaml
security:
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
```

Only these write paths are mounted:

| Path | Volume | Reason |
| --- | --- | --- |
| `/dataiku/dss` | PVC | persistent DSS `DATA_DIR` |
| `/tmp` | memory `emptyDir` | Java/Python/DSS temp files |
| `/var/tmp` | memory `emptyDir` | OS temp fallback |
| `/run` | memory `emptyDir` | runtime sockets and mounted secrets |
| `/home/dataiku` | memory `emptyDir` | ephemeral user caches and Docker CLI config |

The Dataiku license path is under `/run/secrets/dataiku/license/license.json`
so it remains compatible with a read-only root filesystem and the `/run` tmpfs.
The DinD sidecar is not part of this hardened DSS image boundary; for strict
production hardening, use the remote builder pattern above.

## RBAC

`rbac.clusterWideWorkloads=true` allows DSS to create workload resources across
namespaces. This is required for namespace-per-user patterns such as
`dssns-${dssUserLogin}`.

For a tighter POC, set:

```yaml
rbac:
  clusterWideWorkloads: false
  allowNamespaceManagement: false
```

and pre-create all execution namespaces and RoleBindings.

## Network Policy

The default policy is intentionally permissive for egress because DSS must reach:

- Kubernetes API
- Vault
- Internal registry
- Package repositories or internal mirrors
- Data sources
- API endpoints

Restrict egress after the concrete network endpoints are known.
