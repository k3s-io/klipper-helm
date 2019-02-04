FROM alpine:3.8 as extract
RUN apk add -U curl ca-certificates
ARG ARCH
RUN curl https://storage.googleapis.com/kubernetes-helm/helm-v2.12.3-linux-${ARCH}.tar.gz | tar xvzf - --strip-components=1 -C /usr/bin

FROM alpine:3.8
RUN apk add -U --no-cache ca-certificates jq bash
COPY --from=extract /usr/bin/helm /usr/bin/tiller /usr/bin/
COPY entry /usr/bin/
ENTRYPOINT ["entry"]
