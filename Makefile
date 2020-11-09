#
# Maintenance Helpers
#
# This makefile contains targets used for development, as well as helpers to
# aid automatization of maintenance. Unless a target is documented in
# `make help`, it is not supported and is only meant to be used by developers
# to aid their daily development work.
#
# All supported targets honor the `SRCDIR` variable to find the source-tree,
# as well as the `BUILDDIR` variable to specify a build directory.
#

BUILDDIR ?= .
SRCDIR ?= .

DOCKER ?= docker
SHELL := /bin/bash

#
# Automatic Variables
#
# This section contains a bunch of automatic variables used all over the place.
# They mostly try to fetch information from the repository sources to avoid
# hard-coding them in this makefile.
#
#     RANDOM:
#         This evaluates to a different random number each time it is used. It
#         uses the underlying `$RANDOM` variable of the shell.
#
#     SPACE:
#         This evaluates to a single space character. Since this character is
#         special in GNU-make syntax, this variable can be used to explicitly
#         insert it as function arguments. Use it only when required.
#

RANDOM = $(shell echo $$RANDOM)
SPACE := $(subst ,, )

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
#     .FORCE
#         This target has no recipies nor any dependencies. Hence, GNU-make
#         considers it to change on every invocation. This allows generated
#         targets to depend on this, and thus effectively become `.PHONY`.
#

.PHONY: help
help:
	@echo "make [TARGETS...]"
	@echo
	@echo "This is the maintenance makefile of osbuild/containers. The"
	@echo "following targets are available:"
	@echo
	@echo "    help:               Print this usage information."

$(BUILDDIR)/:
	mkdir -p "$@"

$(BUILDDIR)/%/:
	mkdir -p "$@"

.FORCE:

#
# Image Management
#
# This implements a bunch of targets that build and push the containers in
# `./src/containers/`. A set of custom make-targets is created to perform
# a specific operation:
#
#     img-alias-<name>:
#         This is a short-hand for:
#
#           x-alias/$(IMG_REGISTRY)/$(IMG_REPOSITORY)/<name>:$(IMG_TAG)
#
#     img-build-<name>:
#         This is a short-hand for:
#
#           x-build/$(IMG_REGISTRY)/$(IMG_REPOSITORY)/<name>:$(IMG_TAG)
#
#     img-create-<name>:
#         This is a short-hand for:
#
#           x-create/$(IMG_REGISTRY)/$(IMG_REPOSITORY)/<name>:$(IMG_TAG)
#
#     img-list:
#         Print a list of available images the makefile can build. This
#         effectively prints $(IMG_CONTAINERS) as newline separated list.
#
#     x-alias/<registry>/<repo>/<name>
#         This first pulls the image of the following name:
#
#           <registry>/<repo>/<name>:$(IMG_TAG)
#
#         Then, it creates an alias for that image. The alias will be called:
#
#           $(IMG_ALIAS_REGISTRY)/$(IMG_ALIAS_REPOSITORY)/<name>:$(IMG_ALIAS_TAG)
#
#         If $(IMG_PUSH) is `true`, the alias-image is pushed to its registry.
#         Unless $(IMG_VOLATILE) is `false`, both images will be untagged and
#         deleted before returning.
#
#     x-build/<registry>/<repo>/<name>
#         This builds the image with name `<name>` (with path
#         `./src/containers/<name>`. The image will be called:
#
#           <registry>/<repo>/<name>:$(IMG_TAG)
#
#     x-create/<registry>/<repo>/<name>
#         This calls into `x-build/...` of the same image. It then pushes the
#         image to its registry (unless $(IMG_PUSH) is `false`). Furthermore,
#         if $(IMG_VOLATILE) is `true`, it will immediately untag the image
#         again and thus delete it.
#
# The $(IMG_VOLATILE) knob allows to make the Makefile delete all image tags
# immediately after the operation is done. This makes sure to keep the disk
# requirements low and not leave any images around that might exhaust the disk
# space of CI systems.
#
# Furthermore, since docker always operates on a machine-local namespace, a
# random value in $(IMG_TAG) is used as tag by default. You can override the
# variable to make use of a specific tag.
#

# List of containers we support building. They must exist as a directory in
# `./src/containers/<name>`. Add additional containers here to make the CI
# pick them up automatically.
# You can create symlinks like `./src/containers/<link> -> <name>` and then
# add custom build-rules below to create multiple containers of the same source
# files which differ only in the build-arguments (or other configurations).
IMG_CONTAINERS = \
	ghci-manifestdb \
	ghci-osbuild \
	ghci-osbuild-fedmir \
	ghrunt \
	kdc \
	koji \
	postgres

# Internal variables that cannot be modified by the caller.
IMG_ARGS =
IMG_TAG_PROPOSED := volatile-$(RANDOM)

# These variables control the values to use for image-registries, repositories,
# tags, etc. They have suitable defaults, but can be overriden by the caller
# (simply use `make FOO=bar` to override these).
IMG_ALIAS_REGISTRY ?= $(IMG_REGISTRY)
IMG_ALIAS_REPOSITORY ?= $(IMG_REPOSITORY)
IMG_ALIAS_TAG ?= $(IMG_TAG)
IMG_PUSH ?= false
IMG_REGISTRY ?= docker.pkg.github.com
IMG_REPOSITORY ?= osbuild/containers
IMG_TAG ?= $(IMG_TAG_PROPOSED)
IMG_VOLATILE ?= true

