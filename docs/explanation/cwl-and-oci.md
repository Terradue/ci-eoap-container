# CWL and OCI in the CI runtime

CWL describes a command-line tool or workflow. A workflow can refer to container
images for its executable steps, but its CWL document and descriptive metadata
are also useful artifacts in their own right.

This runtime brings the tools for handling both into one CI environment:

```text
CWL document -> validation -> documentation and metadata -> OCI workflow artifact
Container image -> scan -> registry image
```

`cwltool` validates CWL. The `transpiler-mate` plugins derive other representations
from that source, such as an OGC process description, discovery metadata, Markdown,
diagrams, or an SBOM report. Generating these representations from CWL helps keep
the published descriptions tied to the workflow document.

ORAS publishes the CWL document and metadata together with the artifact type
`application/cwl`. Skopeo copies container images between storage locations and
registries. These operations address different objects: publishing a CWL artifact
does not build or publish the executable images referenced by the workflow.

## Validation and scanning answer different questions

CWL validation checks the document's structure and CWL rules. Conversion through
`cwl2ogc` checks whether the selected entry point can be represented for OGC API
Processes. Neither step establishes that a referenced image is free of known
vulnerabilities; image scanning is a separate stage handled by Trivy.

## Tags and digests

A tag is a convenient name for an artifact or image. A digest identifies its exact
content. The build workflow captures the pushed image digest and generates notices
from that image so the attachment corresponds to the published build, even if a
tag later moves.

Try the [tutorial](../tutorials/first-workflow.md) for a first validation, or use
the [publishing guide](../how-to/publish-artifacts.md) for an existing workflow.
