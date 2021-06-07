FROM alpine:3.12 as extract
RUN apk add -U curl ca-certificates
ARG ARCH
RUN curl https://get.helm.sh/helm-v2.17.0-linux-${ARCH}.tar.gz | tar xvzf - --strip-components=1 -C /usr/bin
RUN mv /usr/bin/helm /usr/bin/helm_v2
RUN curl https://get.helm.sh/helm-v3.5.4-linux-${ARCH}.tar.gz | tar xvzf - --strip-components=1 -C /usr/bin
RUN mv /usr/bin/helm /usr/bin/helm_v3

FROM alpine:3.12
RUN apk add -U --no-cache ca-certificates jq bash git
COPY --from=extract /usr/bin/helm_v2 /usr/bin/helm_v3 /usr/bin/tiller /usr/bin/
COPY entry /usr/bin/
ENTRYPOINT ["entry"]
ENV STABLE_REPO_URL=https://charts.helm.sh/stable/
ENV TIMEOUT=
