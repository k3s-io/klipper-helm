FROM alpine:3.8 as extract
RUN apk add -U curl ca-certificates
ARG ARCH
RUN curl https://storage.googleapis.com/kubernetes-helm/helm-v2.12.3-linux-${ARCH}.tar.gz | tar xvzf - --strip-components=1 -C /usr/bin
RUN mv /usr/bin/helm /usr/bin/helm_v2
RUN curl https://get.helm.sh/helm-v3.0.0-linux-${ARCH}.tar.gz | tar xvzf - --strip-components=1 -C /usr/bin
RUN mv /usr/bin/helm /usr/bin/helm_v3

FROM alpine:3.8
RUN apk add -U --no-cache ca-certificates jq bash git
COPY --from=extract /usr/bin/helm_v2 /usr/bin/helm_v3 /usr/bin/tiller /usr/bin/
COPY entry /usr/bin/
ENTRYPOINT ["entry"]
