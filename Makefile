# Shortcut targets
default: image

## Build binary for current platform
all: image-all
###############################################################################
# Both native and cross architecture builds are supported.
# The target architecture is select by setting the ARCH variable.
# When ARCH is undefined it is set to the detected host architecture.
# When ARCH differs from the host architecture a crossbuild will be performed.
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

###############################################################################
GOBUILD_IMAGE ?= calico/go-build
VERSION ?= latest
DEFAULTIMAGE ?= $(GOBUILD_IMAGE):$(VERSION)
ARCHIMAGE ?= $(DEFAULTIMAGE)-$(ARCH)
BUILDIMAGE ?= $(DEFAULTIMAGE)-$(BUILDARCH)

# Check if the docker daemon is running in experimental mode (to get the --squash flag)
DOCKER_EXPERIMENTAL=$(shell docker version -f '{{ .Server.Experimental }}')
DOCKER_BUILD_ARGS?=
ifeq ($(DOCKER_EXPERIMENTAL),true)
DOCKER_BUILD_ARGS+=--squash
endif

###############################################################################
# Building the image
###############################################################################
QEMU_DOWNLOADED=.qemu.downloaded
QEMU_VERSION=v7.2.0-1

.PHONY: download-qemu
download-qemu: $(QEMU_DOWNLOADED)
$(QEMU_DOWNLOADED):
	curl --remote-name-all -sfL --retry 3 https://github.com/multiarch/qemu-user-static/releases/download/${QEMU_VERSION}/qemu-{aarch64,ppc64le,s390x}-static
	chmod 755 qemu-*-static
	touch $@

.PHONY: image
image: calico/go-build
calico/go-build: register download-qemu
	docker buildx build --pull $(DOCKER_BUILD_ARGS) --platform=linux/$(ARCH) -t $(ARCHIMAGE) -f Dockerfile . --load

image-all: $(addprefix sub-image-,$(ARCHES))
sub-image-%:
	$(MAKE) image ARCH=$*

# Enable binfmt adding support for miscellaneous binary formats.
.PHONY: register
register:
ifeq ($(BUILDARCH),amd64)
	docker run --rm --privileged multiarch/qemu-user-static:register --reset
endif

.PHONY: push
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

.PHONY: push-manifest
push-manifest:
	# Docker login to hub.docker.com required before running this target as we are using $(HOME)/.docker/config.json holds the docker login credentials
	docker manifest create $(DEFAULTIMAGE) \
		--amend $(DEFAULTIMAGE)-amd64 \
		--amend $(DEFAULTIMAGE)-arm64 \
		--amend $(DEFAULTIMAGE)-ppc64le \
		--amend $(DEFAULTIMAGE)-s390x
	docker manifest push $(DEFAULTIMAGE)

.PHONY: clean
clean:
	rm -f qemu-*-static
	rm -f $(QEMU_DOWNLOADED)
	-docker image rm -f $$(docker images $(GOBUILD_IMAGE) -a -q)
	-docker manifest rm $(DEFAULTIMAGE)

###############################################################################
# UTs
###############################################################################
test: register
	for arch in $(ARCHES) ; do ARCH=$$arch $(MAKE) testcompile; done

testcompile:
	docker run --rm --user=$(shell id -u) -e GOARCH=$(ARCH) -w /code -v ${PWD}:/code $(BUILDIMAGE) go build -o hello-$(ARCH) hello.go
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
