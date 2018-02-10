#!/bin/bash

# TODO: This is still incomplete!  It should also create packages for
# newlib, GCC proper, and libgcc.

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

while [ $# -gt 0 ]; do
  case "$1" in
    clean|binutils|gcc1|newlib|gcc2)
      BUILDLIST=( "${BUILDLIST[@]}" $1 )
      ;;
    all)
      BUILDLIST=("clean" "binutils" "gcc1" "newlib" "gcc2")
      ;;
    *)
      echo "Unknown option '$1'."
      exit 1
      ;;
  esac
  shift
done

if [ "${#BUILDLIST}" -eq 0 ]; then
  echo "redist-ppa options: clean binutils gcc1 newlib gcc2"
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

# Obtain the code name for whatever Linux distribution we are running on, or
# fall back on a wild guess.
distro="`sed -n '/^DISTRIB_CODENAME=[[:alnum:]]\+$/ { s/^.*=//; p; q; }' \
  /etc/lsb-release || :`"
if [ -z "$distro" ]
  then distro=xenial; fi

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
  bu_date="`cd binutils-ia16 && git show --format='%aI' -s HEAD | \
    sed 's/[A-Z].*//; s/-//g'`"
  [ -n "$bu_uver" -a -n "$bu_date" ]
  bu_ver="$bu_uver"-"$bu_date"
  bu_pver="$bu_ver"-ppa"$ppa_no"
  bu_dir=binutils-ia16-elf_"$bu_ver"
  bu_pdir=binutils-ia16-elf_"$bu_pver"
}

if in_list binutils BUILDLIST; then
  echo
  echo "**********************"
  echo "* Packaging binutils *"
  echo "**********************"
  echo
  # Package up binutils-ia16 as a source package, which we can then pass to
  # launchpad.net to build.
  rm -rf redist-ppa/binutils-ia16-elf_*
  decide_binutils_ver_and_dirs
  mkdir redist-ppa/"$bu_pdir"
  # Copy the source tree over, but do not include .git* or untracked files.
  (cd binutils-ia16 && git archive --prefix="$bu_dir"/ HEAD) | pixz -6t \
    >redist-ppa/"$bu_dir".orig.tar.xz
  pushd redist-ppa/"$bu_pdir"
  # (Argh!  Do we really need to do this unpacking?)
  tar xJf ../"$bu_dir".orig.tar.xz --strip-components=1
  dh_make -s -p "$bu_pdir" -n -y
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
  # The dpkg-buildpackage(1) and debsign(1) man pages claim to recognize the
  # $DEB_SIGN_KEYID and $DEBSIGN_KEYID environment variables respectively. 
  # In practice though, debuild(1) actually just uses whatever name and
  # e-mail address is in the changelog to serve as the key id.  So work
  # around this.
  debuild -i -S ${DEBSIGN_KEYID+"-k$DEBSIGN_KEYID"}
  popd
fi

decide_gcc_ver_and_dirs () {
  # $gcc_uver is the GNU upstream version number, and $gcc_date is our
  # downstream commit date.
  gcc_uver="`cat gcc-ia16/gcc/BASE-VER`"
  gcc_date="`cd gcc-ia16 && git show --format='%aI' -s HEAD | \
    sed 's/[A-Z].*//; s/-//g'`"
  [ -n "$gcc_uver" -a -n "$gcc_date" ]
  gcc_ver="$gcc_uver"-"$gcc_date"
  gcc_pver="$gcc_ver"-ppa"$ppa_no"
  g1_dir=gcc-bootstrap-ia16-elf_"$gcc_ver"
  g1_pdir=gcc-bootstrap-ia16-elf_"$gcc_pver"
  g2_dir=gcc-ia16-elf_"$gcc_uver"
  g2_pdir=gcc-ia16-elf_"$gcc_pver"
}

if in_list gcc1 BUILDLIST; then
  echo
  echo "*************************"
  echo "* Packaging stage 1 GCC *"
  echo "*************************"
  echo
  # Package up gcc-ia16 as a source package.  My current idea is that this
  # `gcc-bootstrap-ia16-elf' package will only be used to build newlib, and
  # then it can be safely jettisoned.  So I try to pack as little stuff as
  # possible into the `.orig' tarball.
  #
  # (The resulting tarball is still pretty big though (20+ MiB).  There is
  # likely a better way...)
  rm -rf redist-ppa/gcc-bootstrap-ia16-elf_*
  decide_binutils_ver_and_dirs
  decide_gcc_ver_and_dirs
  mkdir redist-ppa/"$g1_pdir"
  # Copy the source tree over, but do not include .git* or untracked files.
  #
  # Also exclude the _huge_ testsuite, and language support other than for C
  # and C++.  (C++ is needed for gcc/c-family/cilk.c to build...)  This is a
  # bit hard to do with `git archive' alone --- without dirtying the
  # original source tree --- so rope in GNU tar for the task.
  (cd gcc-ia16 && \
   git archive --prefix="$g1_dir"/ HEAD | \
   tar --delete --wildcards \
    "$g1_dir"/gotools "$g1_dir"/libada "$g1_dir"/libgfortran \
    "$g1_dir"/libgo "$g1_dir"/libjava "$g1_dir"/libobjc \
    "$g1_dir"/libstdc++-v3 "$g1_dir"/gcc/testsuite "$g1_dir"/gcc/ada \
    "$g1_dir"/gnattools "$g1_dir"/gcc/fortran "$g1_dir"/gcc/go \
    "$g1_dir"/gcc/java "$g1_dir"/gcc/objc "$g1_dir/gcc/ChangeLog*") | \
    pixz -6t \
    >redist-ppa/"$g1_dir".orig.tar.xz
  pushd redist-ppa/"$g1_pdir"
  tar xJf ../"$g1_dir".orig.tar.xz --strip-components=1
  dh_make -s -p "$g1_pdir" -n -y
  rm debian/*.ex debian/*.EX debian/README debian/README.*
  cp -a ../../ppa-pkging/build/* debian/
  sed "s|@bu_ver@|$bu_ver|g" debian/control.in >debian/control
  rm debian/control.in
  find debian -name '*~' -print0 | xargs -0 rm -f
  (
    echo "gcc-bootstrap-ia16-elf ($gcc_pver) $distro; urgency=low"
    echo
    echo '  * Release.'
    echo
    echo " -- user <user@localhost.localdomain>  $curr_tm"
  ) >debian/changelog
  cp -a debian/docs debian/*.docs
  debuild -i -S ${DEBSIGN_KEYID+"-k$DEBSIGN_KEYID"}
  cd ..
  popd
fi

if in_list newlib BUILDLIST; then
  echo 'newlib packaging not yet supported.'
  exit 1
fi

if in_list gcc2 BUILDLIST; then
  echo 'gcc2 packaging not yet supported.'
  exit 1
fi
