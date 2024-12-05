include lib.Makefile

VERSION_TAG ?= $(shell hack/generate-version-tag-name.sh -f versions.yaml)
VERSION_TAG_GO_ONLY ?= $(shell hack/generate-version-tag-name.sh -f versions.yaml -g)

GOBUILD ?= calico/go-build
GOBUILD_IMAGE ?= $(GOBUILD):$(VERSION_TAG)
GOBUILD_ARCH_IMAGE ?= $(GOBUILD_IMAGE)-$(ARCH)
GOBUILD_IMAGE_GO_ONLY ?= $(GOBUILD):$(VERSION_TAG_GO_ONLY)
GOBUILD_ARCH_IMAGE_GO_ONLY ?= $(GOBUILD_IMAGE_GO_ONLY)-$(ARCH)

###############################################################################
# Build images
###############################################################################
.PHONY: image-qemu
image-qemu:
	$(MAKE) -C qemu image

.PHONY: image
image: register image-qemu
	docker buildx build $(DOCKER_PROGRESS) --load --platform=linux/$(ARCH) -t $(GOBUILD_ARCH_IMAGE) -f Dockerfile .
	docker tag $(GOBUILD_ARCH_IMAGE) $(GOBUILD_ARCH_IMAGE_GO_ONLY)
ifeq ($(ARCH),amd64)
	docker tag $(GOBUILD_ARCH_IMAGE) $(GOBUILD_IMAGE)
endif

.PHONY: image-all
image-all: $(addprefix sub-image-,$(ARCHES))
sub-image-%:
	$(MAKE) image ARCH=$*

###############################################################################
# Publish images and manifest
###############################################################################
.PHONY: push
push: image
	docker push $(GOBUILD_ARCH_IMAGE)

push-all: $(addprefix sub-push-,$(ARCHES))
sub-push-%:
	$(MAKE) push ARCH=$*

.PHONY: push-manifest
push-manifest:
	docker manifest create $(GOBUILD_IMAGE) $(addprefix --amend ,$(addprefix $(GOBUILD_IMAGE)-,$(ARCHES)))
	docker manifest push --purge $(GOBUILD_IMAGE)
	docker manifest create $(GOBUILD_IMAGE_GO_ONLY) $(addprefix --amend ,$(addprefix $(GOBUILD_IMAGE_GO_ONLY)-,$(ARCHES)))
	docker manifest push --purge $(GOBUILD_IMAGE_GO_ONLY)

###############################################################################
# Clean
###############################################################################
.PHONY: clean
clean:
	$(MAKE) -C qemu clean
	$(MAKE) -C base clean
	-docker image rm -f $$(docker images $(GOBUILD) -a -q)

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
# CI/CD
###############################################################################
.PHONY: ci
ci: image-all test
