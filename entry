#!/bin/bash

set -e -v
eval set -- $(sed -e "s/%{KUBERNETES_API}%/${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}/g" <<< "${@@Q}")
set +v -x

cp /var/run/secrets/kubernetes.io/serviceaccount/ca.crt /usr/local/share/ca-certificates/
update-ca-certificates

tiller --listen=127.0.0.1:44134 --storage=secret &
export HELM_HOST=127.0.0.1:44134

helm init --skip-refresh --client-only
helm repo update --strict || helm repo remove stable
if [ -n "$REPO" ]; then
    helm repo add ${NAME%%/*} $REPO
fi
helm repo update


JQ_CMD='"\(.Releases[0].AppVersion),\(.Releases[0].Status)"'
LINE="$(helm ls --all "^$NAME\$" --output json | jq -r "$JQ_CMD")"
INSTALLED_VERSION=$(echo $LINE | cut -f1 -d,)
STATUS=$(echo $LINE | cut -f2 -d,)

if [ -e /config/values.yaml ]; then
    VALUES="--values /config/values.yaml"
fi

if [ "$1" = "delete" ]; then
    if [ -z "$INSTALLED_VERSION" ]; then
        exit
    fi
    helm delete $NAME || true
    helm "$@"
    exit
fi

if [ -z "$INSTALLED_VERSION" ] && [ -z "$STATUS" ]; then
    helm "$@" $VALUES
    exit
fi
if [ -z "$VERSION" ] || [ "$INSTALLED_VERSION" = "$VERSION" ]; then
    if [ "$STATUS" = "DEPLOYED" ]; then
        echo Already installed $NAME, upgrading
        # We assume the args are always install --name foo CHART
        shift 2
        helm upgrade "$@" $VALUES
        exit
    fi
fi

if [ "$STATUS" = "FAILED" ] || [ "$STATUS" = "DELETED" ]; then
    helm delete --purge $NAME
    echo Deleted
    helm "$@" $VALUES
    exit
fi

# We assume the args are always install --name foo CHART
shift 2
helm upgrade "$@" $VALUES
