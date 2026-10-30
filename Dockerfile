FROM rockylinux/rockylinux:10.2-minimal

# Set up a default user and home directory
ENV HOME=/home/neo

# renovate: datasource=github-releases depName=mikefarah/yq
ARG YQ_VERSION=v4.54.1
# renovate: datasource=github-releases depName=oras-project/oras
ARG ORAS_VERSION=1.3.6
# renovate: datasource=github-releases depName=go-task/task
ARG TASK_VERSION=v3.54.0
# renovate: datasource=github-releases depName=aquasecurity/trivy
ARG TRIVY_VERSION=0.76.1
# renovate: datasource=github-releases depName=nodejs/node
ARG NODE_VERSION=v24.22.1
# renovate: datasource=npm depName=npm
ARG NPM_VERSION=12.2.1
# renovate: datasource=npm depName=undici
ARG UNDICI_VERSION=6.29.1
# renovate: datasource=npm depName=ip-address
ARG IP_ADDRESS_VERSION=10.7.4
# renovate: datasource=github-releases depName=helm-unittest/helm-unittest
ARG HELM_UNITTEST_VERSION=v1.2.1
# renovate: datasource=github-releases depName=chartmuseum/helm-push
ARG HELM_PUSH_VERSION=v0.11.1
# renovate: datasource=github-releases depName=helm/helm
ARG HELM_VERSION=v3.22.0

COPY requirements.txt /tmp/requirements.txt

# Create a user with UID 1001, group root, and a home directory
RUN /usr/sbin/groupadd -g 2000 neo && \
    /usr/sbin/useradd -u 2000 -r -g 2000 -m -d ${HOME} -s /sbin/nologin \
      -c "Default Neo User" neo

# Build bagit 1.9.0's verified source archive into a wheel first. Pip's PEP 517
# metadata subprocess fails under Kaniko, so install the resulting local wheel.
RUN microdnf -y update && \
    microdnf -y install ca-certificates curl tar gzip python3 python3-pip python3-setuptools libstdc++ libatomic openssl gcc skopeo jq git clang wget && \
    printf '%s\n' \
      '[trivy]' \
      'name=Trivy repository' \
      'baseurl=https://aquasecurity.github.io/trivy-repo/rpm/releases/$basearch/' \
      'gpgcheck=1' \
      'enabled=1' \
      'gpgkey=https://aquasecurity.github.io/trivy-repo/rpm/public.key' \
      > /etc/yum.repos.d/trivy.repo && \
    microdnf -y install "trivy-${TRIVY_VERSION}" && \
    # Bootstrap fixed pip before contacting the package index. The advisory's
    # wheel hash prevents an old pip CA bundle from trusting substituted content.
    # Keep this URL/hash in sync with the pip pin in requirements.txt.
    python3 -m pip --disable-pip-version-check install --prefix=/usr/local --no-cache-dir --no-deps --ignore-installed \
      "pip @ https://files.pythonhosted.org/packages/3f/06/3e4420302363fbb71be3c7f35ce042f54bfca330e3e66b3a2e3c4cca579f/pip-26.2.2-py3-none-any.whl#sha256=fd7f4dfa8190e014013b9f08f3e973f4e4c26ffd179a204895533a7254813a70" && \
    python3 -m pip install --prefix=/usr/local --no-cache-dir --ignore-installed \
      setuptools==84.2.1 setuptools-scm==10.3.4 wheel==0.46.2 && \
    mkdir -p /tmp/bagit-wheelhouse && \
    curl -fL https://files.pythonhosted.org/packages/a1/a0/8866b4c6f894af0eb10e4964157f3241dd4117700fc010e7825471d51a13/bagit-1.9.0.tar.gz \
      -o /tmp/bagit-1.9.0.tar.gz && \
    echo '9455006c2d1df88be95ec1fccabc5ea623389589ea4c85b3d85bd256f29d7656  /tmp/bagit-1.9.0.tar.gz' | sha256sum --check - && \
    tar -xzf /tmp/bagit-1.9.0.tar.gz -C /tmp && \
    cd /tmp/bagit-1.9.0 && \
    SETUPTOOLS_SCM_PRETEND_VERSION=1.9.0 python3 setup.py bdist_wheel --dist-dir /tmp/bagit-wheelhouse && \
    cd / && \
    python3 -m pip install --prefix=/usr/local --no-cache-dir --ignore-installed \
      --find-links=/tmp/bagit-wheelhouse --only-binary=bagit \
      -r /tmp/requirements.txt && \
    rm -rf /tmp/bagit-wheelhouse /tmp/bagit-1.9.0 /tmp/bagit-1.9.0.tar.gz && \
    microdnf clean all && \
    cp -a /usr/local/lib64/python3.12/site-packages/msgpack/. \
      /usr/local/lib/python3.12/site-packages/pip/_vendor/msgpack/ && \
    rm -rf /usr/local/lib/python3.12/site-packages/pip/_vendor/urllib3 && \
    cp -a /usr/local/lib/python3.12/site-packages/urllib3 \
      /usr/local/lib/python3.12/site-packages/pip/_vendor/urllib3 && \
    python3 - <<'PY'
