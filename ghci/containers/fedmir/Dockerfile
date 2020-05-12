#
# FedMir - Fedora Package Mirror
#
# This container builds an HTTP Package Mirror for fedora package repositories.
# It builds a package repository with the selected set of packages, the
# specified target release version, as well as the specified architecture. It
# then uses the official `httpd` container to serve this repository via HTTP.
#
# Arguments:
#
#   * FEDMIR_ARCH=?
#       This controls the architecture of the packages to fetch.
#
#   * FEDMIR_BUILD="docker.io/library/fedora:latest"
#       This controls the build-container used to fetch fedora packages and
#       setup the package repository. By default, it uses the latest stable
#       release of the official fedora containers.
#
#   * FEDMIR_HOST="docker.io/library/httpd:2.4"
#       This controls the host-container used to serve the fedora package
#       mirror.
#
#   * FEDMIR_PACKAGES=?
#       Specify the packages to include in the mirror. Separate packages by
#       space. All their dependencies will be included in the mirror.
#
#   * FEDMIR_RELEASE=?
#       This controls the Fedora release used as base for this mirror. The
#       packages will be fetched from the official Fedora repositories of the
#       specified release.
#

# Import container arguments (must be before any `FROM`).
ARG     FEDMIR_BUILD="docker.io/library/fedora:latest"
ARG     FEDMIR_HOST="docker.io/library/httpd:2.4"

# Fetch our build environment.
FROM    "${FEDMIR_BUILD}" AS build

# Import our mirror parameters.
ARG     FEDMIR_ARCH
ARG     FEDMIR_PACKAGES
ARG     FEDMIR_RELEASE

# Prepare our package repository in /srv.
ENV     FEDMIR_PATH "/srv/www/fedmir/fedora-${FEDMIR_RELEASE}/arch-${FEDMIR_ARCH}/"
RUN     mkdir -p "${FEDMIR_PATH}"/{packages,root}

# Update DNF and install our setup utilities.
RUN     dnf -y upgrade \
        && dnf -y install \
                "createrepo" \
        && dnf clean all

# Fetch all packages we want to mirror.
RUN     dnf -y install \
                --downloaddir="${FEDMIR_PATH}/packages" \
                --downloadonly \
                --forcearch="${FEDMIR_ARCH}" \
                --installroot="${FEDMIR_PATH}/root" \
                --releasever="${FEDMIR_RELEASE}" \
                --setopt="module_platform_id=platform:f${FEDMIR_RELEASE}" \
                \
                --disablerepo="*" \
                --enablerepo="fedora" \
                -- \
                        ${FEDMIR_PACKAGES}

# Delete whatever `dnf` put into the `installroot`.
RUN     rm -rf "${FEDMIR_PATH}/root"

# Build repository metadata.
RUN     createrepo "${FEDMIR_PATH}"

# Fetch our host environment.
FROM    "${FEDMIR_HOST}" AS host

# Clear HTTP service directory.
RUN     rm -rf "/usr/local/apache2/htdocs"
RUN     mkdir -p "/usr/local/apache2/htdocs"

# Copy the files to serve.
COPY    --from=build \
        "/srv/www/" \
        "/usr/local/apache2/htdocs/"
