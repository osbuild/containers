#
# OSBuild Containers Makefile
#
# This makefile builds provides maintenance helpers to build and manage the
# container images of the osbuild-containers repository.
#

BIN_DOCKER ?= docker
BIN_JQ     ?= jq
BIN_MKDIR  ?= mkdir

IMG_BAKE_ARGS ?=
IMG_BUILDER   ?= default
IMG_TARGET    ?= osbuild-ci-latest

.PHONY: help
help:
	@echo "make [TARGETS...]"
	@echo
	@echo "This is the maintenance makefile of osbuild/containers."
	@echo "The following targets are available:"
	@echo
	@echo "    help:               Print this usage information."
	@echo "    setup-builder:      Prepare local docker for image builds"
	@echo "    list-targets:       List all targets from bakefile."
	@echo "    list-tags:          List all groups from bakefile."
	@echo "    inspect-target:     Show details of target"
	@echo "    bake:               Build images via docker-buildx-bake"
	@echo ""
	@echo "Additional env variables which can be overwritten from command line:"
	@echo "IMG_TARGET:      Set image to build / inspect (default osbuild-ci-latest)"
	@echo "IMG_BAKE_ARGS:   Add extra arguments for docker bake"
	@echo "IMG_BUILDER:     Set custom builder"
	@echo ""
	@echo "Examples:"
	@echo "make setup-builder"
	@echo "make list-targets"
	@echo "make inspect-target IMG_TARGET=osbuild-ci-latest"
	@echo "make bake IMG_TARGET=osbuild-ci-latest"
	@echo ""
	@echo "When no extra parameters are specified IMG_TARGET defaults"
	@echo "to osbuild-ci-latest"


.PHONY: list-targets
list-targets:
	@$(BIN_DOCKER) \
		buildx \
		bake \
		--print \
		all-images \
		| jq -c '.target | keys'

.PHONY: list-tags
list-tags:
	@$(BIN_DOCKER) \
		buildx \
		bake \
		--print \
		all-images \
		| jq -c '[.target[].tags[]]'

.PHONY: inspect-target
inspect-target:
	@$(BIN_DOCKER) \
		buildx \
		bake \
		--print \
		$(IMG_TARGET)

.PHONY: setup-builder
setup-builder:
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

.PHONY: bake
bake:
	@$(BIN_DOCKER) \
		buildx \
		bake \
		--builder "$(IMG_BUILDER)" \
		$(IMG_BAKE_ARGS) \
		$(IMG_TARGET)
