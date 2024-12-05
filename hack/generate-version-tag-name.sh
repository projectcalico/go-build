#!/bin/bash

set -e

ver_file=""
go_ver_only=false

while getopts ":f:g" opt; do
    case $opt in
    f)
        ver_file="$OPTARG"
        ;;
    g)
        go_ver_only=true
        ;;
    :)
        echo "option: -$OPTARG requires an argument" >&2
        exit 1
        ;;
    *)
        echo "invalid option: -$OPTARG" >&2
        exit 1
        ;;
    esac
done

golang_ver=$(yq -r .golang.version "$ver_file")
k8s_ver=$(yq -r .kubernetes.version "$ver_file")
llvm_ver=$(yq -r .llvm.version "$ver_file")

if [[ -z $golang_ver ]] || [[ -z $k8s_ver ]] || [[ -z $llvm_ver ]]; then
    echo "one of the golang, llvm, or kubernetes versions is empty" >&2
    exit 1
fi

if [[ "$go_ver_only" = true ]]; then
    echo "${golang_ver}"
else
    echo "${golang_ver}-llvm${llvm_ver}-k8s${k8s_ver}"
fi
