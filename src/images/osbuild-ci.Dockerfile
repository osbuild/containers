#
# osbuild-ci - OSBuild CI Images
#
# This image provides the OS environment for the osbuild continuous integration
# on GitHub Actions. It is based on Fedora and includes all the required
# packages and utilities.
#
# Arguments:
#
#   * OSB_FROM="docker.io/library/fedora:latest"
#       This controls the host container used as base for the CI image.
#
#   * OSB_DNF_PACKAGES=""
#       Specify the packages to install into the container. Separate packages
#       by comma. By default, no package is pulled in.
#
#   * OSB_DNF_GROUPS=""
#       Specify the package groups to install into the container. Separate
#       groups by comma. By default, no group is pulled in.
#

ARG             OSB_FROM="docker.io/library/fedora:latest"
FROM            "${OSB_FROM}" AS target

#
# Import our build sources and prepare the target environment. When finished,
# we drop the build sources again, to keep the target image small.
#

WORKDIR         /osb
COPY            src src

ARG             OSB_DNF_PACKAGES=""
ARG             OSB_DNF_GROUPS=""
RUN             ./src/scripts/dnf.sh "${OSB_DNF_PACKAGES}" "${OSB_DNF_GROUPS}"
COPY            src/scripts/osbuild-ci.sh .

RUN             rm -rf /osb/src

#
# Rebuild from scratch to drop all intermediate layers and keep the final image
# as small as possible. Then setup the entrypoint.
#

FROM            scratch
COPY            --from=target . .

WORKDIR         /osb/workdir
ENTRYPOINT      ["/osb/osbuild-ci.sh"]
