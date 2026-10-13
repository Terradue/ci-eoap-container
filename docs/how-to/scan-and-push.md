# Scan and push container images

Run these commands where Trivy and Skopeo are available, such as the CI runtime.
Replace the example registry, repository, and tag with your image reference.
Private registries require credentials configured for the relevant tool.

## Scan an image

```bash
trivy image registry.example.org/my-org/my-image:1.0.0
```

The scanner needs access to the image and its vulnerability database. Review the
report before publishing; the command above does not define a project-specific
blocking policy. See the [CI reference](../reference/ci.md) for the repository's
scan settings.

## Push an image

Authenticate to the destination registry, then copy a locally built image:

```bash
printf '%s' "$REGISTRY_PASSWORD" | skopeo login registry.example.org \
  --username "$REGISTRY_USER" --password-stdin
skopeo copy --all \
  docker-daemon:my-image:1.0.0 \
  docker://registry.example.org/my-org/my-image:1.0.0
```

The `docker-daemon:` source requires access to the Docker daemon that holds the
image. Mounting a working directory into the runtime alone does not provide that
access. When your build produces an image archive, use an archive source instead:

```bash
skopeo copy \
  docker-archive:image.tar \
  docker://registry.example.org/my-org/my-image:1.0.0
```

This is the approach used by this repository's image build workflow.
