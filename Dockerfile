FROM golang:1.7-alpine
MAINTAINER Tom Denham <tom@projectcalico.org>

# Install su-exec for use in the entrypoint.sh (so processes run as the right user)
# Install bash for the entry script (and because it's generally useful)
# Install curl to download glide
# Install git for fetching Go dependencies
RUN apk add --no-cache su-exec curl bash git make

# Install glide
RUN curl https://glide.sh/get | sh

# Install ginkgo CLI tool for running tests
RUN go get github.com/onsi/ginkgo/ginkgo

RUN chmod -R 777 /go

ENV GLIDE_HOME /home/user/.glide

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
