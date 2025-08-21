include ../lib.Makefile
include ../Makefile.common

CALICO_BASE ?= base
CALICO_GO_BUILD ?= go-build

.PHONY: image
image:  calico-go-build-image

.PHONY: image-all
image-all: calico-base-image-all calico-go-build-image-all

# Base image for all calico components.

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

.PHONY: calico-base-image
calico-base-image: register
	$(DOCKER_BUILD) --build-arg LDSONAME=$(LDSONAME) -t $(CALICO_BASE):ubi8-latest-$(ARCH) -f calico-base/Dockerfile.ubi8 calico-base/
	$(MAKE) BUILD_IMAGES=$(CALICO_BASE) retag-build-images-with-registries VALIDARCHES=$(ARCH) LATEST_IMAGE_TAG=ubi8-latest IMAGETAG=ubi8-latest
	$(DOCKER_BUILD) --build-arg LDSONAME=$(LDSONAME) -t $(CALICO_BASE):ubi9-latest-$(ARCH) -f calico-base/Dockerfile.ubi9 calico-base/
	$(MAKE) BUILD_IMAGES=$(CALICO_BASE) retag-build-images-with-registries VALIDARCHES=$(ARCH) LATEST_IMAGE_TAG=ubi9-latest IMAGETAG=ubi9-latest

.PHONY: calico-base-image-all
calico-base-image-all: $(addprefix sub-calico-base-image-,$(VALIDARCHES))
sub-calico-base-image-%:
	$(MAKE) calico-base-image ARCH=$*

.PHONY: calico-base-cd
calico-base-cd: calico-base-image-all var-require-one-of-CONFIRM-DRYRUN var-require-all-BRANCH_NAME
	$(MAKE) BUILD_IMAGES=$(CALICO_BASE) retag-build-images-with-registries push-images-to-registries push-manifests LATEST_IMAGE_TAG=ubi8-latest IMAGETAG=ubi8-$(BRANCH_NAME) EXCLUDEARCH="$(EXCLUDEARCH)"
	$(MAKE) BUILD_IMAGES=$(CALICO_BASE) retag-build-images-with-registries push-images-to-registries push-manifests LATEST_IMAGE_TAG=ubi9-latest IMAGETAG=ubi9-$(BRANCH_NAME) EXCLUDEARCH="$(EXCLUDEARCH)"

# Calico builder which contains Go/Clang compilers and necessary utilities for UT/FVs.
.PHONY: build
build:
	$(MAKE) -C ../cmd build
	mkdir -p calico-go-build/bin/
	cp ../cmd/bin/semvalidator-$(ARCH) calico-go-build/bin/semvalidator-$(ARCH)

CALICO_GO_BUILD_IMAGETAG ?= latest

.PHONY: calico-go-build-image
calico-go-build-image: register build
	$(DOCKER_BUILD) -t $(CALICO_GO_BUILD):latest-$(ARCH)-ubi -f calico-go-build/Dockerfile --target=ubi calico-go-build/
	$(DOCKER_BUILD) -t $(CALICO_GO_BUILD):latest-$(ARCH)-mini -f calico-go-build/Dockerfile --target=mini calico-go-build/
	$(DOCKER_BUILD) -t $(CALICO_GO_BUILD):latest-$(ARCH)-maxi -f calico-go-build/Dockerfile --target=maxi calico-go-build/
	$(DOCKER_BUILD) -t $(CALICO_GO_BUILD):latest-$(ARCH)-tools -f calico-go-build/Dockerfile --target=tools calico-go-build/
	#$(MAKE) BUILD_IMAGES=$(CALICO_GO_BUILD) retag-build-images-with-registries VALIDARCHES=$(ARCH) IMAGETAG=$(CALICO_GO_BUILD_IMAGETAG)

.PHONY: calico-go-build-image-all
calico-go-build-image-all: $(addprefix sub-calico-go-build-image-,$(VALIDARCHES))
sub-calico-go-build-image-%:
	$(MAKE) calico-go-build-image ARCH=$*

.PHONY: calico-go-build-cd
calico-go-build-cd: calico-go-build-image var-require-one-of-CONFIRM-DRYRUN var-require-all-BRANCH_NAME
	$(MAKE) BUILD_IMAGES=$(CALICO_GO_BUILD) retag-build-images-with-registries push-images-to-registries IMAGETAG=$(BRANCH_NAME) EXCLUDEARCH="$(EXCLUDEARCH)"
ifeq ($(BRANCH_NAME),master)
	$(MAKE) BUILD_IMAGES=$(CALICO_GO_BUILD) retag-build-images-with-registries push-images-to-registries IMAGETAG=latest EXCLUDEARCH="$(EXCLUDEARCH)"
endif

.PHONY: push-calico-go-build-manifests
push-calico-go-build-manifests: var-require-one-of-CONFIRM-DRYRUN var-require-all-BRANCH_NAME
	$(MAKE) BUILD_IMAGES=$(CALICO_GO_BUILD) push-manifests IMAGETAG=$(BRANCH_NAME) EXCLUDEARCH="$(EXCLUDEARCH)"
ifeq ($(BRANCH_NAME),master)
	$(MAKE) BUILD_IMAGES=$(CALICO_GO_BUILD) push-manifests IMAGETAG=latest EXCLUDEARCH="$(EXCLUDEARCH)"
endif

.PHONY: clean
clean:
	rm -fr calico-go-build/bin
	-docker image rm -f $$(docker images $(CALICO_BASE) -a -q)
	-docker image rm -f $$(docker images $(CALICO_GO_BUILD) -a -q)
