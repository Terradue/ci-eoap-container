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
- `cwl2ogc`
- `transpiler-mate`
- `cwl2puml`
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

### 2) Validate OGC API Processes compatibility

```bash
cwl2ogc ./workflow.cwl
```

### 3) Transpile metadata with transpiler-mate

```bash
transpiler-mate markdown ./workflow.cwl --output workflow.md
transpiler-mate codemeta ./workflow.cwl --output codemeta.json
transpiler-mate ogcrecord ./workflow.cwl --output ogc-record.json
transpiler-mate datacite ./workflow.cwl --output datacite.json
```

### 4) Publish CWL/metadata as OCI artifacts

```bash
oras login registry.example.org -u "$REGISTRY_USER" -p "$REGISTRY_PASSWORD"
oras push registry.example.org/my-org/my-workflow:1.0.0 \
  ./workflow.cwl:application/cwl \
  ./codemeta.json:application/json \
  ./ogc-record.json:application/json
```

### 5) Scan OCI/Docker images

```bash
trivy image registry.example.org/my-org/my-image:1.0.0
```

### 6) Push container images

```bash
skopeo copy --all \
  docker-daemon:my-image:1.0.0 \
  docker://registry.example.org/my-org/my-image:1.0.0
```
