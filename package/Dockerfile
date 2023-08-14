FROM alpine:3.18 as extract
RUN apk add -U curl ca-certificates
ARG ARCH
RUN curl https://get.helm.sh/helm-v2.17.0-linux-${ARCH}.tar.gz | tar xvzf - --strip-components=1 -C /usr/bin
RUN mv /usr/bin/helm /usr/bin/helm_v2
RUN curl https://get.helm.sh/helm-v3.11.3-linux-${ARCH}.tar.gz | tar xvzf - --strip-components=1 -C /usr/bin
RUN mv /usr/bin/helm /usr/bin/helm_v3
COPY entry /usr/bin/

FROM golang:1.21-alpine3.17 as plugins
RUN apk add -U curl ca-certificates build-base binutils-gold
ARG ARCH
COPY --from=extract /usr/bin/helm_v3 /usr/bin/helm
RUN mkdir -p /go/src/github.com/k3s-io/helm-set-status && \
    curl -sL https://github.com/k3s-io/helm-set-status/archive/refs/tags/v0.1.3.tar.gz | tar xvzf - --strip-components=1 -C /go/src/github.com/k3s-io/helm-set-status && \
    make -C /go/src/github.com/k3s-io/helm-set-status install
RUN mkdir -p /go/src/github.com/helm/helm-mapkubeapis && \
    curl -sL https://github.com/helm/helm-mapkubeapis/archive/refs/tags/v0.4.1.tar.gz | tar xvzf - --strip-components=1 -C /go/src/github.com/helm/helm-mapkubeapis && \
    make -C /go/src/github.com/helm/helm-mapkubeapis && \
    mkdir -p /root/.local/share/helm/plugins/helm-mapkubeapis && \
    cp -vr /go/src/github.com/helm/helm-mapkubeapis/plugin.yaml \
           /go/src/github.com/helm/helm-mapkubeapis/bin \
           /go/src/github.com/helm/helm-mapkubeapis/config \
           /root/.local/share/helm/plugins/helm-mapkubeapis/

FROM alpine:3.18
ARG BUILDDATE
LABEL buildDate=$BUILDDATE
RUN apk --no-cache upgrade && \
    apk add -U --no-cache ca-certificates jq bash git && \
    adduser -D -u 1000 -s /bin/bash klipper-helm
WORKDIR /home/klipper-helm
COPY --chown=1000:1000 --from=plugins /root/.local/share/helm/plugins/ /home/klipper-helm/.local/share/helm/plugins/
COPY --from=extract /usr/bin/helm_v2 /usr/bin/helm_v3 /usr/bin/tiller /usr/bin/entry /usr/bin/
ENTRYPOINT ["entry"]
ENV STABLE_REPO_URL=https://charts.helm.sh/stable/
ENV TIMEOUT=
USER 1000
