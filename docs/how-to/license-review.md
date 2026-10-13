# Retrieve notices and review licenses

## Download notices for a published image

You need ORAS and pull access to the registry. Set `IMAGE_REF` to the exact image
digest you want to inspect, replacing the placeholder before running the command:

```bash
IMAGE_REF='ghcr.io/terradue/ci-eoap-container@sha256:<image-digest>'
oras discover --artifact-type application/vnd.eoap.license-notices.v1 "$IMAGE_REF"
```

Copy the attachment digest returned by discovery, then download it into a
dedicated directory:

```bash
mkdir -p license-notices
cd license-notices
oras pull 'ghcr.io/terradue/ci-eoap-container@sha256:<attachment-digest>'
```

The attachment contains `LICENSE` and `NOTICE`. Use the attachment digest for
the pull, rather than the image digest.

## Generate a local notice

From the repository root, with the image already available to Docker:

```bash
bash scripts/generate-notice.sh ci-eoap-container:latest ./NOTICE
```

The collector runs in a disposable container. CI generates the notice after
publication; a generated `NOTICE` does not need to be committed.

## Review the CI license report

1. Open the relevant `build` run in GitHub Actions.
2. Read the job summary for license entry counts by severity.
3. Download the `license-review` artifact within its 30-day retention period.
4. Inspect `license-report.json` and `license-report.txt`, including UNKNOWN entries.

Findings are report-only; scanner or report-generation errors fail CI. See
[license reports and notices](../explanation/license-evidence.md) for scope and
limitations and the [CI reference](../reference/ci.md) for severity labels.
