#!/bin/sh

set -e

BASEDIR="${PWD}"
SUBDIRS="Backgrounder Backgrounder-Hooks"

for LIB in ${SUBDIRS}; do
    cd "${BASEDIR}/${LIB}"
    make clean
    make 
    /opt/iPhone/ldid -S ${LIB}.dylib
    make install
    ssh root@iphone /usr/bin/restart
done
