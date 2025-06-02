FROM alpine:3.21 AS extract
RUN apk add -U curl ca-certificates
ARG TARGETARCH
RUN if [ "${TARGETARCH}" = "arm/v7" ]; then \
        ARCH="arm" ; \
    else \
        ARCH="${TARGETARCH}" ; \
    fi && \
    curl -sL https://get.helm.sh/helm-v3.18.1-linux-${ARCH}.tar.gz | tar xvzf - --strip-components=1 -C /usr/bin
COPY entry /usr/bin/

FROM golang:1.24-alpine3.20 AS plugins
RUN apk add -U curl ca-certificates build-base binutils-gold
COPY --from=extract /usr/bin/helm /usr/bin/helm
RUN mkdir -p /go/src/github.com/k3s-io/helm-set-status && \
    curl -sL https://github.com/k3s-io/helm-set-status/archive/refs/tags/v0.3.0.tar.gz | tar xvzf - --strip-components=1 -C /go/src/github.com/k3s-io/helm-set-status && \
    cd /go/src/github.com/k3s-io/helm-set-status && \
    make install
RUN mkdir -p /go/src/github.com/helm/helm-mapkubeapis && \
    curl -sL https://github.com/helm/helm-mapkubeapis/archive/refs/tags/v0.5.2.tar.gz | tar xvzf - --strip-components=1 -C /go/src/github.com/helm/helm-mapkubeapis && \
    cd /go/src/github.com/helm/helm-mapkubeapis && \
    make && \
    mkdir -p /root/.local/share/helm/plugins/helm-mapkubeapis && \
    cp -vr /go/src/github.com/helm/helm-mapkubeapis/plugin.yaml \
           /go/src/github.com/helm/helm-mapkubeapis/bin \
           /go/src/github.com/helm/helm-mapkubeapis/config \
           /root/.local/share/helm/plugins/helm-mapkubeapis/

FROM alpine:3.21
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
