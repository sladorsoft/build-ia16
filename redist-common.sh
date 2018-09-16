#!/bin/bash

# Functions used by multiple shell scripts.

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

decide_gcc_ver_and_dirs () {
  # $gcc_uver is the GNU upstream version number, and $gcc_date is our
  # downstream commit date.
  gcc_uver="`cat gcc-ia16/gcc/BASE-VER`"
  gcc_date="`cd gcc-ia16 && git log -n1 --oneline --date=iso-strict-local \
    --format='%ad' | sed 's/-//g; s/:.*$//g; s/T/./g'`"
  [ -n "$gcc_uver" -a -n "$gcc_date" ]
  gcc_ver="$gcc_uver"-"$gcc_date"
  # Messy temporary hack to work around a Launchpad restriction...
  if [ 20180915.16 = "$gcc_date" ]; then
    gcc_ver="$gcc_ver.1"
  fi
  gcc_pver="$gcc_ver"-ppa"$ppa_no~$distro"
  g2_pver="$gcc_pver"
  g1_dir=gcc-bootstraps-ia16-elf_"$gcc_ver"
  g1_pdir=gcc-bootstraps-ia16-elf_"$gcc_pver"
  g2_dir=gcc-ia16-elf_"$gcc_ver"
  g2_pdir=gcc-ia16-elf_"$gcc_pver"
  gs_dir=gcc-stubs-ia16-elf_"$gcc_ver"
  gs_pdir=gcc-stubs-ia16-elf_"$gcc_pver"
  # Another messy temporary hack.
  if [ 20180210 = "$gcc_date" -o 20180215 = "$gcc_date" ]; then
    g2_ver="$gcc_uver"-"$gcc_date".0
    g2_pver="$g2_ver"-ppa"$ppa_no~$distro"
    g2_dir=gcc-ia16-elf_"$g2_ver"
    g2_pdir=gcc-ia16-elf_"$g2_pver"
  fi
}

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
