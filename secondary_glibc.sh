#!/bin/bash

function main() {
    COMMAND=$1
    init_variables

    case $COMMAND in
        build)
            build
            ;;
        help)
            help
            ;;
        *)
            help
            ;;
    esac
}

function init_variables() {
    GLIBC_VERSION=2.37
}

function help() {
    cat <<EOF
1. How to link your program with your local glibc
    export LD_LIBRARY_PATH=/home/username/glibc_\${GLIBC_VERSION}/install/lib:\$LD_LIBRARY_PATH
    gcc -Wl,-rpath=/home/username/glibc_\${}/install/lib -L/home/username/glibc_\${GLIBC_VERSION}/install/lib -I/home/username/glibc_\${GLIBC_VERSION}/install/include myprogram.c -o myprogram


2. If your program is linked with the glibc being compiled with -rpath (this information is for runtime), you don't necessarily have to set LD_LIBRARY_PATH. Otherwise you need to.

EOF
}

function build() {
    # https://tldp.org/HOWTO/Glibc2-HOWTO-5.html

    cd $HOME
    rm -rf glibc-${GLIBC_VERSION}

    # having src, build, install under glibc directory
    mkdir -p $HOME/glibc-${GLIBC_VERSION}/src
    wget http://ftp.gnu.org/gnu/libc/glibc-${GLIBC_VERSION}.tar.gz
    tar -xvf glibc-${GLIBC_VERSION}.tar.gz -C $HOME/glibc-${GLIBC_VERSION}/src
    cd glibc-${GLIBC_VERSION}
    rm -rf build install
    mkdir build
    mkdir install
    
    cd build
    ../src/configure --prefix=$HOME/glibc-${GLIBC_VERSION}/install
    make -j $(nproc)
    make install
}

main "$@"; exit