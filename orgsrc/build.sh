#!/bin/sh

set -e

if_os () { [[ $OSTYPE == *$1* ]]; }
if_nix () {
    case "$OSTYPE" in
        *linux*|*hurd*|*msys*|*cygwin*|*sua*|*interix*) sys="gnu";;
        *bsd*|*darwin*) sys="bsd";;
        *sunos*|*solaris*|*indiana*|*illumos*|*smartos*) sys="sun";;
        *windows*|*indos*) sys="win";;
    esac
    # echo "sys is ${sys}"
    [[ "${sys}" == "$1" ]];
}

CC=${CC:-clang}
if if_nix win; then
    echo "Windows build"
else
    type $CC >/dev/null 2>&1 || CC="gcc"
    type $CC >/dev/null 2>&1 || { echo >&2 "I require clang or gcc but it's not installed. Aborting."; exit 1; }
fi

CMD_BSD="${CC} ctime-maclinux.c -o ctime"
CMD_GNU="${CC} ctime-maclinux.c -lrt -o ctime"
CMD_WIN="cl -O2 ctime.c /link winmm.lib"
CMD=""

if_nix gnu && CMD=$CMD_GNU
if_nix bsd && CMD=$CMD_BSD
if_nix win && CMD=$CMD_WIN

echo "Executing: $CMD"

$CMD

echo "Done."
