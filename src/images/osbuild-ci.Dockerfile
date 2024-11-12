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
#   * OSB_PIP_PACKAGES=""
#       Specify the packages to install into the container using pip. Separate
#       packages by comma. By default, no packages are installed.
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
ARG             OSB_PIP_PACKAGES=""
ARG             OSB_DNF_ALLOW_ERASING="0"
ARG             OSB_DNF_NOBEST="0"
RUN             ./src/scripts/dnf.sh "${OSB_DNF_PACKAGES}" "${OSB_DNF_GROUPS}" "${OSB_DNF_ALLOW_ERASING}" "${OSB_DNF_NOBEST}"
RUN             ./src/scripts/pip.sh "${OSB_PIP_PACKAGES}"
COPY            src/scripts/osbuild-ci.sh .

RUN             rm -rf /osb/src

#
# Allow cross-UID git access. Git users must be careful not to invoke git from
# within untrusted directory-paths.
#

RUN             git config --global --add safe.directory '*'

#
# Rebuild from scratch to drop all intermediate layers and keep the final image
# as small as possible. Then setup the entrypoint.
#

FROM            scratch
COPY            --from=target . .

#
# Drop the python version for which the python3-dnf package was installed.
# This is then used in osbuild tests to enable site-packages in the tox
# environment, when testing using the same python version.
#

RUN            rpm -ql python3-dnf | grep -E '/usr/lib/python.*/site-packages/dnf/' | cut -d '/' -f 4 | uniq | sed -E 's/python([0-9])\.([0-9]+)/py\1\2/' | tee /osb/libdnf-python-version

WORKDIR         /osb/workdir
ENTRYPOINT      ["/osb/osbuild-ci.sh"]
