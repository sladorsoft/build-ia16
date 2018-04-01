#!/bin/bash

# This shell script will create Ubuntu source packages which we can pass to
# launchpad.net (e.g.) to build.  The build environment, options, etc. are
# --- and _should be_! --- kept in sync with those in build.sh as far as
# possible.  There are a few important exceptions:
#
#   * The respective packaging scripts (ppa-pkging/*/rules, which become
#     debian/rules) arrange to install .info files in their own directory
#     (/usr/ia16-elf/info/) rather than the expected place ($PREFIX/share/
#     info/).  This is to avoid clashing with any .info files for the host
#     system's binutils, GCC, etc.
#
#   * The trimmed-down stage 1 and 2 GCC source trees need some help to
#     correctly set up gcc/include-fixed/limits.h .
#
# There is a Personal Package Archive (PPA) for the source packages I have
# created, at https://launchpad.net/~tkchia/+archive/ubuntu/build-ia16/ .
#
# For Ubuntu Trusty, the mainline version of libisl (0.12-2) is too old, so
# I have copied over the libisl 0.16.1-1 from Jonathon F's PPA
# (https://launchpad.net/%7Ejonathonf/+archive/ubuntu/gcc-5.3/+packages)
# into my PPA.
#
# TODO: create more fine-grained packages, e.g. rather than one big package
# gcc-ia16-elf, have separate packages for the C compiler, C++ compiler,
# libgcc1, etc.

set -e -o pipefail
cd $(dirname "$0")

# (These are mostly lifted from build.sh ...)
in_list () {
  local needle=$1
  local haystackname=$2
  local -a haystack
  eval "haystack=( "\${$haystackname[@]}" )"
  for x in "${haystack[@]}"; do
    if [ "$x" = "$needle" ]; then
      return 0
    fi
  done
  return 1
}

distro=
while [ $# -gt 0 ]; do
  case "$1" in
    clean|binutils|gcc1|newlib|gcc2|stubs)
      BUILDLIST=( "${BUILDLIST[@]}" $1 )
      ;;
    all)
      BUILDLIST=("clean" "binutils" "gcc1" "newlib" "gcc2" "stubs")
      ;;
    --distro=?*)
      distro="${1#--distro=}"
      ;;
    *)
      echo "Unknown option '$1'."
      exit 1
      ;;
  esac
  shift
done

if [ "${#BUILDLIST}" -eq 0 ]; then
  echo "redist-ppa options:"
  echo "--distro={trusty|xenial|...} clean binutils gcc1 newlib gcc2 stubs"
  exit 1
fi

# Capture the current date and time, and fabricate a package revision number
# from an abbreviated version of the current date and time.  Use UTC all the
# way, for great consistency.
export TZ=UTC0
curr_tm="`date -R`"
ppa_no="`date -d "$curr_tm" +%y%m%d%H%M`"
ppa_no="${ppa_no%?}"

# Do some sanity checks.
if ! which pixz >/dev/null; then
  echo "Cannot find 'pixz' program --- please install!"
  exit 1
fi

# If no target Ubuntu distribution is specified, obtain the code name for
# whatever Linux distribution we are running on, or fall back on a wild
# guess.
if [ -z "$distro" ]; then
  distro="`sed -n '/^DISTRIB_CODENAME=[[:alnum:]]\+$/ { s/^.*=//; p; q; }' \
    /etc/lsb-release || :`"
  if [ -z "$distro" ]
    then distro=xenial; fi
fi

if in_list clean BUILDLIST; then
  echo
  echo "************"
  echo "* Cleaning *"
  echo "************"
  echo
  # Create and clean up our working directory.
  rm -rf redist-ppa
  mkdir redist-ppa
fi

decide_binutils_ver_and_dirs () {
  # $bu_uver is the GNU upstream version number, and $bu_date is our
  # (downstream) commit date.  $bu_dir is the downstream directory name
  # constructed from $bu_uver and $bu_date.  $bu_pdir is $bu_dir with the
  # package revision number appended to it.
  #
  # I factored out this logic as a function, as several build tasks use it.
  bu_uver="`cat binutils-ia16/bfd/configure | \
    sed -n "/^PACKAGE_VERSION='/ { s/^.*='*//; s/'*$//; p; q; }" || :`"
  bu_date="`cd binutils-ia16 && git log -n1 --oneline --date=short-local \
    --format='%ad' | sed 's/-//g'`"
  [ -n "$bu_uver" -a -n "$bu_date" ]
  bu_ver="$bu_uver"-"$bu_date"
  bu_pver="$bu_ver"-ppa"$ppa_no~$distro"
  bu_dir=binutils-ia16-elf_"$bu_ver"
  bu_pdir=binutils-ia16-elf_"$bu_pver"
}

