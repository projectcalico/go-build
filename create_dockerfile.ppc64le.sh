#!/bin/sh

# Create Dockerfile.ppc64le based on Dockerfile

# Use the ppc64le/golang base image
sed 's/FROM golang:.*/FROM ppc64le\/golang:1.8.1-alpine/' Dockerfile > Dockerfile.ppc64le

# ppc64le platform does not need the syscall patch for x86
sed -i '/^COPY patches/,/RUN go install -v -a syscall/d' Dockerfile.ppc64le
