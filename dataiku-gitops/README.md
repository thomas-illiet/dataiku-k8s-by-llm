# Dataiku GitOps Deployment

This repository contains the Argo CD and Helm assets used to deploy Dataiku on
Kubernetes without application VMs.

The deployment uses:

- Argo CD App of Apps.
- Helm charts stored in Git.
- Vault plus External Secrets Operator for secrets.
- Internally built Dataiku runtime images.
- A bootstrap job that initializes or upgrades `DATA_DIR` and builds Dataiku
  execution images.

## Repository Layout

```text
argocd/root/onprem-prod.yaml        Root Argo CD Application
argocd/root/dataiku-project.yaml    Argo CD AppProject
argocd/apps/                        Child Applications managed by the root app
charts/dataiku-platform/            Main platform chart
charts/dataiku-node/                Reusable node chart skeleton
envs/onprem/prod/                   Production values and secret mapping
docs/                               Runbooks and architecture notes
```

## Bootstrap Order

Argo CD sync waves are used to enforce deployment order:

| Wave | Application | Purpose |
| --- | --- | --- |
| 0 | `external-secrets` | Install ESO and CRDs |
| 10 | `dataiku-secrets` | Namespace, RBAC, PVCs, Vault SecretStore, ExternalSecrets |
| 20 | `dataiku-bootstrap` | Initialize or upgrade `DATA_DIR`, build Dataiku execution images |
| 30 | `dataiku-runtime` | Start Dataiku StatefulSets |

## First Install

1. Build and push the runtime image from `../dataiku-images`.
2. Update `envs/onprem/prod/values.yaml` with the approved image tag.
3. Ensure Vault contains the required secret paths.
4. Apply the Argo CD project and root application:

```bash
kubectl apply -f argocd/root/dataiku-project.yaml
kubectl apply -f argocd/root/onprem-prod.yaml
```

5. Let Argo CD sync each wave.

## Important

This deployment is intentionally outside Dataiku's standard supported
installation path. Validate with Dataiku before production use.

