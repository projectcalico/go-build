FROM registry.access.redhat.com/ubi8/ubi-minimal:latest as ubi

COPY qemu-*-static /usr/bin

RUN microdnf upgrade

FROM scratch as source

# Required external C dependencies for CGO builds.
COPY --from=ubi /lib64/ld-linux-*.so.2 /lib64/
COPY --from=ubi /lib64/libc.so.6 /lib64/libc.so.6
COPY --from=ubi /lib64/libpthread.so.0 /lib64/libpthread.so.0
COPY --from=ubi /lib64/libresolv.so.2 /lib64/libresolv.so.2

# glibc NSS plugins and config files.
COPY --from=ubi /lib64/libnss_dns.so.2 /lib64/libnss_dns.so.2
COPY --from=ubi /lib64/libnss_files.so.2 /lib64/libnss_files.so.2

COPY --from=ubi /etc/host.conf /etc/host.conf
COPY --from=ubi /etc/hosts /etc/hosts
COPY --from=ubi /etc/nsswitch.conf /etc/nsswitch.conf

# tmp.tar has a /tmp with the correct permissions 01777.
ADD base/tmp.tar /

FROM scratch

COPY --from=source / /
