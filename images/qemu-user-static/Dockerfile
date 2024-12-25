FROM fedora:latest AS qemu

RUN dnf install -y qemu-user-static

FROM scratch AS source

COPY --from=qemu /usr/bin/qemu-aarch64-static /usr/bin/qemu-aarch64-static
COPY --from=qemu /usr/bin/qemu-ppc64le-static /usr/bin/qemu-ppc64le-static
COPY --from=qemu /usr/bin/qemu-s390x-static /usr/bin/qemu-s390x-static
COPY --from=qemu /usr/bin/qemu-x86_64-static /usr/bin/qemu-x86_64-static

FROM scratch

COPY --from=source / /
