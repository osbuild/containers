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

Images for the containers in `./src/containers/<name>` can be built via the
rules found in `Makefile`. To build a specific image, use:

```sh
make img-build-<name>
```

The repository contains GitHub-Workflows that will automatically build images
for all containers on every push. If it is built on a branch/tag with name
`master`, `img/latest`, or `img/latest/<name>`, the image will be pushed to
the GitHub Packages registry of the repository it is built on (with the image
tag `latest`).

The `*/<name>` suffix causes the CI to only consider the matching container.
This allows having feature-branches for a specific container, and not always
rebuild all other images.

Similarly, if you push a branch/tag named `img/rc`, or `img/rc/<name>`, the
images will be built and pushed, but this time with tag `rc`.

Lastly, if you push a branch/tag named `img/v*`, or `img/v*/<name>`, no images
are built but instead the current image with tag `rc` is aliases as `v*` as
well as the current commit-SHA.

If you commit to the `osbuild/containers` repository, all images when pushed to
GitHub Packages will also be mirrored on `quay.io` under the `osbuild` group.

### Repository:

 - **web**:   <https://github.com/osbuild/containers>
 - **https**: `https://github.com/osbuild/containers.git`
 - **ssh**:   `git@github.com:osbuild/containers.git`

### License:

 - **Apache-2.0**
 - See LICENSE file for details.
