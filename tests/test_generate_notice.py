"""Run with: python3 -m unittest discover -s tests -v"""
import contextlib
import io
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SOURCE = (Path(__file__).resolve().parents[1] / "scripts/generate-notice.sh").read_text()
COLLECTOR = SOURCE.split("<<'PY'\n", 1)[1].split("\nPY\n", 1)[0]


class NoticeTests(unittest.TestCase):
    def run_collector(self, rpm):
        output = io.StringIO()
        with patch("subprocess.check_output", side_effect=rpm), \
                patch("importlib.metadata.distributions", return_value=[]), \
                patch.dict("os.environ", {"HELM_PLUGINS": "/nonexistent-notice-test"}), \
                contextlib.redirect_stdout(output), contextlib.redirect_stderr(io.StringIO()):
            exec(compile(COLLECTOR, "notice collector", "exec"), {})
        return output.getvalue()

    def test_signing_keys_are_excluded_but_package_notices_are_collected(self):
        with tempfile.TemporaryDirectory() as directory:
            license_file = Path(directory) / "LICENSE"
            license_file.write_text("Fixture attribution text")
            queried = []

            def rpm(args, **kwargs):
                if args[1] == "-qa":
                    return ("gpg-pubkey\tgpg-pubkey-6fedfc85-682ae1a9.(none)\n"
                            "fixture\tfixture-1-1.x86_64\n")
                queried.append(args[-1])
                if args[-1] != "fixture-1-1.x86_64":
                    raise subprocess.CalledProcessError(1, args)
                if "FILEFLAGS" in args[3]:
                    return f"{license_file}\t128\n"
                return "Name: fixture\nLicense: MIT\n"

            output = self.run_collector(rpm)
            self.assertIn("RPM: fixture-1-1.x86_64", output)
            self.assertIn("Fixture attribution text", output)
            self.assertNotIn("gpg-pubkey", output)
            self.assertEqual(queried, ["fixture-1-1.x86_64"] * 2)

    def test_real_package_query_failure_is_not_suppressed(self):
        def rpm(args, **kwargs):
            if args[1] == "-qa":
                return "broken\tbroken-1-1.noarch\n"
            raise subprocess.CalledProcessError(1, args)

        with self.assertRaises(subprocess.CalledProcessError):
            self.run_collector(rpm)

    def test_signing_keys_alone_do_not_count_as_software(self):
        with self.assertRaisesRegex(SystemExit, "No RPM packages"):
            self.run_collector(lambda *a, **kw: "gpg-pubkey\tgpg-pubkey-6fedfc85-682ae1a9.(none)\n")
