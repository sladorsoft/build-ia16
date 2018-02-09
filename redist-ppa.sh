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

# Package up binutils-ia16 as a source package, which we can then pass to
# launchpad.net to build.  $bu_upver is the GNU upstream version number, and
# $bu_date is our (downstream) commit date.  $bu_updir is the upstream
# directory name constructed from $bu_upver.
bu_upver="`cat binutils-ia16/bfd/configure | \
    sed -n "/^PACKAGE_VERSION=/ { s/^.*='*//; s/'*$//; p; q; }" || :`"
bu_date="`cd binutils-ia16 && git show --format='%aI' -s HEAD | \
    sed 's/[A-Z].*//; s/-//g'`"
[ -n "$bu_upver" -a -n "$bu_date" ]
bu_updir=binutils-ia16-elf_"$bu_upver"
bu_dir=binutils-ia16-elf_"$bu_upver"-"$bu_date"ppa1
mkdir redist-ppa/"$bu_dir"
# Copy the source tree over, but do not include .git* or untracked files.
(cd binutils-ia16 && git archive --format=tar.gz --prefix="$bu_updir"/ HEAD) \
    >redist-ppa/"$bu_updir".orig.tar.gz
cd redist-ppa/"$bu_dir"
# (Argh!  Do we really need to do this unpacking?)
tar xzf ../"$bu_updir".orig.tar.gz --strip-components=1
dh_make -s -p binutils-ia16-elf_"$bu_upver"-"$bu_date"ppa1 -n -y
rm debian/*.ex debian/*.EX debian/README debian/README.*
cp -a ../../ppa-pkging/binutils-ia16/* debian/
find debian -name '*~' -print0 | xargs -0 rm -f
cp -a debian/docs debian/*.docs
# The dpkg-buildpackage(1) and debsign(1) man pages claim to recognize the
# $DEB_SIGN_KEYID and $DEBSIGN_KEYID environment variables respectively.  In
# practice though, debuild(1) actually just uses whatever name and e-mail
# address is in the changelog to serve as the key id.  So work around this.
debuild -i -S ${DEBSIGN_KEYID+"-k$DEBSIGN_KEYID"}
cd ../..
