import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('image_sbom', Path(__file__).resolve().parents[1] / 'scripts/image_sbom.py')
sbom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sbom)
ENV = dict(GITHUB_SHA='a' * 40, GITHUB_REF='refs/heads/main', GITHUB_RUN_ID='1')
D = 'sha256:' + 'a' * 64
A = 'sha256:' + 'b' * 64
BOM = {'bomFormat': 'CycloneDX', 'specVersion': '1.5', 'components': []}


class SnapshotTests(unittest.TestCase):
    def test_nested_opaque_refs_versions_and_deduplication(self):
        bom = dict(BOM, components=[{'bom-ref': 'opaque', 'purl': 'pkg:pypi/My_Package', 'version': '1.2',
              'components': [{'bom-ref': 'other', 'purl': 'pkg:pypi/my-package@1.2'},
                             {'purl': 'pkg:npm/%40org/name@2.0?x=y'}]},
              {'purl': 'pkg:rpm/fedora/bash@1'}, {'purl': 'pkg:deb/debian/bash@1'},
              {'purl': 'pkg:generic/tool@1'}, {'purl': 'pkg:pypi/no-version'},
              {'bom-ref': 'pkg:pypi/not-a-purl@1'}, {'purl': 'not-a-purl'}])
        result = sbom.snapshot(bom, ENV)
        packages = result['manifests']['image-sbom']['resolved']
        self.assertEqual(set(packages), {'pkg:pypi/my-package@1.2', 'pkg:npm/%40org/name@2.0'})
        self.assertEqual(result['job']['correlator'], 'container-sbom')
        self.assertEqual(result['detector']['name'], 'container-cyclonedx')

    def test_versions_preserved(self):
        bom = dict(BOM, components=[{'purl': 'pkg:pypi/a@1'}, {'purl': 'pkg:pypi/a@2'},
                                   {'purl': 'pkg:golang/example.org/a', 'version': 'v1+meta'}])
        self.assertEqual(len(sbom.snapshot(bom, ENV)['manifests']['image-sbom']['resolved']), 3)

    def test_invalid_bom(self):
        with self.assertRaises(ValueError):
            sbom.snapshot({}, ENV)


class RetrievalTests(unittest.TestCase):
    def retrieve(self, refs=None, manifest=None, data=None):
        data = json.dumps(BOM).encode() if data is None else data
        blob = 'sha256:' + hashlib.sha256(data).hexdigest()
        refs = {'referrers': [{'digest': A, 'artifactType': sbom.TYPE}]} if refs is None else refs
        manifest = manifest or {'subject': {'digest': D}, 'artifactType': sbom.TYPE,
                               'layers': [{'digest': blob, 'size': len(data), 'mediaType': sbom.TYPE}]}
        commands = []

        def run(args, **kwargs):
            commands.append(args)
            if args[1] == 'resolve':
                return D + '\n'
            if args[1] == 'discover':
                return json.dumps(refs)
            if args[1:3] == ['manifest', 'fetch']:
                return json.dumps(manifest)
            return data

        with tempfile.TemporaryDirectory() as tmp, patch.object(subprocess, 'check_output', side_effect=run):
            sbom.retrieve('ghcr.io/org/image:latest', Path(tmp) / 'bom.json')
        return commands

    def test_resolves_once_and_uses_attachment_digest(self):
        calls = self.retrieve()
        self.assertEqual(sum(c[1] == 'resolve' for c in calls), 1)
        self.assertIn('ghcr.io/org/image@' + D, calls[1])
        self.assertIn('ghcr.io/org/image@' + A, calls[2])
        self.assertFalse(any(':latest' in arg for c in calls[1:] for arg in c))

    def test_missing_ambiguous_or_invalid_descriptor(self):
        for refs in [[], [{'digest': 'bad', 'artifactType': sbom.TYPE}],
                     [{'digest': A, 'artifactType': sbom.TYPE}] * 2]:
            with self.subTest(refs=refs), self.assertRaises(ValueError):
                self.retrieve(refs={'referrers': refs})

    def test_wrong_subject_type_or_layers(self):
        for manifest in [{'subject': {'digest': A}, 'artifactType': sbom.TYPE},
                         {'subject': {'digest': D}, 'artifactType': 'wrong'},
                         {'subject': {'digest': D}, 'artifactType': sbom.TYPE, 'layers': []}]:
            with self.subTest(manifest=manifest), self.assertRaises(ValueError):
                self.retrieve(manifest=manifest)

    def test_corrupt_blob(self):
        data = json.dumps(BOM).encode()
        manifest = {'subject': {'digest': D}, 'artifactType': sbom.TYPE,
                    'layers': [{'digest': A, 'size': len(data), 'mediaType': sbom.TYPE}]}
        with self.assertRaisesRegex(ValueError, 'integrity'):
            self.retrieve(manifest=manifest)

    def test_invalid_cyclonedx(self):
        with self.assertRaises(ValueError):
            self.retrieve(data=b'{}')


@unittest.skipUnless(shutil.which('oras'), 'ORAS required for OCI layout integration')
class LayoutTests(unittest.TestCase):
    def test_real_layout_retrieval_and_missing_attachment(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            layout = str(root / 'layout')
            (root / 'image.txt').write_text('fixture image')
            (root / 'sbom.json').write_text(json.dumps(BOM))

            def oras(*args):
                return subprocess.check_output(['oras', *args], cwd=tmp, text=True)

            oras('push', '--oci-layout', layout + ':latest', 'image.txt:text/plain')
            with self.assertRaises(ValueError):
                sbom.retrieve(layout + ':latest', root / 'out.json', True)
            oras('attach', '--oci-layout', '--artifact-type', sbom.TYPE,
                 layout + ':latest', 'sbom.json:' + sbom.TYPE)
            subject = sbom.retrieve(layout + ':latest', root / 'out.json', True)
            self.assertIn('@sha256:', subject)
            self.assertEqual(json.loads((root / 'out.json').read_text()), BOM)
            # A moved tag cannot change retrieval of the previously resolved subject.
            oras('push', '--oci-layout', layout + ':latest', '--artifact-type', 'new/image')
            sbom.retrieve(subject, root / 'out.json', True)

    def test_real_layout_invalid_attachment(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            layout = str(root / 'layout')
            (root / 'bad.json').write_text('{}')
            subprocess.run(['oras', 'push', '--oci-layout', layout + ':latest'],
                           check=True, capture_output=True)
            subprocess.run(['oras', 'attach', '--oci-layout', '--artifact-type', sbom.TYPE,
                            layout + ':latest', 'bad.json:' + sbom.TYPE],
                           cwd=tmp, check=True, capture_output=True)
            with self.assertRaisesRegex(ValueError, 'CycloneDX'):
                sbom.retrieve(layout + ':latest', root / 'out.json', True)
            self.assertFalse((root / 'out.json').exists())
