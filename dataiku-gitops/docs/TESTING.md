# Dataiku GitOps Test Plan

This document describes how to validate the full Dataiku Kubernetes delivery
chain: image build, Helm rendering, Argo CD deployment, Vault/ESO integration,
bootstrap, runtime, and upgrade.

## Test Levels

| Level | Command | Requires | Purpose |
| --- | --- | --- | --- |
| Static | `make test-static` | `bash`, `helm`, `ruby` | Shell syntax, Helm lint, checked-in YAML parsing, obvious secret scan |
| Help | `make test-help` | `bash` | Script `--help` and missing-input behavior |
| Render | `make test-render` | `helm`, `ruby` | Render `prereqs`, `bootstrap`, `runtime`, and `dataiku-node` charts |
| Build | `make test-build` | Docker, DSS kit, scanner | Build, inspect, scan, optionally push runtime image |
| Cluster | `make test-cluster` | Kubernetes test cluster | Server-side dry-run and optional Argo CD apply/sync |
| E2E | `make test-e2e` | Deployed test stack | Bootstrap, runtime, Ingress, restart smoke tests |

## Local Offline Tests

Run these before every commit:

```bash
make test-static
make test-help
make test-render
```

Expected result:

- All shell scripts parse with `bash -n`.
- Both Helm charts pass `helm lint`.
- Argo CD manifests, values files, ExternalSecrets, and workflow YAML parse.
- Helm renders are valid for all three deployment waves.
- Helm renders keep the DSS container rootless, read-only, and backed by tmpfs
  only for `/tmp`, `/var/tmp`, `/run`, and `/home/dataiku`.
- Image scripts expose `--help` and fail clearly when required input is missing.

## Script Help Contract

All scripts under `dataiku-images/scripts/` must support:

```bash
./scripts/<name>.sh --help
```

Required behavior:

- Output includes `Usage:`.
- Required variables and arguments are listed.
- Missing input exits non-zero.
- No secrets are printed.

## Runtime Image Build Test

Prerequisites:

- Docker daemon available.
- Official kit present in `dataiku-images/`, or an internal URL available via
  `DATAIKU_DSS_KIT_URL`.
- `trivy` or `grype` installed unless `SKIP_SCAN=true`.

Fetch the kit if needed:

```bash
cd dataiku-images
DSS_VERSION=14.x.y ./scripts/fetch-kit.sh
cd ..
```

Build and inspect:

```bash
DSS_VERSION=14.x.y BUILD_REV=1 REGISTRY=registry.internal/dataiku make test-build
```

Push after a successful build:

```bash
DSS_VERSION=14.x.y BUILD_REV=1 REGISTRY=registry.internal/dataiku PUSH_IMAGE=true make test-build
```

Acceptance criteria:

- `docker image inspect` succeeds for
  `registry.internal/dataiku/dss-runtime:<version>-<rev>`.
- The image config uses `USER 1000:1000`.
- The image contains `/opt/dataiku/dataiku-dss-<version>`.
- `kubectl`, `docker`, `java`, `python3`, and `R` are present.
- A smoke container can run with a read-only root filesystem plus tmpfs mounts
  for `/tmp`, `/var/tmp`, `/run`, and `/home/dataiku`.
- Vulnerability scan passes the configured policy.
- Push succeeds when `PUSH_IMAGE=true`.

## Cluster Validation

Use only a non-production cluster.

Prerequisites:

- Current `kubectl` context points to the test cluster.
- Argo CD is installed.
- External Secrets Operator CRDs are installed or installable by the Argo app.
- Vault is reachable from the cluster.
- Internal registry is reachable from pods.
- Ingress Controller, cert-manager, DNS, and block `StorageClass` exist.

Dry-run rendered resources:

```bash
make test-cluster
```

Apply root Argo CD objects:

```bash
APPLY_ARGO=true make test-cluster
```

Sync Argo CD waves:

```bash
SYNC_ARGO=true make test-cluster
```

Acceptance criteria:

- Server-side dry-run accepts rendered Helm resources.
- Root app creates the child apps.
- Sync waves run in order: `0`, `10`, `20`, `30`.
- `SecretStore/vault-dataiku-prod` becomes ready.
- `ExternalSecret/dataiku-license` and
  `ExternalSecret/dataiku-registry-dockerconfig` sync successfully.
- PVC, RBAC, NetworkPolicy, bootstrap Job, StatefulSet, Service, and Ingress are
  present.

## E2E Runtime Smoke Test

Run after Argo CD has deployed the stack:

```bash
DSS_HOST=dss.dataiku.internal make test-e2e
```

For restricted networks or DNS not yet delegated:

```bash
SKIP_INGRESS=true make test-e2e
```

Acceptance criteria:

- Latest bootstrap job completed.
- Bootstrap logs mention `container-exec` and `api-deployer`.
- `StatefulSet/dataiku-design` rolls out successfully.
- `Service/dataiku-design` exposes the expected ports.
- Ingress responds over HTTPS when enabled.
- Deleting the DSS pod creates a new pod and the StatefulSet becomes ready
  again, proving `DATA_DIR` survived pod restart.

## Upgrade And Rollback Test

Use a disposable environment or restoreable PVC snapshot.

1. Set `nodes.design.replicas=0` and sync `dataiku-runtime`.
2. Update `global.image`, `global.dssVersion`, `global.buildRev`, and set
   `bootstrap.upgrade=true`.
3. Sync `dataiku-bootstrap`.
4. Confirm execution images are rebuilt.
5. Set `nodes.design.replicas=1` and `bootstrap.upgrade=false`.
6. Sync `dataiku-runtime`.
7. Run `make test-e2e`.

Rollback rule:

- If `DATA_DIR` has not been upgraded, revert the image tag and sync.
- If `DATA_DIR` has been upgraded, restore the PVC snapshot first, then deploy
  the older runtime image.

## Log Collection

Collect bootstrap logs:

```bash
kubectl -n dataiku logs job/<bootstrap-job> -c bootstrap
kubectl -n dataiku logs job/<bootstrap-job> -c docker
```

Collect runtime logs:

```bash
kubectl -n dataiku logs statefulset/dataiku-design -c dss
kubectl -n dataiku logs statefulset/dataiku-design -c docker
```

Collect Argo CD status:

```bash
argocd app get dataiku-onprem-prod
argocd app get dataiku-secrets
argocd app get dataiku-bootstrap
argocd app get dataiku-runtime
```

## CI Recommendation

Run these jobs on every pull request:

```bash
make test-static
make test-help
make test-render
```

Run `make test-build` only on image build pipelines with access to the DSS kit
and internal registry.

Run `make test-cluster` and `make test-e2e` only against an ephemeral or
dedicated non-production cluster.
