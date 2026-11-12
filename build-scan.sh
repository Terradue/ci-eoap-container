#!/usr/bin/env bash
set -euo pipefail

mkdir -p .local-ci

docker run --rm \
  -v "$PWD:/workspace" \
  gcr.io/kaniko-project/executor:debug \
  --context dir:///workspace \
  --dockerfile /workspace/Dockerfile \
  --no-push \
  --cache=false \
  --tar-path /workspace/.local-ci/image.tar

docker run --rm \
  -v "$PWD/.local-ci:/work" \
  -e TRIVY_DB_REPOSITORY=ghcr.io/aquasecurity/trivy-db \
  aquasec/trivy:0.76.2 \
  image --input /work/image.tar \
  --format cyclonedx --output /work/sbom.cdx.json

docker run --rm \
  -v "$PWD/.local-ci:/work" \
  -v "$PWD/.grype.yaml:/config/.grype.yaml:ro" \
  -w /work \
  ghcr.io/anchore/grype:v0.117.0 \
  sbom:sbom.cdx.json --config /config/.grype.yaml --fail-on high \
  --output sarif --file grype.sarif
