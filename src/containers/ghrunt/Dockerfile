#
# Ghrunt - GitHub-Actions-Runner Terminal
#
# This container packs the GitHub-Actions-Runner with all dependencies
# bundled. It can be deployed as a terminal application to serve a
# configured GitHub account as CI runner. See the GitHub-Actions-Runner
# documentation for details on how the runner works.
#
# This container simple fetches the latest release from GitHub and
# unpacks it into a container with all dependencies installed. An
# entrypoint is provided, which acquires the correct tokens and babysits
# the runner.
#
# Arguments:
#
#   * GHRUNT_HOST="docker.io/library/fedora:latest"
#       The host container to use as base.
#
#   * GHRUNT_GH_VERSION="2.272.0"
#       Version of the GitHub-Runner application.
#

# Import container arguments (must be before any `FROM`).
ARG     GHRUNT_HOST="docker.io/library/fedora:latest"

# Fetch our host environment.
FROM    "${GHRUNT_HOST}" AS host

# Import arguments.
ARG     GHRUNT_GH_VERSION="2.272.0"

# Update local system, install groups and dependencies.
RUN     dnf \
                -y \
                --nodocs \
                --setopt=fastestmirror=True \
                upgrade \
        && dnf \
                -y \
                --nodocs \
                --setopt=fastestmirror=True \
                group install \
                        "Development Tools" \
                        "RPM Development Tools" \
        && dnf \
                -y \
                --nodocs \
                --setopt=fastestmirror=True \
                install \
                        "awscli" \
                        "bash" \
                        "ca-certificates" \
                        "coreutils" \
                        "curl" \
                        "dnf" \
                        "dnf-plugins-core" \
                        "docker" \
                        "e2fsprogs" \
                        "findutils" \
                        "git" \
                        "glibc" \
                        "iproute" \
                        "make" \
                        "ostree" \
                        "policycoreutils" \
                        "pylint" \
                        "python-rpm-macros" \
                        "python3-docutils" \
                        "python3-devel" \
                        "python3-jsonschema" \
                        "python3-rpm-generators" \
                        "python3-rpm-macros" \
                        "qemu-img" \
                        "qemu-system-x86" \
                        "rpm" \
                        "rpm-build" \
                        "rpm-ostree" \
                        "rpmdevtools" \
                        "sudo" \
                        "systemd" \
                        "systemd-container" \
                        "tar" \
                        "unzip" \
                        "util-linux" \
        && dnf clean all

# Create working directories.
RUN     mkdir -p /ghrunt/{src,runner,workdir}

# Download GitHub-Actions-Runner.
RUN     curl \
                -L \
                "https://github.com/actions/runner/releases/download/v${GHRUNT_GH_VERSION}/actions-runner-linux-x64-${GHRUNT_GH_VERSION}.tar.gz" \
                >/ghrunt/runner/actions-runner-linux.tar.gz
RUN     tar -xvz -C /ghrunt/runner -f /ghrunt/runner/actions-runner-linux.tar.gz
RUN     rm /ghrunt/runner/actions-runner-linux.tar.gz
RUN     /ghrunt/runner/bin/installdependencies.sh

# Configure runtime user.
RUN     useradd -m ghrunt
RUN     chown -R ghrunt /ghrunt
USER    ghrunt

# Import custom sources.
COPY    src /ghrunt/src

# Configure entrypoint.
ENTRYPOINT ["/ghrunt/src/entrypoint.py"]
WORKDIR /ghrunt/runner
