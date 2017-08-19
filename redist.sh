#!/bin/bash

set -e -o pipefail

cd $(dirname "$0")

out=prefix/build-ia16-redist.tar.xz

rm -rf "$out" redist
mkdir redist
find prefix -type d \! -path '*/locale' \! -path '*/info' \! -path '*/man' \
  \! -path '*/plugin/include' \! -path '*/locale/*' \! -path '*/info/*' \
  \! -path '*/man/*' \! -path '*/plugin/include/*' \! -path '*/ia16-elf/bin' \
  -print0 | (cd redist && xargs -0 mkdir)
find prefix \! -type d \! -name '*.info' \! -name '*.[0-9]' \! -name dir \
  \! -name '*.mo' \! -path '*/plugin/include/*' \! -path '*/ia16-elf/bin/*' | \
  cpio -p -v redist
find redist/prefix -executable \! -type d \! -type l \! -name '*.la' \
  \! -name '*.sh' \! -name 'mk*' -print0 | xargs -0 strip -s -v
tar cvf - -C redist prefix | xz -9 >"$out"
