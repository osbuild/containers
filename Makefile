#
# OSBuild Containers Makefile
#
# This makefile builds provides maintenance helpers to build and manage the
# container images of the osbuild-containers repository.
#

#
# Global Setup
#
# This section sets some global parameters that get rid of some old `make`
# annoyences.
#
#     SHELL
#         We standardize on `bash` for better inline scripting capabilities,
#         and we always enable `pipefail`, to make sure individual failures
#         in a pipeline will be treated as failure.
#
#     .SECONDARY:
#         An empty SECONDARY target signals gnu-make to keep every intermediate
#         files around, even on failure. We want intermediates to stay around
#         so we get better caching behavior.
#

SHELL			:= /bin/bash -eox pipefail

.SECONDARY:

#
# Parameters
#
# The set of global parameters that can be controlled by the caller and the
# calling environment.
#
#     BUILDDIR
#         Path to the directory used to store build artifacts. This defaults
#         to `./build`, so all artifacts are stored in a subdirectory that can
#         be easily cleaned.
#
#     SRCDIR
#         Path to the source code directory. This defaults to `.`, so it
#         expects `make` to be called from within the source directory.
#
#     BIN_*
#         For all binaries that are executed as part of this makefile, a
#         variable called `BIN_<exe>` defines the path or name of the
#         executable. By default, they are set to the name of the binary.
#

BUILDDIR		?= ./build
SRCDIR			?= .

BIN_DOCKER		?= docker
BIN_JQ			?= jq
BIN_MKDIR		?= mkdir

#
# Generic Targets
#
# The following is a set of generic targets used across the makefile. The
# following targets are defined:
#
#     help
#         This target prints all supported targets. It is meant as
#         documentation of targets we support and might use outside of this
#         repository.
#         This is also the default target.
#
#     $(BUILDDIR)/
#     $(BUILDDIR)/%/
#         This target simply creates the specified directory. It is limited to
#         the build-dir as a safety measure. Note that this requires you to use
#         a trailing slash after the directory to not mix it up with regular
#         files. Lastly, you mostly want this as order-only dependency, since
#         timestamps on directories do not affect their content.
#
#     FORCE
#         Dummy target to use as dependency to force `.PHONY` behavior on
#         targets that cannot use `.PHONY`.
#

.PHONY: help
help:
	@echo "make [TARGETS...]"
	@echo
	@echo "This is the maintenance makefile of osbuild/containers. The"
	@echo "following targets are available:"
	@echo
	@echo "            help:       Print this usage information."
	@echo
	@echo "       img-setup:       Prepare local docker for image builds"
	@echo "        img-list:       List image targets as JSON array"
	@echo "        img-tags:       List image tags as JSON array"
	@echo "        img-bake:       Build images via docker-buildx-bake"

$(BUILDDIR)/:
	$(BIN_MKDIR) -p "$@"

$(BUILDDIR)/%/:
	$(BIN_MKDIR) -p "$@"

.PHONY: FORCE
FORCE:

#
# Image Builds
#
# The following section provides common helpers around `docker buildx`, which
# we use to build all images. For more control, you should invoke buildx
# directly.
#

IMG_BAKE_ARGS		?=
IMG_BUILDER		?= default
IMG_TARGET		?= default

.PHONY: img-setup
img-setup:
	@if \
		! $(BIN_DOCKER) \
			buildx \
			inspect \
			--builder "$(IMG_BUILDER)" \
			>/dev/null \
			2>/dev/null \
			; \
	then \
		$(BIN_DOCKER) \
			buildx \
			create \
			--name "$(IMG_BUILDER)" \
			--driver docker-container \
			; \
	fi
	@$(BIN_DOCKER) \
		buildx \
		inspect \
		--bootstrap \
		--builder "$(IMG_BUILDER)"

.PHONY: img-list
img-list:
	@$(BIN_DOCKER) \
		buildx \
		bake \
		--builder "$(IMG_BUILDER)" \
		--print \
		$(IMG_BAKE_ARGS) \
		$(IMG_TARGET) \
		| $(BIN_JQ) -c '.target | keys'

.PHONY: img-tags
img-tags:
	@$(BIN_DOCKER) \
		buildx \
		bake \
		--builder "$(IMG_BUILDER)" \
		--print \
		$(IMG_BAKE_ARGS) \
		$(IMG_TARGET) \
		| $(BIN_JQ) -c '[.target[].tags[]]'

.PHONY: img-bake
img-bake:
	@$(BIN_DOCKER) \
		buildx \
		bake \
		--builder "$(IMG_BUILDER)" \
		$(IMG_BAKE_ARGS) \
		$(IMG_TARGET)
