# Hosted dependency updates

Dependabot handles the base image, Python requirements, and GitHub Actions.
The hosted Renovate GitHub App handles the Dockerfile pins for yq, ORAS, Task, Node.js,
and Trivy through the root `renovate.json` configuration. Only the custom regex
manager is enabled, avoiding duplicate updates from the two bots.

## Activate the hosted app

1. Open [Install Renovate](https://github.com/apps/renovate/installations/new),
   select the **Terradue** organization, and select **Only select repositories →
   ci-eoap-container**. Review the requested permissions and install, or request
   organization-owner approval if GitHub requires it.
2. Make `renovate.json` available on the repository's default branch through the
   normal reviewed merge/release process. Configuration added only to `develop`
   is not sufficient when the default branch is `main`.
3. Review any onboarding PR or configuration warnings. The existing configuration
   targets update PRs at `develop`; it never enables automerging.
4. Check the Renovate Dependency Dashboard and first update PR to confirm the
   five tools are detected. Trivy updates must include both its Dockerfile ARG
   and all three CI scanner tags in one PR.

Installing the app grants the hosted service the repository permissions shown
by GitHub. This configuration does not install the app, grant permissions, or
require storing a Renovate token in repository secrets. Hosted runs start once
the app has repository access and discovers the configuration.

Node.js is pinned to the 24.x LTS line. Renovate proposes patch/minor updates
within that line; upgrading to another major requires a deliberate configuration
change and runtime validation. The Dockerfile installs the official Node.js
archive and bundled npm, verifies the archive against upstream SHA256 sums, and
checks the installed version. Checksums are fetched over HTTPS from Node.js; they
are not a separately pinned signature or checksum.

## Maintain the configuration

Annotations next to each Dockerfile ARG identify its upstream GitHub releases.
Separate matchers preserve the `v` prefix used by yq, Task, and Node.js and remove the
release tag prefix for ORAS and Trivy. A third matcher tracks the CI Trivy image
tags using the same upstream release source; the Trivy package rule groups all
four occurrences. Official container tags must exist before accepting a release
update. Review checks and release notes before merging any tool update.

CI validates the configuration. To validate locally, use Node.js 24 and run:

```bash
npx --yes --package renovate@44.182.2 renovate-config-validator --strict renovate.json
```

See [Renovate onboarding](https://docs.renovatebot.com/getting-started/installing-onboarding/)
and [regex custom managers](https://docs.renovatebot.com/modules/manager/regex/).
