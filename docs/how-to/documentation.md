# Maintain the documentation

Run the following from the repository root with Python 3.10 or newer available.
Documentation dependencies are separate from the container's Python toolchain.

## Preview locally

```bash
python3 -m venv .venv-docs
. .venv-docs/bin/activate
python -m pip install -r requirements-docs.txt
mkdocs serve
```

Open `http://127.0.0.1:8000` to browse the documentation. Changes under `docs/`
are reloaded during development.

## Add or edit a page

Choose a location based on what the reader needs:

| Directory | Purpose |
| --- | --- |
| `docs/tutorials/` | Guided learning with a concrete example and expected results |
| `docs/how-to/` | Steps to accomplish a specific task, with prerequisites |
| `docs/reference/` | Factual descriptions of tools, configuration, and outputs |
| `docs/explanation/` | Context, design decisions, and conceptual relationships |

Add the page to `nav` in `mkdocs.yml`. Use relative Markdown links between pages.
Keep versions and pipeline behavior aligned with `Dockerfile`, `requirements.txt`,
and `.github/workflows/build-image.yaml`.

Configuration options are described in the
[MkDocs configuration reference](https://www.mkdocs.org/user-guide/configuration/).

## Build and check

```bash
mkdocs build --strict
```

The generated site is written to `site/`, which is ignored by Git. The
documentation workflow runs this same check on pull requests and pushes to
`develop` and `main`. Strict mode rejects warnings, including broken local links
and pages missing from navigation. Publishing the generated site is a separate
hosting step.
