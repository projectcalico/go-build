# Calico go-build
Base image for doing golang builds for the various [project calico](https://projectcalico.org) builds.

| Name |
|---|
|[calicoctl](https://github.com/projectcalico/calicoctl)
|[felix](https://github.com/projectcalico/felix)
|[typha](https://github.com/projectcalico/typha)
|[calico/node](https://github.com/projectcalico/calico/blob/master/calico_node/)
|[libcalico-go](https://github.com/projectcalico/libcalico-go)
|[cni-plugin](https://github.com/projectcalico/cni-plugin)
|[libnetwork-plugin](https://github.com/projectcalico/libnetwork-plugin)
|[kube-controllers](https://github.com/projectcalico/kube-controllers)
|[calico-upgrade](https://github.com/projectcalico/calico-upgrade)
|[confd](https://github.com/projectcalico/confd)
|[calico-bgp-daemon](https://github.com/projectcalico/calico-bgp-daemon)

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
Any supported platform can be built natively from its own platform, i.e.g `amd64` from `amd64`, `arm64` from `arm64` and `ppc64le` from `ppc64le`. In addition,
`ppc64le` and `arm64` are supported for cross-building from `amd64` only. We do not (yet) support cross-building from `arm64` and `ppc64le`.

The cross-build itself will function normally on any platform, since golang supports cross-compiling using `GOARCH=<target> go build `.

```
docker run -e GOARCH=<somearch> calico/go-build:latest-amd64 sh -c 'go build hello.go || ./hello'
```

The above will output a binary `hello` built for the architecture `<somearch>`.

## Running a Binary
To *run* a binary from a different architecture, you need to use `binfmt` and `qemu` static. 

Register `qemu-*-static` for all supported processors except the current one using the following command:

```
docker run --rm --privileged multiarch/qemu-user-static:register
```


If a cross built binary is executed in the go-build container qemu-static will automatically be used.


### Testing Cross-Run
There is a `Makefile` target that cross-builds and runs a binary. To run it on your own architecture:

```
make testcompile
```

or

```
make testcompile ARCH=$(uname -m)
```

To test on a different architecture, for example `arm64` when you are running on `amd64`, pass it an alternate architecture:

```
make testcompile ARCH=arm64
```

You should see the "success" message.

