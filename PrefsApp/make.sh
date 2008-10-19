#!/bin/bash

EXE=BackgrounderPrefs
APP=Backgrounder
PREFS_NAME="jp.ashikase.backgrounder.*"
TOOLCHAIN=/opt/iPhone/sys.saurik 
DEBUG=

usage()
{
cat << EOF
    usage: `basename $0` options
    NOTE: If no options are specified, will run 'make'

    OPTIONS:
    -c      Same as 'make clean'
    -d      Enable debug build
    -h      Show this message
    -i      Install to device
    -m      Same as 'make'
    -p      Delete preferences on device
    -s      Strip the binary
EOF
}

unset clean
unset debug
unset install
unset make
unset prefs
unset strip

while getopts “cdhimpsv” options; do
    case $options in
        c) clean=1;;
        d) debug=1;;
        i) install=1;;
        m) make=1;;
        p) prefs=1;;
        s) strip=1;;
        v) verbose=1;;
        h|\?|*)
            usage
            exit
            ;;
    esac
done

if [ ! -z $clean ]; then
    echo "Cleaning..."
    make clean
fi

if [ ! -z $debug ]; then
    DEBUG="DEBUG=1"
fi

if [ ! -z $make ]; then
    echo "Building..."
    ln -snf ${TOOLCHAIN} /opt/iPhone/sys
    set -e
    if [ -z $verbose ]; then
        make ${DEBUG} 2>&1 | grep -v arm-apple-darwin | grep -v svnversion
    else
        make ${DEBUG}
    fi
    set +e
fi
        
if [[ ! -z $strip ]] && [[ -f ${EXE} ]]; then
    echo "Stripping..."
    arm-apple-darwin9-strip ${EXE}
fi

if [[ ! -z $install ]] && [[ -f ${EXE} ]]; then
    echo "Installing..."
    /opt/iPhone/ldid -S ${EXE}
    ssh root@iphone killall ${EXE} >/dev/null 2>&1
    ssh root@iphone rm -f /Applications/${APP}.app/${EXE}
    scp ${EXE} root@iphone:/Applications/${APP}.app/ >/dev/null 2>&1

fi

if [ ! -z $prefs ]; then
    echo "Deleting preferences..."
	ssh root@iphone rm -f /var/mobile/Library/Preferences/${PREFS_NAME}
fi

# If no options were set, run make
if [[ -z $clean ]] && [[ -z $install ]] && [[ -z $prefs ]] && [[ -z $strip ]] && [[ -z $make ]]; then
    echo "Building..."
    if [ -z $verbose ]; then
        make ${DEBUG} 2>&1 | grep -v arm-apple-darwin | grep -v svnversion
    else
        make ${DEBUG}
    fi
fi
