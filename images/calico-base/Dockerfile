# CLEANUPLEVEL defines the level of FS stripping we apply to the generated image.
ARG CLEANUP_LEVEL
ARG BASE

FROM --platform=linux/amd64 calico/qemu-user-static:latest AS qemu

FROM ${BASE} AS source-unstripped

ARG LDSONAME

COPY --from=qemu /usr/bin/qemu-*-static /usr/bin/

ARG PKGMAN
RUN ${PKGMAN} upgrade -y
# Prepare a rootfs for necessary files from UBI.
# Symbolic links are preserved.
RUN mkdir -p /rootfs/lib64 /rootfs/etc

# Copy dynamic loader and symbolic links.
# Note: The dynamic loader name and links might be different in a future release.
RUN cp /lib64/ld-2.28.so /rootfs/lib64/ld-2.28.so
RUN set -eux; \
    cp -a /lib64/${LDSONAME} /rootfs/lib64/${LDSONAME}; \
    if [ -f /lib/${LDSONAME} ]; then \
        mkdir -p /rootfs/lib && cp -a /lib/${LDSONAME} /rootfs/lib/${LDSONAME}; \
    fi

# Required external C dependencies for CGO builds.
RUN cp /lib64/libc.so.6 /rootfs/lib64/libc.so.6
RUN cp /lib64/libpthread.so.0 /rootfs/lib64/libpthread.so.0
RUN cp /lib64/libresolv.so.2 /rootfs/lib64/libresolv.so.2

# glibc NSS plugins and config files.
RUN cp /lib64/libnss_dns.so.2 /rootfs/lib64/libnss_dns.so.2
RUN cp /lib64/libnss_files.so.2 /rootfs/lib64/libnss_files.so.2

RUN cp /etc/host.conf /rootfs/etc/host.conf
RUN cp /etc/hosts /rootfs/etc/hosts
RUN cp /etc/networks /rootfs/etc/networks
RUN cp /etc/nsswitch.conf /rootfs/etc/nsswitch.conf

# Copy base image release info.
RUN cp /etc/os-release /rootfs/etc/os-release

# Stripped image.
FROM scratch AS source-stripped
COPY --from=source-unstripped /rootfs /
# tmp.tar has a /tmp with the correct permissions 01777.
ADD tmp.tar /
COPY licenses /licenses/

# Unstripped image.
FROM source-unstripped
# Remove the prepped rootfs for the unstripped img.
RUN rm -rf /rootfs

# Choose which image is shipped.
FROM source-${CLEANUP_LEVEL}