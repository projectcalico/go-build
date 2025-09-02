include ../lib.Makefile
include ../Makefile.common

PACKAGE_NAME := github.com/projectcalico/go-build
VERSION := $(shell git describe --tags --dirty --always --abbrev=12)
REVISION := $(shell git rev-parse --short HEAD)

.PHONY: build
build: build-semvalidator-$(ARCH) build-docker-credential-calieph-$(ARCH)

.PHONY: clean
clean:
	rm -fr bin/

.PHONY: build-%-$(ARCH)
build-%-$(ARCH): %/main.go
	CGO_ENABLED=0 GOOS=linux GOARCH=$(ARCH) \
		go build -o bin/$*-$(ARCH) -v -buildvcs=false \
		-ldflags="-s -w -X '$(PACKAGE_NAME)/cmd/$*.Revision=$(REVISION)' -X '$(PACKAGE_NAME)/cmd/$*.Version=$(VERSION)'" \
		$*/main.go