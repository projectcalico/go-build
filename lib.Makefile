VALIDARCHES = amd64 arm64 ppc64le s390x

ifdef CI
    DOCKER_PROGRESS := --progress=plain
endif

DOCKER_BUILD=docker buildx build $(DOCKER_PROGRESS) --load --platform=linux/$(ARCH)

DEV_REGISTRIES ?= calico