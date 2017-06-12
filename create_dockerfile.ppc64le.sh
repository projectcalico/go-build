#!/bin/sh

set -e

# Create Dockerfile.ppc64le based on Dockerfile

# Use the ppc64le/golang base image
sed 's/FROM golang:.*/FROM ppc64le\/golang:1.8.1-alpine/' Dockerfile > tmp.Dockerfile.ppc64le

# ppc64le platform does not need the syscall patch for x86
sed -i '/^COPY patches/,/RUN go install -v -a syscall/d' tmp.Dockerfile.ppc64le

mv -f tmp.Dockerfile.ppc64le Dockerfile.ppc64le
