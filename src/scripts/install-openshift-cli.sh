#!/bin/bash

set -eox pipefail

TEMPDIR=$(mktemp -d)

# WARNING: these will only work on x86_64

# https://docs.openshift.com/container-platform/4.13/cli_reference/openshift_cli/getting-started-cli.html
curl -L --insecure https://downloads-openshift-console.apps.ocp-virt.prod.psi.redhat.com/amd64/linux/oc.tar --output-dir "$TEMPDIR"
# https://docs.openshift.com/container-platform/4.13/virt/virt-using-the-cli-tools.html
curl -L --insecure https://hyperconverged-cluster-cli-download-openshift-cnv.apps.ocp-virt.prod.psi.redhat.com/amd64/linux/virtctl.tar.gz --output-dir "$TEMPDIR"

pushd "$TEMPDIR"
tar -xvf oc.tar
tar -xzvf virtctl.tar.gz
popd

cp "$TEMPDIR/oc" /root/bin
cp "$TEMPDIR/virtctl" /root/bin

chmod a+x /root/bin/*
