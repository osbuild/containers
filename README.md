OSBuild Containers
==================

Containers for the OSBuild Project

This repository contains sources for containers used by the OSBuild project and
its associated infrastructure. Furthermore, it contains auxiliary resources
used with these containers.

### Project

 * **Website**: <https://www.osbuild.org>
 * **Bug Tracker**: <https://github.com/osbuild/containers/issues>

### Requirements

The requirements for this project are:

 * `docker >= 19.03`

### Build

This project contains makefile with predefined targets which allows
easy building of defined images.

If not specified, the default `IMG_TARGET` is set to `osbuild-ci-latest`

Example usage:

```sh
# Prepare host environment
make setup-builder

# Show abailable targets
make list-targets

# Show details of particular target
make inspect-target IMG_TARGET=osbuild-ci-latest

# Build selected target
make bake IMG_TARGET=osbuild-ci-latest
```

### Manual build

Container images in `./src/images/` are built via Docker BuildKit. The build
instructions are available in `./docker-bake.hcl`, and can be executed via
`docker buildx bake`. To build **all** targets, use:

```sh
docker buildx bake all-images
```

Replace `all-images` with a specific target or group if you only want to
build a subset of all images. The `--print` argument is useful to print the
build-configuration instead of actually building anything:

```sh
docker buildx bake --print all-images
```

The CI system will build and verify all images on every PR. However, it will
not store the images by default. Only if you trigger an explicit deployment
the images will be stored in a registry. To trigger a deployment, go to the
`CI for Image Builds` workflow on GitHub:

<https://github.com/osbuild/containers/actions/workflows/ci-images.yml>

Then click `Run Workflow`, specify the target (or `all-images`) and submit
it. This will build all images and push them out with a new unique tag. The
images are stored on the GitHub Container Registry and mirrored on Quay. To
make use of those images, go to `ghcr.io/osbuild/<image>` and checkout the
new tag. Alternatively, you can resolve the digest of the `-latest` tags to
get the digest of the latest build.

Apart from the individual build targets, there are target groups for easier
selection of a subset of images. Those target groups always start with
`all-*` and build a set of images. The `all-images` target group, for instance,
builds all available images. However, check out `./docker-bake.hcl` for other
target groups. Usually, there will be a `all-<name>` target group corresponding
to `./src/images/<name>.Dockerfile`, which will build all supported
configurations of a specific image.

### Repository:

 - **web**:   <https://github.com/osbuild/containers>
 - **https**: `https://github.com/osbuild/containers.git`
 - **ssh**:   `git@github.com:osbuild/containers.git`

### License:

 - **Apache-2.0**
 - See LICENSE file for details.
