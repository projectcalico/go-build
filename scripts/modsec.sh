#!/usr/bin/env sh
set -e
cd /tmp
git clone https://github.com/SpiderLabs/ModSecurity.git
cd ModSecurity
git checkout ${MODSEC_VERSION:-v3.0.8}
git submodule update --init
./build.sh
./configure
make
make install
cd ..
rm -rf /tmp/ModSecurity