# List of valid targets. We use these to limit our implicit-rules to a
# predefined set of targets so we do not accidentally get rules too broad.
IMG_CONTAINERS_ALIAS = $(patsubst %,img-alias-%,$(IMG_CONTAINERS))
IMG_CONTAINERS_BUILD = $(patsubst %,img-build-%,$(IMG_CONTAINERS))
IMG_CONTAINERS_CREATE = $(patsubst %,img-create-%,$(IMG_CONTAINERS))
IMG_CONTAINERS_X_ALIAS = $(patsubst %,x-alias/$(IMG_REGISTRY)/$(IMG_REPOSITORY)/%,$(IMG_CONTAINERS))
IMG_CONTAINERS_X_BUILD = $(patsubst %,x-build/$(IMG_REGISTRY)/$(IMG_REPOSITORY)/%,$(IMG_CONTAINERS))
IMG_CONTAINERS_X_CREATE = $(patsubst %,x-create/$(IMG_REGISTRY)/$(IMG_REPOSITORY)/%,$(IMG_CONTAINERS))

$(IMG_CONTAINERS_X_ALIAS): x-alias/$(IMG_REGISTRY)/$(IMG_REPOSITORY)/%: .FORCE
	[[ "$(IMG_ALIAS_REGISTRY)/$(IMG_ALIAS_REPOSITORY)/$*:$(IMG_ALIAS_TAG)" != "$(patsubst x-alias/%,%,$@):$(IMG_TAG)" ]] || exit 1
	$(DOCKER) pull \
		--quiet \
		"$(patsubst x-alias/%,%,$@):$(IMG_TAG)"
	$(DOCKER) tag \
		"$(patsubst x-alias/%,%,$@):$(IMG_TAG)" \
		"$(IMG_ALIAS_REGISTRY)/$(IMG_ALIAS_REPOSITORY)/$*:$(IMG_ALIAS_TAG)"
	[[ "$(IMG_PUSH)" != "true" ]] || \
		$(DOCKER) push \
			"$(IMG_ALIAS_REGISTRY)/$(IMG_ALIAS_REPOSITORY)/$*:$(IMG_ALIAS_TAG)"
	[[ "$(IMG_VOLATILE)" != "true" ]] || \
		( \
			$(DOCKER) image rm "$(IMG_ALIAS_REGISTRY)/$(IMG_ALIAS_REPOSITORY)/$*:$(IMG_ALIAS_TAG)" ; \
			$(DOCKER) image rm "$(patsubst x-alias/%,%,$@):$(IMG_TAG)" \
		)

$(IMG_CONTAINERS_X_BUILD): x-build/$(IMG_REGISTRY)/$(IMG_REPOSITORY)/%: .FORCE
	$(DOCKER) build \
		--quiet \
		--tag "$(patsubst x-build/%,%,$@):$(IMG_TAG)" \
		$(IMG_ARGS) \
		"$(SRCDIR)/src/containers/$*"

$(IMG_CONTAINERS_X_CREATE): x-create/$(IMG_REGISTRY)/$(IMG_REPOSITORY)/%: .FORCE
	$(MAKE) "$(patsubst x-create/%,x-build/%,$@)" "IMG_TAG=$(IMG_TAG)"
	[[ "$(IMG_PUSH)" != "true" ]] || \
		$(DOCKER) push "$(patsubst x-create/%,%,$@):$(IMG_TAG)"
	[[ "$(IMG_VOLATILE)" != "true" ]] || \
		$(DOCKER) image rm "$(patsubst x-create/%,%,$@):$(IMG_TAG)"

# This sets the `IMG_ARGS` variable for the `ghci-manifestdb` container. We
# pull in the list of packages to install from
# `./src/pkglists/ghci-manifestdb`.
x-build/$(IMG_REGISTRY)/$(IMG_REPOSITORY)/ghci-manifestdb: IMG_ARGS= \
	"--build-arg=CI_PACKAGES=$$(cat $(SRCDIR)/src/pkglists/ghci-manifestdb)"

# This sets the `IMG_ARGS` variable for the `ghci-osbuild` container. We pull
# in the list of packages to install from `./src/pkglists/ghci-osbuild`.
x-build/$(IMG_REGISTRY)/$(IMG_REPOSITORY)/ghci-osbuild: IMG_ARGS= \
	"--build-arg=CI_PACKAGES=$$(cat $(SRCDIR)/src/pkglists/ghci-osbuild)"

# This sets the `IMG_ARGS` variable for `ghci-osbuild-fedmir`, setting the
# expected FEDMIR parameters, as well as pulling in the right package-list.
x-build/$(IMG_REGISTRY)/$(IMG_REPOSITORY)/ghci-osbuild-fedmir: IMG_ARGS= \
	"--build-arg=FEDMIR_ARCH=x86_64" \
	"--build-arg=FEDMIR_PACKAGES=$$(cat $(SRCDIR)/src/pkglists/ghci-osbuild-fedmir)" \
	"--build-arg=FEDMIR_RELEASE=32"

.PHONY: $(IMG_CONTAINERS_ALIAS)
$(IMG_CONTAINERS_ALIAS): img-alias-%: x-alias/$(IMG_REGISTRY)/$(IMG_REPOSITORY)/%

.PHONY: $(IMG_CONTAINERS_BUILD)
$(IMG_CONTAINERS_BUILD): img-build-%: x-build/$(IMG_REGISTRY)/$(IMG_REPOSITORY)/%

.PHONY: $(IMG_CONTAINERS_CREATE)
$(IMG_CONTAINERS_CREATE): img-create-%: x-create/$(IMG_REGISTRY)/$(IMG_REPOSITORY)/%

.PHONY: img-list
img-list:
	@echo -e "$(subst $(SPACE),\\n,$(IMG_CONTAINERS))"
