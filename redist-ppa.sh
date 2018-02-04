#!/bin/bash

# TODO: This is still incomplete!  It should also create packages for
# newlib, GCC proper, and libgcc.

set -e -x -o pipefail

cd $(dirname "$0")
export CC_FOR_TARGET="`pwd`/prefix/bin/ia16-elf-gcc"

# Do some sanity checks.
[ -x "$CC_FOR_TARGET" ]

# Create and clean up our working directory.
rm -rf redist-ppa
mkdir redist-ppa

# Package up binutils-ia16.  $bu_upver is the GNU upstream version number,
# and $bu_date is our (downstream) commit date.
bu_upver="`cat binutils-ia16/bfd/configure | \
    sed -n "/^PACKAGE_VERSION=/ { s/^.*='*//; s/'*$//; p; q; }" || :`"
bu_date="`cd binutils-ia16 && git show --format='%aI' -s HEAD | \
    sed 's/[A-Z].*//; s/-//g'`"
[ -n "$bu_upver" -a -n "$bu_date" ]
bu_dir=binutils-ia16-elf_"$bu_upver"-"$bu_date"ppa1
mkdir redist-ppa/"$bu_dir"
# Copy the source tree over, but do not include .git* or untracked files.
(cd binutils-ia16 && git archive --format=tar.gz HEAD) | \
    tar xzf - -C redist-ppa/"$bu_dir"
cd redist-ppa/"$bu_dir"
dh_make -s -p binutils-ia16-elf_"$bu_upver"-"$bu_date"ppa1 -n -y
rm debian/*.ex debian/*.EX debian/README debian/README.*
cp -a ../../ppa-src/binutils-ia16/* debian/
cp -a debian/docs debian/*.docs
debuild -i -us -uc -b
cd ../..
