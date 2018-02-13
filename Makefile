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
	docker push $(ARCHIMAGE)

pushdefault: maybedefault

defaulttarget:
	docker tag $(ARCHIMAGE) $(DEFAULTIMAGE)
	docker push $(DEFAULTIMAGE)

testcompile:
	docker run --rm -e LOCAL_USER_ID=$(shell id -u) -e GOARCH=$(ARCH) -w /code -v ${PWD}:/code $(BUILDIMAGE) go build -o hello-$(ARCH) hello.go
	docker run --rm -v ${PWD}:/code $(BUILDIMAGE) /code/hello-$(ARCH) | grep -q "hello world"
	@echo "success"
