#!/bin/sh

set -e

FILE_NAME=Backgrounder.dylib

make clean
make 
ssh root@iphone rm -f /Library/MobileSubstrate/DynamicLibraries/${FILE_NAME}
/opt/iPhone/ldid -S ${FILE_NAME}
scp ${FILE_NAME} root@iphone:/Library/MobileSubstrate/DynamicLibraries/
ssh root@iphone /usr/bin/restart
