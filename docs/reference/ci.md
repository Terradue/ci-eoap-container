# CI pipeline and artifacts

The image build is defined in
[`.github/workflows/build-image.yaml`](https://github.com/Terradue/ci-eoap-container/blob/develop/.github/workflows/build-image.yaml).

## Triggers and tags

| Git ref | Published image tag |
| --- | --- |
| Push to `develop` | `latest-dev` |
| Push to `main` | `latest` |
| Tag `v<version>` | `<version>`, checked against `release.yaml` |

`release.yaml` supplies `image_registry`, `image_prefix`, `image_name`, and
`image_version`. The resulting image reference is
`<image_registry>/<image_prefix>/<image_name>:<tag>`.

## Build stages

1. Resolve the image tag and validate release tags against `release.yaml`.
2. Build `image.tar` with Kaniko without pushing.
3. Scan HIGH and CRITICAL vulnerabilities with Trivy `0.50.2`, using `--exit-code 0`.
4. Generate an SPDX JSON SBOM with the same Trivy version.
5. Scan licenses, format the report, and upload the review artifact.
6. Push the archive with Skopeo and record its digest.
7. Pull that exact digest, generate `NOTICE`, and attach it with `LICENSE` using ORAS.

The image job declares `contents: read` and `packages: write`. Registry publication
uses `GITHUB_TOKEN`; optional Docker Hub authentication uses the
`dockerhub-username` and `dockerhub-token` secrets.

## Outputs

| Output | Location and purpose |
| --- | --- |
| `image.tar` | Build-job workspace; image archive used for scans and publication |
| `sbom.spdx.json` | Build-job workspace; generated runtime SBOM, no upload step is defined |
| `license-report.json`, `license-report.txt` | `license-review` Actions artifact, retained for 30 days |
| `pushed.digest`, `image.digest` | Build-job workspace; digest records used during publication |
| `LICENSE`, `NOTICE` | Registry attachment to the pushed image digest |

The notice attachment type is `application/vnd.eoap.license-notices.v1`.
Its files are not placed inside the runtime image.

## License scan settings

The full license scan uses `--scanners license --license-full`, retains all
severities, and sets `--exit-code 0`. Findings do not block publication; scanner
and report-generation errors fail the job.

The README records these default Trivy classifications:

| Severity | Classification |
| --- | --- |
| CRITICAL | Forbidden |
| HIGH | Restricted |
| MEDIUM | Reciprocal |
| LOW | Notice, Permissive, or Unencumbered |
| UNKNOWN | Unrecognized |

These are scanner labels, not a project-approved policy. See
[license evidence](../explanation/license-evidence.md) for interpretation.
