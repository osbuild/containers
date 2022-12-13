#
# nfsd - NFS-Daemon Utility Images
#
# This image runs the NFS Daemon and exports a configured file-system for NFS
# clients to mount. It is based on RHEL and only supports NFSv4.
#
# The exported root directory is `/srv/nfsd`. Bind your container volumes at
# this path to export them via NFS.
#
# Arguments:
#
#   * OSB_FROM="docker.io/almalinux/9-init:latest"
#       This controls the host container used as base for the CI image.
#

ARG             OSB_FROM="docker.io/almalinux/9-init:latest"
FROM            "${OSB_FROM}" AS target

#
# Import our build sources and prepare the target environment. When finished,
# we drop the build sources again, to keep the target image small.
#

WORKDIR         /osb
COPY            src src

RUN             ./src/scripts/dnf.sh "nfs-utils" ""

# Ensure the export-directory exists. Note that you likely need to mount your
# volumes there, otherwise the export is empty and has almost no disk space
# available. Lastly, it likely even fails since overlayfs lacks NFS support.
RUN             mkdir -p /srv/nfsd

# Configure the export-directory in /etc/exports for nfsd to pick up. We set
# it as default-FS and disable some security configurations that do not apply
# to containers. Note that root-squashing is enabled by default, though.
RUN             mkdir -p /etc
RUN             echo \
                        "/srv/nfsd *(rw,fsid=0,no_subtree_check,no_auth_nlm,insecure)" \
                        >/etc/exports

# Disable the nfs-server-generator. It is meant to order mount-jobs for exports
# before nfsd, but this just fails in containers so we silence the error by
# masking it.
RUN             mkdir -p /etc/systemd/system-generators
RUN             ln -s /dev/null /etc/systemd/system-generators/nfs-server-generator

# Enable the required daemons for NFS exports to work.
RUN             systemctl enable nfs-server rpcbind

RUN             rm -rf /osb/src

#
# Rebuild from scratch to drop all intermediate layers and keep the final image
# as small as possible. Then setup the entrypoint.
#

FROM            scratch
COPY            --from=target . .

EXPOSE          2049

STOPSIGNAL      SIGRTMIN+3
ENTRYPOINT      ["/sbin/init"]
