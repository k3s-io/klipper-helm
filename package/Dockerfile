FROM alpine:3.20 as extract
RUN apk add -U curl ca-certificates
ARG ARCH
RUN curl -sL https://get.helm.sh/helm-v3.15.3-linux-${ARCH}.tar.gz | tar xvzf - --strip-components=1 -C /usr/bin
COPY entry /usr/bin/

FROM golang:1.23-alpine3.20 as plugins
RUN apk add -U curl ca-certificates build-base binutils-gold
ARG ARCH
COPY --from=extract /usr/bin/helm /usr/bin/helm
RUN mkdir -p /go/src/github.com/k3s-io/helm-set-status && \
    curl -sL https://github.com/k3s-io/helm-set-status/archive/refs/tags/v0.2.0.tar.gz | tar xvzf - --strip-components=1 -C /go/src/github.com/k3s-io/helm-set-status && \
    cd /go/src/github.com/k3s-io/helm-set-status && \
    go get -u ./... && \
    go mod tidy && \
    make install
RUN mkdir -p /go/src/github.com/helm/helm-mapkubeapis && \
    curl -sL https://github.com/k3s-io/helm-mapkubeapis/archive/refs/tags/v0.4.1-k3s1.tar.gz | tar xvzf - --strip-components=1 -C /go/src/github.com/helm/helm-mapkubeapis && \
    cd /go/src/github.com/helm/helm-mapkubeapis && \
    go get -u ./... && \
    go mod tidy && \
    make && \
    mkdir -p /root/.local/share/helm/plugins/helm-mapkubeapis && \
    cp -vr /go/src/github.com/helm/helm-mapkubeapis/plugin.yaml \
           /go/src/github.com/helm/helm-mapkubeapis/bin \
           /go/src/github.com/helm/helm-mapkubeapis/config \
           /root/.local/share/helm/plugins/helm-mapkubeapis/

FROM alpine:3.20
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
