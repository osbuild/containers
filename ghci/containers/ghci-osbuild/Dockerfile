#
# ghci-osbuild - GitHub-CI for OSBuild
#
# This image provides the OS environment for the osbuild continuous integration
# on GitHub Actions. It is based on Fedora and includes all the required
# packages and utilities.
#
# Arguments:
#
#   * CI_HOST="docker.io/library/fedora:latest"
#       This controls the host container used as base for the CI image.
#
#   * CI_PACKAGES=?
#       Specify the packages to include in the image. Separate packages by
#       space. All their dependencies will be included as well.
#

# Import container arguments (must be before any `FROM`).
ARG     CI_HOST="docker.io/library/fedora:latest"

# Fetch our host environment.
FROM    "${CI_HOST}" AS host

# Import our image parameters.
ARG     CI_PACKAGES

# Update local system.
RUN     dnf \
                -y \
                --nodocs \
                --setopt=fastestmirror=True \
                --setopt=install_weak_deps=False \
                upgrade \
        && dnf clean all

# Install basic package groups.
RUN     dnf \
                -y \
                --nodocs \
                --setopt=fastestmirror=True \
                --setopt=install_weak_deps=False \
                group install \
                        'Development Tools' \
                        'RPM Development Tools' \
        && dnf clean all

# Install CI dependencies.
RUN     dnf \
                -y \
                --nodocs \
                --setopt=fastestmirror=True \
                --setopt=install_weak_deps=False \
                install \
                        ${CI_PACKAGES} \
        && dnf clean all

# Create our working environment.
COPY    ci /ci
ENTRYPOINT ["/ci/entrypoint.sh"]
WORKDIR /ci/workdir
