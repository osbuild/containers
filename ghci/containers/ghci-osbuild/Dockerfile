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

# Import container arguments (must be before any `FROM`).
ARG     CI_HOST="docker.io/library/fedora:latest"

# Fetch our host environment.
FROM    "${CI_HOST}" AS host

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
                        bash \
                        coreutils \
                        curl \
                        dnf \
                        dnf-plugins-core \
                        e2fsprogs \
                        findutils \
                        git \
                        glibc \
                        iproute \
                        make \
                        nbd \
                        nbd-cli \
                        ostree \
                        policycoreutils \
                        pylint \
                        python-rpm-macros \
                        python3-docutils \
                        python3-devel \
                        python3-jsonschema \
                        python3-pylint \
                        python3-rpm-generators \
                        python3-rpm-macros \
                        qemu-img \
                        qemu-system-x86 \
                        rpm \
                        rpm-build \
                        rpm-ostree \
                        rpmdevtools \
                        systemd \
                        systemd-container \
                        tar \
                        util-linux \
        && dnf clean all

# Create our working environment.
COPY    ci /ci
ENTRYPOINT ["/ci/entrypoint.sh"]
WORKDIR /ci/workdir
