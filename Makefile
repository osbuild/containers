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
SHELL = /bin/bash

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

RANDOM = $(shell echo $$RANDOM)

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
# GHCI Management (GitHub CI)
#
# This implements a bunch of targets that build and push the containers in
# `./ghci/containers/`. Note that docker always operates on a global namespace,
# which means any local operations will affect the global image setup and
# namespace. Therefore, unless specified otherwise, this always uses random
# tags for all images created. Furthermore, it always discards all images
# unless volatile mode is disabled.
#

GHCI_ALIAS_REGISTRY ?= $(GHCI_REGISTRY)
GHCI_ALIAS_REPOSITORY ?= $(GHCI_REPOSITORY)
GHCI_ALIAS_TAG ?= $(GHCI_TAG)
GHCI_PUSH ?= false
GHCI_REGISTRY ?= docker.pkg.github.com
GHCI_REPOSITORY ?= osbuild/containers
GHCI_TAG_PROPOSED := volatile-$(RANDOM)
GHCI_TAG ?= $(GHCI_TAG_PROPOSED)
GHCI_VOLATILE ?= true

GHCI_CONTAINERS_DIR = $(wildcard $(SRCDIR)/ghci/containers/*)
GHCI_CONTAINERS_LABEL = $(patsubst $(SRCDIR)/ghci/containers/%,%,$(GHCI_CONTAINERS_DIR))

GHCI_CONTAINERS_BUILD = $(patsubst %,x-build/$(GHCI_REGISTRY)/$(GHCI_REPOSITORY)/%,$(GHCI_CONTAINERS_LABEL))
GHCI_CONTAINERS_CREATE = $(patsubst %,x-create/$(GHCI_REGISTRY)/$(GHCI_REPOSITORY)/%,$(GHCI_CONTAINERS_LABEL))
GHCI_CONTAINERS_ALIAS = $(patsubst %,x-alias/$(GHCI_REGISTRY)/$(GHCI_REPOSITORY)/%,$(GHCI_CONTAINERS_LABEL))

$(GHCI_CONTAINERS_BUILD): x-build/$(GHCI_REGISTRY)/$(GHCI_REPOSITORY)/%: .FORCE
	$(DOCKER) build \
		--quiet \
		--tag "$(patsubst x-build/%,%,$@):$(GHCI_TAG)" \
		"$(SRCDIR)/ghci/containers/$*"

$(GHCI_CONTAINERS_CREATE): x-create/$(GHCI_REGISTRY)/$(GHCI_REPOSITORY)/%: .FORCE
	$(MAKE) "$(patsubst x-create/%,x-build/%,$@)" "GHCI_TAG=$(GHCI_TAG)"
	[[ "$(GHCI_PUSH)" != "true" ]] || \
		$(DOCKER) push "$(patsubst x-create/%,%,$@):$(GHCI_TAG)"
	[[ "$(GHCI_VOLATILE)" != "true" ]] || \
		$(DOCKER) image rm "$(patsubst x-create/%,%,$@):$(GHCI_TAG)"

$(GHCI_CONTAINERS_ALIAS): x-alias/$(GHCI_REGISTRY)/$(GHCI_REPOSITORY)/%: .FORCE
	[[ "$(GHCI_ALIAS_REGISTRY)/$(GHCI_ALIAS_REPOSITORY)/$*:$(GHCI_ALIAS_TAG)" != "$(patsubst x-alias/%,%,$@):$(GHCI_TAG)" ]] || exit 1
	$(MAKE) "$(patsubst x-alias/%,x-build/%,$@)" "GHCI_TAG=$(GHCI_TAG)"
	$(DOCKER) tag \
		"$(patsubst x-alias/%,%,$@):$(GHCI_TAG)" \
		"$(GHCI_ALIAS_REGISTRY)/$(GHCI_ALIAS_REPOSITORY)/$*:$(GHCI_ALIAS_TAG)"
	[[ "$(GHCI_PUSH)" != "true" ]] || \
		$(DOCKER) push \
			"$(GHCI_ALIAS_REGISTRY)/$(GHCI_ALIAS_REPOSITORY)/$*:$(GHCI_ALIAS_TAG)"
	[[ "$(GHCI_VOLATILE)" != "true" ]] || \
		( \
			$(DOCKER) image rm "$(GHCI_ALIAS_REGISTRY)/$(GHCI_ALIAS_REPOSITORY)/$*:$(GHCI_ALIAS_TAG)" ; \
			$(DOCKER) image rm "$(patsubst x-alias/%,%,$@):$(GHCI_TAG)" \
		)

.PHONY: ghci-create
ghci-create: $(GHCI_CONTAINERS_CREATE)

.PHONY: ghci-alias
ghci-alias: $(GHCI_CONTAINERS_ALIAS)
