FROM rockylinux/rockylinux:10.1-minimal

# Set up a default user and home directory
ENV HOME=/home/neo

ARG YQ_VERSION=v4.44.3
ARG JQ_VERSION=jq-1.8.1
ARG ORAS_VERSION=1.2.2
ARG TRIVY_VERSION=0.69.3
ARG TRANSPILER_MATE_VERSION=0.27.0
ARG CWL2OGC_VERSION=0.13.0
ARG CWL2PUML_VERSION=0.32.0

# Create a user with UID 1001, group root, and a home directory
RUN /usr/sbin/groupadd -g 2000 neo && \
    /usr/sbin/useradd -u 2000 -r -g 2000 -m -d ${HOME} -s /sbin/nologin \
      -c "Default Neo User" neo

RUN microdnf -y update && \
    microdnf -y install curl tar gzip python3 python3-pip python3-setuptools nodejs gcc skopeo && \
    pip3 install --no-cache-dir \
      cwltool \
      "transpiler-mate==${TRANSPILER_MATE_VERSION}" \
      "cwl2ogc==${CWL2OGC_VERSION}" \
      "cwl2puml==${CWL2PUML_VERSION}" && \
    curl -fL https://github.com/pypa/hatch/releases/download/hatch-v1.14.0/hatch-x86_64-unknown-linux-gnu.tar.gz \
      -o /tmp/hatch.tar.gz && \
    tar -xzf /tmp/hatch.tar.gz -C /tmp && \
    install -m 0755 /tmp/hatch /usr/local/bin/hatch && \
    curl -fL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" \
      -o /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq && \
    curl -fL https://github.com/jqlang/jq/releases/download/${JQ_VERSION}/jq-linux-amd64 \
      -o /usr/bin/jq && \
    chmod +x /usr/bin/jq && \
    curl -fL https://github.com/oras-project/oras/releases/download/v${ORAS_VERSION}/oras_${ORAS_VERSION}_linux_amd64.tar.gz \
      -o /tmp/oras.tar.gz && \
    tar -xzf /tmp/oras.tar.gz -C /tmp oras && \
    install -m 0755 /tmp/oras /usr/local/bin/oras && \
    curl -fL https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz \
      -o /tmp/trivy.tar.gz && \
    tar -xzf /tmp/trivy.tar.gz -C /tmp trivy && \
    install -m 0755 /tmp/trivy /usr/local/bin/trivy && \
    rm -rf /tmp/hatch /tmp/hatch.tar.gz /tmp/oras /tmp/oras.tar.gz /tmp/trivy /tmp/trivy.tar.gz && \
    microdnf clean all
