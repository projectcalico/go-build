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

.PHONY: register
# Enable binfmt adding support for miscellaneous binary formats.  This is needed for building non-native images.
register:
	sudo docker run --rm --privileged multiarch/qemu-user-static:register || true

bin/qemu-ppc64le-static:
	mkdir bin || true
	wget https://github.com/multiarch/qemu-user-static/releases/download/v2.9.1/qemu-ppc64le-static.tar.gz 
	tar zxvf qemu-ppc64le-static.tar.gz -C bin
	rm qemu-ppc64le-static.tar.gz

bin/qemu-aarch64-static:
	mkdir bin || true
	wget https://github.com/multiarch/qemu-user-static/releases/download/v2.9.1-1/qemu-aarch64-static.tar.gz 
	tar zxvf qemu-aarch64-static.tar.gz -C bin
	rm qemu-aarch64-static.tar.gz

build: calico/go-build 

calico/go-build: bin/qemu-ppc64le-static bin/qemu-aarch64-static register
	# Make sure we re-pull the base image to pick up security fixes.
	docker build --pull -t $(ARCHIMAGE) -f $(DOCKERFILE) .

push: build pusharch pushdefault

pusharch:
	docker push $(ARCHIMAGE)

pushdefault: maybedefault

defaulttarget:
	docker tag $(ARCHIMAGE) $(DEFAULTIMAGE)
	docker push $(DEFAULTIMAGE)

clean:
	rm -rif bin
