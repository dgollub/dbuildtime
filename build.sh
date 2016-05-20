#!/bin/sh

set -e

CC="dmd"

mkdir -p build

CMD="${CC} -Isrc src/dbuildtime.d -ofbuild/dbuildtime"

echo "Executing: $CMD"

$CMD

echo "Done."

