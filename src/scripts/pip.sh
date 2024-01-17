#!/bin/bash

#
# This script is a pip package install helper for container images. It takes
# packages as argument and then installs them via `pip3`.
#

set -eox pipefail

OSB_IFS=$IFS

#
# Parse command-line arguments into local variables. We accept:
#   @1: Comma-separated list of packages to install.
#

if (( $# > 0 )) ; then
        IFS=',' read -r -a PIP_PACKAGES <<< "$1"
        IFS=$OSB_IFS
fi
if (( $# > 1 )) ; then
        echo >&2 "ERROR: invalid number of arguments"
        exit 1
fi

#
# Install the specified packages.
#

if (( ${#PIP_PACKAGES[@]} )) ; then
        pip3 install --upgrade "${PIP_PACKAGES[@]}"
fi
