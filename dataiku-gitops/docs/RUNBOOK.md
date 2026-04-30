# Dataiku GitOps Runbook

## First Install

1. Confirm platform prerequisites:
   - Argo CD is installed.
   - Ingress Controller is installed and supports WebSockets.
   - cert-manager is installed.
   - Vault is reachable from the cluster.
   - External Secrets Operator can authenticate to Vault.
   - Internal registry is reachable from pods.
   - StorageClass `fast-block-rwo` exists.

2. Build the runtime image from `dataiku-images`.

3. Push the image to the internal registry.

4. Update `envs/onprem/prod/values.yaml`:

```yaml
global:
  image: registry.internal/dataiku/dss-runtime:<version>-<rev>
  dssVersion: "<version>"
  buildRev: "<rev>"
```

5. Apply Argo CD objects:

```bash
kubectl apply -f argocd/root/dataiku-project.yaml
kubectl apply -f argocd/root/onprem-prod.yaml
```

6. Watch waves:

```bash
argocd app sync external-secrets
argocd app sync dataiku-secrets
argocd app sync dataiku-bootstrap
argocd app sync dataiku-runtime
```

## Upgrade

Use three controlled GitOps changes.

1. Stop runtime:

```yaml
nodes:
  design:
    replicas: 0
```

Sync `dataiku-runtime` and wait until the pod is gone.

2. Upgrade and rebuild:

```yaml
global:
  image: registry.internal/dataiku/dss-runtime:<new-version>-<rev>
  dssVersion: "<new-version>"
  buildRev: "<rev>"
bootstrap:
  upgrade: true
```

Sync `dataiku-bootstrap`.

3. Restart runtime:

```yaml
nodes:
  design:
    replicas: 1
bootstrap:
  upgrade: false
```

Sync `dataiku-runtime`.

## Rollback

Rollback is only safe before a DSS data directory upgrade. After a DSS upgrade
has modified `DATA_DIR`, restore a PVC snapshot before deploying an older image.

## Backup

Use CSI snapshots or storage-native snapshots for the PVCs:

- `dataiku-design-data`
- `dataiku-automation-data`
- `dataiku-deployer-data`
- `dataiku-govern-data`

For Govern, also back up PostgreSQL.

## Rebuild Execution Images

Execution images are rebuilt by the bootstrap job. Toggle the required image
families under:

```yaml
bootstrap:
  buildImages:
    containerExec: true
    spark: true
    cde: false
    apiDeployer: true
```

## Troubleshooting

Check bootstrap logs:

```bash
kubectl -n dataiku logs job/dataiku-bootstrap-dataiku-platform-bootstrap-<version>-<rev> -c bootstrap
```

Check Docker sidecar logs:

```bash
kubectl -n dataiku logs job/dataiku-bootstrap-dataiku-platform-bootstrap-<version>-<rev> -c docker
```

Check runtime:

```bash
kubectl -n dataiku get pods
kubectl -n dataiku logs statefulset/dataiku-design -c dss
```

