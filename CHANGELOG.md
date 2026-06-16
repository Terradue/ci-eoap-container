# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### [1.6.0] - 2026-06-16

- Advanced the development image version to `1.6.0`.
- Bumped `cwl2puml` from `0.41.0` to `0.44.0`.
- Bumped `transpiler-mate` from `0.43.0` to `0.45.0`.
- `cwl2ogc` CLI removed in favour of `transpiler-mate ogcprocesses`

### [1.5.0] - 2026-04-10

- Advanced the development image version to `1.5.0`.
- Bumped `cwl2puml` from `0.40.0` to `0.41.0`.

### Fixed

- Bumped `cwl2ogc` from `0.15.0` to `0.16.0` to address empty schema generation for `AliasType`.

## [1.4.0] - 2026-04-09

### Added

- Added Helm 3 installation to the container image.
- Added `helm-unittest` `1.0.3` to support Helm chart unit testing.

### Changed

- Bumped the image version to `1.4.0`.

## [1.3.0] - 2026-04-08

### Changed

- Bumped the image version to `1.3.0`.
- Bumped `transpiler-mate` from `0.42.0` to `0.43.0`.
- Bumped `cwl2puml` from `0.39.0` to `0.40.0`.

## [1.2.0] - 2026-04-08

### Changed

- Bumped the image version to `1.2.0`.
- Bumped `cwl2ogc` from `0.14.0` to `0.15.0`.
- Bumped `cwl2puml` from `0.38.0` to `0.39.0`.

## [1.1.0] - 2026-04-07

### Added

- Added Dependabot configuration for daily Docker and Python dependency updates.
- Added `requirements.txt` to pin Python tooling used by the image.
- Added `task` `v3.49.1` to the container image.
- Added `ruff`, `pre-commit`, and `git` to the container image.

### Changed

- Moved Python package installation from Dockerfile version arguments to `requirements.txt`.
- Switched `jq` and `trivy` installation to package-managed installs.
- Pinned `cwltool` to `3.1.20260315121657`.
- Bumped `transpiler-mate` from `0.31.0` to `0.42.0`.
- Bumped `cwl2ogc` from `0.13.0` to `0.14.0`.
- Bumped `cwl2puml` from `0.32.0` to `0.38.0`.
- Bumped the image version to `1.1.0`.

## [1.0.1] - 2026-03-10

### Changed

- Bumped `transpiler-mate` from `0.28.0` to `0.31.0`.
- Bumped the image version to `1.0.1`.

## [1.0.0] - 2026-03-09

### Added

- Added the initial Rocky Linux `10.1` minimal based CI container image.
- Added CWL and metadata tooling: `cwltool`, `cwl2ogc`, `transpiler-mate`, and `cwl2puml`.
- Added OCI and container tooling: `skopeo`, `trivy`, and `oras`.
- Added supporting tools: `jq`, `yq`, `hatch`, `nodejs`, and `python3`.
- Added a GitHub Actions workflow to build the image with Kaniko, run Trivy scans, generate an SPDX SBOM, and push the image with Skopeo.
- Added `release.yaml` image metadata for `ghcr.io/terradue/ci-eoap-container:1.0.0`.
- Added README documentation with build and CI usage examples.

[Unreleased]: https://github.com/Terradue/ci-eoap-container/compare/v1.6.0...HEAD
[1.6.0]: https://github.com/Terradue/ci-eoap-container/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/Terradue/ci-eoap-container/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/Terradue/ci-eoap-container/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/Terradue/ci-eoap-container/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/Terradue/ci-eoap-container/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/Terradue/ci-eoap-container/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/Terradue/ci-eoap-container/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/Terradue/ci-eoap-container/releases/tag/v1.0.0
