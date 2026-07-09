#!/bin/sh
# go-mod-overrides.sh — apply tracked go.mod overrides on top of an upstream
# module so the built image stays CVE-free even when upstream has not yet bumped.
#
# The overrides file is a simple line-oriented list where each non-comment line
# is passed verbatim to `go mod edit`. That keeps this a thin, dependency-free
# wrapper (just `go` + `sh`) and makes every override trivially reviewable in a
# PR diff.
#
# Usage:
#   go-mod-overrides.sh [OVERRIDES_FILE]
#
# Defaults to ./go-mod-overrides. Must be run from the module directory (the
# directory containing the go.mod you want to patch).

set -e

OVERRIDES="${1:-go-mod-overrides}"

if [ ! -f "${OVERRIDES}" ]; then
    echo "go-mod-overrides: no overrides file at '${OVERRIDES}', nothing to do" >&2
    exit 0
fi

if [ ! -f go.mod ]; then
    echo "go-mod-overrides: no go.mod found in $(pwd)" >&2
    exit 1
fi

# Read line by line; strip comments and surrounding whitespace; pass the rest
# straight to `go mod edit`. Module paths/versions contain no whitespace, so the
# intentional word-splitting of ${line} cleanly separates the flag from its arg.
while IFS= read -r line || [ -n "${line}" ]; do
    line="${line%%#*}"
    # Trim leading/trailing whitespace (pure POSIX sh; avoids external deps like sed).
    line=${line#"${line%%[![:space:]]*}"}
    line=${line%"${line##*[![:space:]]}"}
    [ -z "${line}" ] && continue
    echo "go-mod-overrides: go mod edit ${line}"
    # shellcheck disable=SC2086
    go mod edit ${line}
done < "${OVERRIDES}"

# Reconcile the module graph and re-vendor only if upstream vendors its deps.
go mod tidy
if [ -d vendor ]; then
    go mod vendor
fi

echo "go-mod-overrides: applied overrides from '${OVERRIDES}'"
