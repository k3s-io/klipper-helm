FROM alpine:3.23 AS extract
ARG TARGETARCH
RUN apk add -U curl ca-certificates
RUN case "${TARGETARCH}" in \
        arm/v7|arm) ARCH="arm";   HELM_SHA256="758375df78fb8f91f4056244bda539710a73be79284b24b4bdad68384348ca33" ;; \
        arm64)  ARCH="arm64"; HELM_SHA256="56b9d1b0e0efbb739be6e68a37860ace8ec9c7d3e6424e3b55d4c459bc3a0401" ;; \
        amd64)  ARCH="amd64"; HELM_SHA256="0165ee4a2db012cc657381001e593e981f42aa5707acdd50658326790c9d0dc3" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    cd /tmp && \
    curl -fsSL https://get.helm.sh/helm-v3.20.1-linux-${ARCH}.tar.gz -o helm.tar.gz && \
    echo "${HELM_SHA256}  helm.tar.gz" | sha256sum -c - && \
    tar xzf helm.tar.gz --strip-components=1 -C /usr/bin && \
    rm -f /tmp/helm.tar.gz
COPY entry /usr/bin/

FROM golang:1.25-alpine3.23 AS plugins
ARG TARGETARCH
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
    go mod edit --replace helm.sh/helm/v3=helm.sh/helm/v3@v3.20.1 && \
    go mod tidy && \
    make install
RUN mkdir -p /go/src/github.com/helm/helm-mapkubeapis && \
    cd /tmp && \
    curl -fsSL https://github.com/helm/helm-mapkubeapis/archive/refs/tags/v0.6.1.tar.gz -o helm-mapkubeapis.tar.gz && \
    echo "261f4adb3a09a5b7c06a32464057c6f93c8fbde9c5776bd07b17fdcaad18ec02  helm-mapkubeapis.tar.gz" | sha256sum -c - && \
    tar xzf helm-mapkubeapis.tar.gz --strip-components=1 -C /go/src/github.com/helm/helm-mapkubeapis && \
    rm -f /tmp/helm-mapkubeapis.tar.gz && \
    cd /go/src/github.com/helm/helm-mapkubeapis && \
    go mod edit --replace helm.sh/helm/v3=helm.sh/helm/v3@v3.20.1 && \
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
    apk add -U --no-cache ca-certificates jq bash && \
    adduser -D -u 1000 -s /bin/bash klipper-helm
WORKDIR /home/klipper-helm
COPY --chown=1000:1000 --from=plugins /root/.local/share/helm/plugins/ /home/klipper-helm/.local/share/helm/plugins/
COPY --from=extract /usr/bin/helm /usr/bin/entry /usr/bin/
ENTRYPOINT ["entry"]
ENV STABLE_REPO_URL=https://charts.helm.sh/stable/
ENV TIMEOUT=
USER 1000