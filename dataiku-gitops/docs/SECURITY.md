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

