#
# ghci-koji - Contained Koji Instance
#
# This images provides a Koji instance (Fedora Package Building Infrastructure)
# for local testing purposes. User/password and GSSAPI authentication methods
# are available.
#
# Run-time environment variables (all mandatory):
#
#   * POSTGRES_HOST      - PostgreSQL hostname
#   * POSTGRES_USER      - PostgreSQL username
#   * POSTGRES_PASSWORD  - PostgreSQL password
#   * POSTGRES_DB        - PostgreSQL database name
#
# Also, the user of this container has to provide several files:
#
#   * /share/koji.keytab - Kojihub Kerberos keytab, see the next paragraph
#   * /share/crt.pem     - TLS certificate (for HTTPS)
#   * /share/key.pem     - TLS private key (for HTTPS)
#
# Kojihub Kerberos keytab must contain HTTP/[DOMAIN]@[REALM] principal.
# DOMAIN must be substituted by a domain name on which the kojihub is running,
# REALM needs to be substitued with a Kerberos realm name.
#
# Note that this principal enables only the newer GSSAPI/SPNEGO authentication
# (performed by Apache's mod_auth_gssapi module). If you need the legacy
# "plain" Kerberos authentication, you also need host/kojihub@[REALM]
#  principal. This authentication method wasn't tested though.
#
# See https://docs.pagure.org/koji/server_howto/#principals-and-keytabs for
# more information.
#

FROM docker.io/library/fedora:latest

# koji db schema is in docs, remove nodocs from from dnf config
RUN sed  -i '/^tsflags=nodocs$/d' /etc/dnf/dnf.conf

RUN dnf -y upgrade \
    && dnf -y \
            --setopt=fastestmirror=True \
            --setopt=install_weak_deps=False \
            install \
                    koji-hub \
                    postgresql \
                    mod_ssl \
    && dnf clean all

RUN mkdir -p /mnt/koji/{packages,repos,work,scratch,repos-dist}

RUN chown -R apache:apache /mnt/koji

COPY ci/run-koji.sh /ci/

ENTRYPOINT /ci/run-koji.sh
