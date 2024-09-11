ARG TARGETARCH=${TARGETARCH}

FROM calico/bpftool:v7.4.0 as bpftool

FROM --platform=amd64 calico/qemu-user-static:latest as qemu

FROM registry.access.redhat.com/ubi8/ubi:latest as ubi

ARG TARGETARCH

ARG GOLANG_VERSION=1.22.7
ARG GOLANG_SHA256_AMD64=ba79d4526102575196273416239cca418a651e049c2b099f3159db85e7bade7d
ARG GOLANG_SHA256_ARM64=a8e177c354d2e4a1b61020aca3562e27ea3e8f8247eca3170e3fa1e0c2f9e771
ARG GOLANG_SHA256_PPC64LE=a3e5834657ef92523f570f798fed42f1f87bc18222a16815ec76b84169649ec4
ARG GOLANG_SHA256_S390X=7590c3e278e2dc6040aae0a39da3ca1eb2e3921673a7304cc34d588c45889eec

ARG CONTAINERREGISTRY_VERSION=v0.19.1
ARG GO_LINT_VERSION=v1.57.2
ARG K8S_VERSION=v1.29.6
ARG K8S_LIBS_VERSION=v0.29.6
ARG MOCKERY_VERSION=2.42.2

ARG CALICO_CONTROLLER_TOOLS_VERSION=calico-0.1

ENV PATH=/usr/local/go/bin:$PATH

# Enable non-native runs on amd64 architecture hosts
# Supported qemu-user-static arch files are copied in Makefile `download-qemu` target
COPY --from=qemu /usr/bin/qemu-*-static /usr/bin

# Install system dependencies
RUN dnf upgrade -y && dnf install -y \
    autoconf \
    automake \
    clang \
    gcc \
    gcc-c++ \
    git \
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
    xz \
    zip

# Install system dependencies that are not in UBI repos
COPY almalinux/RPM-GPG-KEY-AlmaLinux /etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux
COPY almalinux/almalinux*.repo /etc/yum.repos.d/

RUN dnf --enablerepo=baseos,powertools install -y \
    elfutils-libelf-devel \
    iproute-devel \
    iproute-tc \
    libbpf-devel

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

ENV GOPATH=/go
ENV PATH=$GOPATH/bin:$PATH
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
        curl -sfL https://github.com/projectcalico/controller-tools/releases/download/${CALICO_CONTROLLER_TOOLS_VERSION}/controller-gen -o /usr/local/bin/controller-gen && chmod +x /usr/local/bin/controller-gen; \
    fi

# crane is needed for our release targets to copy images from the dev registries to the release registries.
RUN set -eux; \
    if [ "${TARGETARCH}" = "amd64" ]; then \
        curl -sfL https://github.com/google/go-containerregistry/releases/download/${CONTAINERREGISTRY_VERSION}/go-containerregistry_Linux_x86_64.tar.gz | tar xz -C /usr/local/bin crane; \
    fi

RUN curl -sfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b /usr/local/bin $GO_LINT_VERSION

# Install necessary Kubernetes binaries used in tests.
RUN curl -sfL https://dl.k8s.io/${K8S_VERSION}/bin/linux/${TARGETARCH}/kube-apiserver -o /usr/local/bin/kube-apiserver && chmod +x /usr/local/bin/kube-apiserver && \
    curl -sfL https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/${TARGETARCH}/kubectl -o /usr/local/bin/kubectl && chmod +x /usr/local/bin/kubectl && \
    curl -sfL https://dl.k8s.io/${K8S_VERSION}/bin/linux/${TARGETARCH}/kube-controller-manager -o /usr/local/bin/kube-controller-manager && chmod +x /usr/local/bin/kube-controller-manager

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
RUN go install github.com/onsi/ginkgo/v2/ginkgo@v2.17.1 && mv /go/bin/ginkgo /go/bin/ginkgo2 && \
    go install github.com/onsi/ginkgo/ginkgo@v1.16.5 && \
    go install github.com/jstemmer/go-junit-report@v1.0.0 && \
    go install github.com/mikefarah/yq/v3@3.4.1 && \
    go install github.com/pmezard/licenses@v0.0.0-20160314180953-1117911df3df && \
    go install github.com/swaggo/swag/cmd/swag@v1.16.3 && \
    go install github.com/wadey/gocovmerge@v0.0.0-20160331181800-b5bfa59ec0ad && \
    go install golang.org/x/tools/cmd/goimports@v0.19.0 && \
    go install golang.org/x/tools/cmd/stringer@v0.20.0 && \
    go install gotest.tools/gotestsum@v1.11.0 && \
    go install k8s.io/code-generator/cmd/client-gen@${K8S_LIBS_VERSION} && \
    go install k8s.io/code-generator/cmd/conversion-gen@${K8S_LIBS_VERSION} && \
    go install k8s.io/code-generator/cmd/deepcopy-gen@${K8S_LIBS_VERSION} && \
    go install k8s.io/code-generator/cmd/defaulter-gen@${K8S_LIBS_VERSION} && \
    go install k8s.io/code-generator/cmd/informer-gen@${K8S_LIBS_VERSION} && \
    go install k8s.io/code-generator/cmd/lister-gen@${K8S_LIBS_VERSION} && \
    go install k8s.io/code-generator/cmd/openapi-gen@${K8S_LIBS_VERSION} && \
    go clean -modcache && go clean -cache

# Ensure that everything under the GOPATH is writable by everyone
RUN chmod -R 777 $GOPATH

# Do not create mail box.
RUN sed -i 's/^CREATE_MAIL_SPOOL=yes/CREATE_MAIL_SPOOL=no/' /etc/default/useradd

# Allow validated remote servers
COPY ssh_known_hosts /etc/ssh/ssh_known_hosts

# Add bpftool for Felix UT/FV.
COPY --from=bpftool /bpftool /usr/bin

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# Squash into a single layer
FROM scratch

ENV GOPATH=/go
ENV GOTOOLCHAIN=local
ENV PATH=$GOPATH/bin:/usr/local/go/bin:$PATH

COPY --from=ubi / /

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
