# Shortcut targets
default: image

## Build binary for current platform
all: image-all
###############################################################################
# Both native and cross architecture builds are supported.
# The target architecture is select by setting the ARCH variable.
# When ARCH is undefined it is set to the detected host architecture.
# When ARCH differs from the host architecture a crossbuild will be performed.
###############################################################################
ARCHES = amd64 arm64 ppc64le s390x

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

VERSION ?= latest

GOBUILD ?= calico/go-build
GOBUILD_IMAGE ?= $(GOBUILD):$(VERSION)
GOBUILD_ARCH_IMAGE ?= $(GOBUILD_IMAGE)-$(ARCH)

BASE ?= calico/base
BASE_IMAGE ?= $(BASE):latest
BASE_ARCH_IMAGE ?= $(BASE_IMAGE)-$(ARCH)

###############################################################################
# Building images
###############################################################################
QEMU_DOWNLOADED=.qemu.downloaded
QEMU_VERSION=v7.2.0-1

.PHONY: download-qemu
download-qemu: $(QEMU_DOWNLOADED)
$(QEMU_DOWNLOADED):
	curl --remote-name-all -sfL --retry 3 https://github.com/multiarch/qemu-user-static/releases/download/${QEMU_VERSION}/qemu-{aarch64,ppc64le,s390x}-static
	chmod 755 qemu-*-static
	touch $@

.PHONY: calico/go-build
calico/go-build: register download-qemu
	docker buildx build --load --pull --platform=linux/$(ARCH) -t $(GOBUILD_ARCH_IMAGE) -f Dockerfile .

.PHONY: image
image: calico/go-build

.PHONY: image-all
image-all: $(addprefix sub-image-,$(ARCHES))
sub-image-%:
	$(MAKE) image ARCH=$*

.PHONY: calico/base
calico/base: register download-qemu
	docker buildx build --load --pull --platform=linux/$(ARCH) -t $(BASE_ARCH_IMAGE) -f base/Dockerfile .

.PHONY: image-base
image-base: calico/base

.PHONY: image-base-all
image-base-all: $(addprefix sub-image-base-,$(ARCHES))
sub-image-base-%:
	$(MAKE) image-base ARCH=$*

# Enable binfmt adding support for miscellaneous binary formats.
.PHONY: register
register:
ifeq ($(BUILDARCH),amd64)
	docker run --rm --privileged multiarch/qemu-user-static:register --reset
endif

.PHONY: push
push: image
	docker push $(GOBUILD_ARCH_IMAGE)
	# to handle default case, because quay.io does not support manifest yet
ifeq ($(ARCH),amd64)
	docker tag $(GOBUILD_ARCH_IMAGE) quay.io/$(GOBUILD_IMAGE)
	docker push quay.io/$(GOBUILD_IMAGE)
endif

.PHONY: push-base
push-base: image-base
	docker push $(BASE_ARCH_IMAGE)

push-all: $(addprefix sub-push-,$(ARCHES))
sub-push-%:
	$(MAKE) push ARCH=$*
	$(MAKE) push-base ARCH=$*

.PHONY: push-manifest
push-manifest:
	# Docker login to hub.docker.com required before running this target as we are using $(HOME)/.docker/config.json holds the docker login credentials
	docker manifest create $(DEFAULTIMAGE) $(addprefix --amend ,$(addprefix $(DEFAULTIMAGE)-,$(ARCHES)))
	docker manifest push --purge $(DEFAULTIMAGE)
	docker manifest create $(BASE_IMAGE) $(addprefix --amend ,$(addprefix $(BASE_IMAGE)-,$(ARCHES)))
	docker manifest push --purge $(BASE_IMAGE)

.PHONY: clean
clean:
	rm -f qemu-*-static
	rm -f $(QEMU_DOWNLOADED)
	-docker image rm -f $$(docker images $(GOBUILD) -a -q)
	-docker image rm -f $$(docker images $(BASE) -a -q)

###############################################################################
# UTs
###############################################################################
test: register
	for arch in $(ARCHES) ; do ARCH=$$arch $(MAKE) testcompile; done

testcompile:
	docker run --rm -e LOCAL_USER_ID=$(shell id -u) -e GOARCH=$(ARCH) -w /code -v ${PWD}:/code $(GOBUILD_IMAGE)-$(BUILDARCH) go build -o hello-$(ARCH) hello.go
	docker run --rm -v ${PWD}:/code $(GOBUILD_IMAGE)-$(BUILDARCH) /code/hello-$(ARCH) | grep -q "hello world"
	@echo "success"

###############################################################################
# CI
###############################################################################
.PHONY: ci
ci: image-all image-base-all test

###############################################################################
# CD
###############################################################################
.PHONY: cd
cd:
ifndef CONFIRM
	$(error CONFIRM is undefined - run using make <target> CONFIRM=true)
endif
ifndef BRANCH_NAME
	$(error BRANCH_NAME is undefined - run using make <target> BRANCH_NAME=var or set an environment variable)
endif
	$(MAKE) push-all VERSION=${BRANCH_NAME}
	$(MAKE) push-manifest VERSION=${BRANCH_NAME}
