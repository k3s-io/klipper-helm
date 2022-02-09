FROM alpine:3.15 as extract
RUN apk add -U curl ca-certificates
ARG ARCH
RUN curl https://get.helm.sh/helm-v2.17.0-linux-${ARCH}.tar.gz | tar xvzf - --strip-components=1 -C /usr/bin
RUN mv /usr/bin/helm /usr/bin/helm_v2
RUN curl https://get.helm.sh/helm-v3.8.1-linux-${ARCH}.tar.gz | tar xvzf - --strip-components=1 -C /usr/bin
RUN mv /usr/bin/helm /usr/bin/helm_v3
COPY entry /usr/bin/

FROM golang:1.16-alpine3.15 as plugins
RUN apk add -U curl ca-certificates build-base binutils-gold
ARG ARCH
COPY --from=extract /usr/bin/helm_v3 /usr/bin/helm
RUN mkdir -p /go/src/github.com/k3s-io/helm-set-status && \
    curl -sL https://github.com/k3s-io/helm-set-status/archive/refs/tags/v0.1.2.tar.gz | tar xvzf - --strip-components=1 -C /go/src/github.com/k3s-io/helm-set-status && \
    make -C /go/src/github.com/k3s-io/helm-set-status install
RUN mkdir -p /go/src/github.com/helm/helm-mapkubeapis && \
    curl -sL https://github.com/helm/helm-mapkubeapis/archive/09f250b089fa7f38adcb27769c1c3c50dcb5de5e.tar.gz | tar xvzf - --strip-components=1 -C /go/src/github.com/helm/helm-mapkubeapis && \
    make -C /go/src/github.com/helm/helm-mapkubeapis && \
    mkdir -p /root/.local/share/helm/plugins/helm-mapkubeapis && \
    cp -vr /go/src/github.com/helm/helm-mapkubeapis/plugin.yaml \
           /go/src/github.com/helm/helm-mapkubeapis/bin \
           /go/src/github.com/helm/helm-mapkubeapis/config \
           /root/.local/share/helm/plugins/helm-mapkubeapis/

FROM alpine:3.15
RUN apk add -U --no-cache ca-certificates jq bash git && \
    adduser -D -u 1000 -s /bin/bash klipper-helm
WORKDIR /home/klipper-helm
COPY --chown=1000:1000 --from=plugins /root/.local/share/helm/plugins/ /home/klipper-helm/.local/share/helm/plugins/
COPY --from=extract /usr/bin/helm_v2 /usr/bin/helm_v3 /usr/bin/tiller /usr/bin/entry /usr/bin/
ENTRYPOINT ["entry"]
ENV STABLE_REPO_URL=https://charts.helm.sh/stable/
ENV TIMEOUT=
USER 1000
