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
                "osbuild-ci-latest",
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

/*
 * We keep building f32 images for osbuild-ci, since we have not yet migrated
 * the CI to F33. This allows to keep the images up to date, while still
 * avoiding an upgrade to F33.
 */
target "osbuild-ci-f32" {
        args = {
                OSB_FROM = "docker.io/library/fedora:32",
        }
        inherits = [
                "virtual-osbuild-ci",
        ]
        tags = concat(
                mirror("osbuild-ci", "f32", "latest", OSB_UNIQUEID),
        )
}

target "osbuild-ci-latest" {
        args = {
                OSB_FROM = "docker.io/library/fedora:latest",
        }
        inherits = [
                "virtual-osbuild-ci",
        ]
        tags = concat(
                mirror("osbuild-ci", "latest", "", OSB_UNIQUEID),
        )
}
