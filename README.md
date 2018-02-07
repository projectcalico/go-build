# Calico go-build
Base image for doing golang builds for the various [project calico](https://projectcalico.org) builds.


## Building the image
To build the image:

```
make build
```

The above will build for whatever architecture you are running on. To force a different architecture:

```
ARCH=<somearch> make build
```

## Tagging
The image is tagged the version, e.g. `v0.9` or `latest`. In addition, the given architecture is appended to the end. Thus, for example, the latest version on `amd64` will be `calico/go-build:latest-amd64`.

The above tagging scheme keeps everything in a single image repository `calico/go-build` and prepares for using milti-architecture image manifests. 

As of this writing, the only way to create such manifests is using the [manifest-tool](https://github.com/estesp/manifest-tool), which involves multiple steps. This can be incorporated into the build process, or we can wait until `docker manifest` is rolled into the docker CLI, see [this PR](https://github.com/docker/cli/pull/138).

Until such time as the `docker manifest` is ready, or we decide to use `manifest-tool`, the default image name will point to `amd64`. Thus, `calico/go-build:latest` refers to `calico/go-build:latest-amd64`.


## Cross building using go-build:

Ppc64le and arm64 are supported for cross-building. This example assumes you are running on an amd64/linux system.

Register qemu-*-static for all supported processors except the current one using the following command:

```
sudo docker run --rm --privileged multiarch/qemu-user-static:register
```

Specify the target arch by setting GOARCH.

```
docker run -e GOARCH=<somearch> calico/go-build:latest-amd64 sh -c 'go build hello.go || ./hello'
```

If a cross built binary is executed in the go-build container qemu-static will automatically be used.
