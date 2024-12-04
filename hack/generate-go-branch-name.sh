#!/bin/bash

set -e

ver_file="$1"
if [[ -z $ver_file ]]; then
    echo "missing version metadata"
    exit 1
fi

golang_ver=$(yq -r .golang.version "$ver_file")

if [[ -z $golang_ver ]]; then
    echo "golang version is empty"
    exit 1
fi

# transform 1.xy.z to go1.xy
echo "go${golang_ver%.*}"
