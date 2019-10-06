#!/bin/bash

# This shell script will create IA-16 toolchain packages for FreeDOS
# (http://wiki.freedos.org/wiki/index.php/Package) which can work with an
# installation of DJGPP (http://www.ibiblio.org/pub/micro/pc-stuff/freedos/
# files/distributions/1.2/repos/pkg-html/djgpp.html).
#
# Before running this script, the toolchain binaries need to be compiled using
# a command like the following:
#	./build.sh clean-djgpp prereqs-djgpp binutils-djgpp gcc-djgpp

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
    (
      echo ">> Packed by `basename "$0"` on $date."
      echo ">> This package uses LZMA compression, which some unzip-programs"
      echo ">> may not handle.  To view its contents, one way is to use 7-Zip."
    ) | zip -z redist-djgpp/repack/tmp.zip
    if [ "`wc -c <redist-djgpp/repack/tmp.zip`" -lt \
	 "`wc -c <redist-djgpp/"$1".zip`" ]; then
      mv -v redist-djgpp/"$1".zip redist-djgpp/"$1".deflated.zip
      mv -v redist-djgpp/repack/tmp.zip redist-djgpp/"$1".zip
    fi
    rm -rf redist-djgpp/repack
  fi
}

decide_binutils_ver_and_dirs
sed -e "s|@date@|$date|" -e "s|@bu_ver@|$bu_ver|" \
  djgpp-fdos-pkging/i16butil.lsm.in >redist-djgpp/appinfo/i16butil.lsm
cp -a "$our_dir"/prefix-djgpp-binutils/* redist-djgpp/devel/i16gnu
mkdir -p redist-djgpp/links redist-djgpp/source/i16butil
for path in redist-djgpp/devel/i16gnu/bin/*.exe; do
  prog="`basename "$path" .exe | cut -c1-8`"
  echo 'devel\i16gnu\bin\'"$prog.exe" >redist-djgpp/links/"$prog.bat"
done
(
  cat <<'FIN'
This is a patch against the official GNU Binutils 2.31.1.  You can find
Binutils 2.31.1 via http://ftp.gnu.org/gnu/binutils, http://ftpmirror.gnu.org,
and elsewhere.  The SHA-512 checksum for binutils-2.31.1.tar.xz is
  0fca326f eb1d5f5f e505a827 b20237fe 3ec9c13e af7ec7e3 5847fd71 184f605b
  a1cefe13 14b1b8f8 a29c0aa9 d8816284 9ee1c1a3 e70c2f74 07d88339 b17edb30.
===========================================================================
FIN
  xzcat djgpp-fdos-pkging/binutils-2.31.1-51b4f73a37.diff.xz
  # And...
  git -C binutils-ia16 diff 51b4f73a37c2e7eec31e932fc3c8dae879735f63
) >redist-djgpp/source/i16butil/i16butil.dif
# I am not quite sure how to handle the elf_i386.xdce, elf_i386.xswe, etc.
# linker scripts yet --- we cannot have two separate files elf_i386.xdc and
# elf_i386.xdce in the same ldscripts/ directory under MS-DOS's 8.3 filename
# restrictions.
#
# Currently I exclude (most of) the `d' and `s' scripts, since `d' corresponds
# to the `-pie' linker option, and `-s' to the `-shared' option, neither of
# which make much sense (yet) in the IA-16 context.
#
# Also, the elf_i386_msdos_mz.x* scripts are the same as the elf_i386.x* ones.
rm -f -v redist-djgpp/devel/i16gnu/ia16-elf/lib/ldscripts/elf_i386.x[ds][^e]* \
	 redist-djgpp/devel/i16gnu/ia16-elf/lib/ldscripts/elf_i386_msdos_mz.x*
(cd redist-djgpp && zip -9rkX i16butil.zip appinfo devel links source)
(cd redist-djgpp && \
  zip -d i16butil.zip '*.1' '*.INF' '*/MAN/' '*/MAN1/' '*/INFO/')
