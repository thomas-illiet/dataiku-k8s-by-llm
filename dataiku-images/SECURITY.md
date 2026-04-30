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

## Runtime Hardening

The DSS runtime image runs as `USER 1000:1000` and is validated with a
read-only root filesystem.

Required writable mounts:

| Path | Type | Purpose |
| --- | --- | --- |
| `/dataiku/dss` | persistent volume | Dataiku `DATA_DIR` |
| `/tmp` | tmpfs | Java, Python, native libraries, short-lived DSS temp files |
| `/var/tmp` | tmpfs | OS and library temp fallback |
| `/run` | tmpfs | runtime sockets, pid files, mounted runtime secrets |
| `/home/dataiku` | tmpfs | user-level caches and CLI config |

Do not make the image root filesystem writable to fix application writes.
Instead, add the specific runtime path as a documented tmpfs or persistent
volume, then add a test that proves the root filesystem remains read-only.

## Image Supply Chain

Recommended controls:

- Generate an SBOM for every runtime image.
- Scan the image before publishing.
- Sign the image and enforce verification at admission time.
- Pin all deployed tags by immutable version.
