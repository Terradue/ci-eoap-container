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

All directly installed pip packages are pinned in `requirements.txt`, including
these development tools, so Dependabot can propose updates. Transitive Python
dependencies are still resolved during the build; this is not a full lockfile.

## System and downloaded tools

| Tool or component | Build selection |
| --- | --- |
| Base image | `rockylinux/rockylinux:10.1-minimal` |
| `yq` | `YQ_VERSION=v4.44.3` build argument |
| `oras` | `ORAS_VERSION=1.2.2` build argument |
| `task` | `TASK_VERSION=v3.49.1` build argument |
| `skopeo`, `jq`, `nodejs`, `python3` | RPM repositories, unpinned |
| `trivy` | Trivy RPM repository, unpinned |
| Helm | Upstream Helm 3 installation script, unpinned |
| `helm-unittest` | Downloaded binary, `1.0.3` |
| Helm `cm-push` plugin | Installed from ChartMuseum repository, unpinned |

The RPM installation also includes curl, tar, gzip, pip, setuptools, GCC, Git,
Clang, and wget. Downloads for yq, ORAS, Task, and helm-unittest target Linux amd64.

## Runtime defaults

The Dockerfile creates user `neo` with UID/GID `2000` and sets `HOME=/home/neo`.
It does not set a `USER` instruction, so Docker runs commands as root by default.
Use `--user` to override this when writing files into a host-mounted directory.

The Trivy version installed in the runtime is distinct from the `0.50.2` scanner
image selected by the [CI pipeline](ci.md).