import json
from pathlib import Path

sbom = Path("/usr/local/lib/python3.12/site-packages/pip/_vendor/bom.cdx.json")
document = json.loads(sbom.read_text())
refs = {}
for component in document.get("components", []):
    name = component.get("name")
    if name in {"msgpack", "urllib3"}:
        old_ref = component.get("bom-ref")
        version = {"msgpack": "1.2.3", "urllib3": "2.8.0"}[name]
        new_ref = f"pkg:pypi/{name}@{version}"
        component.update({"version": version, "purl": new_ref, "bom-ref": new_ref})
        if old_ref:
            refs[old_ref] = new_ref
    elif name == "setuptools":
        # pip vendors pkg_resources, not the vulnerable setuptools PackageIndex.
        component["name"] = "pip-vendored-pkg_resources"
        component["bom-ref"] = "pkg:generic/pip-vendored/pkg_resources@70.3.0"
        component.pop("purl", None)
        refs["pkg:pypi/setuptools@70.3.0"] = component["bom-ref"]

def update_refs(value):
    if isinstance(value, dict):
        for key, item in value.items():
            if isinstance(item, str) and item in refs:
                value[key] = refs[item]
            else:
                update_refs(item)
    elif isinstance(value, list):
        for item in value:
            update_refs(item)

update_refs(document)
sbom.write_text(json.dumps(document, separators=(",", ":")) + "\n")

import pip._vendor.msgpack as vendored_msgpack
import pip._vendor.urllib3 as vendored_urllib3
assert vendored_msgpack.__version__ == "1.2.3"
assert vendored_urllib3.__version__ == "2.8.0"
PY

# Make tools installed under /usr/local available during the remaining build steps.
ENV PATH="/usr/bin:/usr/local/bin:/bin:${PATH}"

# Install the selected upstream Node.js release (including its bundled npm).
# This image's downloaded tools target Linux amd64.
RUN cd /tmp && \
    curl -fLO "https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-x64.tar.gz" && \
    curl -fLo node-SHASUMS256.txt "https://nodejs.org/dist/${NODE_VERSION}/SHASUMS256.txt" && \
    grep "  node-${NODE_VERSION}-linux-x64.tar.gz$" node-SHASUMS256.txt | sha256sum --check - && \
    tar -xzf "node-${NODE_VERSION}-linux-x64.tar.gz" -C /usr/local --strip-components=1 && \
    rm "node-${NODE_VERSION}-linux-x64.tar.gz" node-SHASUMS256.txt && \
    test "$(node --version)" = "${NODE_VERSION}" && \
    npm install --global "npm@${NPM_VERSION}" && \
    mkdir /tmp/npm-undici && \
    npm pack "undici@${UNDICI_VERSION}" --pack-destination /tmp/npm-undici >/dev/null && \
    tar -xzf "/tmp/npm-undici/undici-${UNDICI_VERSION}.tgz" -C /tmp/npm-undici && \
    rm -rf /usr/local/lib/node_modules/npm/node_modules/undici && \
    mv /tmp/npm-undici/package /usr/local/lib/node_modules/npm/node_modules/undici && \
    rm -rf /tmp/npm-undici && \
    mkdir /tmp/npm-ip-address && \
    npm pack "ip-address@${IP_ADDRESS_VERSION}" --pack-destination /tmp/npm-ip-address >/dev/null && \
    tar -xzf "/tmp/npm-ip-address/ip-address-${IP_ADDRESS_VERSION}.tgz" -C /tmp/npm-ip-address && \
    rm -rf /usr/local/lib/node_modules/npm/node_modules/ip-address && \
    mv /tmp/npm-ip-address/package /usr/local/lib/node_modules/npm/node_modules/ip-address && \
    rm -rf /tmp/npm-ip-address && npm cache clean --force && npm --version && \
    test "$(node -p 'require("/usr/local/lib/node_modules/npm/node_modules/ip-address/package.json").version')" = "${IP_ADDRESS_VERSION}"

