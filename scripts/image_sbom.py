"""Retrieve digest-bound CycloneDX referrers and convert application inventory."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
from urllib.parse import quote, unquote

TYPE = 'application/vnd.cyclonedx+json'
DIGEST = re.compile(r'sha256:[0-9a-f]{64}')
SUPPORTED = {'pypi', 'npm', 'maven', 'nuget', 'gem', 'cargo', 'golang', 'composer', 'pub', 'hex', 'swift'}


def validate(bom):
    if (not isinstance(bom, dict) or bom.get('bomFormat') != 'CycloneDX'
            or not re.fullmatch(r'1\.\d+', str(bom.get('specVersion', '')))
            or not isinstance(bom.get('components'), list)):
        raise ValueError('Invalid CycloneDX inventory')
    return bom


def retrieve(reference, output, layout=False):
    flags = ['--oci-layout'] if layout else []

    def oras(*args):
        return subprocess.check_output(['oras', *args, *flags], text=True)

    digest = oras('resolve', reference).strip()
    if not DIGEST.fullmatch(digest):
        raise ValueError('Invalid image digest')
    repository = reference.split('@')[0]
    if ':' in repository.rsplit('/', 1)[-1]:
        repository = repository.rsplit(':', 1)[0]
    subject = f'{repository}@{digest}'
    refs = json.loads(oras('discover', '--format', 'json', '--artifact-type', TYPE, subject))
    attachments = refs.get('referrers', [])
    if len(attachments) != 1:
        raise ValueError('Expected exactly one CycloneDX attachment')
    attachment = attachments[0]
    attachment_digest = attachment['digest']
    if attachment.get('artifactType') != TYPE or not DIGEST.fullmatch(attachment_digest):
        raise ValueError('Invalid attachment descriptor')
    target = f'{repository}@{attachment_digest}'
    manifest = json.loads(oras('manifest', 'fetch', target))
    if manifest.get('subject', {}).get('digest') != digest or manifest.get('artifactType') != TYPE:
        raise ValueError('Attachment subject or type mismatch')
    layers = manifest.get('layers', [])
    if len(layers) != 1 or layers[0].get('mediaType') != TYPE:
        raise ValueError('Expected one CycloneDX layer')
    layer = layers[0]
    if not DIGEST.fullmatch(layer['digest']):
        raise ValueError('Invalid SBOM blob digest')
    # Fetch the layer from the verified attachment manifest, avoiding archive paths.
    data = subprocess.check_output(['oras', 'blob', 'fetch', '--output', '-',
                                    f"{repository}@{layer['digest']}", *flags])
    if 'sha256:' + hashlib.sha256(data).hexdigest() != layer['digest'] or len(data) != layer['size']:
        raise ValueError('SBOM blob integrity mismatch')
    validate(json.loads(data))
    Path(output).write_bytes(data)
    return subject


def package_url(component):
    purl = component.get('purl', '')
    match = re.fullmatch(r'pkg:([a-z]+)/(\S+)', purl)
    if not match or match[1] not in SUPPORTED:
        return None
    body = match[2].split('#', 1)[0].split('?', 1)[0]
    name, sep, version = body.rpartition('@')
    if not sep:
        name, version = body, ''
    version = unquote(version) or str(component.get('version') or '')
    if not name or not version or any(not part for part in name.split('/')):
        return None
    if match[1] == 'pypi':
        name = re.sub(r'[-_.]+', '-', unquote(name)).lower()
    return f'pkg:{match[1]}/{name}@{quote(version, safe=".+-_")}'


def snapshot(bom, env=os.environ):
    validate(bom)
    resolved = {}

    def walk(components):
        for component in components:
            purl = package_url(component)
            if purl:
                resolved[purl] = {'package_url': purl, 'scope': 'runtime'}
            walk(component.get('components', []))

    walk(bom['components'])
    return {'version': 0, 'sha': env['GITHUB_SHA'], 'ref': env['GITHUB_REF'],
            'job': {'id': env['GITHUB_RUN_ID'], 'correlator': 'container-sbom'},
            'detector': {'name': 'container-cyclonedx', 'version': '1.0.0',
                         'url': 'https://github.com/Terradue/ci-eoap-container'},
            'scanned': datetime.datetime.now(datetime.timezone.utc).isoformat(),
            'manifests': {'image-sbom': {'name': 'image-sbom', 'resolved': dict(sorted(resolved.items()))}}}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['retrieve', 'snapshot'])
    parser.add_argument('source')
    parser.add_argument('output')
    parser.add_argument('--oci-layout', action='store_true')
    args = parser.parse_args()
    if args.command == 'retrieve':
        print(retrieve(args.source, args.output, args.oci_layout))
    else:
        Path(args.output).write_text(json.dumps(snapshot(json.loads(Path(args.source).read_text())), indent=2))
