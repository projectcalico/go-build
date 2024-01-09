ARG TARGETARCH=${TARGETARCH}

FROM calico/bpftool:v5.3-${TARGETARCH} as bpftool

FROM registry.access.redhat.com/ubi8/ubi:latest

ARG TARGETARCH

ARG GOLANG_VERSION=1.21.6
ARG GOLANG_SHA256_AMD64=3f934f40ac360b9c01f616a9aa1796d227d8b0328bf64cb045c7b8c4ee9caea4
ARG GOLANG_SHA256_ARM64=e2e8aa88e1b5170a0d495d7d9c766af2b2b6c6925a8f8956d834ad6b4cacbd9a
ARG GOLANG_SHA256_PPC64LE=e872b1e9a3f2f08fd4554615a32ca9123a4ba877ab6d19d36abc3424f86bc07f
ARG GOLANG_SHA256_S390X=92894d0f732d3379bc414ffdd617eaadad47e1d72610e10d69a1156db03fc052

ARG CONTAINERREGISTRY_VERSION=v0.16.1
ARG GO_LINT_VERSION=v1.55.2
ARG K8S_VERSION=v1.27.8
ARG MOCKERY_VERSION=2.36.1

ARG CALICO_CONTROLLER_TOOLS_VERSION=calico-0.1

ENV PATH /usr/local/go/bin:$PATH

# Enable non-native runs on amd64 architecture hosts
# Supported qemu-user-static arch files are copied in Makefile `download-qemu` target
COPY qemu-*-static /usr/bin

# Install system dependencies and enable epel
RUN dnf upgrade -y && dnf install -y \
    autoconf \
    automake \
    clang \
    gcc \
    gcc-c++ \
    git \
    glibc-static \
    iputils \
    jq \
    libcurl-devel \
    libpcap-devel \
    libtool \
    llvm \
    make \
    openssh-clients \
    pcre-devel \
    pkg-config \
    wget \
    zip

# Install system dependencies that are not in UBI repos
COPY rockylinux/Rocky*.repo /etc/yum.repos.d/

RUN set -eux; \
    if [ "${TARGETARCH}" = "amd64" ] || [ "${TARGETARCH}" = "arm64" ]; then \
        dnf --enablerepo=baseos,extras,powertools install -y \
            elfutils-libelf-devel \
            epel-release \
            iproute-devel \
            iproute-tc \
            libbpf-devel \
            lmdb-libs; \
        # requires epel-release package to be installed first
        dnf install -y \
            GeoIP-devel \
            libmodsecurity-devel; \
    fi

RUN set -eux; \
    if [ "${TARGETARCH}" = "amd64" ]; then \
        dnf --enablerepo=powertools install -y \
            mingw64-gcc; \
    fi

RUN dnf clean all

# Install Go official release
RUN set -eux; \
    url=; \
    case "${TARGETARCH}" in \
    'amd64') \
        url="https://dl.google.com/go/go${GOLANG_VERSION}.linux-amd64.tar.gz"; \
        sha256="${GOLANG_SHA256_AMD64}"; \
        ;; \
    'arm64') \
        url="https://dl.google.com/go/go${GOLANG_VERSION}.linux-arm64.tar.gz"; \
        sha256="${GOLANG_SHA256_ARM64}"; \
        ;; \
    'ppc64le') \
        url="https://dl.google.com/go/go${GOLANG_VERSION}.linux-ppc64le.tar.gz"; \
        sha256="${GOLANG_SHA256_PPC64LE}"; \
        ;; \
    's390x') \
        url="https://dl.google.com/go/go${GOLANG_VERSION}.linux-s390x.tar.gz"; \
        sha256="${GOLANG_SHA256_S390X}"; \
        ;; \
    *) echo >&2 "error: unsupported architecture '${TARGETARCH}'"; exit 1 ;; \
    esac; \
    \
    wget -O go.tgz.asc "$url.asc"; \
    wget -O go.tgz "$url" --progress=dot:giga; \
    echo "$sha256 *go.tgz" | sha256sum -c -; \
    \
    # https://github.com/golang/go/issues/14739#issuecomment-324767697
    GNUPGHOME="$(mktemp -d)"; export GNUPGHOME; \
    # https://www.google.com/linuxrepositories/
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 'EB4C 1BFD 4F04 2F6D DDCC  EC91 7721 F63B D38B 4796'; \
    # let's also fetch the specific subkey of that key explicitly that we expect "go.tgz.asc" to be signed by, just to make sure we definitely have it
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys '2F52 8D36 D67B 69ED F998  D857 78BD 6547 3CB3 BD13'; \
    gpg --batch --verify go.tgz.asc go.tgz; \
    gpgconf --kill all; \
    rm -rf "$GNUPGHOME" go.tgz.asc; \
    \
    tar -C /usr/local -xzf go.tgz; \
    rm -f go.tgz*; \
    \
    go version

# don't auto-upgrade the gotoolchain
# https://github.com/docker-library/golang/issues/472
ENV GOTOOLCHAIN=local

