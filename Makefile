calico/go-build:
	# Make sure we re-pull the base image to pick up security fixes.
	docker build --pull -t calico/go-build .

calico/go-build-ppc64le:
	docker build --pull -t calico/go-build-ppc64le -f Dockerfile.ppc64le .
