[![Build Status](https://semaphoreci.com/api/v1/calico/go-build/branches/master/badge.svg)](https://semaphoreci.com/calico/go-build)

# Calico go-build

Base image for doing golang builds for the various [project calico](https://projectcalico.org) builds.

## Building the image

To build the image:

```bash
make image
```

The above will build for whatever architecture you are running on. To force a different architecture:

```bash
ARCH=<somearch> make image
```

## Tagging

The image is tagged the version, e.g. `v0.9` or `latest`. In addition, the given architecture is appended to the end. Thus, for example, the latest version on `amd64` will be `calico/go-build:latest-amd64`.

The above tagging scheme keeps everything in a single image repository `calico/go-build` and prepares for using multi-architecture image manifests.

As of this writing, the only way to create such manifests is using the [manifest-tool](https://github.com/estesp/manifest-tool), which involves multiple steps. This can be incorporated into the build process, or we can wait until `docker manifest` is rolled into the docker CLI, see [this PR](https://github.com/docker/cli/pull/138).

Until such time as the `docker manifest` is ready, or we decide to use `manifest-tool`, the default image name will point to `amd64`. Thus, `calico/go-build:latest` refers to `calico/go-build:latest-amd64`.

## Cross building using go-build

Any supported platform can be built natively from its own platform, i.e.g `amd64` from `amd64`, `arm64` from `arm64` and `ppc64le` from `ppc64le`. In addition,
`ppc64le` and `arm64` are supported for cross-building from `amd64` only. We do not (yet) support cross-building from `arm64` and `ppc64le`.

The cross-build itself will function normally on any platform, since golang supports cross-compiling using `GOARCH=<target> go build`.

```bash
docker run -e GOARCH=<somearch> calico/go-build:latest-amd64 sh -c 'go build hello.go || ./hello'
```

The above will output a binary `hello` built for the architecture `<somearch>`.

## Cross-running Binaries binfmt

The Linux kernel has the ability to run binaries built for one arch on another, e.g. `arm64` binaries on an `amd64` architecture. Support requires two things:

1. Registering an interpreter that can run the binary for the other architecture along with configuration information on how to identify which binaries are for which platform and which emulator will handle them.
2. Making the interpreter binary available.

The interpreter must exist in one of two places:

* The container where you are running the other-architecture binary.
* The container where you run registration, if you pass the correct flag during registration. This is supported **only** from Linux kernel version 4.8+.

For example, if you registered the `s390x` emulator at `/usr/bin/qemu-s390x-static`, and then wanted to run `docker run -it --rm s390x/alpine:3.10 sh` on an `amd64`, it wouldn't work in the first method, because the new container doesn't have an emulator in it. However, if you followed the second method, it would work, since the kernel already found and loaded the emulator. This works **even if you delete the registration container.**

To register emulators, we run:

```bash
docker run -it --rm --privileged multiarch/qemu-user-static:register
```

or simply

```bash
make register
```

After the above registration, your system can handle other-architecture binaries. The above registration uses the first method, since _all_ kernels that support `binfmt` support this method, while only kernels from version 4.8+ support the latter. While docker-for-mac and docker-for-windows both use supporting kernels, almost every CI-as-a-service does not.

## Using binfmt in other Calico projects

To use `binfmt` in other projects:

1. Ensure you have run registration as above.
2. Copy the correct interpreter into the container in which you will run other-architecture commands. The `COPY` **must** be before _any_ `RUN` command.

```dockerfile
FROM calico/go-build:v0.16 as qemu

FROM arm64v8/golang:1.15.2-buster as base

# Enable non-native builds of this image on an amd64 hosts.
# This must be the first RUN command in this file!
# we only need this for the intermediate "base" image, so we can run all the apk and other commands
COPY --from=qemu /usr/bin/qemu-*-static /usr/bin/

# now we can do all our RUN commands
RUN apk --update add curl
# etc
```

## Running a Binary

To _run_ a binary from a different architecture, you need to use `binfmt` and `qemu` static.

Register `qemu-*-static` for all supported processors except the current one using the following command:

```bash
docker run --rm --privileged multiarch/qemu-user-static:register
```

If a cross built binary is executed in the go-build container qemu-static will automatically be used.

### Testing Cross-Run

There is a `Makefile` target that cross-builds and runs a binary. To run it on your own architecture:

```bash
make testcompile
```

or

```bash
make testcompile ARCH=$(uname -m)
```

To test on a different architecture, for example `arm64` when you are running on `amd64`, pass it an alternate architecture:

```bash
make testcompile ARCH=arm64
```

You should see the "success" message.