if in_list binutils BUILDLIST; then
  echo
  echo "**********************"
  echo "* Packaging binutils *"
  echo "**********************"
  echo
  # Package up binutils-ia16 as a source package.
  rm -rf redist-ppa/binutils-ia16-elf_*
  decide_binutils_ver_and_dirs
  mkdir redist-ppa/"$bu_pdir"
  # Copy the source tree over, but do not include .git* or untracked files.
  (cd binutils-ia16 && git archive --prefix="$bu_dir"/ HEAD) | pixz -6t \
    >redist-ppa/"$bu_dir".orig.tar.xz
  pushd redist-ppa/"$bu_pdir"
  # We do not really need to do this unpacking here:
  #	tar xJf ../"$bu_dir".orig.tar.xz --strip-components=1
  # ...but we do need to tell debuild later to ignore all the "removed" files
  # in the source tree.
  dh_make -s -p "$bu_pdir" -n -f ../"$bu_dir".orig.tar.xz -y
  rm debian/*.ex debian/*.EX debian/README debian/README.*
  cp -a ../../ppa-pkging/build-binutils/* debian/
  find debian -name '*~' -print0 | xargs -0 rm -f
  # TODO:
  #   * Generate the most recent changelog entry in a saner way.  E.g. 
  #     extract and include the user id information from $DEBSIGN_KEYID.
  #   * Include changelog entries for actual source changes.
  (
    echo "binutils-ia16-elf ($bu_pver) $distro; urgency=low"
    echo
    echo '  * Release.'
    echo
    echo " -- user <user@localhost.localdomain>  $curr_tm"
  ) >debian/changelog
  cp -a debian/docs debian/*.docs
  # (1) Since we do not unpack the .orig tarball at all, we need to tell
  #	debuild to ignore all the file "removals" in the "unpacked" source
  #	tree.
  #
  # (2) The dpkg-buildpackage(1) and debsign(1) man pages claim to recognize
  #	the $DEB_SIGN_KEYID and $DEBSIGN_KEYID environment variables
  #	respectively.  In practice though, debuild(1) actually just uses
  #	whatever name and e-mail address is in the changelog to serve as the
  #	key id.  So work around this.
  debuild -i'.*' -S ${DEBSIGN_KEYID+"-k$DEBSIGN_KEYID"}
  popd
fi

decide_gcc_ver_and_dirs () {
  # $gcc_uver is the GNU upstream version number, and $gcc_date is our
  # downstream commit date.
  gcc_uver="`cat gcc-ia16/gcc/BASE-VER`"
  gcc_date="`cd gcc-ia16 && git log -n1 --oneline --date=iso-strict-local \
    --format='%ad' | sed 's/-//g; s/:.*$//g; s/T/./g'`"
  [ -n "$gcc_uver" -a -n "$gcc_date" ]
  gcc_ver="$gcc_uver"-"$gcc_date"
  gcc_pver="$gcc_ver"-ppa"$ppa_no~$distro"
  g2_pver="$gcc_pver"
  g1_dir=gcc-bootstraps-ia16-elf_"$gcc_ver"
  g1_pdir=gcc-bootstraps-ia16-elf_"$gcc_pver"
  g2_dir=gcc-ia16-elf_"$gcc_ver"
  g2_pdir=gcc-ia16-elf_"$gcc_pver"
  gs_dir=gcc-stubs-ia16-elf_"$gcc_ver"
  gs_pdir=gcc-stubs-ia16-elf_"$gcc_pver"
  # Messy temporary hack to work around a Launchpad restriction...
  if [ 20180210 = "$gcc_date" -o 20180215 = "$gcc_date" ]; then
    g2_ver="$gcc_uver"-"$gcc_date".0
    g2_pver="$g2_ver"-ppa"$ppa_no~$distro"
    g2_dir=gcc-ia16-elf_"$g2_ver"
    g2_pdir=gcc-ia16-elf_"$g2_pver"
  fi
}

if in_list gcc1 BUILDLIST; then
  echo
  echo "*************************"
  echo "* Packaging stage 1 GCC *"
  echo "*************************"
  echo
  # Package up gcc-ia16 as a source package.  My current idea is that this
  # `gcc-bootstraps-ia16-elf' package will only be used to build newlib, and
  # then it can be safely jettisoned.  So I try to pack as little stuff as
  # possible into the `.orig' tarball.
  #
  # (The resulting tarball is still pretty big though (20+ MiB).  There is
  # likely a better way...)
  rm -rf redist-ppa/gcc-bootstraps-ia16-elf_*
  decide_binutils_ver_and_dirs
  decide_gcc_ver_and_dirs
  mkdir redist-ppa/"$g1_pdir"
  # Copy the source tree over, but do not include .git* or untracked files.
  #
  # Also exclude the _huge_ testsuite, and language support other than for C
  # and C++.  (C++ is needed for gcc/c-family/cilk.c to build...)  This is a
  # bit hard to do with `git archive' alone --- without dirtying the
  # original source tree --- so rope in GNU tar for the task.
  #
  # Also take out the boehm-gc/ and libffi/ directories, which we do not
  # really need at this stage.  Keep gcc/fortran/, gcc/go/, and gcc/java/
  # around so that libbacktrace/ will not be built for ia16-elf (!).
  (cd gcc-ia16 && \
   git archive --prefix="$g1_dir"/ HEAD | \
   tar --delete --wildcards \
    "$g1_dir"/gotools "$g1_dir"/libada "$g1_dir"/libgfortran "$g1_dir"/libgo \
    "$g1_dir"/libjava "$g1_dir"/libobjc "$g1_dir"/libsanitizer \
    "$g1_dir"/libstdc++-v3 "$g1_dir"/gcc/testsuite "$g1_dir"/gcc/ada \
    "$g1_dir"/gnattools "$g1_dir"/gcc/objc "$g1_dir"/boehm-gc \
    "$g1_dir"/libffi "$g1_dir/gcc/ChangeLog*") | \
    pixz -6t \
    >redist-ppa/"$g1_dir".orig.tar.xz
  pushd redist-ppa/"$g1_pdir"
  dh_make -s -p "$g1_pdir" -n -f ../"$g1_dir".orig.tar.xz -y
  rm debian/*.ex debian/*.EX debian/README debian/README.*
  cp -a ../../ppa-pkging/build/* debian/
  sed "s|@bu_ver@|$bu_ver|g" debian/control.in >debian/control
  rm debian/control.in
  find debian -name '*~' -print0 | xargs -0 rm -f
  (
    echo "gcc-bootstraps-ia16-elf ($gcc_pver) $distro; urgency=low"
    echo
    echo '  * Release.'
    echo
    echo " -- user <user@localhost.localdomain>  $curr_tm"
  ) >debian/changelog
  cp -a debian/docs debian/*.docs
  debuild -i'.*' -S ${DEBSIGN_KEYID+"-k$DEBSIGN_KEYID"}
  cd ..
  popd
fi

decide_newlib_ver_and_dirs () {
  decide_binutils_ver_and_dirs
  decide_gcc_ver_and_dirs
  nl_uver="`cat newlib-ia16/newlib/configure | \
    sed -n "/^PACKAGE_VERSION='/ { s/^.*='*//; s/'*$//; p; q; }" || :`"
  nl_date="`cd newlib-ia16 && git log -n1 --oneline --date=short-local \
    --format='%ad' | sed 's/-//g'`"
  [ -n "$nl_uver" -a -n "$nl_date" ]
  # Include the GCC and binutils versions inside the newlib version, to
  # distinguish between different newlib binaries compiled from the same
  # source (but different GCC and binutils versions).
  nl_ver="$nl_uver"-"$nl_date"-stage1gcc"$gcc_ver"-binutils"$bu_ver"
  nl_pver="$nl_ver"-ppa"$ppa_no~$distro"
  nl_dir=libnewlib-ia16-elf_"$nl_ver"
  nl_pdir=libnewlib-ia16-elf_"$nl_pver"
}

