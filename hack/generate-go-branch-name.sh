#!/bin/bash

set -eu

ver_file=""

while getopts ":f:" opt; do
    case $opt in
    f)
        ver_file="$OPTARG"
        ;;
    :)
        echo "option: -$OPTARG requires an argument" >&2
        exit 1
        ;;
    *)
        echo "invalid argument -$OPTARG" >&2
        exit 1
        ;;
    esac
done

golang_ver=$(yq -r .golang.version "$ver_file")

if [[ -z $golang_ver ]]; then
    echo "golang version is empty" >&2
    exit 1
fi

# transform 1.xy.z to go1.xy
echo "go${golang_ver%.*}"
