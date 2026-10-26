# Build and run the container

Use these commands from a checkout of this repository with Docker running.
The Dockerfile downloads amd64 binaries, so use an amd64 environment or a Docker
installation configured to emulate it.

## Build locally

```bash
docker build --pull --no-cache -t ci-eoap-container:latest .
```

Use `--pull --no-cache` for security rebuilds so Docker refreshes the base image
and reruns the system certificate update. CI explicitly disables Kaniko layer
caching. The Dockerfile updates RPMs, explicitly installs `ca-certificates`, then
bootstraps pip 26.2.2 from the advisory's SHA256-verified wheel before installing
requirements with its fixed CA bundle. `certifi==2026.10.19` and `uv==0.13.5` are
also pinned to include the certificate incident fixes. When updating pip, update
both its requirements pin and the bootstrap wheel URL/hash in the Dockerfile.
Existing published images need a fresh build; changing these files does not patch
them. New virtual environments may carry their own pip or CA bundles and must
also use fixed versions before downloading dependencies.
See the [Python certificate incident guidance](https://discuss.python.org/t/109576).

The build needs network access to package repositories and downloaded tools.
See [included tools](../reference/tools.md) for the build inputs.

## Work with local files

From the directory containing your CWL files, start a shell with that directory
mounted at `/work`:

```bash
docker run --rm -it \
  --user "$(id -u):$(id -g)" -e HOME=/tmp \
  -v "$PWD:/work" -w /work \
  ci-eoap-container:latest bash
```

Run the commands in the other how-to guides in this shell, or in a CI job that
already uses the image as its runtime. Outputs under `/work` persist in the host
directory. Files elsewhere in this disposable container are removed on exit.

For a single command, replace `bash` with the tool and its arguments:

```bash
docker run --rm -v "$PWD:/work" -w /work \
  ci-eoap-container:latest cwltool --validate workflow.cwl
```

See the [CI reference](../reference/ci.md) for published image tags.
