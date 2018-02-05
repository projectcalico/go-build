ARCH ?= $(shell uname -m)

ifeq ($(ARCH),aarch64)
        ARCH=arm64
endif
ifeq ($(ARCH),x86_64)
        ARCH=amd64
endif

DOCKERFILE ?= Dockerfile.$(ARCH)
VERSION ?= latest
DEFAULTIMAGE ?= calico/go-build:$(VERSION)
ARCHIMAGE ?= $(DEFAULTIMAGE)-$(ARCH)

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

