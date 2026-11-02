#!/usr/bin/env bash
set -euo pipefail

cd /tmp
archive="node-${NODE_VERSION}-linux-x64.tar.gz"
curl -fLO "https://nodejs.org/dist/${NODE_VERSION}/${archive}"
curl -fLo node-SHASUMS256.txt "https://nodejs.org/dist/${NODE_VERSION}/SHASUMS256.txt"
grep "  ${archive}$" node-SHASUMS256.txt | sha256sum --check -
tar -xzf "$archive" -C /usr/local --strip-components=1
rm "$archive" node-SHASUMS256.txt
test "$(node --version)" = "$NODE_VERSION"

npm install --global "npm@${NPM_VERSION}"

install_npm_package() {
  local name=$1
  local version=$2
  local destination="/usr/local/lib/node_modules/npm/node_modules/${name}"
  local package_dir="/tmp/npm-${name}"

  mkdir "$package_dir"
  npm pack "${name}@${version}" --pack-destination "$package_dir" >/dev/null
  tar -xzf "${package_dir}/${name}-${version}.tgz" -C "$package_dir"
  rm -rf "$destination"
  mv "${package_dir}/package" "$destination"
  rm -rf "$package_dir"
}

install_npm_package undici "$UNDICI_VERSION"
install_npm_package ip-address "$IP_ADDRESS_VERSION"
npm cache clean --force
npm --version
test "$(node -p 'require("/usr/local/lib/node_modules/npm/node_modules/ip-address/package.json").version')" = "$IP_ADDRESS_VERSION"
