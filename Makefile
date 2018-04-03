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

# We cross build these arches.
ARCHES=amd64 arm64 ppc64le

all: build

# to handle default case, because we do not use the manifest for multi-arch yet
ifeq ($(ARCH),amd64)
maybedefault: defaulttarget
else
maybedefault:
endif

build: calico/go-build

calico/go-build:
	# Make sure we re-pull the base image to pick up security fixes.
	docker build --pull -t $(ARCHIMAGE) -f $(DOCKERFILE) .

push: build pusharch pushdefault

pusharch:
	docker tag $(ARCHIMAGE) quay.io/$(ARCHIMAGE)
	docker push $(ARCHIMAGE)
	docker push quay.io/$(ARCHIMAGE)

pushdefault: maybedefault

defaulttarget:
	docker tag $(ARCHIMAGE) $(DEFAULTIMAGE)
	docker tag $(ARCHIMAGE) quay.io/$(DEFAULTIMAGE)
	docker push $(DEFAULTIMAGE)
	docker push quay.io/$(DEFAULTIMAGE)

# Enable binfmt adding support for miscellaneous binary formats.
.PHONY: register
register:
ifeq ($(ARCH),amd64)
	docker run --rm --privileged multiarch/qemu-user-static:register --reset
endif


dist/qemu-%-static:
	@mkdir -p dist
	cp /usr/bin/$(@F) dist

# To build cross platform Docker images, the qemu-static binaries are needed. On ubuntu "apt-get install  qemu-user-static"
test: register dist/qemu-s390x-static dist/qemu-ppc64le-static dist/qemu-aarch64-static dist/qemu-arm-static
	for arch in $(ARCHES) ; do ARCH=$$arch $(MAKE) testcompile; done

testcompile: calico/go-build
	docker run --rm -e LOCAL_USER_ID=$(shell id -u) -e GOARCH=$(ARCH) -w /code -v ${PWD}:/code $(BUILDIMAGE) go build -o hello-$(ARCH) hello.go
	docker run --rm -v ${PWD}:/code $(BUILDIMAGE) /code/hello-$(ARCH) | grep -q "hello world"
	@echo "success"
