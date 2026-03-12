FROM rockylinux/rockylinux:10.1-minimal

# Set up a default user and home directory
ENV HOME=/home/neo

ARG YQ_VERSION=v4.44.3
ARG ORAS_VERSION=1.2.2

COPY requirements.txt /tmp/requirements.txt

# Create a user with UID 1001, group root, and a home directory
RUN /usr/sbin/groupadd -g 2000 neo && \
    /usr/sbin/useradd -u 2000 -r -g 2000 -m -d ${HOME} -s /sbin/nologin \
      -c "Default Neo User" neo

RUN microdnf -y update && \
    microdnf -y install curl tar gzip python3 python3-pip python3-setuptools nodejs gcc skopeo jq && \
    printf '%s\n' \
      '[trivy]' \
      'name=Trivy repository' \
      'baseurl=https://aquasecurity.github.io/trivy-repo/rpm/releases/$basearch/' \
      'gpgcheck=1' \
      'enabled=1' \
      'gpgkey=https://aquasecurity.github.io/trivy-repo/rpm/public.key' \
      > /etc/yum.repos.d/trivy.repo && \
    microdnf -y install trivy && \
    pip3 install --no-cache-dir -r /tmp/requirements.txt hatch && \
    curl -fL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" \
      -o /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq && \
    curl -fL https://github.com/oras-project/oras/releases/download/v${ORAS_VERSION}/oras_${ORAS_VERSION}_linux_amd64.tar.gz \
      -o /tmp/oras.tar.gz && \
    tar -xzf /tmp/oras.tar.gz -C /tmp oras && \
    install -m 0755 /tmp/oras /usr/local/bin/oras && \
    rm -rf /tmp/oras /tmp/oras.tar.gz && \
    microdnf clean all
