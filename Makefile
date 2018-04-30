BUILDARCH ?= $(shell uname -m)
ARCH ?= $(BUILDARCH)

ifeq ($(BUILDARCH),aarch64)
        override BUILDARCH=arm64
endif
ifeq ($(BUILDARCH),x86_64)
        override BUILDARCH=amd64
endif
ifeq ($(ARCH),aarch64)
        override ARCH=arm64
endif
ifeq ($(ARCH),x86_64)
        override ARCH=amd64
endif

DOCKERFILE ?= Dockerfile.$(ARCH)
VERSION ?= latest
DEFAULTIMAGE ?= calico/go-build:$(VERSION)
ARCHIMAGE ?= $(DEFAULTIMAGE)-$(ARCH)
BUILDIMAGE ?= $(DEFAULTIMAGE)-$(BUILDARCH)
ALL_ARCH = amd64 arm64 ppc64le

MANIFEST_TOOL_DIR := $(shell mktemp -d)
export PATH := $(MANIFEST_TOOL_DIR):$(PATH)

MANIFEST_TOOL_VERSION := v0.7.0

space :=
space +=
comma := ,
prefix_linux = $(addprefix linux/,$(strip $1))
join_platforms = $(subst $(space),$(comma),$(call prefix_linux,$(strip $1)))

# We cross build these arches.
ARCHES=amd64 arm64 ppc64le

all: all-build

push-manifest:
	# Docker login to hub.docker.com required before running this target as we are using $(HOME)/.docker/config.json holds the docker login credentials
	docker run -t --entrypoint /bin/sh -v $(HOME)/.docker/config.json:/root/.docker/config.json $(ARCHIMAGE) -c "/usr/bin/manifest-tool push from-args --platforms $(call join_platforms,$(ALL_ARCH)) --template $(DEFAULTIMAGE)-ARCH --target $(DEFAULTIMAGE)"

all-build: $(addprefix sub-build-,$(ALL_ARCH))
sub-build-%:
	$(MAKE) build ARCH=$*

build: calico/go-build

calico/go-build: register
	# Make sure we re-pull the base image to pick up security fixes.
	# Limit the build to use only one CPU, This helps to work around qemu bugs such as https://bugs.launchpad.net/qemu/+bug/1098729
	docker build --cpuset-cpus 0 --pull -t $(ARCHIMAGE) -f $(DOCKERFILE) .

all-push: $(addprefix sub-push-,$(ALL_ARCH))
sub-push-%:
	$(MAKE) push ARCH=$*

push: build
	docker push $(ARCHIMAGE)
	# to handle default case, because quay.io does not support manifest yet
ifeq ($(ARCH),amd64)
	docker tag $(ARCHIMAGE) quay.io/$(DEFAULTIMAGE)
	docker push quay.io/$(DEFAULTIMAGE)
endif

# Enable binfmt adding support for miscellaneous binary formats.
.PHONY: register
register:
ifeq ($(ARCH),amd64)
	docker run --rm --privileged multiarch/qemu-user-static:register --reset
endif


test: register
	for arch in $(ARCHES) ; do ARCH=$$arch $(MAKE) testcompile; done

testcompile:
	docker run --rm -e LOCAL_USER_ID=$(shell id -u) -e GOARCH=$(ARCH) -w /code -v ${PWD}:/code $(BUILDIMAGE) go build -o hello-$(ARCH) hello.go
	docker run --rm -v ${PWD}:/code $(BUILDIMAGE) /code/hello-$(ARCH) | grep -q "hello world"
	@echo "success"
