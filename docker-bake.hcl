/*
 * OSB_UNIQUEID - Unique Identifier
 *
 * If provided by the caller, this ID must be unique across all builds. It
 * is used to tag immutable images and make them available to external
 * users.
 *
 * If not provided (i.e., an empty string), no such unique tags will be pushed.
 *
 * A common way to generate this ID is to use UUIDs, or to use the current date
 * (e.g., `20210101`).
 *
 * Note that we strongly recommend external users to access images by digest
 * rather than this tag. We mostly use the unique tag to guarantee the image
 * stays available in the registry and is not garbage-collected.
 */

variable "OSB_UNIQUEID" {
        /*
         * XXX: This should be `null` instead of an empty string, but current
         *      `xbuild+HCL` does not support that.
         */
        default = ""
}

/*
 * Mirroring
 *
 * The custom `mirror()` function takes an image name, an image tag, an
 * optional tag-suffix, as well as an optional unique suffix. It then produces
 * an array of tags for all the configured hosts.
 *
 * If the unique suffix is not empty, an additional tag with the unique suffix
 * is added for each host (replacing the specified suffix). In other words,
 * this function concatenates the configured host with the specified image,
 * tag, "-" and suffix or unique-suffix. The dash is skipped if the suffix is
 * empty.
 */

function "mirror" {
        params = [image, tag, suffix, unique]

        result = flatten([
                for host in [
                        "ghcr.io/osbuild",
                        "quay.io/osbuild",
                ] : concat(
                        notequal(suffix, "") ?
                                ["${host}/${image}:${tag}-${suffix}"] :
                                ["${host}/${image}:${tag}"],
                        notequal(unique, "") ?
                                ["${host}/${image}:${tag}-${unique}"] :
                                [],
                )
        ])
}

/*
 * Target Groups
 *
 * The following section defines some custom target groups, which we use in
 * the CI system to rebuild a given set of images.
 *
 *     all-images
 *         Build all "product" images. That is, all images that are part of
 *         the project release and thus used by external entities.
 */

group "all-images" {
        targets = [
                "all-kdc",
                "all-koji",
                "all-nfsd",
                "all-osbuild-ci",
                "all-postgres",
                "all-rpmrepo-ci",
                "all-rpmrepo-snapshot",
                "all-cloud-tools",
        ]
}

/*
 * Virtual Base Targets
 *
 * This section defines virtual base targets, which are shared across the
 * different dependent targets.
 */

target "virtual-default" {
        context = "."
        labels = {
                "org.opencontainers.image.source" = "https://github.com/osbuild/containers",
        }
}

target "virtual-platforms" {
        platforms = [
                "linux/amd64",

                /*
                 * The following architectures are possible to build, but are
                 * currently not used by anyone, so we skip their build. Note
                 * that they will most likely be built via qemu-user, so this
                 * is really something to debate for production.
                 *
                 * "linux/arm64",
                 * "linux/ppc64le",
                 * "linux/s390x",
                 */
        ]
}

/*
 * kdc - Kerberos Key Distribution Center
 *
 * The following groups and targets build the kdc images, a simple way to get
 * Kerberos Key Distribution Centers up and running for testing.
 */

group "all-kdc" {
        targets = [
                "kdc-latest",
        ]
}

target "virtual-kdc" {
        dockerfile = "src/images/kdc.Dockerfile"
        inherits = [
                "virtual-default",
                "virtual-platforms",
        ]
}

target "kdc-latest" {
        inherits = [
                "virtual-kdc",
        ]
        tags = concat(
                mirror("kdc", "latest", "", OSB_UNIQUEID),
        )
        platforms = [
                "linux/amd64",
                "linux/arm64",
        ]
}

/*
 * koji - Koji Build Server
 *
 * The following groups and targets build the koji images, a simple way to get
 * Koji RPM Build Server up and running for testing.
 */

group "all-koji" {
        targets = [
                "koji-latest",
        ]
}

target "virtual-koji" {
        dockerfile = "src/images/koji.Dockerfile"
        inherits = [
                "virtual-default",
                "virtual-platforms",
        ]
}

target "koji-latest" {
        inherits = [
                "virtual-koji",
        ]
        tags = concat(
                mirror("koji", "latest", "", OSB_UNIQUEID),
        )
        platforms = [
                "linux/amd64",
                "linux/arm64",
        ]
}

/*
 * nfsd - NFS Daemon
 *
 * The following groups and targets build the nfsd images, a simple
 * containerized way to export file-systems via NFS.
 */

group "all-nfsd" {
        targets = [
                "nfsd-latest",
        ]
}

target "virtual-nfsd" {
        dockerfile = "src/images/nfsd.Dockerfile"
        inherits = [
                "virtual-default",
                "virtual-platforms",
        ]
}

target "nfsd-latest" {
        args = {
                OSB_FROM = "docker.io/almalinux/9-init:latest",
        }
        inherits = [
                "virtual-nfsd",
        ]
        tags = concat(
                mirror("nfsd", "latest", "", OSB_UNIQUEID),
        )
}

