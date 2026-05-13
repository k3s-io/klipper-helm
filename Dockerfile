ARG HELM_IMAGE=rancher/hardened-helm
FROM ${HELM_IMAGE} AS extract
COPY entry /usr/bin/

FROM golang:1.25-alpine3.23 AS plugins
ARG TARGETARCH
ARG HELM_VERSION=v3.20.2
COPY --from=extract /usr/local/bin/helm /usr/bin/helm
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
COPY --from=extract /usr/local/bin/helm /usr/bin/entry /usr/bin/
ENTRYPOINT ["entry"]
ENV STABLE_REPO_URL=https://charts.helm.sh/stable/
ENV TIMEOUT=
USER 1000
