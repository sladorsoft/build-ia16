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
  bu_date="`cd binutils-ia16 && git log -n1 --oneline --date=iso-strict-local \
    --format='%ad' | sed 's/-//g; s/:.*$//g; s/T/./g'`"
  [ -n "$bu_uver" -a -n "$bu_date" ]
  bu_ver="$bu_uver"-"$bu_date"
  bu_pver="$bu_ver"-ppa"$ppa_no~$distro"
  bu_dir=binutils-ia16-elf"$1"_"$bu_ver"
  bu_pdir=binutils-ia16-elf"$1"_"$bu_pver"
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
    gcc_ver="$gcc_ver.2"
  fi
  gcc_pver="$gcc_ver"-ppa"$ppa_no~$distro"
  g2_pver="$gcc_pver"
  g1_dir=gcc-bootstraps-ia16-elf_"$gcc_ver"
  g1_pdir=gcc-bootstraps-ia16-elf_"$gcc_pver"
  g2_dir=gcc-ia16-elf"$1"_"$gcc_ver"
  g2_pdir=gcc-ia16-elf"$1"_"$gcc_pver"
  gs_ver="$gcc_ver"
  gs_pver="$gcc_pver"
  # Another messy temporary hack.
  if [ 20200201.13 = "$gcc_date" ]; then
    gs_ver="$gcc_ver".1
    gs_pver="$gs_ver"-ppa"$ppa_no~$distro"
  fi
  gs_dir=gcc-stubs-ia16-elf_"$gs_ver"
  gs_pdir=gcc-stubs-ia16-elf_"$gs_pver"
  # Yet another messy temporary hack.
  if [ 20180210 = "$gcc_date" -o 20180215 = "$gcc_date" ]; then
    g2_ver="$gcc_uver"-"$gcc_date".0
    g2_pver="$g2_ver"-ppa"$ppa_no~$distro"
    g2_dir=gcc-ia16-elf"$1"_"$g2_ver"
    g2_pdir=gcc-ia16-elf"$1"_"$g2_pver"
  fi
}

decide_newlib_ver_and_dirs () {
  decide_binutils_ver_and_dirs "$1"
  decide_gcc_ver_and_dirs "$1"
  nl_uver="`cat newlib-ia16/newlib/configure | \
    sed -n "/^PACKAGE_VERSION='/ { s/^.*='*//; s/'*$//; p; q; }" || :`"
  nl_date="`cd newlib-ia16 && git log -n1 --oneline --date=iso-strict-local \
    --format='%ad' | sed 's/-//g; s/:.*$//g; s/T/./g'`"
  [ -n "$nl_uver" -a -n "$nl_date" ]
  # Include the GCC and binutils versions inside the newlib version, to
  # distinguish between different newlib binaries compiled from the same
  # source (but different GCC and binutils versions).
  nl_ver="$nl_uver"-"$nl_date"-stage1gcc"$gcc_ver"-binutils"$bu_ver"
  nl_pver="$nl_ver"-ppa"$ppa_no~$distro"
  nl_dir=libnewlib-ia16-elf_"$nl_ver"
  nl_pdir=libnewlib-ia16-elf_"$nl_pver"
}