/*
 * osbuild-ci - OSBuild CI Images
 *
 * The following groups and targets build the CI images used by osbuild. They
 * build on the official fedora and cXs images.
 *
 * The `osbuild-ci-cXs-latest` images are missing some packages, compared to
 * the `osbuild-ci-latest` image, because they are not available in
 * the cXs repositories. The intention is to use them only to run unit
 * tests in osbuild upstream. The Fedora image should be used for all the
 * other tests, such as linters and running unit tests on multiple Python
 * versions.
 *
 * NB: Docker bake HCL does not support definig arrays as a variable or calling
 * functions in variable definitions, so we need to duplicate the package list
 * in Fedora and cXs targets.
 */

group "all-osbuild-ci" {
        targets = [
                "osbuild-ci-latest",
                "osbuild-ci-c8s-latest",
                "osbuild-ci-c9s-latest",
        ]
}

target "virtual-osbuild-ci-base" {
        args = {
                OSB_DNF_PACKAGES = join(",", [
                        "bash",
                        "btrfs-progs",
                        "bubblewrap",
                        "coreutils",
                        "cryptsetup",
                        "curl",
                        "dnf",
                        "dnf-plugins-core",
                        "dosfstools",
                        "e2fsprogs",
                        "findutils",
                        "git",
                        "glibc",
                        "iproute",
                        "lvm2",
                        "make",
                        "nbd",
                        "nbd-cli",
                        "ostree",
                        "pacman",
                        "podman",
                        "policycoreutils",
                        "pylint",
                        "python-rpm-macros",
                        "python3.6",
                        "python3.7",
                        "python3.8",
                        "python3.9",
                        "python3.10",
                        "python3.12",
                        "python3-autopep8",
                        "python3-boto3",
                        "python3-botocore",
                        "python3-docutils",
                        "python3-devel",
                        "python3-iniparse",
                        "python3-isort",
                        "python3-jsonschema",
                        "python3-librepo",
                        "python3-libdnf5",
                        "python3-mako",
                        "python3-mypy",
                        "python3-pip",
                        "python3-pylint",
                        "python3-pytest",
                        "python3-pytest-cov",
                        "python3-pyyaml",
                        "python3-rpm-generators",
                        "python3-rpm-macros",
                        "qemu-img",
                        "qemu-system-x86",
                        "rpm",
                        "rpm-build",
                        "rpm-ostree",
                        "rpmdevtools",
                        "skopeo",
                        "systemd",
                        "systemd-container",
                        "tar",
                        "tox",
                        "util-linux",
                ]),
                OSB_DNF_GROUPS = join(",", [
                        "development tools",
                        "rpm-development-tools",
                ]),
        }
        dockerfile = "src/images/osbuild-ci.Dockerfile"
        inherits = [
                "virtual-default",
                "virtual-platforms",
        ]
}

target "osbuild-ci-latest" {
        args = {
                OSB_FROM = "registry.fedoraproject.org/fedora:latest",
        }
        inherits = [
                "virtual-osbuild-ci-base",
        ]
        tags = concat(
                mirror("osbuild-ci", "latest", "", OSB_UNIQUEID),
        )
}

target "virtual-osbuild-ci-cXs" {
        args = {
                OSB_DNF_PACKAGES = join(",", [
                        "bash",
                        //"btrfs-progs",         // not available in cXs
                        "bubblewrap",
                        "coreutils",
                        "cryptsetup",
                        "curl",
                        "dnf",
                        "dnf-plugins-core",
                        "dosfstools",
                        "e2fsprogs",
                        "findutils",
                        "git",
                        "glibc",
                        "iproute",
                        "lvm2",
                        "make",
                        //"nbd",                 // not available in cXs
                        //"nbd-cli",             // not available in cXs
                        "ostree",
                        //"pacman",              // not available in cXs
                        "policycoreutils",
                        //"pylint",              // not available in cXs
                        "python-rpm-macros",
                        "python3",               // install just the default version
                        //"python3.6",
                        //"python3.7",
                        //"python3.8",
                        //"python3.9",
                        //"python3.10",
                        //"python3.12",
                        //"python3-autopep8",    // not available in cXs
                        //"python3-boto3",       // not available in cXs
                        //"python3-botocore",    // not available in cXs
                        //"python3-docutils",    // not available in cXs
                        "python3-devel",
                        "python3-iniparse",
                        //"python3-isort",       // not available in cXs
                        "python3-jsonschema",
                        "python3-librepo",
                        "python3-mako",
                        //"python3-mypy",        // not available in cXs
                        "python3-pip",
                        //"python3-pylint",      // not available in cXs
                        //"python3-pytest",      // too old in cXs
                        //"python3-pytest-cov",  // not available in cXs
                        "python3-pyyaml",
                        "python3-rpm-generators",
                        "python3-rpm-macros",
                        "qemu-img",
                        //"qemu-system-x86",     // not available in cXs
                        "rpm",
                        "rpm-build",
                        "rpm-ostree",
                        "rpmdevtools",
                        "skopeo",
                        "systemd",
                        "systemd-container",
                        "tar",
                        //"tox",                 // not available in cXs
                        "util-linux",
                        "fuse-overlayfs",
                ]),
                OSB_PIP_PACKAGES = join(",", [
                        "autopep8",
                        "boto3",
                        "botocore",
                        "docutils",
                        "isort",
                        "mypy",
                        "pylint",
                        "pytest",
                        "pytest-cov",
                        "tox",
                ]),
                OSB_DNF_ALLOW_ERASING = 1,
        }
        dockerfile = "src/images/osbuild-ci-cstream.Dockerfile"
        inherits = [
                "virtual-osbuild-ci-base",
        ]
}

