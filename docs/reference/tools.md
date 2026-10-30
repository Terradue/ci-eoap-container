# Included tools

The build inputs are defined in
[`Dockerfile`](https://github.com/Terradue/ci-eoap-container/blob/develop/Dockerfile)
and [`requirements.txt`](https://github.com/Terradue/ci-eoap-container/blob/develop/requirements.txt).
The versions below reflect those files; unpinned tools are resolved during build.

## Python packages

| Package | Pinned version | Role |
| --- | --- | --- |
| `cwltool` | `3.3.20260925135507` | CWL validation and execution tooling |
| `transpiler-mate-api` | `1.0.1` | Transpiler API |
| `transpiler-mate-runtime` | `1.3.1` | `transpiler-mate` runtime |
| `cwl2codemeta` | `0.1.1` | CodeMeta metadata |
| `cwl2datacite` | `0.1.1` | DataCite metadata |
| `cwl2markdown` | `0.2.1` | Markdown documentation |
| `cwl2oci` | `0.1.1` | OCI metadata |
| `cwl2ogc` | `0.22.2` | OGC API Processes descriptions |
| `cwl2ogcrecords` | `0.2.0` | OGC Records metadata |
| `cwl2puml` | `0.49.1` | PlantUML diagrams |
| `cwl2ro-crate` | `0.1.1` | RO-Crate metadata |
| `cwl2sbom` | `0.1.1` | Workflow SBOM reports |
| `cwl2webgl` | `0.1.1` | HTML workflow explorer |
| `eoap-cwlwrap` | `0.32.0` | `transpiler-mate cwlwrap`: wrap workflows with stage-in and stage-out and produce packed CWL |
| `hatch` | `1.18.1` | Python project and environment management |
| `ruff` | `0.17.2` | Python linting and formatting |
| `pre-commit` | `4.7.0` | Git hook management |
| `pip` | `26.2.2` | Hash-verified bootstrap before index access |
| `certifi` | `2026.10.23` | Updated Python CA bundle |
| `uv` | `0.13.6` | Python package management; explicit pin for the certificate incident fix |

All directly installed pip packages are pinned in `requirements.txt`, including
these development tools, so Dependabot can propose updates. Transitive Python
dependencies are still resolved during the build; this is not a full lockfile.

## System and downloaded tools

| Tool or component | Build selection |
| --- | --- |
| Base image | `rockylinux/rockylinux:10.2-minimal` |
| `yq` | `YQ_VERSION=v4.54.1`; built from source with Go `1.27.3` and patched `x/net` |
| `oras` | `ORAS_VERSION=1.3.6`; built from source with Go `1.27.3` |
| `task` | `TASK_VERSION=v3.54.0`; built from source with Go `1.27.3` and patched Go modules |
| `skopeo`, `jq`, `python3` | RPM repositories, unpinned |
| `nodejs`, bundled `npm` | `NODE_VERSION=v24.22.1`; upstream Linux x64 archive checked against release SHA256 sums, then npm updated to `12.2.1` with patched `undici` and `ip-address` dependencies |
| `trivy` | `TRIVY_VERSION=0.76.1`; RPM installed, then rebuilt from source with patched Go dependencies |
| Helm | `HELM_VERSION=v3.22.0`; built from source with Go `1.27.3` and patched Go dependencies |
| `helm-unittest` | `v1.2.1`, built from source with Go `1.27.3` and patched Go modules |
| Helm `cm-push` plugin | ChartMuseum `v0.11.1`, rebuilt with Go `1.27.3` and updated Go module dependencies |

The RPM installation also includes ca-certificates, curl, tar, gzip, pip, setuptools, GCC, Git,
Clang, OpenSSL, the Node.js runtime libraries, and wget. Go source builds target Linux amd64.

## Runtime defaults

The Dockerfile creates user `neo` with UID/GID `2000` and sets `HOME=/home/neo`.
It does not set a `USER` instruction, so Docker runs commands as root by default.
Use `--user` to override this when writing files into a host-mounted directory.

The runtime and [CI pipeline](ci.md) both pin Trivy to `0.76.1`. When upgrading,
update the Dockerfile build argument and all Trivy image references in the build
workflow together, then validate CycloneDX generation and license reporting.
