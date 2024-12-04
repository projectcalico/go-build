include ../lib.Makefile

BASE ?= calico/base
BASE_IMAGE ?= $(BASE):latest
BASE_ARCH_IMAGE ?= $(BASE_IMAGE)-$(ARCH)

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

.PHONY: image
image: register
	docker buildx build $(DOCKER_PROGRESS) --load --platform=linux/$(ARCH) --build-arg LDSONAME=$(LDSONAME) -t $(BASE_ARCH_IMAGE) -f Dockerfile .

.PHONY: image-all
image-all: $(addprefix sub-image-,$(ARCHES))
sub-image-%:
	$(MAKE) image ARCH=$*

.PHONY: push
push: image
	docker push $(BASE_ARCH_IMAGE)

.PHONY: push-all
push-all: $(addprefix sub-push-,$(ARCHES))
sub-push-%:
	$(MAKE) push ARCH=$*

.PHONY: push-manifest
push-manifest:
	docker manifest create $(BASE_IMAGE) $(addprefix --amend ,$(addprefix $(BASE_IMAGE)-,$(ARCHES)))
	docker manifest push --purge $(BASE_IMAGE)

.PHONY: clean
clean:
	-docker image rm -f $$(docker images $(BASE) -a -q)
