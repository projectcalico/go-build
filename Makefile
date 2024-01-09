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
ifeq ($(ARCH),x86_64)
	override ARCH=arm64
else ifeq ($(ARCH),aarch64)
	override ARCH=amd64
endif

# ELF interpreter (dynamic loader) soname
LDSONAME=ld64.so.1
ifeq ($(ARCH),amd64)
	override LDSONAME=ld-linux-x86-64.so.2
else ifeq ($(ARCH),arm64)
	override LDSONAME=ld-linux-aarch64.so.1
else ifeq ($(ARCH),ppc64le)
	override LDSONAME=ld64.so.2
else ifeq ($(ARCH),s390)
	override LDSONAME=ld64.so.1
endif


VERSION ?= latest

GOBUILD ?= calico/go-build
GOBUILD_IMAGE ?= $(GOBUILD):$(VERSION)
GOBUILD_ARCH_IMAGE ?= $(GOBUILD_IMAGE)-$(ARCH)

BASE ?= calico/base
BASE_IMAGE ?= $(BASE):latest
BASE_ARCH_IMAGE ?= $(BASE_IMAGE)-$(ARCH)

QEMU ?= calico/qemu-user-static
QEMU_IMAGE ?= $(QEMU):latest

###############################################################################
# Building images
###############################################################################
QEMU_IMAGE_CREATED=.qemu.created

.PHONY: image-qemu
image-qemu: $(QEMU_IMAGE_CREATED)
$(QEMU_IMAGE_CREATED):
	docker buildx build --load --platform=linux/amd64 --pull -t $(QEMU_IMAGE) -f qemu/Dockerfile qemu
	touch $@

.PHONY: image
image: register image-qemu
	docker buildx build --load --platform=linux/$(ARCH) -t $(GOBUILD_ARCH_IMAGE) -f Dockerfile .

.PHONY: image-all
image-all: $(addprefix sub-image-,$(ARCHES))
sub-image-%:
	$(MAKE) image ARCH=$*

.PHONY: image-base
image-base: register image-qemu
	docker buildx build --load --platform=linux/$(ARCH) --build-arg LDSONAME=$(LDSONAME) -t $(BASE_ARCH_IMAGE) -f base/Dockerfile base

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

.PHONY: push-qemu
push-qemu: image-qemu
	docker push $(QEMU_IMAGE)

push-all: $(addprefix sub-push-,$(ARCHES))
sub-push-%:
	$(MAKE) push ARCH=$*
	$(MAKE) push-base ARCH=$*
	$(MAKE) push-qemu

.PHONY: push-manifest
push-manifest:
	# Docker login to hub.docker.com required before running this target as we are using $(HOME)/.docker/config.json holds the docker login credentials
	docker manifest create $(GOBUILD_IMAGE) $(addprefix --amend ,$(addprefix $(GOBUILD_IMAGE)-,$(ARCHES)))
	docker manifest push --purge $(GOBUILD_IMAGE)
	docker manifest create $(BASE_IMAGE) $(addprefix --amend ,$(addprefix $(BASE_IMAGE)-,$(ARCHES)))
	docker manifest push --purge $(BASE_IMAGE)

.PHONY: clean
clean:
	rm -f $(QEMU_IMAGE_CREATED)
	-docker image rm -f $$(docker images $(GOBUILD) -a -q)
	-docker image rm -f $$(docker images $(BASE) -a -q)
	-docker image rm -f $$(docker images $(QEMU) -a -q)

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
