#!/bin/sh

set -e

BASEDIR="${PWD}"
SUBDIRS="Backgrounder"

for LIB in ${SUBDIRS}; do
    cd "${BASEDIR}/${LIB}"
    make clean
    make 
    /opt/iPhone/ldid -S ${LIB}.dylib
    make install
done

ssh root@iphone /usr/bin/restart
