[![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/Terradue/ci-eoap-container/build-image.yaml?branch=develop&event=push&label=build&logo=githubactions)](https://github.com/Terradue/ci-eoap-container/actions/workflows/build-image.yaml?query=branch%3Adevelop)
[![Apache License, Version 2.0](https://img.shields.io/badge/license-Apache%20License%202.0-blue)](https://www.apache.org/licenses/LICENSE-2.0)


# ci-eoap-container

Container image for CI chains that manage CWL documents as OCI artifacts.

## Goal

Provide a single CI runtime with tooling to:

- validate CWL with `cwltool`
- check OGC API Processes entry point compliance with `cwl2ogc`
- transpile CWL metadata with `transpiler-mate` (for example to CodeMeta, OGC Record, DataCite, and Markdown)
- push container images with `skopeo`
- scan container images with `trivy`
- publish OCI artifacts with `oras`

## Included tools

- `cwltool`
- `transpiler-mate` and related plugins:
  - `cwl2codemeta`
  - `cwl2markdown`
  - `cwl2oci`
  - `cwl2ogc`
  - `cwl2puml`
  - `cwl2ro-crate`
  - `cwl2sbom`
  - `cwl2webgl`
- `skopeo`
- `trivy`
- `oras`
- `jq`
- `yq`
- `hatch`
- `nodejs`
- `python3`

## Build

```bash
docker build -t ci-eoap-container:latest .
```

## Typical CI usage

### 1) Validate CWL

```bash
cwltool --validate ./workflow.cwl
```

### 2) Transpile CWL with `transpiler-mate`

The [transpiler-mate](https://github.com/Transpiler-mate/) is a collection of open-source tools built around [CWL](https://www.commonwl.org/) to convert the CWL to other diferent formats.

#### 2.1) Validate OGC API Processes compatibility

```bash
transpiler-mate cwl2ogc ./workflow.cwl#${WORKFLOW_ID} --output ogc-process.json
```

#### 2.1) Documentation generation

```bash
transpiler-mate cwl2markdown ./workflow.cwl --output ./docs
transpiler-mate cwl2puml \
  --diagrams component \
  --output ./docs \
  --convert-image \
  --image-format svg \
  --puml-server uml.planttext.com \
  'workflow.cwl#${WORKFLOW_ID}'
transpiler-mate cwl2webgl 'workflow.cwl#${WORKFLOW_ID}' --output ./docs/${WORKFLOW_ID}-explorer.html
```

#### 2.2) Metadata generation

```bash
transpiler-mate cwl2codemeta \
  --code-repository https://gitlab.com/example/hello.git \
  --output ./codemeta.json \
  workflow.cwl
transpiler-mate cwl2ogcrecords ./workflow.cwl --output ogc-record.json
transpiler-mate cwl2datacite workflow.cwl --output datacite.json
transpiler-mate cwl2oci workflow.cwl#${WORKFLOW_ID} \
  --image-source https://github.com/example/project \
  --image-revision 4f8c2ad
```

#### 2.3) Reports generation

```bash
transpiler-mate cwl2sbom --platform linux/amd64 --output sbom \
  workflow.cwl
```

### 3) Publish CWL/metadata as OCI artifacts

```bash
oras login registry.example.org -u "$REGISTRY_USER" -p "$REGISTRY_PASSWORD"
oras push registry.example.org/my-org/my-workflow:1.0.0 \
  --annotation-file annotations.json \
  --artifact-type application/cwl \
  ./workflow.cwl:application/cwl \
  ./codemeta.json:application/json \
  ./datacite.json:application/json \
  ./ogc-process.json:application/json \
  ./ogc-record.json:application/json
```

### 4) Scan OCI/Docker images

```bash
trivy image registry.example.org/my-org/my-image:1.0.0
```

### 5) Push container images

```bash
skopeo copy --all \
  docker-daemon:my-image:1.0.0 \
  docker://registry.example.org/my-org/my-image:1.0.0
```

## Third-party notices

After pushing the image, `.github/workflows/build-image.yaml` pulls the exact
pushed digest and generates `NOTICE` in a disposable container. It then attaches
`NOTICE` and the repository's `LICENSE` together as an OCI artifact using ORAS.
The artifact type is `application/vnd.eoap.license-notices.v1`. Generation runs
in CI; no local registry access or generated NOTICE commit is needed.

These files are registry attachments associated with the image digest, not files
inside the image. To find the attachment and download both files with ORAS:

```bash
oras discover --artifact-type application/vnd.eoap.license-notices.v1 \
  ghcr.io/terradue/ci-eoap-container@sha256:<image-digest>
# Use the attachment digest returned above:
oras pull ghcr.io/terradue/ci-eoap-container@sha256:<attachment-digest>
```

The workflow needs registry pull/push access through `GITHUB_TOKEN` and declares
`packages: write`. Include `LICENSE` and `scripts/generate-notice.sh` in the
repository when committing the workflow changes.

The collector includes installed RPM packages (including the base image), Python
distributions, and Helm plugin license and attribution files. Known downloaded
tools are listed even without notice files. Missing notices and embedded or
unmanaged dependencies are listed for review; collection is best-effort and
does not guarantee complete attribution coverage.

For optional local use with an image already available in Docker:

```bash
bash scripts/generate-notice.sh ci-eoap-container:latest ./NOTICE
```

## License review in CI

Before pushing the image, CI runs Trivy's full license scanner against the built
`image.tar`, covering supported package metadata and recognizable license text.
The `license-review` GitHub Actions artifact contains `license-report.json` and
`license-report.txt` (retained for 30 days); the job summary lists entry counts
by severity. All severities, including UNKNOWN, are retained.

This is **report only**: license findings do not block publication, while scanner
or report-generation errors fail CI. It uses the same Trivy 0.50.2 version as the
existing scans and its default license classifications. In those classifications,
CRITICAL means Forbidden, HIGH Restricted, MEDIUM Reciprocal, LOW Notice,
Permissive or Unencumbered, and UNKNOWN unrecognized. These are Trivy's labels,
not an approved project policy or evidence that a license is unlawful.

Review unknown licenses and relevant license obligations before deciding on a
blocking policy. Detection cannot establish license compatibility, fulfillment
of source-distribution or attribution obligations, or complete coverage of
embedded dependencies. Neither a successful scan nor a generated NOTICE is a
legal clearance. See [Trivy license scanning documentation](https://trivy.dev/v0.50/docs/scanner/license/).
