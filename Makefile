calico/go-build:
	docker build -t calico/go-build .

calico/go-build-ppc64le:
	./create_dockerfile.ppc64le.sh
	docker build -t calico/go-build-ppc64le -f Dockerfile.ppc64le .
