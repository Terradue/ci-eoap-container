# Image SBOM and vulnerability monitoring

## Published inventory

The build generates `sbom.cdx.json` (CycloneDX JSON) from the Kaniko image archive
with Trivy, preserving application and OS packages. Skopeo records the destination
image digest after publication. ORAS attaches the SBOM to that exact digest as an
OCI referrer with artifact and layer type `application/vnd.cyclonedx+json`.
The `image-sbom` Actions artifact retains the full inventory for 30 days.
License notices remain a separate attachment.

Both security jobs retrieve this published attachment; they do not regenerate an
inventory from a moving tag. The helper resolves the image once, discovers its
referrers by digest, fetches the attachment manifest by digest, verifies its
subject and type, then downloads and verifies the referenced SBOM blob. Missing,
ambiguous, or invalid attachments fail closed. Old images without attachments
must be rebuilt before they can be monitored this way.

## Dependabot

Only builds on the repository's configured default branch submit the application
inventory to GitHub's dependency submission API. The snapshot uses stable detector
`container-cyclonedx`, correlator `container-sbom`, and manifest `image-sbom`, so a
new submission replaces the previous inventory rather than accumulating releases.
The job requires `contents: write` and `packages: read` on `GITHUB_TOKEN`.

The converter recursively visits nested components, reads PURLs independently of
opaque `bom-ref` identifiers, retains distinct package versions, and deduplicates
identical package URLs. A missing PURL version is filled from the component's
version. It submits versioned PURLs for PyPI, npm, Maven, NuGet, RubyGems, Cargo,
Go, Composer, Pub, Hex, and Swift. Packages without usable versioned PURLs and
unsupported types (including RPM, Debian, APK, generic binaries) are omitted from
the snapshot, but remain in the full SBOM scanned by Grype. Dependencies are
reported with runtime scope without guessing direct/transitive relationships.

Enable **Settings → Advanced Security → Dependency graph** and **Dependabot
alerts** (the security settings section may be named Code security in some
repositories). Allow Actions to grant the declared token permissions. Alerts
require a supported GitHub Advisory Database ecosystem and a matching advisory;
submission does not guarantee coverage of all installed software. The SBOM does
not provide a source lockfile that Dependabot can edit to fix every image package.
The Dependabot configuration separately checks Docker, pip, and GitHub Actions
for version updates.

See GitHub's [dependency submission API](https://docs.github.com/en/rest/dependency-graph/dependency-submission)
and [supported ecosystems](https://docs.github.com/en/code-security/dependabot/ecosystems-supported-by-dependabot/supported-ecosystems-and-repositories).

## Grype and code scanning

After each successful build/publish job, the reusable `scan-image.yaml` workflow
scans the attached SBOM with Grype. The same workflow runs daily at 05:23 UTC
against both `latest` and `latest-dev`. GitHub runs schedules only from the default
branch; this workflow must be present there for daily scans to start. A manual run accepts a release image tag
(e.g. `2.1.0`), a `sha256:…` image digest, or a full image reference.
Tags are resolved once; attachment discovery and content retrieval use digests.

HIGH or CRITICAL findings fail the scan check, including findings without fixes.
The upload steps run even after that failure: the SBOM, image digest record, and
SARIF report are retained as 30-day Actions artifacts, and SARIF is uploaded to
GitHub code scanning. Scanner/runtime failures also fail the check; a report may
not exist when the scanner cannot complete. Scheduled targets run independently.

**Scanning happens after publication. A failed scan does not remove an already
published image.** Review alerts and publish a corrected image as appropriate.
Daily scans use refreshed vulnerability intelligence against the original
inventory; they cannot discover software omitted by the original SBOM generator.

Enable code scanning in repository security settings and ensure Actions may
upload SARIF (`security-events: write`). The scan job also requires
`contents: read` and `packages: read`, with GHCR access for the repository token.
Private/internal repositories need the applicable GitHub Code Security entitlement.
The workflow supplies SARIF directly; a CodeQL build is not required.
See [SARIF upload requirements](https://docs.github.com/en/code-security/code-scanning/integrating-with-code-scanning/uploading-a-sarif-file-to-github).

## Retrieve or scan manually

Install ORAS 1.3 and Python 3, and authenticate to GHCR when required:

```bash
printf '%s' "$GH_TOKEN" | oras login ghcr.io --username "$GITHUB_ACTOR" --password-stdin
python3 scripts/image_sbom.py retrieve \
  ghcr.io/terradue/ci-eoap-container:latest-dev sbom.cdx.json
# Install Grype, then scan the downloaded full inventory:
grype sbom:sbom.cdx.json --fail-on high --output sarif --file grype.sarif
```

The helper prints the resolved image digest. To inspect the attachment manually:

```bash
oras resolve ghcr.io/terradue/ci-eoap-container:latest-dev
oras discover --artifact-type application/vnd.cyclonedx+json \
  ghcr.io/terradue/ci-eoap-container@sha256:<image-digest>
# Use the attachment digest, not the image digest, in this command:
oras pull ghcr.io/terradue/ci-eoap-container@sha256:<attachment-digest>
```

From the Actions UI, choose **Image vulnerability monitoring → Run workflow** and
enter a release tag or image digest to run the same reporting and threshold policy.
