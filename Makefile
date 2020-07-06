# Shortcut targets
default: image

## Build binary for current platform
all: image-all
###############################################################################
# Both native and cross architecture builds are supported.
# The target architecture is select by setting the ARCH variable.
# When ARCH is undefined it is set to the detected host architecture.
# When ARCH differs from the host architecture a crossbuild will be performed.
ARCHES = amd64 arm64 ppc64le

# BUILDARCH is the host architecture
# ARCH is the target architecture
# we need to keep track of them separately
BUILDARCH ?= $(shell uname -m)

# canonicalized names for host architecture
ifeq ($(BUILDARCH),aarch64)
        BUILDARCH=arm64
endif
ifeq ($(BUILDARCH),x86_64)
        BUILDARCH=amd64
endif

# unless otherwise set, I am building for my own architecture, i.e. not cross-compiling
ARCH ?= $(BUILDARCH)

# canonicalized names for target architecture
ifeq ($(ARCH),aarch64)
        override ARCH=arm64
endif
ifeq ($(ARCH),x86_64)
        override ARCH=amd64
endif

###############################################################################
DOCKERFILE ?= Dockerfile.$(ARCH)
VERSION ?= latest
DEFAULTIMAGE ?= calico/go-build:$(VERSION)
ARCHIMAGE ?= $(DEFAULTIMAGE)-$(ARCH)
BUILDIMAGE ?= $(DEFAULTIMAGE)-$(BUILDARCH)

MANIFEST_TOOL_VERSION := v1.0.2
MANIFEST_TOOL_DIR := $(shell mktemp -d)
export PATH := $(MANIFEST_TOOL_DIR):$(PATH)

space :=
space +=
comma := ,
prefix_linux = $(addprefix linux/,$(strip $1))
join_platforms = $(subst $(space),$(comma),$(call prefix_linux,$(strip $1)))

# Check if the docker daemon is running in experimental mode (to get the --squash flag)
DOCKER_EXPERIMENTAL=$(shell docker version -f '{{ .Server.Experimental }}')
DOCKER_BUILD_ARGS?=
ifeq ($(DOCKER_EXPERIMENTAL),true)
DOCKER_BUILD_ARGS+=--squash
endif
ifneq ($(ARCH),amd64)
DOCKER_BUILD_ARGS+=--cpuset-cpus 0
endif

###############################################################################
# Building the image
###############################################################################
image: calico/go-build
calico/go-build: register
	# Make sure we re-pull the base image to pick up security fixes.
	# Limit the build to use only one CPU, This helps to work around qemu bugs such as https://bugs.launchpad.net/qemu/+bug/1098729
	docker build $(DOCKER_BUILD_ARGS) --pull -t $(ARCHIMAGE) -f $(DOCKERFILE) .

image-all: $(addprefix sub-image-,$(ARCHES))
sub-image-%:
	$(MAKE) image ARCH=$*

# Enable binfmt adding support for miscellaneous binary formats.
.PHONY: register
register:
ifeq ($(ARCH),amd64)
	docker run --rm --privileged multiarch/qemu-user-static:register --reset
endif

push: image
	docker push $(ARCHIMAGE)
	# to handle default case, because quay.io does not support manifest yet
ifeq ($(ARCH),amd64)
	docker tag $(ARCHIMAGE) quay.io/$(DEFAULTIMAGE)
	docker push quay.io/$(DEFAULTIMAGE)
endif

push-all: $(addprefix sub-push-,$(ARCHES))
sub-push-%:
	$(MAKE) push ARCH=$*

push-manifest:
	# Docker login to hub.docker.com required before running this target as we are using $(HOME)/.docker/config.json holds the docker login credentials
	docker run -t --entrypoint /bin/sh -v $(HOME)/.docker/config.json:/root/.docker/config.json $(ARCHIMAGE) -c "/usr/bin/manifest-tool push from-args --platforms $(call join_platforms,$(ARCHES)) --template $(DEFAULTIMAGE)-ARCH --target $(DEFAULTIMAGE)"

###############################################################################
# UTs
###############################################################################
test: register
	for arch in $(ARCHES) ; do ARCH=$$arch $(MAKE) testcompile; done

testcompile:
	docker run --rm -e LOCAL_USER_ID=$(shell id -u) -e GOARCH=$(ARCH) -w /code -v ${PWD}:/code $(BUILDIMAGE) go build -o hello-$(ARCH) hello.go
	docker run --rm -v ${PWD}:/code $(BUILDIMAGE) /code/hello-$(ARCH) | grep -q "hello world"
	@echo "success"

###############################################################################
# CI
###############################################################################
.PHONY: ci
## Run what CI runs
ci: image-all test

###############################################################################
# CD
###############################################################################
.PHONY: cd
## Deploys images to registry
cd:
ifndef CONFIRM
	$(error CONFIRM is undefined - run using make <target> CONFIRM=true)
endif
ifndef BRANCH_NAME
	$(error BRANCH_NAME is undefined - run using make <target> BRANCH_NAME=var or set an environment variable)
endif
	$(MAKE) push-all VERSION=${BRANCH_NAME}
	$(MAKE) push-manifest VERSION=${BRANCH_NAME}
