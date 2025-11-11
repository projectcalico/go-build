ARG UBI_IMAGE=registry.access.redhat.com/ubi9/ubi-minimal:latest

FROM ${UBI_IMAGE}

ARG TARGETARCH
ARG RUST_VERSION=1.90.0
ARG PROTOC_VERSION=32.1

RUN microdnf upgrade -y
RUN microdnf install -y \
  file \
  clang \
  make \
  git \
  pkg-config \
  openssl-devel \
  cmake \
  unzip

# install protoc
ENV PROTOC_VERSION=${PROTOC_VERSION}
RUN set -eux; \
    \
    case "${TARGETARCH}" in \
        amd64) PROTOC_ZIP=protoc-${PROTOC_VERSION}-linux-x86_64.zip;; \
        arm64) PROTOC_ZIP=protoc-${PROTOC_VERSION}-linux-aarch_64.zip;; \
        ppc64le) PROTOC_ZIP=protoc-${PROTOC_VERSION}-linux-ppcle_64.zip;; \
        s390x) PROTOC_ZIP=protoc-${PROTOC_VERSION}-linux-s390_64.zip;; \
        *) echo "unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    \
    curl -L -o "/tmp/${PROTOC_ZIP}" "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/${PROTOC_ZIP}"; \
    unzip "/tmp/${PROTOC_ZIP}" -d /tmp; \
    mv /tmp/bin/protoc /usr/local/bin; \
    chmod +x /usr/local/bin/protoc

# install rust
ENV RUST_VERSION=${RUST_VERSION}
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --default-toolchain ${RUST_VERSION} \
  --profile minimal --component rustfmt --component clippy --component llvm-tools && \
  mkdir -p /usr/local/lib/rustup && \
  mv /root/.cargo /usr/local/lib/rustup/cargo && \
  mv /root/.rustup /usr/local/lib/rustup/rustup
RUN cat <<'EOF' > /etc/profile.d/rust.sh
# Shared read-only Rust binaries
export PATH=/usr/local/lib/rustup/cargo/bin:$PATH

# Per-user writable Cargo and Rustup directories
if [ -z "$CARGO_HOME" ]; then
    export CARGO_HOME="$HOME/.cargo"
fi
if [ -z "$RUSTUP_HOME" ]; then
    export RUSTUP_HOME="$HOME/.rustup"
fi

[ -d "$CARGO_HOME" ] || mkdir -p "$CARGO_HOME"
[ -d "$RUSTUP_HOME" ] || mkdir -p "$RUSTUP_HOME"

# Copy system-wide toolchain to user home if empty
if [ ! -d "$RUSTUP_HOME/toolchains" ]; then
    cp -r /usr/local/lib/rustup/cargo/* "$CARGO_HOME/"
    cp -r /usr/local/lib/rustup/rustup/* "$RUSTUP_HOME/"
fi
EOF
ENV PATH=/usr/local/lib/rustup/cargo/bin:${PATH}

RUN microdnf clean all

# Build su-exec
RUN curl -L -o /tmp/su-exec.c https://raw.githubusercontent.com/ncopa/su-exec/master/su-exec.c && \
    clang -Os -o /usr/local/bin/su-exec /tmp/su-exec.c && \
    chmod +x /usr/local/bin/su-exec && \
    rm -f /tmp/su-exec.c

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/sh"]

WORKDIR /work