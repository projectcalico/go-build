QEMU ?= calico/qemu-user-static
QEMU_IMAGE ?= $(QEMU):latest

.PHONY: image
image:
	docker buildx build $(DOCKER_PROGRESS) --load --platform=linux/amd64 --pull -t $(QEMU_IMAGE) -f Dockerfile .

.PHONY: push
push: image
	docker push $(QEMU_IMAGE)

.PHONY: clean
clean:
	-docker image rm -f $$(docker images $(QEMU) -a -q)
