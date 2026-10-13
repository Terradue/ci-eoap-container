# Your first CWL validation

In this tutorial you will build the CI image, create a small CWL document, and
validate it inside the container. No registry account is needed.

## Before you start

You need Git, a running Docker installation, an amd64 Linux container environment,
and network access to download the image's dependencies. Run the commands in a
Bash-compatible shell.

## Build the runtime

Clone the repository and build the image:

```bash
git clone https://github.com/Terradue/ci-eoap-container.git
cd ci-eoap-container
docker build -t ci-eoap-container:latest .
```

Docker should finish by creating the local `ci-eoap-container:latest` image.

## Create a CWL document

Create a separate working directory and a minimal command-line tool:

```bash
mkdir -p tutorial-work
cd tutorial-work
cat > hello.cwl <<'EOF'
cwlVersion: v1.2
class: CommandLineTool
baseCommand: echo
inputs:
  message:
    type: string
    inputBinding:
      position: 1
outputs: []
EOF
```

This document describes a command that accepts a string and passes it to `echo`.

## Validate the document

Mount the working directory into the container and run the validator:

```bash
docker run --rm \
  -v "$PWD:/work" -w /work \
  ci-eoap-container:latest \
  cwltool --validate hello.cwl
```

The command should exit successfully and report that `hello.cwl` is valid CWL.
Validation checks the document; it does not execute the described command.

## Generate documentation

Use the same image to turn the CWL into Markdown. Pass your user and group IDs
so generated files in the mounted directory belong to you:

```bash
mkdir -p generated-docs
docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp \
  -v "$PWD:/work" -w /work \
  ci-eoap-container:latest \
  transpiler-mate cwl2markdown hello.cwl --output ./generated-docs
ls generated-docs
```

Open the generated Markdown to inspect the description of your tool.
You have now used two tools from the same CI runtime against one mounted document.

Next, use your own workflow with the [transformation guide](../how-to/transform-cwl.md),
or read [why CWL and OCI are used together](../explanation/cwl-and-oci.md).
