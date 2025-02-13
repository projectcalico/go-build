include ../lib.Makefile
include ../Makefile.common

VERSION_TAG ?= latest

CALICO_BASE ?= base
CALICO_GO_BUILD ?= go-build

QEMU_USER_STATIC ?= $(DEV_REGISTRIES)/qemu-user-static
QEMU_USER_STATIC_IMAGE_CREATED = .qemu-user-static.created

.PHONY: image
image: qemu-user-static-image calico-base-image calico-go-build-image

.PHONY: image-all
image-all: qemu-user-static-image calico-base-image-all calico-go-build-image-all

# Holder image for all qemu-*-static binaries Calico supports.
# It only builds for linux/amd64 platform.
.PHONY: qemu-user-static-image
qemu-user-static-image: $(QEMU_USER_STATIC_IMAGE_CREATED)
$(QEMU_USER_STATIC_IMAGE_CREATED):
	docker buildx build $(DOCKER_PROGRESS) --load --platform=linux/amd64 --pull \
		-t $(QEMU_USER_STATIC):latest \
		-f qemu-user-static/Dockerfile qemu-user-static/
	touch $@

.PHONY: qemu-user-static-cd
qemu-user-static-cd: qemu-user-static-image
	docker push $(QEMU_USER_STATIC):latest

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
calico-base-image: register qemu-user-static-image
	$(DOCKER_BUILD) --build-arg LDSONAME=$(LDSONAME) -t $(CALICO_BASE):latest-$(ARCH) -f calico-base/Dockerfile calico-base/
	$(MAKE) BUILD_IMAGES=$(CALICO_BASE) retag-build-images-with-registries VALIDARCHES=$(ARCH) IMAGETAG=latest

.PHONY: calico-base-image-all
calico-base-image-all: $(addprefix sub-calico-base-image-,$(VALIDARCHES))
sub-calico-base-image-%:
	$(MAKE) calico-base-image ARCH=$*

.PHONY: calico-base-cd
calico-base-cd: calico-base-image-all var-require-one-of-CONFIRM-DRYRUN var-require-all-BRANCH_NAME
	$(MAKE) BUILD_IMAGES=$(CALICO_BASE) retag-build-images-with-registries push-images-to-registries push-manifests IMAGETAG=$(if $(IMAGETAG_PREFIX),$(IMAGETAG_PREFIX)-)$(BRANCH_NAME) EXCLUDEARCH="$(EXCLUDEARCH)"

# Calico builder which contains Go/Clang compilers and necessary utilities for UT/FVs.
.PHONY: build
build:
	$(MAKE) -C ../cmd build
	mkdir -p calico-go-build/bin/
	cp ../cmd/bin/semvalidator-$(ARCH) calico-go-build/bin/semvalidator-$(ARCH)

.PHONY: calico-go-build-image
calico-go-build-image: register qemu-user-static-image build
	$(DOCKER_BUILD) -t $(CALICO_GO_BUILD):latest-$(ARCH) -f calico-go-build/Dockerfile calico-go-build/
	$(MAKE) BUILD_IMAGES=$(CALICO_GO_BUILD) retag-build-images-with-registries VALIDARCHES=$(ARCH) IMAGETAG=$(VERSION_TAG)

.PHONY: calico-go-build-image-all
calico-go-build-image-all: $(addprefix sub-calico-go-build-image-,$(VALIDARCHES))
sub-calico-go-build-image-%:
	$(MAKE) calico-go-build-image ARCH=$*

.PHONY: calico-go-build-cd
calico-go-build-cd: calico-go-build-image var-require-one-of-CONFIRM-DRYRUN var-require-all-BRANCH_NAME
	$(MAKE) BUILD_IMAGES=$(CALICO_GO_BUILD) retag-build-images-with-registries push-images-to-registries IMAGETAG=$(if $(IMAGETAG_PREFIX),$(IMAGETAG_PREFIX)-)$(BRANCH_NAME) EXCLUDEARCH="$(EXCLUDEARCH)"

.PHONY: push-calico-go-build-manifests
push-calico-go-build-manifests: var-require-one-of-CONFIRM-DRYRUN var-require-all-BRANCH_NAME
	$(MAKE) BUILD_IMAGES=$(CALICO_GO_BUILD) push-manifests IMAGETAG=$(if $(IMAGETAG_PREFIX),$(IMAGETAG_PREFIX)-)$(BRANCH_NAME) EXCLUDEARCH="$(EXCLUDEARCH)"

.PHONY: clean
clean:
	rm -f $(QEMU_USER_STATIC_IMAGE_CREATED)
	rm -fr calico-go-build/bin
	-docker image rm -f $$(docker images $(CALICO_BASE) -a -q)
	-docker image rm -f $$(docker images $(CALICO_GO_BUILD) -a -q)
	-docker image rm -f $$(docker images $(QEMU_USER_STATIC) -a -q)
