FROM golang:1.7-alpine
MAINTAINER Tom Denham <tom@projectcalico.org>

# Install su-exec for use in the entrypoint.sh (so processes run as the right user)
# Install bash for the entry script (and because it's generally useful)
# Install curl to download glide
# Install git for fetching Go dependencies
# Install mercurial for fetching go dependencies
# Install wget for fetching glibc
# Install make for building things
# Install util-linux for column command (used for output formatting).
RUN apk add --no-cache su-exec curl bash git mercurial make wget util-linux

# Install glibc
RUN wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://raw.githubusercontent.com/sgerrand/alpine-pkg-glibc/master/sgerrand.rsa.pub
RUN wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.23-r3/glibc-2.23-r3.apk
RUN apk add glibc-2.23-r3.apk

# Disable cgo so that binaries we build will be fully static.
ENV CGO_ENABLED=0

# Apply patches to Go runtime and recompile.
# See https://github.com/golang/go/issues/5838 for defails of vfork patch.
COPY patches/use-clone-vfork-b7edfba429d982e3e065d637334bcc63ad49f8f9.patch \
     /tmp/use-clone-vfork-b7edfba429d982e3e065d637334bcc63ad49f8f9.patch
RUN cd /usr/local/go && \
    patch -p 1 < /tmp/use-clone-vfork-b7edfba429d982e3e065d637334bcc63ad49f8f9.patch
RUN go install -v -a syscall

# Recompile the standard library with cgo disabled.  This prevents the standard library from being
# marked stale, causing full rebuilds every time.
RUN go install -v std

# Install glide
RUN go get github.com/Masterminds/glide
ENV GLIDE_HOME /home/user/.glide

# Install ginkgo CLI tool for running tests
RUN go get github.com/onsi/ginkgo/ginkgo

# Install linting tools
RUN go get -u github.com/alecthomas/gometalinter
RUN gometalinter --install

# Install license checking tool.
RUN go get github.com/pmezard/licenses

# Install tool to merge coverage reports.
RUN go get github.com/wadey/gocovmerge

# Install patched version of goveralls (upstream is bugged if not used from Travis).
RUN wget https://github.com/fasaxc/goveralls/releases/download/v0.0.1-smc/goveralls && \
    chmod +x goveralls && \
    mv goveralls /usr/bin/

# Ensure that everything under the GOPATH is writable by everyone
RUN chmod -R 777 $GOPATH

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
