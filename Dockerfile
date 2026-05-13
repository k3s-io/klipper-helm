ARG HELM_VERSION=v3.20.2
ARG HELM_COMMIT=8fb76d6ab555577e98e23b7500009537a471feee

FROM alpine/git:2.49.1 AS helm-src
ARG HELM_VERSION
ARG HELM_COMMIT
RUN git clone --branch "${HELM_VERSION}" --depth 1 https://github.com/helm/helm.git /src/helm && \
    GIT_COMMIT="$(git -C /src/helm rev-parse HEAD)" && \
    if [ "${GIT_COMMIT}" != "${HELM_COMMIT}" ]; then \
        echo "Resolved Helm commit ${GIT_COMMIT} does not match expected ${HELM_COMMIT} for ${HELM_VERSION}"; \
        exit 1; \
    fi && \
    printf '%s\n' "${GIT_COMMIT}" > /src/helm/.git-commit

FROM golang:1.25-alpine3.23 AS extract
ARG TARGETARCH
ARG TARGETVARIANT
ARG HELM_VERSION
COPY --from=helm-src /src/helm /src/helm
RUN case "${TARGETARCH}${TARGETVARIANT:+/${TARGETVARIANT}}" in \
        arm/v7|arm) export GOARCH="arm" GOARM="7" ;; \
        arm64)      export GOARCH="arm64" ;; \
        amd64)      export GOARCH="amd64" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}${TARGETVARIANT:+/${TARGETVARIANT}}" && exit 1 ;; \
    esac && \
    cd /src/helm && \
    K8S_MODULES_VER="$(go list -f '{{.Version}}' -m k8s.io/client-go | tr -d 'v')" && \
    K8S_MODULES_MAJOR_VER="$(echo "${K8S_MODULES_VER}" | cut -d. -f1)" && \
    K8S_MODULES_MINOR_VER="$(echo "${K8S_MODULES_VER}" | cut -d. -f2)" && \
    GIT_COMMIT="$(cat .git-commit)" && \
    CGO_ENABLED=0 go build -trimpath \
      -ldflags "-w -s \
      -X helm.sh/helm/v3/internal/version.version=${HELM_VERSION} \
      -X helm.sh/helm/v3/internal/version.metadata= \
      -X helm.sh/helm/v3/internal/version.gitCommit=${GIT_COMMIT} \
      -X helm.sh/helm/v3/internal/version.gitTreeState=clean \
      -X helm.sh/helm/v3/pkg/lint/rules.k8sVersionMajor=$((K8S_MODULES_MAJOR_VER + 1)) \
      -X helm.sh/helm/v3/pkg/lint/rules.k8sVersionMinor=${K8S_MODULES_MINOR_VER} \
      -X helm.sh/helm/v3/pkg/chartutil.k8sVersionMajor=$((K8S_MODULES_MAJOR_VER + 1)) \
      -X helm.sh/helm/v3/pkg/chartutil.k8sVersionMinor=${K8S_MODULES_MINOR_VER}" \
      -o /usr/bin/helm ./cmd/helm
COPY entry /usr/bin/

FROM golang:1.26-alpine3.23 AS plugins
ARG TARGETARCH
ARG HELM_VERSION
COPY --from=extract /usr/bin/helm /usr/bin/helm
RUN apk add -U curl ca-certificates build-base $([ "${TARGETARCH}" = "arm64" ] && echo binutils-gold)
RUN go version
RUN mkdir -p /go/src/github.com/k3s-io/helm-set-status && \
    cd /tmp && \
    curl -fsSL https://github.com/k3s-io/helm-set-status/archive/refs/tags/v0.3.0.tar.gz -o helm-set-status.tar.gz && \
    echo "56dfeabb802664b7c692607eafc823f784605181539070afaa369e62b4dfd0fb  helm-set-status.tar.gz" | sha256sum -c - && \
    tar xzf helm-set-status.tar.gz --strip-components=1 -C /go/src/github.com/k3s-io/helm-set-status && \
    rm -f /tmp/helm-set-status.tar.gz && \
    cd /go/src/github.com/k3s-io/helm-set-status && \
    go mod edit --replace helm.sh/helm/v3=helm.sh/helm/v3@${HELM_VERSION} && \
    go mod tidy && \
    make install
RUN mkdir -p /go/src/github.com/helm/helm-mapkubeapis && \
    cd /tmp && \
    curl -fsSL https://github.com/helm/helm-mapkubeapis/archive/refs/tags/v0.6.1.tar.gz -o helm-mapkubeapis.tar.gz && \
    echo "261f4adb3a09a5b7c06a32464057c6f93c8fbde9c5776bd07b17fdcaad18ec02  helm-mapkubeapis.tar.gz" | sha256sum -c - && \
    tar xzf helm-mapkubeapis.tar.gz --strip-components=1 -C /go/src/github.com/helm/helm-mapkubeapis && \
    rm -f /tmp/helm-mapkubeapis.tar.gz && \
    cd /go/src/github.com/helm/helm-mapkubeapis && \
    go mod edit --replace helm.sh/helm/v3=helm.sh/helm/v3@${HELM_VERSION} && \
    go mod tidy && \
    make && \
    mkdir -p /root/.local/share/helm/plugins/helm-mapkubeapis && \
    cp -vr /go/src/github.com/helm/helm-mapkubeapis/plugin.yaml \
           /go/src/github.com/helm/helm-mapkubeapis/bin \
           /go/src/github.com/helm/helm-mapkubeapis/config \
           /root/.local/share/helm/plugins/helm-mapkubeapis/

FROM alpine:3.23
ARG BUILDDATE
LABEL buildDate=$BUILDDATE
RUN apk --no-cache upgrade && \
    apk add -U --no-cache ca-certificates-bundle jq bash && \
    apk del libcrypto3 libssl3 apk-tools zlib && \
    adduser -D -u 1000 -s /bin/bash klipper-helm
WORKDIR /home/klipper-helm
COPY --chown=1000:1000 --from=plugins /root/.local/share/helm/plugins/ /home/klipper-helm/.local/share/helm/plugins/
COPY --from=extract /usr/bin/helm /usr/bin/entry /usr/bin/
ENTRYPOINT ["entry"]
ENV STABLE_REPO_URL=https://charts.helm.sh/stable/
ENV TIMEOUT=
USER 1000