if in_list newlib BUILDLIST; then
  echo
  echo "******************************"
  echo "* Packaging Newlib C library *"
  echo "******************************"
  echo
  rm -rf redist-ppa/libnewlib-ia16-elf_*
  decide_binutils_ver_and_dirs
  decide_gcc_ver_and_dirs
  decide_newlib_ver_and_dirs
  mkdir redist-ppa/"$nl_pdir"
  (cd newlib-ia16 && git archive --prefix="$nl_dir"/ HEAD) | pixz -6t \
    >redist-ppa/"$nl_dir".orig.tar.xz
  pushd redist-ppa/"$nl_pdir"
  dh_make -s -p "$nl_pdir" -n -f ../"$nl_dir".orig.tar.xz -y
  rm debian/*.ex debian/*.EX debian/README debian/README.*
  cp -a ../../ppa-pkging/build-newlib/* debian/
  sed -e "s|@bu_ver@|$bu_ver|g" -e "s|@gcc_ver@|$gcc_ver|g" \
    debian/control.in >debian/control
  rm debian/control.in
  find debian -name '*~' -print0 | xargs -0 rm -f
  (
    echo "libnewlib-ia16-elf ($nl_pver) $distro; urgency=low"
    echo
    echo '  * Release.'
    echo
    echo " -- user <user@localhost.localdomain>  $curr_tm"
  ) >debian/changelog
  cp -a debian/docs debian/*.docs
  debuild -i'.*' -S ${DEBSIGN_KEYID+"-k$DEBSIGN_KEYID"}
  popd
fi

if in_list gcc2 BUILDLIST; then
  echo
  echo "*************************"
  echo "* Packaging stage 2 GCC *"
  echo "*************************"
  echo
  rm -rf redist-ppa/gcc-ia16-elf_*
  decide_binutils_ver_and_dirs
  decide_gcc_ver_and_dirs
  decide_newlib_ver_and_dirs
  mkdir redist-ppa/"$g2_pdir"
  # Copy the source tree over, except for .git* files, untracked files, and
  # the bigger testsuites.
  (cd gcc-ia16 && \
   git archive --prefix="$g2_dir"/ HEAD | \
   tar --delete --wildcards "$g2_dir"/libjava/testsuite \
    "$g2_dir"/gcc/testsuite "$g2_dir"/libgomp/testsuite) | \
    pixz -6t \
    >redist-ppa/"$g2_dir".orig.tar.xz
  pushd redist-ppa/"$g2_pdir"
  dh_make -s -p "$g2_pdir" -n -f ../"$g2_dir".orig.tar.xz -y
  rm debian/*.ex debian/*.EX debian/README debian/README.*
  cp -a ../../ppa-pkging/build2/* debian/
  sed -e "s|@bu_ver@|$bu_ver|g" -e "s|@nl_ver@|$nl_ver|g" debian/control.in \
    >debian/control
  rm debian/control.in
  find debian -name '*~' -print0 | xargs -0 rm -f
  (
    echo "gcc-ia16-elf ($g2_pver) $distro; urgency=low"
    echo
    echo '  * Release.'
    echo
    echo " -- user <user@localhost.localdomain>  $curr_tm"
  ) >debian/changelog
  cp -a debian/docs debian/*.docs
  debuild -i'.*' -S ${DEBSIGN_KEYID+"-k$DEBSIGN_KEYID"}
  cd ..
  popd
fi

if in_list stubs BUILDLIST; then
  echo
  echo "**************************"
  echo "* Creating stub packages *"
  echo "**************************"
  echo
  rm -rf redist-ppa/gcc-stubs-ia16-elf_*
  decide_gcc_ver_and_dirs
  mkdir redist-ppa/"$gs_pdir"
  pushd redist-ppa/"$gs_pdir"
  dh_make -s -p "$gs_pdir" -n -y
  rm debian/*.ex debian/*.EX debian/README debian/README.*
  cp -a ../../ppa-pkging/build-stubs-gcc/* debian/
  sed "s|@gcc_ver@|$gcc_ver|g" debian/control.in >debian/control
  rm debian/control.in
  find debian -name '*~' -print0 | xargs -0 rm -f
  (
    echo "gcc-stubs-ia16-elf ($gcc_pver) $distro; urgency=low"
    echo
    echo '  * Release.'
    echo
    echo " -- user <user@localhost.localdomain>  $curr_tm"
  ) >debian/changelog
  cp -a debian/docs debian/*.docs
  debuild --no-tgz-check -i -S ${DEBSIGN_KEYID+"-k$DEBSIGN_KEYID"}
  cd ..
  popd
fi
