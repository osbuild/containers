#
# rpmrepo-snapshot - RPMrepo Snapshot Creation
#
# This image provides the necessary tools to create snapshots and store them
# in the RPMrepo storage system.
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

ARG             OSB_FROM="docker.io/library/fedora:40"
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
COPY            src/scripts/rpmrepo-snapshot.sh .

# This is needed for DNF to be able to verify the TLS cert on some internal repos
# Embedding the cert in the container has been consulted with RH InfoSec.
COPY            src/config/2015-IT-Root-CA.pem /etc/pki/ca-trust/source/anchors/2015-IT-Root-CA.pem
COPY            src/config/2022-IT-Root-CA.pem /etc/pki/ca-trust/source/anchors/2022-IT-Root-CA.pem
RUN             update-ca-trust

RUN             rm -rf /osb/src

#
# Rebuild from scratch to drop all intermediate layers and keep the final image
# as small as possible. Then setup the entrypoint.
#

FROM            scratch
COPY            --from=target . .

WORKDIR         /osb/workdir
ENTRYPOINT      ["/osb/rpmrepo-snapshot.sh"]
