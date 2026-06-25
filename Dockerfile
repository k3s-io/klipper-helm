ARG HELM_VERSION=v4.1.4
ARG HELM_COMMIT=05fa37973dc9e42b76e1d2883494c87174b6074f

FROM --platform=$BUILDPLATFORM alpine:3.24 AS helm-src
ARG HELM_VERSION
ARG HELM_COMMIT
RUN apk add --no-cache git
RUN git clone --branch "${HELM_VERSION}" --depth 1 https://github.com/helm/helm.git /src/helm && \
    GIT_COMMIT="$(git -C /src/helm rev-parse HEAD)" && \
    if [ "${GIT_COMMIT}" != "${HELM_COMMIT}" ]; then \
        echo "Resolved Helm commit ${GIT_COMMIT} does not match expected ${HELM_COMMIT} for ${HELM_VERSION}"; \
        exit 1; \
    fi && \
    printf '%s\n' "${GIT_COMMIT}" > /src/helm/.git-commit

FROM --platform=$BUILDPLATFORM golang:1.26-alpine3.24 AS helm
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT
ARG TARGETPLATFORM
ARG HELM_VERSION
COPY --from=helm-src /src/helm /src/helm
# Apply tracked go.mod CVE overrides on top of the upstream Helm module before
# building. See go-mod-overrides / scripts/go-mod-overrides.sh.
COPY scripts/go-mod-overrides.sh /usr/local/bin/go-mod-overrides.sh
COPY go-mod-overrides /src/go-mod-overrides
RUN chmod +x /usr/local/bin/go-mod-overrides.sh && \
    cd /src/helm && \
    go-mod-overrides.sh /src/go-mod-overrides
RUN case "${TARGETARCH}${TARGETVARIANT:+/${TARGETVARIANT}}" in \
        arm/v7|arm) export GOARCH="arm" GOARM="7" ;; \
        arm64)      export GOARCH="arm64" ;; \
        amd64)      export GOARCH="amd64" ;; \
        riscv64)    export GOARCH="riscv64" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}${TARGETVARIANT:+/${TARGETVARIANT}}" && exit 1 ;; \
    esac && \
    cd /src/helm && \
    K8S_MODULES_VER="$(go list -f '{{.Version}}' -m k8s.io/client-go | tr -d 'v')" && \
    K8S_MODULES_MAJOR_VER="$(echo "${K8S_MODULES_VER}" | cut -d. -f1)" && \
    K8S_MODULES_MINOR_VER="$(echo "${K8S_MODULES_VER}" | cut -d. -f2)" && \
    GIT_COMMIT="$(cat .git-commit)" && \
    CGO_ENABLED=0 GOOS="${TARGETOS}" GOARCH="${GOARCH}" GOARM="${GOARM}" go build -trimpath \
        -ldflags "-w -s \
        -X helm.sh/helm/v4/internal/version.version=${HELM_VERSION} \
        -X helm.sh/helm/v4/internal/version.metadata= \
        -X helm.sh/helm/v4/internal/version.gitCommit=${GIT_COMMIT} \
        -X helm.sh/helm/v4/internal/version.gitTreeState=clean \
        -X helm.sh/helm/v4/pkg/lint/rules.k8sVersionMajor=$((K8S_MODULES_MAJOR_VER + 1)) \
        -X helm.sh/helm/v4/pkg/lint/rules.k8sVersionMinor=${K8S_MODULES_MINOR_VER} \
        -X helm.sh/helm/v4/pkg/chartutil.k8sVersionMajor=$((K8S_MODULES_MAJOR_VER + 1)) \
        -X helm.sh/helm/v4/pkg/chartutil.k8sVersionMinor=${K8S_MODULES_MINOR_VER}" \
        -o /usr/bin/helm ./cmd/helm
COPY entry /usr/bin/

FROM --platform=$BUILDPLATFORM golang:1.26-alpine3.24 AS plugins
ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH
ARG HELM_VERSION
COPY --from=helm /usr/bin/helm /usr/bin/helm
RUN apk add -U --no-cache curl ca-certificates make git
RUN go version
# The plugins are built from their own upstream modules, so apply the same
# tracked go.mod CVE overrides to each before building.
COPY scripts/go-mod-overrides.sh /usr/local/bin/go-mod-overrides.sh
COPY go-mod-overrides /src/go-mod-overrides
RUN chmod +x /usr/local/bin/go-mod-overrides.sh
RUN mkdir -p /go/src/github.com/k3s-io/helm-set-status && \
    cd /tmp && \
    curl -fsSL https://github.com/k3s-io/helm-set-status/archive/aa683c2b38a34bbd7261c5cd59e8d7c02e9d5c6e/helm-set-status.tar.gz -o helm-set-status.tar.gz && \
    tar xzf helm-set-status.tar.gz --strip-components=1 -C /go/src/github.com/k3s-io/helm-set-status && \
    rm -f /tmp/helm-set-status.tar.gz && \
    cd /go/src/github.com/k3s-io/helm-set-status && \
    go mod edit --replace helm.sh/helm/v4=helm.sh/helm/v4@"${HELM_VERSION}" && \
    go-mod-overrides.sh /src/go-mod-overrides && \
    make CGO_ENABLED=0 GOOS="${TARGETOS}" GOARCH="${TARGETARCH}" HELM_PLUGIN_PATH=/root/.local/share/helm/plugins/helm-set-status install
RUN mkdir -p /go/src/github.com/helm/helm-mapkubeapis && \
    cd /tmp && \
    curl -fsSL https://github.com/helm/helm-mapkubeapis/archive/a8a487a350db0ca85fb4247afb7e220d5f254b6f/helm-mapkubeapis.tar.gz -o helm-mapkubeapis.tar.gz && \
    tar xzf helm-mapkubeapis.tar.gz --strip-components=1 -C /go/src/github.com/helm/helm-mapkubeapis && \
    rm -f /tmp/helm-mapkubeapis.tar.gz && \
    cd /go/src/github.com/helm/helm-mapkubeapis && \
    go mod edit --replace helm.sh/helm/v4=helm.sh/helm/v4@"${HELM_VERSION}" && \
    go-mod-overrides.sh /src/go-mod-overrides && \
    make CGO_ENABLED=0 GOOS="${TARGETOS}" GOARCH="${TARGETARCH}" build && \
    mkdir -p /root/.local/share/helm/plugins/helm-mapkubeapis && \
    cp -vr /go/src/github.com/helm/helm-mapkubeapis/plugin.yaml \
           /go/src/github.com/helm/helm-mapkubeapis/bin \
           /go/src/github.com/helm/helm-mapkubeapis/config \
           /root/.local/share/helm/plugins/helm-mapkubeapis/

FROM alpine:3.24
ARG BUILDDATE
LABEL buildDate=$BUILDDATE
RUN apk --no-cache upgrade && \
    apk add -U --no-cache ca-certificates-bundle jq bash && \
    apk del libcrypto3 libssl3 apk-tools zlib && \
    adduser -D -u 1000 -s /bin/bash klipper-helm
WORKDIR /home/klipper-helm
COPY --chown=1000:1000 --from=plugins /root/.local/share/helm/plugins/ /home/klipper-helm/.local/share/helm/plugins/
COPY --from=helm /usr/bin/helm /usr/bin/entry /usr/bin/
ENTRYPOINT ["entry"]
ENV STABLE_REPO_URL=https://charts.helm.sh/stable/
ENV TIMEOUT=
USER 1000
