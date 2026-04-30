# Security Notes

## Secrets

The runtime image must never contain:

- Dataiku license files
- Registry credentials
- Vault credentials
- PostgreSQL passwords
- TLS private keys
- Admin passwords

These values are injected at runtime through Kubernetes Secrets created by
External Secrets Operator from Vault.

## Docker Build Privileges

The Kubernetes deployment uses Docker-in-Docker for the first POC because
Dataiku image build commands expect a Docker-compatible daemon.

This requires a privileged sidecar in the Dataiku pod and bootstrap job.
If this is not acceptable for production, replace it with a remote Docker or
BuildKit service that remains compatible with Dataiku `dssadmin
build-base-image` commands.

## Image Supply Chain

Recommended controls:

- Generate an SBOM for every runtime image.
- Scan the image before publishing.
- Sign the image and enforce verification at admission time.
- Pin all deployed tags by immutable version.