RUN cd /tmp && \
    curl -fLO https://go.dev/dl/go1.27.3.linux-amd64.tar.gz && \
    echo '65efbc80fdc1fa2cd2631cad5b481777a68e8725f34e89f50fc6ac714e379b40  go1.27.3.linux-amd64.tar.gz' | sha256sum --check - && \
    tar -xzf go1.27.3.linux-amd64.tar.gz -C /usr/local && \
    curl -fL "https://github.com/helm/helm/archive/refs/tags/${HELM_VERSION}.tar.gz" -o /tmp/helm.tar.gz && \
    mkdir /tmp/helm-src && tar -xzf /tmp/helm.tar.gz --strip-components=1 -C /tmp/helm-src && \
    cd /tmp/helm-src && \
    /usr/local/go/bin/go mod edit -require=golang.org/x/net@v0.62.0 && \
    CGO_ENABLED=0 GOTOOLCHAIN=local /usr/local/go/bin/go build -mod=mod -trimpath -buildvcs=false \
      -ldflags "-X helm.sh/helm/v3/internal/version.version=${HELM_VERSION}" \
      -o /usr/local/bin/helm ./cmd/helm && \
    helm version --short && \
    helm plugin install https://github.com/chartmuseum/helm-push --version "${HELM_PUSH_VERSION}" && \
    curl -fL "https://github.com/chartmuseum/helm-push/archive/refs/tags/${HELM_PUSH_VERSION}.tar.gz" -o /tmp/helm-push.tar.gz && \
    mkdir /tmp/helm-push && tar -xzf /tmp/helm-push.tar.gz --strip-components=1 -C /tmp/helm-push && \
    cd /tmp/helm-push && \
    /usr/local/go/bin/go mod edit \
      -require=github.com/klauspost/compress@v1.18.7 \
      -require=golang.org/x/crypto@v0.55.0 \
      -require=golang.org/x/net@v0.62.0 \
      -require=golang.org/x/text@v0.41.0 \
      -require=google.golang.org/grpc@v1.83.2 \
      -require=helm.sh/helm/v3@v3.20.2 \
      -require=helm.sh/helm/v4@v4.1.4 \
      -require=github.com/containerd/containerd@v1.7.36 \
      -require=oras.land/oras-go/v2@v2.6.2 && \
    CGO_ENABLED=0 GOTOOLCHAIN=local /usr/local/go/bin/go build -mod=mod -trimpath -buildvcs=false -o "${HOME}/.local/share/helm/plugins/helm-push/bin/helm-cm-push" ./cmd/helm-cm-push && \
    helm cm-push --help && \
    curl -fL "https://github.com/helm-unittest/helm-unittest/archive/refs/tags/${HELM_UNITTEST_VERSION}.tar.gz" -o /tmp/helm-unittest.tar.gz && \
    mkdir /tmp/helm-unittest && tar -xzf /tmp/helm-unittest.tar.gz --strip-components=1 -C /tmp/helm-unittest && \
    cd /tmp/helm-unittest && \
    /usr/local/go/bin/go mod edit \
      -require=golang.org/x/crypto@v0.55.0 \
      -require=golang.org/x/net@v0.62.0 \
      -require=golang.org/x/text@v0.41.0 && \
    CGO_ENABLED=0 GOTOOLCHAIN=local /usr/local/go/bin/go build -mod=mod -trimpath -buildvcs=false -o /usr/local/bin/helm-unittest ./cmd/helm-unittest && \
    /usr/local/bin/helm-unittest --help >/dev/null && \
    curl -fL "https://github.com/mikefarah/yq/archive/refs/tags/${YQ_VERSION}.tar.gz" -o /tmp/yq.tar.gz && \
    mkdir /tmp/yq && tar -xzf /tmp/yq.tar.gz --strip-components=1 -C /tmp/yq && \
    cd /tmp/yq && \
    /usr/local/go/bin/go mod edit -require=golang.org/x/net@v0.62.0 && \
    CGO_ENABLED=0 GOTOOLCHAIN=local /usr/local/go/bin/go build -mod=mod -trimpath -buildvcs=false -o /usr/local/bin/yq . && \
    curl -fL "https://github.com/go-task/task/archive/refs/tags/${TASK_VERSION}.tar.gz" -o /tmp/task-src.tar.gz && \
    mkdir /tmp/task-src && tar -xzf /tmp/task-src.tar.gz --strip-components=1 -C /tmp/task-src && \
    cd /tmp/task-src && \
    /usr/local/go/bin/go mod edit \
      -require=github.com/go-jose/go-jose/v4@v4.1.6 \
      -require=golang.org/x/net@v0.62.0 && \
    CGO_ENABLED=0 GOTOOLCHAIN=local /usr/local/go/bin/go build -mod=mod -trimpath -buildvcs=false -o /usr/local/bin/task ./cmd/task && \
    curl -fL "https://github.com/oras-project/oras/archive/refs/tags/v${ORAS_VERSION}.tar.gz" -o /tmp/oras-src.tar.gz && \
    mkdir /tmp/oras-src && tar -xzf /tmp/oras-src.tar.gz --strip-components=1 -C /tmp/oras-src && \
    cd /tmp/oras-src && \
    CGO_ENABLED=0 GOTOOLCHAIN=local /usr/local/go/bin/go build -mod=mod -trimpath -buildvcs=false -o /usr/local/bin/oras ./cmd/oras && \
    curl -fL "https://github.com/aquasecurity/trivy/archive/refs/tags/v${TRIVY_VERSION}.tar.gz" -o /tmp/trivy.tar.gz && \
    mkdir /tmp/trivy-src && tar -xzf /tmp/trivy.tar.gz --strip-components=1 -C /tmp/trivy-src && \
    cd /tmp/trivy-src && \
    /usr/local/go/bin/go mod edit \
      -require=github.com/go-jose/go-jose/v4@v4.1.6 \
      -require=golang.org/x/net@v0.62.0 && \
    CGO_ENABLED=0 GOTOOLCHAIN=local /usr/local/go/bin/go build -mod=mod -trimpath -buildvcs=false \
      -ldflags "-X github.com/aquasecurity/trivy/pkg/version/app.ver=${TRIVY_VERSION#v}" \
      -o /usr/bin/trivy ./cmd/trivy && \
    trivy --version && \
    rm -rf /usr/local/go /root/go /root/.cache "${HOME}/go" "${HOME}/.cache" /tmp/go1.27.3.linux-amd64.tar.gz \
      /tmp/helm-push /tmp/helm-push.tar.gz /tmp/helm-unittest /tmp/helm-unittest.tar.gz \
      /tmp/helm-src /tmp/helm.tar.gz /tmp/yq /tmp/yq.tar.gz \
      /tmp/task-src /tmp/task-src.tar.gz /tmp/oras-src /tmp/oras-src.tar.gz \
      /tmp/trivy-src /tmp/trivy.tar.gz
