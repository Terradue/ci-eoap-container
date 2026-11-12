#!/usr/bin/env bash
set -euo pipefail

# Bootstrap pip from its verified wheel before contacting the package index.
# Keep this URL and hash aligned with pip== in requirements.txt.
python3 -m pip --disable-pip-version-check install \
  --prefix=/usr/local --no-cache-dir --no-deps --ignore-installed \
  "pip @ https://files.pythonhosted.org/packages/3f/06/3e4420302363fbb71be3c7f35ce042f54bfca330e3e66b3a2e3c4cca579f/pip-26.2.2-py3-none-any.whl#sha256=fd7f4dfa8190e014013b9f08f3e973f4e4c26ffd179a204895533a7254813a70"

python3 -m pip install --prefix=/usr/local --no-cache-dir --ignore-installed \
  setuptools==84.2.1 setuptools-scm==10.3.4 wheel==0.46.2

# bagit 1.9.0's PEP 517 metadata subprocess fails under Kaniko. Build its wheel
# directly from the verified source archive, then let pip install that wheel.
wheelhouse=/tmp/bagit-wheelhouse
source_dir=/tmp/bagit-1.9.0
archive=/tmp/bagit-1.9.0.tar.gz
mkdir -p "$wheelhouse"
curl -fL \
  https://files.pythonhosted.org/packages/a1/a0/8866b4c6f894af0eb10e4964157f3241dd4117700fc010e7825471d51a13/bagit-1.9.0.tar.gz \
  -o "$archive"
echo '9455006c2d1df88be95ec1fccabc5ea623389589ea4c85b3d85bd256f29d7656  /tmp/bagit-1.9.0.tar.gz' \
  | sha256sum --check -
tar -xzf "$archive" -C /tmp
cd "$source_dir"
SETUPTOOLS_SCM_PRETEND_VERSION=1.9.0 \
  python3 setup.py bdist_wheel --dist-dir "$wheelhouse"
cd /

python3 -m pip install --prefix=/usr/local --no-cache-dir --ignore-installed \
  --find-links="$wheelhouse" --only-binary=bagit -r /tmp/requirements.txt

cwltool_shebang=$(head -n 1 /usr/local/bin/cwltool)
if [[ "$cwltool_shebang" == '#!' ]]; then
  python_path=$(command -v python3)
  sed -i "1c\\#!${python_path}" /usr/local/bin/cwltool
fi
/usr/local/bin/cwltool --version

rm -rf "$wheelhouse" "$source_dir" "$archive"

# pip is a build-time installer. Its bundled msgpack and urllib3 copies lag the
# patched runtime packages, so keep uv as the supported runtime package manager.
site_packages=$(python3 -c 'import sysconfig; print(sysconfig.get_path("purelib", vars={"base": "/usr/local", "platbase": "/usr/local"}))')
rm -rf "$site_packages/pip" "$site_packages"/pip-*.dist-info
rm -f /usr/local/bin/pip /usr/local/bin/pip3 /usr/local/bin/pip3.*
