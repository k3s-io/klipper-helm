FROM alpine:3.8 as extract
RUN apk add -U curl ca-certificates
ARG ARCH
RUN curl https://get.helm.sh/helm-v3.0.0-linux-${ARCH}.tar.gz | tar xvzf - --strip-components=1 -C /usr/bin

FROM alpine:3.8
RUN apk add -U --no-cache ca-certificates jq bash
COPY --from=extract /usr/bin/helm /usr/bin/
RUN helm plugin install https://github.com/helm/helm-2to3
COPY entry /usr/bin/
ENTRYPOINT ["entry"]
