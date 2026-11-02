#!/usr/bin/env bash
set -euo pipefail

go_archive=go1.27.3.linux-amd64.tar.gz
go_sha256=65efbc80fdc1fa2cd2631cad5b481777a68e8725f34e89f50fc6ac714e379b40
cd /tmp
curl -fLO "https://go.dev/dl/${go_archive}"
echo "${go_sha256}  ${go_archive}" | sha256sum --check -
tar -xzf "$go_archive" -C /usr/local

build_helm() {
  curl -fL "https://github.com/helm/helm/archive/refs/tags/${HELM_VERSION}.tar.gz" -o /tmp/helm.tar.gz
  mkdir /tmp/helm-src
  tar -xzf /tmp/helm.tar.gz --strip-components=1 -C /tmp/helm-src
  cd /tmp/helm-src
  /usr/local/go/bin/go mod edit -require=golang.org/x/net@v0.62.0
  CGO_ENABLED=0 GOTOOLCHAIN=local /usr/local/go/bin/go build -mod=mod -trimpath -buildvcs=false \
    -ldflags "-X helm.sh/helm/v3/internal/version.version=${HELM_VERSION}" \
    -o /usr/local/bin/helm ./cmd/helm
  helm version --short
}

build_helm_unittest() {
  curl -fL "https://github.com/helm-unittest/helm-unittest/archive/refs/tags/${HELM_UNITTEST_VERSION}.tar.gz" \
    -o /tmp/helm-unittest.tar.gz
  mkdir /tmp/helm-unittest
  tar -xzf /tmp/helm-unittest.tar.gz --strip-components=1 -C /tmp/helm-unittest
  cd /tmp/helm-unittest
  /usr/local/go/bin/go mod edit \
    -require=golang.org/x/crypto@v0.55.0 \
    -require=golang.org/x/net@v0.62.0 \
    -require=golang.org/x/text@v0.41.0
  CGO_ENABLED=0 GOTOOLCHAIN=local /usr/local/go/bin/go build -mod=mod -trimpath -buildvcs=false \
    -o /usr/local/bin/helm-unittest ./cmd/helm-unittest
  /usr/local/bin/helm-unittest --help >/dev/null
}

build_yq() {
  curl -fL "https://github.com/mikefarah/yq/archive/refs/tags/${YQ_VERSION}.tar.gz" -o /tmp/yq.tar.gz
  mkdir /tmp/yq
  tar -xzf /tmp/yq.tar.gz --strip-components=1 -C /tmp/yq
  cd /tmp/yq
  /usr/local/go/bin/go mod edit -require=golang.org/x/net@v0.62.0
  CGO_ENABLED=0 GOTOOLCHAIN=local /usr/local/go/bin/go build -mod=mod -trimpath -buildvcs=false \
    -o /usr/local/bin/yq .
}

build_task() {
  curl -fL "https://github.com/go-task/task/archive/refs/tags/${TASK_VERSION}.tar.gz" -o /tmp/task-src.tar.gz
  mkdir /tmp/task-src
  tar -xzf /tmp/task-src.tar.gz --strip-components=1 -C /tmp/task-src
  cd /tmp/task-src
  /usr/local/go/bin/go mod edit \
    -require=github.com/go-jose/go-jose/v4@v4.1.6 \
    -require=golang.org/x/net@v0.62.0
  CGO_ENABLED=0 GOTOOLCHAIN=local /usr/local/go/bin/go build -mod=mod -trimpath -buildvcs=false \
    -o /usr/local/bin/task ./cmd/task
}

build_oras() {
  curl -fL "https://github.com/oras-project/oras/archive/refs/tags/v${ORAS_VERSION}.tar.gz" -o /tmp/oras-src.tar.gz
  mkdir /tmp/oras-src
  tar -xzf /tmp/oras-src.tar.gz --strip-components=1 -C /tmp/oras-src
  cd /tmp/oras-src
  CGO_ENABLED=0 GOTOOLCHAIN=local /usr/local/go/bin/go build -mod=mod -trimpath -buildvcs=false \
    -o /usr/local/bin/oras ./cmd/oras
}

build_trivy() {
  curl -fL "https://github.com/aquasecurity/trivy/archive/refs/tags/v${TRIVY_VERSION}.tar.gz" -o /tmp/trivy.tar.gz
  mkdir /tmp/trivy-src
  tar -xzf /tmp/trivy.tar.gz --strip-components=1 -C /tmp/trivy-src
  cd /tmp/trivy-src
  /usr/local/go/bin/go mod edit \
    -require=github.com/go-jose/go-jose/v4@v4.1.6 \
    -require=golang.org/x/net@v0.62.0
  CGO_ENABLED=0 GOTOOLCHAIN=local /usr/local/go/bin/go build -mod=mod -trimpath -buildvcs=false \
    -ldflags "-X github.com/aquasecurity/trivy/pkg/version/app.ver=${TRIVY_VERSION#v}" \
    -o /usr/bin/trivy ./cmd/trivy
  trivy --version
}

build_helm
build_helm_unittest
build_yq
build_task
build_oras
build_trivy

rm -rf /usr/local/go /root/go /root/.cache "${HOME}/go" "${HOME}/.cache" \
  "/tmp/${go_archive}" /tmp/helm-unittest /tmp/helm-unittest.tar.gz \
  /tmp/helm-src /tmp/helm.tar.gz /tmp/yq /tmp/yq.tar.gz \
  /tmp/task-src /tmp/task-src.tar.gz /tmp/oras-src /tmp/oras-src.tar.gz \
  /tmp/trivy-src /tmp/trivy.tar.gz
