# Validate and transform CWL

Run these commands inside the [CI runtime](build-and-run.md#work-with-local-files)
from a directory containing `workflow.cwl`. For commands that select an entry
point, set its actual CWL identifier:

```bash
export WORKFLOW_ID=main
```

Replace `main` with the entry point in your document. Double quotes around
`"workflow.cwl#${WORKFLOW_ID}"` allow the shell to expand the variable.

## Validate CWL and OGC compatibility

```bash
cwltool --validate ./workflow.cwl
transpiler-mate cwl2ogc "./workflow.cwl#${WORKFLOW_ID}" --output ogc-process.json
```

The first command validates CWL. The second checks conversion to an OGC API
Processes description and writes `ogc-process.json`.

## Wrap a workflow with data staging

The `eoap-cwlwrap` plugin and its `transpiler-mate` runtime are included in the
container. The plugin adds stage-in and stage-out steps around the application
workflow and writes a single packed CWL document.

For a workflow with `Directory` inputs and outputs, provide compatible stage-in
and stage-out CWL components in the working directory:

```bash
transpiler-mate cwlwrap "./workflow.cwl#${WORKFLOW_ID}" \
  --directory-stage-in ./stage-in.cwl \
  --directory-stage-out ./stage-out.cwl \
  --output ./wrapped.cwl
cwltool --enable-ext --validate ./wrapped.cwl
```

For `File` inputs or outputs, supply `--file-stage-in ./stage-in-file.cwl` or
`--file-stage-out ./stage-out-file.cwl`, respectively. Supply a matching staging
component for each `Directory` or `File` type present in the workflow interface;
omit components for types that are absent. Staging components can also be URLs.

Since version `0.32.0`, invoke `transpiler-mate cwlwrap` instead of the standalone
`eoap-cwlwrap` command. Pass the source as a positional argument instead of
`--workflow`, select the process with `#${WORKFLOW_ID}` instead of `--workflow-id`,
and use `--directory-stage-out` instead of `--stage-out`. See the upstream
[CLI reference](https://eoepca.github.io/eoap-cwlwrap/reference/cli/)
for all options and the
[wrapping guide](https://eoepca.github.io/eoap-cwlwrap/how-to-guides/build-a-wrapper/)
for staging examples.

## Generate documentation and diagrams

```bash
mkdir -p generated-docs
transpiler-mate cwl2markdown ./workflow.cwl --output ./generated-docs
transpiler-mate cwl2puml \
  --diagrams component \
  --output ./generated-docs \
  --convert-image \
  --image-format svg \
  --puml-server uml.planttext.com \
  "workflow.cwl#${WORKFLOW_ID}"
transpiler-mate cwl2webgl "workflow.cwl#${WORKFLOW_ID}" \
  --output "./generated-docs/${WORKFLOW_ID}-explorer.html"
```

The SVG conversion uses the specified external PlantUML server. These commands
produce workflow documentation separately from this repository's MkDocs `docs/`.

## Generate metadata

Replace the example source URL and revision with your workflow repository values:

```bash
transpiler-mate cwl2codemeta \
  --code-repository https://gitlab.com/example/hello.git \
  --output ./codemeta.json \
  workflow.cwl
transpiler-mate cwl2ogcrecords ./workflow.cwl --output ogc-record.json
transpiler-mate cwl2datacite workflow.cwl --output datacite.json
transpiler-mate cwl2oci "workflow.cwl#${WORKFLOW_ID}" \
  --image-source https://github.com/example/project \
  --image-revision 4f8c2ad
```

## Generate an SBOM report

```bash
transpiler-mate cwl2sbom --platform linux/amd64 --output sbom workflow.cwl
```

This report concerns the workflow's container dependencies. The runtime image's
own SBOM is generated separately by the [build pipeline](../reference/ci.md).

To distribute the workflow and generated metadata, follow
[publish a CWL artifact](publish-artifacts.md).