ENV GOPATH /go
ENV PATH $GOPATH/bin:$PATH
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 1777 "$GOPATH"

# su-exec is used by the entrypoint script to execute the user's command with the right UID/GID.
RUN set -eux; \
    curl -sfL https://raw.githubusercontent.com/ncopa/su-exec/master/su-exec.c -o /tmp/su-exec.c; \
    gcc -Wall -O2 /tmp/su-exec.c -o /usr/bin/su-exec; \
    rm -f /tmp/su-exec.c

# Install Go utilities

# controller-gen is used for generating CRD files.
# Download a version of controller-gen that has been updated to support additional types (e.g., float).
# We can remove this once we update the Calico v3 APIs to use only types which are supported by the upstream controller-gen
# tooling. Example: float, all the types in the numorstring package, etc.
RUN set -eux; \
    if [ "${TARGETARCH}" = "amd64" ]; then \
        wget -O /usr/local/bin/controller-gen https://github.com/projectcalico/controller-tools/releases/download/${CALICO_CONTROLLER_TOOLS_VERSION}/controller-gen && chmod +x /usr/local/bin/controller-gen; \
    fi

# crane is needed for our release targets to copy images from the dev registries to the release registries.
RUN set -eux; \
    if [ "${TARGETARCH}" = "amd64" ]; then \
        curl -sfL https://github.com/google/go-containerregistry/releases/download/${CONTAINERREGISTRY_VERSION}/go-containerregistry_Linux_x86_64.tar.gz | tar xz -C /usr/local/bin crane; \
    fi

RUN curl -sfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b /usr/local/bin $GO_LINT_VERSION

# Install necessary Kubernetes binaries used in tests.
RUN wget https://dl.k8s.io/${K8S_VERSION}/bin/linux/${TARGETARCH}/kube-apiserver -O /usr/local/bin/kube-apiserver && chmod +x /usr/local/bin/kube-apiserver && \
    wget https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/${TARGETARCH}/kubectl -O /usr/local/bin/kubectl && chmod +x /usr/local/bin/kubectl && \
    wget https://dl.k8s.io/${K8S_VERSION}/bin/linux/${TARGETARCH}/kube-controller-manager -O /usr/local/bin/kube-controller-manager && chmod +x /usr/local/bin/kube-controller-manager

RUN set -eux; \
    case "${TARGETARCH}" in \
    'amd64') \
        curl -sfL https://github.com/vektra/mockery/releases/download/v${MOCKERY_VERSION}/mockery_${MOCKERY_VERSION}_Linux_x86_64.tar.gz | tar xz -C /usr/local/bin --extract mockery; \
        ;; \
    'arm64') \
        curl -sfL https://github.com/vektra/mockery/releases/download/v${MOCKERY_VERSION}/mockery_${MOCKERY_VERSION}_Linux_arm64.tar.gz | tar xz -C /usr/local/bin --extract mockery; \
        ;; \
    *) echo >&2 "warning: unsupported architecture '${TARGETARCH}'" ;; \
    esac

# Install go programs that we rely on
# Install ginkgo v2 as ginkgo2 and keep ginkgo v1 as ginkgo
RUN go install github.com/onsi/ginkgo/v2/ginkgo@v2.13.0 && mv /go/bin/ginkgo /go/bin/ginkgo2 && \
    go install github.com/onsi/ginkgo/ginkgo@v1.16.5 && \
    go install github.com/jstemmer/go-junit-report@v1.0.0 && \
    go install github.com/mikefarah/yq/v3@3.4.1 && \
    go install github.com/pmezard/licenses@v0.0.0-20160314180953-1117911df3df && \
    go install github.com/swaggo/swag/cmd/swag@v1.16.2 && \
    go install github.com/wadey/gocovmerge@v0.0.0-20160331181800-b5bfa59ec0ad && \
    go install golang.org/x/tools/cmd/goimports@v0.14.0 && \
    go install golang.org/x/tools/cmd/stringer@v0.14.0 && \
    go install gotest.tools/gotestsum@v1.11.0 && \
    go install k8s.io/code-generator/cmd/client-gen@v0.27.8 && \
    go install k8s.io/code-generator/cmd/conversion-gen@v0.27.8 && \
    go install k8s.io/code-generator/cmd/deepcopy-gen@v0.27.8 && \
    go install k8s.io/code-generator/cmd/defaulter-gen@v0.27.8 && \
    go install k8s.io/code-generator/cmd/informer-gen@v0.27.8 && \
    go install k8s.io/code-generator/cmd/lister-gen@v0.27.8 && \
    go install k8s.io/code-generator/cmd/openapi-gen@v0.27.8 && \
    go clean -modcache && go clean -cache

# Ensure that everything under the GOPATH is writable by everyone
RUN chmod -R 777 $GOPATH

# Allow validated remote servers
COPY ssh_known_hosts /etc/ssh/ssh_known_hosts

# Add bpftool for Felix UT/FV.
COPY --from=bpftool /bpftool /usr/bin

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