target "osbuild-ci-c8s-latest" {
        args = {
                OSB_FROM = "quay.io/centos/centos:stream8",
        }
        inherits = [
                "virtual-osbuild-ci-cXs",
        ]
        tags = concat(
                mirror("osbuild-ci-c8s", "latest", "", OSB_UNIQUEID),
        )
}

target "osbuild-ci-c9s-latest" {
        args = {
                OSB_FROM = "quay.io/centos/centos:stream9",
        }
        inherits = [
                "virtual-osbuild-ci-cXs",
        ]
        tags = concat(
                mirror("osbuild-ci-c9s", "latest", "", OSB_UNIQUEID),
        )
}

/*
 * postgres - PostgreSQL Mirror
 *
 * The following groups and targets build the PostgreSQL images. They mostly
 * just mirror the official images in our own repositories.
 */

group "all-postgres" {
        targets = [
                "postgres-13-alpine",
        ]
}

/*
 * Currently postgres is the only image that needs
 * arm64. If this changes, so it doesn't use virtual-platforms
 */
target "virtual-postgres" {
        dockerfile = "src/images/postgres.Dockerfile"
        inherits = [
                "virtual-default",
        ]
        platforms = [
                "linux/amd64",
                "linux/arm64",
        ]
}

target "postgres-13-alpine" {
        inherits = [
                "virtual-postgres",
        ]
        tags = concat(
                mirror("postgres", "13-alpine", "", OSB_UNIQUEID),
        )
}

/*
 * cloud-tools - Images with Cloud CLI tools
 *
 * The following groups and targets build the "cloud tools" images used by
 * osbuild-composer CI. They build on the official fedora images.
 */

group "all-cloud-tools" {
        targets = [
                "cloud-tools-latest",
        ]
}

target "virtual-cloud-tools" {
        args = {
                OSB_DNF_PACKAGES = join(",", [
                        "google-cloud-sdk",
                        "libxcrypt-compat", 
                        "azure-cli",
                        "awscli",
                        "openssh-clients",
                ]),
        }
        dockerfile = "src/images/cloud-tools.Dockerfile"
        inherits = [
                "virtual-default",
        ]
        platforms = [
                "linux/amd64",
                "linux/arm64",
        ]
}

target "cloud-tools-latest" {
        args = {
                OSB_FROM = "docker.io/library/fedora:latest",
        }
        inherits = [
                "virtual-cloud-tools",
        ]
        tags = concat(
                mirror("cloud-tools", "latest", "", OSB_UNIQUEID),
        )
}

/*
 * rpmrepo-ci - RPMrepo CI Images
 *
 * The following groups and targets build the CI images used by RPMrepo. They
 * build on the official fedora images.
 */

group "all-rpmrepo-ci" {
        targets = [
                "rpmrepo-ci-latest",
        ]
}

target "virtual-rpmrepo-ci" {
        args = {
                OSB_DNF_PACKAGES = join(",", [
                        "python3-boto3",
                        "python3-botocore",
                        "python3-pylint",
                        "python3-pytest",
                        "python3-requests",
                ]),
        }
        dockerfile = "src/images/rpmrepo-ci.Dockerfile"
        inherits = [
                "virtual-default",
                "virtual-platforms",
        ]
}

target "rpmrepo-ci-latest" {
        args = {
                OSB_FROM = "docker.io/library/fedora:latest",
        }
        inherits = [
                "virtual-rpmrepo-ci",
        ]
        tags = concat(
                mirror("rpmrepo-ci", "latest", "", OSB_UNIQUEID),
        )
}

/*
 * rpmrepo-snapshot - RPMrepo Snapshot Creation
 *
 * The following groups and targets build the snapshot images used by RPMrepo.
 * They build on the official fedora images.
 */

group "all-rpmrepo-snapshot" {
        targets = [
                "rpmrepo-snapshot-latest",
        ]
}

target "virtual-rpmrepo-snapshot" {
        args = {
                OSB_DNF_PACKAGES = join(",", [
                        "curl",
                        "dnf-command(reposync)",
                        "git",
                        "jq",
                        "python3-boto3",
                        "python3-devel",
                ]),
        }
        dockerfile = "src/images/rpmrepo-snapshot.Dockerfile"
        inherits = [
                "virtual-default",
                "virtual-platforms",
        ]
}

target "rpmrepo-snapshot-latest" {
        args = {
                OSB_FROM = "docker.io/library/fedora:latest",
        }
        inherits = [
                "virtual-rpmrepo-snapshot",
        ]
        tags = concat(
                mirror("rpmrepo-snapshot", "latest", "", OSB_UNIQUEID),
        )
}
