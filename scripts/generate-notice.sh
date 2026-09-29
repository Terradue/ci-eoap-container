#!/usr/bin/env bash
# Run locally; stream the collector into a disposable container.
set -euo pipefail
if [[ ${1:-} == --help || ${1:-} == -h ]]; then
    cat <<'HELP'
Usage: bash scripts/generate-notice.sh IMAGE [OUTPUT|-]

Generate notices for an existing Docker image. OUTPUT defaults to NOTICE in
this repository. Use - for stdout. Requires Docker locally, RPM and Python 3
in the image. No scripts or generated files are added to the image.
HELP
    exit 0
fi
if (( $# < 1 || $# > 2 )) || [[ -z $1 || $1 == -* ]]; then
    echo 'Usage: bash scripts/generate-notice.sh IMAGE [OUTPUT|-]' >&2
    exit 2
fi
command -v docker >/dev/null || { echo 'Docker is required' >&2; exit 1; }
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
output=${2:-"$script_dir/../NOTICE"}
# Resolve locally once, avoiding tag changes and implicit pulls during collection.
image_id=$(docker image inspect --format '{{.Id}}' "$1")
collect() {
    docker run --rm --interactive --network none --read-only \
        --entrypoint python3 "$image_id" - <<'PY'
import importlib.metadata as metadata
import os
from pathlib import Path
import re
import subprocess
import sys

lines = ['THIRD-PARTY SOFTWARE NOTICES', '',
         'Collected from installed package metadata and files.',
         'License labels do not replace license text. Missing notices and embedded',
         'dependencies require review against the corresponding upstream releases.', '']
gaps = []
pattern = re.compile(r'^(licen[cs]e|copying|copyright|notice|authors|third[-_]?party)([._-].*|$)', re.I)
def query(*args):
    return subprocess.check_output(['rpm', *args], text=True).splitlines()
def section(title, fields=()):
    lines.extend(['=' * 78, title, '=' * 78, *fields, ''])
def collect(paths, owner):
    count = 0
    for path in sorted(set(map(Path, paths)), key=str):
        try:
            text = path.read_text(encoding='utf-8')
            if not text.strip():
                raise ValueError('empty file')
        except (OSError, UnicodeError, ValueError) as exc:
            gaps.append(f'{owner}: cannot collect {path}: {exc}')
            continue
        lines.extend([f'--- {path} ---', text, ''])
        count += 1
    if not count:
        gaps.append(f'{owner}: no readable installed license/notice text found')

packages = sorted(query('-qa', '--qf', '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n'))
if not packages:
    raise SystemExit('No RPM packages found; refusing an empty inventory')
for package in packages:
    section(f'RPM: {package}', query('-q', '--qf', 'Name: %{NAME}\nVersion: %{VERSION}-%{RELEASE}\nLicense: %{LICENSE}\nURL: %{URL}\n', package))
    entries = query('-q', '--qf', '[%{FILENAMES}\t%{FILEFLAGS}\n]', package)
    paths = []
    for entry in entries:
        path, flags = entry.rsplit('\t', 1)
        if int(flags) & 128 or pattern.match(Path(path).name) or path.startswith('/usr/share/licenses/'):
            if not Path(path).is_dir():
                paths.append(path)
    collect(paths, f'RPM {package}')

for dist in sorted(metadata.distributions(), key=lambda d: (d.metadata.get('Name', '').lower(), d.version, str(d.locate_file('')))):
    owner = f"Python: {dist.metadata.get('Name', '(unnamed)')} {dist.version}"
    fields = []
    for key in ('License-Expression', 'License', 'Author', 'Author-email', 'Home-page', 'Project-URL'):
        fields.extend(f'{key}: {value}' for value in dist.metadata.get_all(key, []))
    section(owner, fields)
    collect([dist.locate_file(p) for p in (dist.files or [])
             if pattern.match(Path(p).name) or 'licenses' in [x.lower() for x in Path(p).parts]], owner)

for name, project in (
    ('yq', 'mikefarah/yq'), ('oras', 'oras-project/oras'),
    ('task', 'go-task/task'), ('helm', 'helm/helm'),
    ('helm-unittest', 'helm-unittest/helm-unittest'),
):
    binary = Path('/usr/local/bin') / name
    if binary.exists():
        section(f'Standalone tool: {name}', [f'Binary: {binary}', f'Project: https://github.com/{project}'])
        root = Path('/usr/local/share/licenses') / name
        collect([p for p in root.rglob('*') if p.is_file()], name)
        gaps.append(f'{name}: verify exact release and embedded dependency attributions upstream')

root = Path(os.environ.get('HELM_PLUGINS', str(Path.home() / '.local/share/helm/plugins')))
if root.is_dir():
    for plugin in sorted(root.iterdir()):
        if plugin.is_dir():
            section(f'Helm plugin: {plugin.name}', [f'Installed path: {plugin}'])
            collect([p for p in plugin.rglob('*') if p.is_file() and pattern.match(p.name)], plugin.name)
            gaps.append(f'Helm plugin {plugin.name}: verify embedded dependency attributions upstream')

section('COVERAGE AND ITEMS REQUIRING REVIEW')
lines.extend(sorted(set(gaps)))
lines.extend(['', 'Other unmanaged software, global npm packages and vendored dependencies',
              'may not be represented by these inventories.', ''])
text = '\n'.join(lines)
sys.stdout.write(text)
print(f'Collected {len(packages)} RPM packages; {len(set(gaps))} items require attribution review.', file=sys.stderr)
PY
}
if [[ $output == - ]]; then
    collect
else
    temporary=$(mktemp "${output}.tmp.XXXXXX")
    trap 'rm -f -- "$temporary"' EXIT
    collect > "$temporary"
    chmod 0644 "$temporary"
    mv -f -- "$temporary" "$output"
    echo "Wrote $output" >&2
fi
