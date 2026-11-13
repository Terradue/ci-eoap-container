FROM rockylinux/rockylinux:10.2-minimal

# Set up a default user and home directory
ENV HOME=/home/neo

# renovate: datasource=github-releases depName=mikefarah/yq
ARG YQ_VERSION=v4.54.3
# renovate: datasource=github-releases depName=oras-project/oras
ARG ORAS_VERSION=1.3.6
# renovate: datasource=github-releases depName=go-task/task
ARG TASK_VERSION=v3.54.0
# renovate: datasource=github-releases depName=aquasecurity/trivy
ARG TRIVY_VERSION=0.76.2
# renovate: datasource=github-releases depName=nodejs/node
ARG NODE_VERSION=v24.22.3
# renovate: datasource=npm depName=npm
ARG NPM_VERSION=12.2.2
# renovate: datasource=npm depName=undici
ARG UNDICI_VERSION=8.12.4
# renovate: datasource=npm depName=ip-address
ARG IP_ADDRESS_VERSION=10.7.6
# renovate: datasource=github-releases depName=helm-unittest/helm-unittest
ARG HELM_UNITTEST_VERSION=v1.2.1
# renovate: datasource=github-releases depName=helm/helm
ARG HELM_VERSION=v4.3.2

COPY requirements.txt /tmp/requirements.txt
COPY scripts/install-python-deps.sh scripts/install-node-tools.sh scripts/build-go-tools.sh /usr/local/bin/

# Create a user with UID 1001, group root, and a home directory
RUN /usr/sbin/groupadd -g 2000 neo && \
    /usr/sbin/useradd -u 2000 -r -g 2000 -m -d ${HOME} -s /sbin/nologin \
      -c "Default Neo User" neo

# Install the system tools required for the image and source builds.
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
    /usr/local/bin/install-python-deps.sh && \
    microdnf -y remove python3-pip python3-setuptools && \
    microdnf clean all

# Make tools installed under /usr/local available during the remaining build steps.
ENV PATH="/usr/bin:/usr/local/bin:/bin:${PATH}"

# Install the selected upstream Node.js release (including its bundled npm).
# This image's downloaded tools target Linux amd64.
RUN /usr/local/bin/install-node-tools.sh

RUN /usr/local/bin/build-go-tools.sh
