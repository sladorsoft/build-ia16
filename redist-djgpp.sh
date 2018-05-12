#!/bin/bash

# This shell script will create IA-16 toolchain packages for FreeDOS
# (http://wiki.freedos.org/wiki/index.php/Package) which can work with an
# installation of DJGPP (http://www.ibiblio.org/pub/micro/pc-stuff/freedos/
# files/distributions/1.2/repos/pkg-html/djgpp.html).

set -e -o pipefail
cd $(dirname "$0")
our_dir="`pwd`"

rm -rf redist-djgpp
mkdir -p redist-djgpp/appinfo redist-djgpp/devel/djgpp

export TZ=UTC0
date="`date +%Y-%m-%d`"

. redist-common.sh

decide_binutils_ver_and_dirs
sed -e "s|@date@|$date|" -e "s|@bu_ver@|$bu_ver|" \
  djgpp-fdos-pkging/i16butil.lsm.in >redist-djgpp/appinfo/i16butil.lsm
ln -s "$our_dir"/prefix-djgpp-binutils/* redist-djgpp/devel/djgpp
(cd redist-djgpp && zip -9rkX i16butil.zip appinfo devel)
(cd redist-djgpp && \
  zip -d i16butil.zip '*.1' '*.INF' '*/MAN/' '*/MAN1/' '*/INFO/')
rm redist-djgpp/appinfo/*.lsm
sed -e "s|@date@|$date|" -e "s|@gcc_ver@|$gcc_ver|" \
  djgpp-fdos-pkging/i16budoc.lsm.in >redist-djgpp/appinfo/i16budoc.lsm
(cd redist-djgpp && \
  find -L . \( -name '*.1' -o -name '*.info' \) -print0 | \
    xargs -0 zip -9rkX i16budoc.zip)
rm redist-djgpp/appinfo/*.lsm redist-djgpp/devel/djgpp/*

decide_newlib_ver_and_dirs
# Use a short version number inside the .lsm .
sed -e "s|@date@|$date|" -e "s|@nl_ver@|$nl_uver-$nl_date|" \
  djgpp-fdos-pkging/i16newli.lsm.in >redist-djgpp/appinfo/i16newli.lsm
ln -s "$our_dir"/prefix-djgpp-newlib/* redist-djgpp/devel/djgpp
(cd redist-djgpp && zip -9rkX i16newli.zip appinfo devel)
rm redist-djgpp/appinfo/*.lsm redist-djgpp/devel/djgpp/*

decide_gcc_ver_and_dirs
sed -e "s|@date@|$date|" -e "s|@gcc_ver@|$gcc_ver|" \
  djgpp-fdos-pkging/i16gcc.lsm.in >redist-djgpp/appinfo/i16gcc.lsm
ln -s "$our_dir"/prefix-djgpp-gcc/* redist-djgpp/devel/djgpp
(cd redist-djgpp && zip -9rkX i16gcc.zip appinfo devel)
(cd redist-djgpp && \
  zip -d i16gcc.zip '*.1' '*.INF' '*/MAN/' '*/MAN1/' '*/INFO/' \
		    '*/LTO-WRAP.EXE')
rm redist-djgpp/appinfo/*.lsm
sed -e "s|@date@|$date|" -e "s|@gcc_ver@|$gcc_ver|" \
  djgpp-fdos-pkging/i16gcdoc.lsm.in >redist-djgpp/appinfo/i16gcdoc.lsm
(cd redist-djgpp && \
  find -L . \( -name '*.1' -o -name '*.info' \) -print0 | \
    xargs -0 zip -9rkX i16gcdoc.zip)
rm redist-djgpp/appinfo/*.lsm
if (cd redist-djgpp && zip -d i16gcc.zip '*LTO*' &>/dev/null); then
  sed -e "s|@date@|$date|" -e "s|@gcc_ver@|$gcc_ver|" \
    djgpp-fdos-pkging/i16gclto.lsm.in >redist-djgpp/appinfo/i16gclto.lsm
  (cd redist-djgpp && \
    find -L . \( -name '*.lsm' -o -name '*lto*' \) -print0 | \
      xargs -0 zip -9rkX i16gclto.zip)
fi
rm -r redist-djgpp/appinfo redist-djgpp/devel
