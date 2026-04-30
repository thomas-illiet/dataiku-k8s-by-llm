# Dataiku Kubernetes GitOps

This repository contains a proof-of-concept delivery stack for running Dataiku
DSS without application VMs.

It covers two complementary scopes:

- `dataiku-images/`: build an internal Dataiku DSS runtime image from the
  official Dataiku kit archive.
- `dataiku-gitops/`: deploy Dataiku on Kubernetes with Argo CD, Helm, Vault,
  and External Secrets Operator.

The design assumes that Dataiku does not provide the production runtime image.
CI must build and publish the image, then GitOps promotes the approved tag.
Argo CD only deploys manifests; it does not build images.

## Repository Layout

```text
.
|-- dataiku-images/       Runtime image Dockerfile, build scripts, image docs
|-- dataiku-gitops/       Helm charts, Argo CD apps, environment values
|-- scripts/              Local validation and smoke-test helpers
|-- docker-compose.local.yml
|-- Makefile
`-- README.md
```

## Local Docker Smoke Test

Use this path to validate the runtime image and a local DSS instance without a
Kubernetes cluster:

```bash
export DSS_VERSION=13.3.2
export BUILD_REV=local

scripts/local-docker.sh fetch
scripts/local-docker.sh build
scripts/local-docker.sh up
scripts/local-docker.sh status
```

DSS is exposed on:

```text
http://localhost:10000/
```

Useful lifecycle commands:

```bash
scripts/local-docker.sh logs
scripts/local-docker.sh down
scripts/local-docker.sh destroy
```

The local container runs as `1000:1000` with a read-only root filesystem,
dropped capabilities, `no-new-privileges`, a persistent volume for
`/dataiku/dss`, and tmpfs mounts for `/tmp`, `/var/tmp`, `/run`, and
`/home/dataiku`.

## Runtime Image Build

The runtime image is built from:

```text
dataiku-dss-<DSS_VERSION>.tar.gz
```

Example:

```bash
cd dataiku-images
export DSS_VERSION=14.x.y
export BUILD_REV=1
export REGISTRY=registry.internal/dataiku

./scripts/build-runtime.sh
./scripts/scan-image.sh "${REGISTRY}/dss-runtime:${DSS_VERSION}-${BUILD_REV}"
./scripts/push-image.sh "${REGISTRY}/dss-runtime:${DSS_VERSION}-${BUILD_REV}"
```

The image must not contain licenses, passwords, registry credentials, Vault
tokens, or private keys.

See `dataiku-images/README.md` and `dataiku-images/SECURITY.md` for details.

## Kubernetes Deployment

The Kubernetes deployment uses:

- Argo CD App of Apps
- Helm charts stored in Git
- Vault plus External Secrets Operator
- internally built Dataiku runtime images
- a bootstrap job to initialize or upgrade `DATA_DIR`
- StatefulSets for DSS runtime nodes

Deployment waves:

| Wave | Purpose |
| --- | --- |
| 0 | External Secrets Operator and CRDs |
| 10 | Namespace, RBAC, PVCs, Vault SecretStore, ExternalSecrets |
| 20 | Dataiku bootstrap and execution-image build |
| 30 | Dataiku runtime StatefulSets |

See `dataiku-gitops/README.md`, `dataiku-gitops/docs/ARCHITECTURE.md`, and
`dataiku-gitops/docs/RUNBOOK.md`.

## Security Model

The DSS runtime container is hardened by default:

- non-root user `1000:1000`
- read-only root filesystem
- dropped Linux capabilities
- privilege escalation disabled
- RuntimeDefault seccomp profile in Kubernetes
- writable paths limited to the `DATA_DIR` PVC and explicit tmpfs mounts
- secrets injected at runtime by External Secrets Operator

The default POC still uses a privileged `docker:dind` sidecar for Dataiku
execution-image builds. For stricter production hardening, switch to a remote
Docker or BuildKit builder compatible with `dssadmin build-base-image`.

See `dataiku-gitops/docs/SECURITY.md`.

## Tests

Run local tests that do not require Docker or a cluster:

```bash
make test-static
make test-help
make test-render
```

Build and inspect the runtime image:

```bash
DSS_VERSION=13.3.2 BUILD_REV=local REGISTRY=local SKIP_SCAN=true make test-build
```

Cluster and end-to-end tests:

```bash
make test-cluster
make test-e2e
```

The complete validation matrix is in `dataiku-gitops/docs/TESTING.md`.

## Important Notes

- `DATA_DIR` must use POSIX block storage such as ext4 or XFS.
- Do not use NFS, GlusterFS, EFS, or other non-POSIX shared filesystems for
  `DATA_DIR`.
- After every DSS upgrade, rebuild the runtime image and Dataiku execution
  images.
- This approach is outside the standard Dataiku installation path. Validate the
  target architecture with Dataiku before production use.
