#!/bin/bash
set -euxo pipefail

# Clean up all containers.
podman system prune -af

# This command seems to exit with a 1 frequently.
buildah logout --all || true