decide_elks_libc_ver_and_dirs () {
  decide_binutils_ver_and_dirs "$1"
  decide_gcc_ver_and_dirs "$1"
  el_uver1="`cat elks/elks/Makefile* | sed -n \
    "/^VERSION[ \t]*=/ { s/^.*=[ \t]*//; s/#.*$//; s/[ \t]*$//; p; q; }" || :`"
  el_uver2="`cat elks/elks/Makefile* | sed -n \
    "/^PATCHLEVEL[ \t]*=/ { s/^.*=[ \t]*//; s/#.*$//; s/[ \t]*$//; p; q; }" \
    || :`"
  el_uver3="`cat elks/elks/Makefile* | sed -n \
    "/^SUBLEVEL[ \t]*=/ { s/^.*=[ \t]*//; s/#.*$//; s/[ \t]*$//; p; q; }" \
    || :`"
  el_uver4="`cat elks/elks/Makefile* | sed -n \
    "/^PRE[ \t]*=/ { s/^.*=[ \t]*//; s/#.*$//; s/[ \t]*$//; p; q; }" \
    || :`"
  el_uver="$el_uver1"
  if [ -n "$el_uver2" ]; then
    el_uver="$el_uver.$el_uver2"
    if [ -n "$el_uver3" ]
      then el_uver="$el_uver.$el_uver3"; fi
  fi
  if [ -n "$el_uver4" ]; then
    el_uver="$el_uver~pre$el_uver4"
  fi
  el_date="`cd elks && git log -n1 --oneline --date=iso-strict-local \
    --format='%ad' | sed 's/-//g; s/:.*$//g; s/T/./g'`"
  [ -n "$el_uver" -a -n "$el_date" ]
  # Include the GCC and binutils versions inside the elks-libc version.
  el_ver="$el_uver"-"$el_date"-stage1gcc"$gcc_ver"-binutils"$bu_ver"
  # Yet another messy hack.
  if [ 20190505.14 = "$el_date" ]; then
    el_ver="$el_uver"-"$el_date".7-stage1gcc"$gcc_ver"-binutils"$bu_ver"
  fi
  if [ 20200214.13 = "$el_date" ]; then
    el_ver="$el_uver"-"$el_date".0-stage1gcc"$gcc_ver"-binutils"$bu_ver"
  fi
  el_pver="$el_ver"-ppa"$ppa_no~$distro"
  el_dir=elks-libc-gcc-ia16-elf_"$el_ver"
  el_pdir=elks-libc-gcc-ia16-elf_"$el_pver"
}

decide_elksemu_ver_and_dirs () {
  # Use the ELKS version number rather than elks-libc's...
  ee_uver="`awk 'BEGIN { v = p = s = 0; q = -1; FS = "[ \t]*[=#][ \t]*" }
		 /^VERSION[ \t]*=/ { v = $2 }
		 /^PATCHLEVEL[ \t]*=/ { p = $2 }
		 /^SUBLEVEL[ \t]*=/ { s = $2 }
		 /^PRE[ \t]*=/ { q = $2 }
		 END { if (q != -1) print v "." p "." s "." q; else
				    print v "." p "." s }' \
	      elks/elks/Makefile-rules || :`"
  ee_date="`cd elks && git log -n1 --oneline --date=iso-strict-local \
    --format='%ad' | sed 's/-//g; s/:.*$//g; s/T/./g'`"
  [ -n "$ee_uver" -a -n "$ee_date" ]
  ee_ver="$ee_uver"-"$ee_date"
  ee_pver="$ee_ver"-ppa"$ppa_no~$distro"
  ee_dir=elksemu_"$ee_ver"
  ee_pdir=elksemu_"$ee_pver"
}

decide_libi86_ver_and_dirs () {
  decide_binutils_ver_and_dirs "$1"
  decide_gcc_ver_and_dirs "$1"
  li_uver="`cat libi86/configure | \
    sed -n "/^PACKAGE_VERSION='/ { s/^.*='*//; s/'*$//; p; q; }" || :`"
  [ -n "$li_uver" ]
  if [ 20200321 = "$li_uver" ]; then
    li_uver=20200321.0
  fi
  if [ 20210401 = "$li_uver" ]; then
    li_uver=20210401.0
  fi
  # Include the GCC and binutils versions inside the libi86 version.
  li_ver="$li_uver"-stage1gcc"$gcc_ver"-binutils"$bu_ver"
  li_pver="$li_ver"-ppa"$ppa_no~$distro"
  li_dir=libi86-ia16-elf_"$li_ver"
  li_pdir=libi86-ia16-elf_"$li_pver"
}
