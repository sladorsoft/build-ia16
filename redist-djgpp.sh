#!/bin/bash

# This shell script will create IA-16 toolchain packages for FreeDOS
# (http://wiki.freedos.org/wiki/index.php/Package) which can work with an
# installation of DJGPP (http://www.ibiblio.org/pub/micro/pc-stuff/freedos/
# files/distributions/1.2/repos/pkg-html/djgpp.html).

set -e -o pipefail
cd $(dirname "$0")
our_dir="`pwd`"

rm -rf redist-djgpp
mkdir -p redist-djgpp/appinfo redist-djgpp/devel/i16gnu redist-djgpp/source

export TZ=UTC0
date="`date +%Y-%m-%d`"

. redist-common.sh

repack () {
  # Repack an archive using 7-Zip's LZMA compression, if 7-Zip is installed. 
  # This potentially saves a bit of space (a few hundred KiB) for each
  # archive.  Retain the old deflate-compressed archive if no space is saved.
  local zip
  if 7za &>/dev/null; then
    rm -rf redist-djgpp/repack
    mkdir redist-djgpp/repack
    unzip -dredist-djgpp/repack redist-djgpp/"$1".zip
    (cd redist-djgpp/repack && 7za a -mm=lzma -mx=9 -tzip tmp.zip *)
    if [ "`wc -c <redist-djgpp/repack/tmp.zip`" -lt \
	 "`wc -c <redist-djgpp/"$1".zip`" ]; then
      mv -v redist-djgpp/repack/tmp.zip redist-djgpp/"$1".zip
    fi
    rm -rf redist-djgpp/repack
  fi
}

decide_binutils_ver_and_dirs
sed -e "s|@date@|$date|" -e "s|@bu_ver@|$bu_ver|" \
  djgpp-fdos-pkging/i16butil.lsm.in >redist-djgpp/appinfo/i16butil.lsm
ln -s "$our_dir"/prefix-djgpp-binutils/* redist-djgpp/devel/i16gnu
mkdir -p redist-djgpp/links
for path in redist-djgpp/devel/i16gnu/bin/*.exe; do
  prog="`basename "$path" .exe | cut -c1-8`"
  echo 'devel\i16gnu\bin\'"$prog.exe" >redist-djgpp/links/"$prog.bat"
done
(cd redist-djgpp && zip -9rkX i16butil.zip appinfo devel links)
(cd redist-djgpp && \
  zip -d i16butil.zip '*.1' '*.INF' '*/MAN/' '*/MAN1/' '*/INFO/')
rm redist-djgpp/appinfo/*.lsm
repack i16butil
#
sed -e "s|@date@|$date|" -e "s|@bu_ver@|$bu_ver|" \
  djgpp-fdos-pkging/i16budoc.lsm.in >redist-djgpp/appinfo/i16budoc.lsm
(cd redist-djgpp && \
  find -L . \( -name '*.1' -o -name '*.info' -o -name '*.lsm' \) -print0 | \
    xargs -0 zip -9rkX i16budoc.zip)
rm -r redist-djgpp/appinfo/*.lsm redist-djgpp/devel/i16gnu/* redist-djgpp/links
repack i16budoc

decide_newlib_ver_and_dirs
# Use a short version number inside the .lsm .
sed -e "s|@date@|$date|" -e "s|@nl_ver@|$nl_uver-$nl_date|" \
  djgpp-fdos-pkging/i16newli.lsm.in >redist-djgpp/appinfo/i16newli.lsm
ln -s "$our_dir"/prefix-djgpp-newlib/* redist-djgpp/devel/i16gnu
mkdir -p redist-djgpp/source/i16newli
git -C newlib-ia16 archive --prefix=newlib-ia16/ -v HEAD | xz -9 \
  >redist-djgpp/source/i16newli/i16newli.txz
(cd redist-djgpp && zip -9rkX i16newli.zip appinfo devel source)
rm -r redist-djgpp/appinfo/*.lsm redist-djgpp/devel/i16gnu/* \
  redist-djgpp/source/*
repack i16newli

decide_gcc_ver_and_dirs
sed -e "s|@date@|$date|" -e "s|@gcc_ver@|$gcc_ver|" \
  djgpp-fdos-pkging/i16gcc.lsm.in >redist-djgpp/appinfo/i16gcc.lsm
ln -s "$our_dir"/prefix-djgpp-gcc/* redist-djgpp/devel/i16gnu
mkdir redist-djgpp/links
for path in redist-djgpp/devel/i16gnu/bin/*.exe; do
  prog="`basename "$path" .exe | cut -c1-8`"
  echo 'devel\i16gnu\bin\'"$prog.exe" >redist-djgpp/links/"$prog.bat"
done
(cd redist-djgpp && zip -9rkX i16gcc.zip appinfo devel links)
(cd redist-djgpp && \
  zip -d i16gcc.zip '*.1' '*.INF' '*/MAN/' '*/MAN1/' '*/INFO/' \
		    '*/LTO-WRAP.EXE')
rm -r redist-djgpp/appinfo/*.lsm redist-djgpp/links
repack i16gcc
#
sed -e "s|@date@|$date|" -e "s|@gcc_ver@|$gcc_ver|" \
  djgpp-fdos-pkging/i16gcdoc.lsm.in >redist-djgpp/appinfo/i16gcdoc.lsm
(cd redist-djgpp && \
  find -L . \( -name '*.1' -o -name '*.info' -o -name '*.lsm' \) -print0 | \
    xargs -0 zip -9rkX i16gcdoc.zip)
rm redist-djgpp/appinfo/*.lsm
repack i16gcdoc
#
if (cd redist-djgpp && zip -d i16gcc.zip '*LTO*' &>/dev/null); then
  sed -e "s|@date@|$date|" -e "s|@gcc_ver@|$gcc_ver|" \
    djgpp-fdos-pkging/i16gclto.lsm.in >redist-djgpp/appinfo/i16gclto.lsm
  (cd redist-djgpp && \
    find -L . \( -name '*.lsm' -o -name '*lto*' \) -print0 | \
      xargs -0 zip -9rkX i16gclto.zip)
  repack i16gclto
fi
rm -r redist-djgpp/appinfo redist-djgpp/devel redist-djgpp/source
