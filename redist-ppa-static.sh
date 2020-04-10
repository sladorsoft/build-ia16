#!/bin/bash

# This is a very experimental shell script which, like, redist-ppa.sh,
# creates Ubuntu source packages.  The difference is that the source
# packages from this script will build host binaries which are statically
# linked.

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
    binutils|gcc2)
      BUILDLIST=( "${BUILDLIST[@]}" $1 )
      ;;
    all)
      BUILDLIST=("binutils" "gcc2")
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
  echo "--distro={trusty|xenial|...} binutils gcc2"
  exit 1
fi

# Capture the current date and time, and fabricate a package revision number
# from an abbreviated version of the current date and time.  Use UTC all the
# way, for great consistency.
export TZ=UTC0
curr_tm="`date -R`"
ppa_no="`date -d "$curr_tm" +%y%m%d%H%M`"
ppa_no="${ppa_no%?}"

# If no target Ubuntu distribution is specified, obtain the code name for
# whatever Linux distribution we are running on, or fall back on a wild
# guess.
if [ -z "$distro" ]
  then distro="`lsb_release -c -s || :`"; fi
if [ -z "$distro" ]; then
  distro="`sed -n '/^DISTRIB_CODENAME=[[:alnum:]]\+$/ { s/^.*=//; p; q; }' \
    /etc/lsb-release || :`"
fi
if [ -z "$distro" ]
  then distro=xenial; fi

case "$distro" in
  '' | *[^-0-9a-z]*)
    echo "Bad distribution name (\`$distro')!"
    exit 1
    ;;
esac

case "$distro" in
  trusty | xenial | bionic)
    maybe_libisl_dev='libisl-dev (>= 0.14),';;
  *)
    maybe_libisl_dev=;;
esac

# Create unsigned packages if $DEBSIGN_KEYID is undefined or blank;
# otherwise create packages signed with the given key id.
case "$DEBSIGN_KEYID" in
  '')
    signing=("-us" "-uc");;
  *)
    signing=("-k$DEBSIGN_KEYID");;
esac

. redist-common.sh

if in_list binutils BUILDLIST; then
  echo
  echo "**********************"
  echo "* Packaging binutils *"
  echo "**********************"
  echo
  # Package up binutils-ia16 as a source package.
  rm -rf redist-ppa/"$distro"/binutils-ia16-elf-static_*
  decide_binutils_ver_and_dirs -static
  mkdir -p redist-ppa/"$distro"/"$bu_pdir"
  # Copy the source tree over, but do not include .git* or untracked files.
  git -C binutils-ia16 ls-files -z | \
    sed -z -n '/^\.git/! { /\/\.git/! p }' | \
    (cd binutils-ia16 && \
     tar cf - --no-recursion --null -T - --transform "s?^?$bu_dir/?") | \
    xz -9v \
    >redist-ppa/"$distro"/"$bu_dir".orig.tar.xz
  pushd redist-ppa/"$distro"/"$bu_pdir"
  dh_make -s -p "$bu_pdir" -n -f ../"$bu_dir".orig.tar.xz -y
  rm debian/*.ex debian/*.EX debian/README debian/README.*
  cp -a ../../../ppa-pkging/build-binutils/* debian/
  sed "s|@ifstatic@|-static|g" debian/control.in >debian/control
  # The -static flag only causes libtool to refrain from dynamically linking
  # _some_ libraries.  Thus I need to force libtool to pass -static to the
  # host linker by saying -Wl,-static.  This however causes an unresolved
  # reference to dl_iterate_phdr (, ) in gas --- likely due to a circular
  # library dependency --- so we need to work around this in $(LIBS).  What a
  # mess.  -- tkchia 20200410
  sed \
    -e "s|@ifstatic_cflags@|-static|g" \
    -e "s|@ifstatic_ldflags@|-static -Wl,-static|g" \
    -e "s|@ifstatic_libs@|-Wl,--start-group,-lc,-lgcc,-lgcc_eh,--end-group|g" \
    -e "s|@disable_enable_static@|--enable-static|g" \
    -e "s|@disable_enable_shared@|--disable-shared|g" \
    debian/rules.in >debian/rules
  rm debian/control.in debian/rules.in
  find debian -name '*~' -print0 | xargs -0 rm -f
  (
    echo "binutils-ia16-elf-static ($bu_pver) $distro; urgency=medium"
    echo
    echo '  * Release.'
    echo
    echo " -- user <user@localhost.localdomain>  $curr_tm"
  ) >debian/changelog
  cp -a debian/docs debian/*.docs
  debuild -i'.*' -S -rfakeroot -d ${signing[@]}
  popd
fi

if in_list gcc2 BUILDLIST; then
  echo
  echo "*************************"
  echo "* Packaging stage 2 GCC *"
  echo "*************************"
  echo
  rm -rf redist-ppa/"$distro"/gcc-ia16-elf-static_*
  decide_binutils_ver_and_dirs -static
  decide_gcc_ver_and_dirs -static
  decide_newlib_ver_and_dirs -static
  decide_libi86_ver_and_dirs -static
  mkdir -p redist-ppa/"$distro"/"$g2_pdir"
  # Copy the source tree over, except for .git* files, untracked files, and
  # the bigger testsuites.
  git -C gcc-ia16 ls-files -z | \
    sed -z -n '/^\(\(libjava\|gcc\|libgomp\)\/testsuite\/\|\.git\)/! '` \
      `'{ /\/\.git/! p }' | \
    (cd gcc-ia16 && \
     tar cf - --no-recursion --null -T - --transform "s?^?$g2_dir/?") | \
    xz -9v \
    >redist-ppa/"$distro"/"$g2_dir".orig.tar.xz
  pushd redist-ppa/"$distro"/"$g2_pdir"
  dh_make -s -p "$g2_pdir" -n -f ../"$g2_dir".orig.tar.xz -y
  rm debian/*.ex debian/*.EX debian/README debian/README.*
  cp -a ../../../ppa-pkging/build2/* debian/
  sed -e "s|@bu_ver@|$bu_ver|g" -e "s|@nl_ver@|$nl_ver|g" \
      -e "s|@li_ver@|$li_ver|g" -e "s|@maybe_libisl_dev@|$maybe_libisl_dev|g" \
      -e "s|@ifstatic@|-static|g" debian/control.in >debian/control
  sed \
    -e "s|@ifstatic@|-static|g" \
    -e "s|@ifstatic_cflags@|-static|g" \
    -e "s|@ifstatic_ldflags@|-static -Wl,-static|g" \
    -e "s|@disable_enable_shared@|--disable-shared|g" \
    debian/rules.in >debian/rules
  rm debian/control.in debian/rules.in
  find debian -name '*~' -print0 | xargs -0 rm -f
  (
    echo "gcc-ia16-elf-static ($g2_pver) $distro; urgency=medium"
    echo
    echo '  * Release.'
    echo
    echo " -- user <user@localhost.localdomain>  $curr_tm"
  ) >debian/changelog
  cp -a debian/docs debian/*.docs
  debuild -i'.*' -S -rfakeroot -d ${signing[@]}
  cd ..
  popd
fi
