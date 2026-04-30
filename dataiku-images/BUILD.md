# Build And Promotion

## Versioning

Use immutable image tags:

```text
registry.internal/dataiku/dss-runtime:<DSS_VERSION>-<BUILD_REV>
```

Examples:

```text
registry.internal/dataiku/dss-runtime:14.4.2-1
registry.internal/dataiku/dss-runtime:14.4.2-2
```

Do not deploy `latest`.

## Required CI Stages

1. Verify the DSS kit archive exists.
2. Build the runtime image.
3. Generate an SBOM.
4. Scan vulnerabilities.
5. Sign the image.
6. Push to the internal registry.
7. Open a GitOps pull request updating the image tag.

## Local Build Contract

The Docker build context must include:

```text
dataiku-dss-<DSS_VERSION>.tar.gz
assets/
Dockerfile.runtime
entrypoint.sh
```

The `assets/` directory may be empty, but it must exist.

## Promotion

Promotion is done by Git, not by retagging mutable images.

Update:

```yaml
global:
  image: registry.internal/dataiku/dss-runtime:<DSS_VERSION>-<BUILD_REV>
```

in the environment values file and let Argo CD reconcile the deployment.

