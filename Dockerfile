ARG HELM_VERSION=v4.1.4
ARG HELM_COMMIT=05fa37973dc9e42b76e1d2883494c87174b6074f
ARG HELM_SET_STATUS_COMMIT=3a3a40923262fcd0bdf729b538cda7dd4b15b047
ARG HELM_MAPKUBEAPIS_COMMIT=a8a487a350db0ca85fb4247afb7e220d5f254b6f

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

FROM alpine/git:2.49.1 AS helm-set-status-src
ARG HELM_SET_STATUS_COMMIT
RUN git init /src/helm-set-status && \
    cd /src/helm-set-status && \
    git remote add origin https://github.com/k3s-io/helm-set-status.git && \
    git fetch --depth 1 origin "${HELM_SET_STATUS_COMMIT}" && \
    git checkout --detach FETCH_HEAD && \
    if [ "$(git rev-parse HEAD)" != "${HELM_SET_STATUS_COMMIT}" ]; then \
        echo "Resolved helm-set-status commit $(git rev-parse HEAD) does not match expected ${HELM_SET_STATUS_COMMIT}"; \
        exit 1; \
    fi

FROM alpine/git:2.49.1 AS helm-mapkubeapis-src
ARG HELM_MAPKUBEAPIS_COMMIT
RUN git init /src/helm-mapkubeapis && \
    cd /src/helm-mapkubeapis && \
    git remote add origin https://github.com/helm/helm-mapkubeapis.git && \
    git fetch --depth 1 origin "${HELM_MAPKUBEAPIS_COMMIT}" && \
    git checkout --detach FETCH_HEAD && \
    if [ "$(git rev-parse HEAD)" != "${HELM_MAPKUBEAPIS_COMMIT}" ]; then \
        echo "Resolved helm-mapkubeapis commit $(git rev-parse HEAD) does not match expected ${HELM_MAPKUBEAPIS_COMMIT}"; \
        exit 1; \
    fi

FROM golang:1.25-alpine3.23 AS helm
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

FROM golang:1.25-alpine3.23 AS plugins
ARG TARGETARCH
ARG HELM_VERSION
COPY --from=helm /usr/bin/helm /usr/bin/helm
COPY --from=helm-set-status-src /src/helm-set-status /go/src/github.com/k3s-io/helm-set-status
COPY --from=helm-mapkubeapis-src /src/helm-mapkubeapis /go/src/github.com/helm/helm-mapkubeapis
RUN apk add -U ca-certificates build-base $([ "${TARGETARCH}" = "arm64" ] && echo binutils-gold)
RUN go version
RUN cd /go/src/github.com/k3s-io/helm-set-status && \
    go mod edit --replace helm.sh/helm/v4=helm.sh/helm/v4@"${HELM_VERSION}" && \
    go mod tidy && \
    make install
RUN cd /go/src/github.com/helm/helm-mapkubeapis && \
    go mod edit --replace helm.sh/helm/v4=helm.sh/helm/v4@"${HELM_VERSION}" && \
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
COPY --from=helm /usr/bin/helm /usr/bin/entry /usr/bin/
ENTRYPOINT ["entry"]
ENV STABLE_REPO_URL=https://charts.helm.sh/stable/
ENV TIMEOUT=
USER 1000
