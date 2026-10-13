# License reports and notices

The image build produces two complementary outputs: a license scan for review
and an attribution attachment for the published image.

## License reports

Before publication, Trivy scans `image.tar` using supported package metadata and
recognizable license text. The JSON and text reports preserve all severity levels,
including UNKNOWN. Counts in the job summary help reviewers locate findings;
they do not determine whether a dependency is acceptable for a particular use.

The pipeline is report-only for license findings. This allows evidence to be
reviewed before a blocking policy is established, while scanner or formatting
errors still fail the job.

## Third-party notices

After publication, the collector runs against the exact pushed digest. It gathers
installed RPM packages, including base-image packages, Python distributions, and
Helm plugin license and attribution files. Known downloaded tools are listed even
when notice files are unavailable.

ORAS attaches the resulting `NOTICE` together with the repository's `LICENSE` as
an OCI artifact associated with the image digest. Keeping these as an attachment
lets consumers retrieve attribution for that image without adding generated files
to the repository or placing them inside the image.

## Coverage and interpretation

Notice collection is best-effort. Missing notices and embedded or unmanaged
dependencies remain items for review. A scan cannot establish complete dependency
coverage, license compatibility, or fulfillment of source-distribution and
attribution obligations. Neither a successful scan nor a generated notice is
legal clearance.

The [retrieval guide](../how-to/license-review.md) explains where to find both
outputs. The [CI reference](../reference/ci.md) records the report settings.
