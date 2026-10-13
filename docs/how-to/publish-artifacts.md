# Publish a CWL artifact

Use ORAS in the CI runtime to publish a CWL document and its metadata to an OCI
registry. You need registry push permission and the files produced by
[validate and transform CWL](transform-cwl.md): `workflow.cwl`, `codemeta.json`,
`datacite.json`, `ogc-process.json`, and `ogc-record.json`.

## Authenticate

Provide `REGISTRY_USER` and `REGISTRY_PASSWORD` through your CI secret mechanism.
Replace `registry.example.org` and the artifact repository in the commands below
with your registry destination.

```bash
printf '%s' "$REGISTRY_PASSWORD" | oras login registry.example.org \
  --username "$REGISTRY_USER" --password-stdin
```

## Push the document and metadata

```bash
oras push registry.example.org/my-org/my-workflow:1.0.0 \
  --artifact-type application/cwl \
  ./workflow.cwl:application/cwl \
  ./codemeta.json:application/json \
  ./datacite.json:application/json \
  ./ogc-process.json:application/json \
  ./ogc-record.json:application/json
```

ORAS prints the published artifact digest on success. Record it when downstream
jobs need to identify the exact artifact.

If you already have an ORAS-compatible `annotations.json`, add
`--annotation-file annotations.json` to the push command. The basic example does
not require an annotations file.

For executable container images, use [Skopeo](scan-and-push.md#push-an-image)
instead. See [CWL and OCI](../explanation/cwl-and-oci.md) for the relationship
between workflow artifacts and images.
