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
                "all-osbuild-ci",
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
 * osbuild-ci - OSBuild CI Images
 *
 * The following groups and targets build the CI images used by osbuild. They
 * build on the official fedora images.
 */

group "all-osbuild-ci" {
        targets = [
                "osbuild-ci-f32",
                "osbuild-ci-f33",
        ]
}

target "virtual-osbuild-ci" {
        args = {
                OSB_DNF_PACKAGES = join(",", [
                        "bash",
                        "bubblewrap",
                        "coreutils",
                        "curl",
                        "dnf",
                        "dnf-plugins-core",
                        "e2fsprogs",
                        "findutils",
                        "git",
                        "glibc",
                        "iproute",
                        "make",
                        "nbd",
                        "nbd-cli",
                        "ostree",
                        "policycoreutils",
                        "pylint",
                        "python-rpm-macros",
                        "python3-docutils",
                        "python3-devel",
                        "python3-iniparse",
                        "python3-jsonschema",
                        "python3-pylint",
                        "python3-pytest",
                        "python3-pytest-cov",
                        "python3-rpm-generators",
                        "python3-rpm-macros",
                        "qemu-img",
                        "qemu-system-x86",
                        "rpm",
                        "rpm-build",
                        "rpm-ostree",
                        "rpmdevtools",
                        "systemd",
                        "systemd-container",
                        "tar",
                        "util-linux",
                ]),
                OSB_DNF_GROUPS = join(",", [
                        "development-tools",
                        "rpm-development-tools",
                ]),
        }
        dockerfile = "src/images/osbuild-ci.Dockerfile"
        inherits = [
                "virtual-default",
                "virtual-platforms",
        ]
}

target "osbuild-ci-f32" {
        args = {
                OSB_FROM = "docker.io/library/fedora:32",
        }
        inherits = [
                "virtual-osbuild-ci",
        ]
        tags = [
                "ghcr.io/osbuild/osbuild-ci:f32-latest",
                notequal(OSB_UNIQUEID, "") ? "ghcr.io/osbuild/osbuild-ci:f32-${OSB_UNIQUEID}" : "",
        ]
}

target "osbuild-ci-f33" {
        args = {
                OSB_FROM = "docker.io/library/fedora:33",
        }
        inherits = [
                "virtual-osbuild-ci",
        ]
        tags = [
                "ghcr.io/osbuild/osbuild-ci:latest",
                "ghcr.io/osbuild/osbuild-ci:f33-latest",
                notequal(OSB_UNIQUEID, "") ? "ghcr.io/osbuild/osbuild-ci:f33-${OSB_UNIQUEID}" : "",
        ]
}
