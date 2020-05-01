#!/bin/bash
set -euxo pipefail

echo "Building container ${CONTAINER_NAME}..."

if [[ ! -x /usr/bin/buildah ]] || [[ ! -x /usr/bin/podman ]]; then
    sudo dnf -y install buildah podman runc
    podman system prune -af
fi

if [[ ${CHANGE_BRANCH:-master} == "master" ]]; then
    CONTAINER_TAG=latest
else
    CONTAINER_TAG=${CHANGE_BRANCH}
fi

buildah bud \
    -f builds/${CONTAINER_NAME} \
    -t quay.io/osbuild/${CONTAINER_NAME}:${CONTAINER_TAG} .

buildah  login --username ${QUAY_CREDS_USR} --password ${QUAY_CREDS_PSW} quay.io
buildah --log-level info push quay.io/osbuild/${CONTAINER_NAME}:${CONTAINER_TAG}