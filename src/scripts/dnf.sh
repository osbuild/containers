#!/bin/bash

#
# This script is a DNF package and comp-group install helper for container
# images. It takes packages and comp-groups as arguments and then installs
# them via `dnf`.
#

set -eox pipefail

OSB_IFS=$IFS

#
# Parse command-line arguments into local variables. We accept:
#   @1: Comma-separated list of packages to install.
#   @2: Comma-separated list of comp-groups to install.
#   @3: 0 or 1 to enable or disable --allowerasing when installing packages.
#       Disabled by default. (optional)
#

if (( $# > 0 )) ; then
        IFS=',' read -r -a OSB_PACKAGES <<< "$1"
        IFS=$OSB_IFS
fi
if (( $# > 1 )) ; then
        IFS=',' read -r -a OSB_GROUPS <<< "$2"
        IFS=$OSB_IFS
fi
if (( $# > 2 )) ; then
        if [[ ! $3 =~ ^[01]$ ]] ; then
                echo >&2 "ERROR: invalid value for the third argument '$3'"
                echo >&2 "       only 0 or 1 are allowed"
                exit 1
        fi
fi
if (( $# > 3 )) ; then
        echo >&2 "ERROR: invalid number of arguments"
        exit 1
fi

ALLOW_ERASING=${3:-0}

#
# Clean all caches so we force a metadata refresh. Then make sure to update
# the system to avoid unsynchronized installs. Note that we force a metadata
# refresh so all our installs share the same metadata. This gets as close to
# deterministic RPM behavior as possible, without crazy workarounds. If
# immutable RPM repositories ever become available, we should switch to it.
#

dnf clean all
dnf -y upgrade

#
# Install the specified packages and groups. We install the groups as second
# step to keep the number of duplicate installs low.
#

EXTRA_ARGS=""

if [[ "$ALLOW_ERASING" == 1 ]] ; then
        EXTRA_ARGS+=" --allowerasing"
fi

DNF_VERSION=$(rpm -q --whatprovides dnf --qf "%{VERSION}\n")
POSITIONAL_OPS_DELIMITER="--"
# We can't use -- with DNF5 until https://github.com/rpm-software-management/dnf5/issues/1848 is fixed.
if [[ "${DNF_VERSION%%.*}" -ge 5 ]] ; then
        POSITIONAL_OPS_DELIMITER=""
fi

if (( ${#OSB_PACKAGES[@]} )) ; then
        dnf -y \
                --nodocs \
                --setopt=fastestmirror=True \
                --setopt=install_weak_deps=False \
                $EXTRA_ARGS \
                install \
                $POSITIONAL_OPS_DELIMITER "${OSB_PACKAGES[@]}"
fi

if (( ${#OSB_GROUPS[@]} )) ; then
        dnf -y \
                --nodocs \
                --setopt=fastestmirror=True \
                --setopt=install_weak_deps=False \
                $EXTRA_ARGS \
                group install \
                $POSITIONAL_OPS_DELIMITER "${OSB_GROUPS[@]}"
fi

#
# As last step clean all the metadata again. It will at some point be outdated
# and refreshed at a random time. Hence, make sure to clear it so we avoid
# accidentally using it later on. We want all installs to happen in this script
# so we can rely on the content later on.
#

dnf clean all
