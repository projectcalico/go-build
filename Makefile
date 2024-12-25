include Makefile.common

.PHONY: build
build:
	$(MAKE) -C cmd build

.PHONY: image
image:
	$(MAKE) -C images image

.PHONY: clean
clean:
	$(MAKE) -C cmd clean
	$(MAKE) -C images clean

.PHONY: update-go-build-pins
update-go-build-pins:
	SEMAPHORE_AUTO_PIN_UPDATE_PROJECT_IDS=$(SEMAPHORE_CALICO_PROJECT_ID) \
	SEMAPHORE_WORKFLOW_FILE=update-go-build-pins.yml \
	$(MAKE) semaphore-run-auto-pin-update-workflows
