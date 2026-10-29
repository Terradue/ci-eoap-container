FROM rockylinux/rockylinux:10.2-minimal

# Set up a default user and home directory
ENV HOME=/home/neo

# renovate: datasource=github-releases depName=mikefarah/yq
ARG YQ_VERSION=v4.54.1
# renovate: datasource=github-releases depName=oras-project/oras
ARG ORAS_VERSION=1.2.2
# renovate: datasource=github-releases depName=go-task/task
ARG TASK_VERSION=v3.54.0
# renovate: datasource=github-releases depName=aquasecurity/trivy
ARG TRIVY_VERSION=0.76.1
# renovate: datasource=github-releases depName=nodejs/node
ARG NODE_VERSION=v24.22.1

COPY requirements.txt /tmp/requirements.txt

# Create a user with UID 1001, group root, and a home directory
RUN /usr/sbin/groupadd -g 2000 neo && \
    /usr/sbin/useradd -u 2000 -r -g 2000 -m -d ${HOME} -s /sbin/nologin \
      -c "Default Neo User" neo

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
    python3 -m pip --disable-pip-version-check install --no-cache-dir --no-deps --ignore-installed \
      "pip @ https://files.pythonhosted.org/packages/3f/06/3e4420302363fbb71be3c7f35ce042f54bfca330e3e66b3a2e3c4cca579f/pip-26.2.2-py3-none-any.whl#sha256=fd7f4dfa8190e014013b9f08f3e973f4e4c26ffd179a204895533a7254813a70" && \
    python3 -m pip install --no-cache-dir -r /tmp/requirements.txt && \
    curl -fL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" \
      -o /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq && \
    curl -fL https://github.com/oras-project/oras/releases/download/v${ORAS_VERSION}/oras_${ORAS_VERSION}_linux_amd64.tar.gz \
      -o /tmp/oras.tar.gz && \
    tar -xzf /tmp/oras.tar.gz -C /tmp oras && \
    install -m 0755 /tmp/oras /usr/local/bin/oras && \
    rm -rf /tmp/oras /tmp/oras.tar.gz && \
    curl -fL https://github.com/go-task/task/releases/download/${TASK_VERSION}/task_linux_amd64.tar.gz \
      -o /tmp/task.tar.gz && \
    tar -xzf /tmp/task.tar.gz -C /tmp task && \
    install -m 0755 /tmp/task /usr/local/bin/task && \
    rm -rf /tmp/task /tmp/task.tar.gz && \
    microdnf clean all

# Install the selected upstream Node.js release (including its bundled npm).
# This image's downloaded tools target Linux amd64.
RUN cd /tmp && \
    curl -fLO "https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-x64.tar.gz" && \
    curl -fLo node-SHASUMS256.txt "https://nodejs.org/dist/${NODE_VERSION}/SHASUMS256.txt" && \
    grep "  node-${NODE_VERSION}-linux-x64.tar.gz$" node-SHASUMS256.txt | sha256sum --check - && \
    tar -xzf "node-${NODE_VERSION}-linux-x64.tar.gz" -C /usr/local --strip-components=1 && \
    rm "node-${NODE_VERSION}-linux-x64.tar.gz" node-SHASUMS256.txt && \
    test "$(node --version)" = "${NODE_VERSION}" && npm --version

RUN curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

RUN VERSION=1.0.3 && \
    curl -L -o /tmp/helm-unittest.tgz "https://github.com/helm-unittest/helm-unittest/releases/download/v${VERSION}/helm-unittest-linux-amd64-${VERSION}.tgz" && \
    tar -C /tmp -xzf /tmp/helm-unittest.tgz && \
    mv /tmp/untt /usr/local/bin/helm-unittest && \
    chmod +x /usr/local/bin/helm-unittest

ENV PATH="/usr/bin:/usr/local/bin:/bin:${PATH}"

RUN helm plugin install https://github.com/chartmuseum/helm-push && helm cm-push --help
