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
	override ARCH=amd64
else ifeq ($(ARCH),aarch64)
	override ARCH=arm64
endif

ifdef CI
    DOCKER_PROGRESS := --progress=plain
endif

.PHONY: register
register:
ifeq ($(BUILDARCH),amd64)
	docker run --rm --privileged multiarch/qemu-user-static:register --reset
endif
