include ../Makefile.common
include ../lib.Makefile

.PHONY: build
build: semvalidator-build-$(ARCH)

.PHONY: semvalidator-build-$(ARCH)
semvalidator-build-$(ARCH): semvalidator/main.go
	CGO_ENABLED=0 go build -o bin/semvalidator-$(ARCH) -v -buildvcs=false -ldflags "-s -w" semvalidator/main.go

.PHONY: clean
clean:
	rm -fr bin/
