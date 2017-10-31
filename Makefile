calico/go-build:
	docker build -t calico/go-build .

calico/go-build-ppc64le:
	docker build -t calico/go-build-ppc64le -f Dockerfile.ppc64le .

calico/go-build-arm64:
	docker build -t calico/go-build-arm64 -f Dockerfile.arm64 .
