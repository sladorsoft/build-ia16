#!/bin/bash

set -e -o pipefail

cd $(dirname "$0")

out=prefix/build-ia16-redist.tar.xz

rm -rf "$out" redist
mkdir redist
find prefix -type d \! -path '*/locale' \! -path '*/info' \! -path '*/man' \
  \! -path '*/plugin/include' \! -path '*/locale/*' \! -path '*/info/*' \
  \! -path '*/man/*' \! -path '*/plugin/include/*' \! -path '*/ia16-elf/bin' \
  \! -path '*/include/c++/*/experimental' \
  \! -path '*/include/c++/*/experimental/*' \
  \! -path '*/freedos/doc' \! -path '*/freedos/doc/*' \
  \! -path '*/freedos/nls' \! -path '*/freedos/nls/*' \
  -print0 | (cd redist && xargs -0 mkdir)
find prefix \! -type d \! -name '*.info' \! -path '*/man/*' \! -name dir \
  \! -name '*.mo' \! -path '*/plugin/include/*' \! -path '*/ia16-elf/bin/*' \
  \! -path '*/include/c++/*/experimental/*' \
  \! -name '*-readelf' \! -name '*-elfedit' \! -name '*-c++filt' \
  \! -name '*-gcov' \! -name '*-gcov-tool' \! -name '*-gprof' \
  \! -name '*-addr2line' \! -path '*/freedos/doc/*' \
  \! -path '*/freedos/help/*.en' \! -path '*/freedos/nls/*' \! -name '*.lsm' \
  \! -name '*.pdf' | \
  cpio -p -v redist
find redist/prefix -executable \! -type d \! -type l \! -name '*.la' \
  \! -name '*.sh' \! -name 'mk*' \! -name dosemu -print0 | \
  xargs -0 strip -s -v
(cd redist/prefix/bin && ln -s ../lib/dosemu/*.so .)
(git log -n1 --pretty=tformat:'%H build-ia16' && \
 git remote -v show | awk '{ print $2; exit }') >redist/prefix/VERSION
(cd gcc-ia16 && \
 git log -n1 --pretty=tformat:'%H gcc-ia16' && \
 git remote -v show | awk '{ print $2; exit }') >>redist/prefix/VERSION
(cd newlib-ia16 && \
 git log -n1 --pretty=tformat:'%H newlib-ia16' && \
 git remote -v show | awk '{ print $2; exit }') >>redist/prefix/VERSION
if [ -f pdcurses/.git/config -a -f redist/prefix/ia16-elf/lib/libpdcurses.a ]
then
  (cd pdcurses && \
   git log -n1 --pretty=tformat:'%H pdcurses' && \
   git remote -v show | awk '{ print $2; exit }') >>redist/prefix/VERSION
fi
tar cvf - -C redist prefix | xz -9e >"$out"
