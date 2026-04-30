# Validation Checklist

## Argo CD

- Root app `dataiku-onprem-prod` is healthy.
- Child apps are created.
- Sync waves run in order: `0`, `10`, `20`, `30`.
- `dataiku-runtime` has no drift.

## Secrets

- `SecretStore/vault-dataiku-prod` is ready.
- `ExternalSecret/dataiku-license` is synced.
- `ExternalSecret/dataiku-registry-dockerconfig` is synced.
- No secret values are committed in Git.

## Runtime

- `StatefulSet/dataiku-design` is ready.
- `Service/dataiku-design` exposes ports `10000-10010`.
- Ingress responds over HTTPS.
- WebSockets work through the Ingress.
- Restarting the pod preserves DSS configuration.

## Build

- Runtime image exists in the internal registry.
- Bootstrap job succeeds.
- `container-exec` image is pushed.
- `api-deployer` image is pushed if enabled.

## Workloads

- Python recipe can run in Kubernetes.
- R recipe can run in Kubernetes if R is enabled.
- Spark recipe can run in Kubernetes if Spark image is enabled.
- API service can be deployed via API Deployer if enabled.

