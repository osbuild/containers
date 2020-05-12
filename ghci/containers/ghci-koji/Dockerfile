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
    && dnf clean all

RUN mkdir -p /mnt/koji/{packages,repos,work,scratch,repos-dist}

RUN chown -R apache:apache /mnt/koji

COPY ci/run-koji.sh /ci/

ENTRYPOINT /ci/run-koji.sh
