#
# kdc - Key Distribution Center for Kerberos
#
# This images provides a Key Distribution Center for Kerberos. The default
# realm name is LOCAL and it cannot be currently changed.
#
# Don't forget to open port 88 for UDP packets when creating a container from
# this image.
#
# The simplest way to use this container is to share a directory with it and
# use the following snippets to initialize some principals:
#
# Create a principal with a keytab:
#   docker exec CONTAINER kadmin.local -r LOCAL add_principal -randkey PRINCIPAL
#   docker exec CONTAINER kadmin.local -r LOCAL ktadd -k /share/keytab PRINCIPAL
#
# Create a principal with a password:
#   docker exec CONTAINER kadmin.local -r LOCAL add_principal PRINCIPAL
#
# Create a principal with a password without a prompt (warning: unsafe!):
#   docker exec CONTAINER kadmin.local -r LOCAL add_principal -pw PASSWORD PRINCIPAL
#
FROM docker.io/library/fedora:latest

RUN dnf -y upgrade \
    && dnf -y \
            --setopt=fastestmirror=True \
            --setopt=install_weak_deps=False \
            install krb5-server \
    && dnf clean all

COPY ci /ci/

ENV KRB5_CONFIG /ci/krb5.conf
ENV KRB5_KDC_PROFILE /ci/kdc.conf

ENTRYPOINT /ci/run-kdc.sh
