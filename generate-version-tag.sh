#!/bin/bash

set -e

ver_file="$1"
if [[ -z $ver_file ]]; then
    ver_file=versions.yaml
fi

golang_ver=$(yq -r .golang.version "$ver_file")
k8s_ver=$(yq -r .kubernetes.version "$ver_file")
llvm_ver=$(yq -r .llvm.version "$ver_file")

if [[ -z $golang_ver ]] || [[ -z $k8s_ver ]] || [[ -z $llvm_ver ]]; then
    exit 1
fi

echo "${golang_ver}-llvm${llvm_ver}-k8s${k8s_ver}"