rm -r redist-djgpp/appinfo/*.lsm redist-djgpp/source/*
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
# FIXME: find a way to support all the .cct files for Newlib iconv.
rm -rf redist-djgpp/devel/i16gnu/share/iconv_data/cns*.cct \
       redist-djgpp/devel/i16gnu/share/iconv_data/iso_8859*.cct \
       redist-djgpp/devel/i16gnu/share/iconv_data/jis*.cct
mkdir -p redist-djgpp/source/i16newli
git -C newlib-ia16 archive --format=zip --prefix=newlib-ia16/ -0 -v HEAD \
  >redist-djgpp/source/i16newli/newlib.zip
(cd redist-djgpp && zip -9rkX i16newli.zip appinfo devel source)
(cd redist-djgpp && zip -d i16newli.zip '*/ELK*' '*/LIBELK*')
rm -r redist-djgpp/appinfo/*.lsm redist-djgpp/source/*
repack i16newli
#
sed -e "s|@date@|$date|" -e "s|@nl_ver@|$nl_uver-$nl_date|" \
  djgpp-fdos-pkging/i16nlelk.lsm.in >redist-djgpp/appinfo/i16nlelk.lsm
(cd redist-djgpp && \
  find -L . \( -name 'elk*' -o -name 'libelk*' -o -name '*.lsm' \) -print0 | \
    xargs -0 zip -9rkX i16nlelk.zip)
rm -r redist-djgpp/appinfo/*.lsm redist-djgpp/devel/i16gnu/*

decide_elks_libc_ver_and_dirs
# Again, use a short version number inside the .lsm .
sed -e "s|@date@|$date|" -e "s|@el_ver@|$el_uver-$el_date|" \
  djgpp-fdos-pkging/i16elklc.lsm.in >redist-djgpp/appinfo/i16elklc.lsm
ln -s "$our_dir"/prefix-djgpp-elkslibc/* redist-djgpp/devel/i16gnu
# Workaround.  See prereqs-djgpp in build.sh.
(cd redist-djgpp/devel/i16gnu/ia16-elf/lib/elkslibc/include/linuxmt && \
 rm -f -v minix_fs.h minix_fs_sb.h msdos_fs.h msdos_fs_sb.h msdos_fs_i.h)
mkdir -p redist-djgpp/source/i16elklc
git -C elks archive --format=zip --prefix=elks/ -0 -v HEAD \
  >redist-djgpp/source/i16elklc/elks.zip
(cd redist-djgpp && zip -9rkX i16elklc.zip appinfo devel source)
rm -r redist-djgpp/appinfo/*.lsm redist-djgpp/devel/i16gnu/* \
  redist-djgpp/source/*
repack i16elklc

decide_libi86_ver_and_dirs
# Yet again, use a short version number inside the .lsm .
sed -e "s|@date@|$date|" -e "s|@li_ver@|$li_uver|" \
  djgpp-fdos-pkging/i16lbi86.lsm.in >redist-djgpp/appinfo/i16lbi86.lsm
ln -s "$our_dir"/prefix-djgpp-libi86/* redist-djgpp/devel/i16gnu
mkdir -p redist-djgpp/source/i16lbi86
git -C libi86 archive --format=zip --prefix=libi86/ -0 -v HEAD \
  >redist-djgpp/source/i16lbi86/libi86.zip
(cd redist-djgpp && zip -9rkX i16lbi86.zip appinfo devel source)
rm -r redist-djgpp/appinfo/*.lsm redist-djgpp/devel/i16gnu/* \
  redist-djgpp/source/*
# Do not repack libi86 with LZMA for now --- fdnpkg has some problem unpacking
# the LZMA'd version.

decide_gcc_ver_and_dirs
sed -e "s|@date@|$date|" -e "s|@gcc_ver@|$gcc_ver|" \
  djgpp-fdos-pkging/i16gcc.lsm.in >redist-djgpp/appinfo/i16gcc.lsm
ln -s "$our_dir"/prefix-djgpp-gcc/* redist-djgpp/devel/i16gnu
mkdir -p redist-djgpp/links redist-djgpp/source/i16gcc
for path in redist-djgpp/devel/i16gnu/bin/*.exe; do
  prog="`basename "$path" .exe | cut -c1-8`"
  echo 'devel\i16gnu\bin\'"$prog.exe" >redist-djgpp/links/"$prog.bat"
done
(
  cat <<'FIN'
This is a patch against the official GCC 6.3.0.  You can find GCC 6.3.0 via
https://gcc.gnu.org/mirrors.html, http://ftpmirror.gnu.org, and elsewhere.
The SHA-512 checksum for gcc-6.3.0.tar.bz2 is
  234dd9b1 bdc9a9c6 e352216a 7ef4ccad c6c07f15 6006a597 59c5e0e6 a69f0abc
  dc14630e ff11e382 6dd6ba59 33a8faa4 3043f3d1 d62df6bd 5ab1e828 62f9bf78.
===========================================================================
FIN
  git -C gcc-ia16 diff 4b5e15daff8b54440e3fda451c318ad31e532fab
) >redist-djgpp/source/i16gcc/i16gcc.dif
(cd redist-djgpp && zip -9rkX i16gcc.zip appinfo devel links source)
(cd redist-djgpp && \
  zip -d i16gcc.zip '*.1' '*.INF' '*/MAN/' '*/MAN1/' '*/INFO/' \
		    '*/LTO-WRAP.EXE')
rm -r redist-djgpp/appinfo/*.lsm redist-djgpp/links redist-djgpp/source/*
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
