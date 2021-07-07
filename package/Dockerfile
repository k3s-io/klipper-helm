FROM alpine:3.12 as extract
RUN apk add -U curl ca-certificates
ARG ARCH
RUN curl https://get.helm.sh/helm-v2.17.0-linux-${ARCH}.tar.gz | tar xvzf - --strip-components=1 -C /usr/bin
RUN mv /usr/bin/helm /usr/bin/helm_v2
RUN curl https://get.helm.sh/helm-v3.5.4-linux-${ARCH}.tar.gz | tar xvzf - --strip-components=1 -C /usr/bin
RUN mv /usr/bin/helm /usr/bin/helm_v3

FROM golang:1.16-alpine3.12 as plugins
RUN apk add -U curl ca-certificates build-base binutils-gold
ARG ARCH
COPY --from=extract /usr/bin/helm_v3 /usr/bin/helm
RUN mkdir -p /go/src/github.com/k3s-io/helm-set-status && \
    curl -L https://github.com/k3s-io/helm-set-status/archive/refs/tags/v0.1.1.tar.gz | tar xvzf - --strip-components=1 -C /go/src/github.com/k3s-io/helm-set-status && \
    make -C /go/src/github.com/k3s-io/helm-set-status install

FROM alpine:3.12
WORKDIR /home/klipper-helm
ENV HOME=/home/klipper-helm
COPY --from=extract /usr/bin/helm_v2 /usr/bin/helm_v3 /usr/bin/tiller /usr/bin/
COPY --from=plugins /root/.local/share/helm/plugins/ /root/.local/share/helm/plugins/
COPY entry /usr/bin/
RUN apk add -U --no-cache ca-certificates jq bash git && \
    chown 1000:1000 -R /home/klipper-helm && \
    chmod +x /usr/bin/entry
ENTRYPOINT ["entry"]
ENV STABLE_REPO_URL=https://charts.helm.sh/stable/
ENV TIMEOUT=
USER 1000