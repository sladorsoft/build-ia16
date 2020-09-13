#!/bin/bash

set -e
set -o pipefail

SCRIPTDIR="$(dirname "$0")"
export HERE="$(cd "$SCRIPTDIR" && pwd)"
PREFIX="$HERE/prefix"
REDIST="$HERE/redist"
REDIST_PPA="$HERE/redist-ppa"
REDIST_DJGPP="$HERE/redist-djgpp"
PARALLEL="-j 4"
#PARALLEL=""
BINUTILSOPTS="--enable-ld=default --enable-gold=yes ` \
	     `--enable-targets=ia16-elf --enable-hpa-segelf=yes"
AUTOTESTPARALLEL="-j3"
export SHELL=/bin/bash  # make sure subshells, e.g. in `script', are also bash

# Set this to false to disable C++ (speed up build a bit) for Linux and
# Windows hosts.
WITHCXX=true
# Set this to false to disable C++ for DJGPP/MS-DOS.
WITHCXXDJGPP=false

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

either_in_list () {
  local needle1=$1
  local needle2=$2
  local haystackname=$3
  local -a haystack
  eval "haystack=( "\${$haystackname[@]}" )"
  for x in "${haystack[@]}"; do
    if [ "$x" = "$needle1" -o "$x" = "$needle2" ]; then
      return 0
    fi
  done
  return 1
}

either_or_or_in_list () {
  local needle1=$1
  local needle2=$2
  local needle3=$3
  local haystackname=$4
  local -a haystack
  eval "haystack=( "\${$haystackname[@]}" )"
  for x in "${haystack[@]}"; do
    if [ "$x" = "$needle1" -o "$x" = "$needle2" -o "$x" = "$needle3" ]; then
      return 0
    fi
  done
  return 1
}

ensure_prog () {
  local x
  for x in ${1+"$@"}; do
    if type -p "$x" >/dev/null; then
      return 0
    fi
  done
  echo -n "Need one of these programs for build:"
  for x in ${1+"$@"}; do
    echo -n " '$x'"
  done
  echo
  exit 1
}

declare -a BUILDLIST
BUILDLIST=()

while [ $# -gt 0 ]; do
  case "$1" in
    clean|binutils|prereqs|gcc1|newlib|elks-libc|elf2elks|elksemu|libi86|gcc2|extra|sim|test|debug|binutils-debug|clean-windows|prereqs-windows|binutils-windows|gcc-windows|clean-djgpp|prereqs-djgpp|some-prereqs-djgpp|binutils-djgpp|elf2elks-djgpp|gcc-djgpp|redist-djgpp)
      BUILDLIST=( "${BUILDLIST[@]}" $1 )
      ;;
    all)
      BUILDLIST=("clean" "binutils" "prereqs" "gcc1" "newlib" "elks-libc" "elf2elks" "elksemu" "libi86" "gcc2" "extra" "sim" "test" "debug" "binutils-debug" "clean-windows" "prereqs-windows" "binutils-windows" "gcc-windows" "clean-djgpp" "prereqs-djgpp" "some-prereqs-djgpp" "binutils-djgpp" "elf2elks-djgpp" "gcc-djgpp" "redist-djgpp")
      ;;
    *)
      echo "Unknown option '$1'."
      exit 1
      ;;
  esac
  shift
done

if [ "${#BUILDLIST}" -eq 0 ]; then
  echo "build options: clean binutils prereqs gcc1 newlib elks-libc elf2elks elksemu libi86 gcc2 extra sim test debug binutils-debug all clean-windows prereqs-windows binutils-windows gcc-windows clean-djgpp prereqs-djgpp some-prereqs-djgpp binutils-djgpp elf2elks-djgpp gcc-djgpp redist-djgpp"
  exit 1
fi

if $WITHCXX; then
  LANGUAGES="c,c++"
  # Remember to sync this with ppa-pkging/build2/rules !
  #
  # Exclude the "dual ABI" backward compatibility stuff --- including it makes
  # it harder than it already is to fit the text section into 64 KiB.
  #
  # Also disable the use of external template instantiations.  The default
  # instantiations in libstdc++-v3/src/ are too coarse-grained --- e.g. 
  # libstdc++-v3/src/c++11/istream-inst.cc instantiates both std::istream
  # and std::wistream (!), _and_ also throws in several <iomanip>
  # manipulators for good measure (!!).  If we disable these, then each
  # module in a user's program will only instantiate those functions that
  # the program really needs.  The trade-off is that the intermediate object
  # files may be larger and duplicate code (which should be merged at link
  # time).
  #
  # And, disable verbose std::terminate () error messages, which require quite
  # a hefty amount of code to handle.
  EXTRABUILD2OPTS="--with-newlib --disable-libstdcxx-dual-abi ` \
    `--disable-extern-template --disable-wchar_t --disable-libstdcxx-verbose"
else
  LANGUAGES="c"
  EXTRABUILD2OPTS=
fi

if $WITHCXXDJGPP; then
  LANGUAGESDJGPP="c,c++"
  EXTRABUILD2OPTSDJGPP="--with-newlib --disable-libstdcxx-dual-abi ` \
    `--disable-extern-template --disable-wchar_t --disable-libstdcxx-verbose"
else
  LANGUAGESDJGPP="c"
  EXTRABUILD2OPTSDJGPP=
fi

BIN=$HERE/prefix/bin
if [[ ":$PATH:" != *":$BIN:"* ]]; then
    export PATH="$BIN:${PATH:+"$PATH"}"
    echo Path set to $PATH
fi
DJGPP_BIN=$HERE/djgpp/bin
if [[ ":$PATH:" != *":$DJGPP_BIN:"* ]]; then
    export PATH="$DJGPP_BIN:${PATH:+"$PATH"}"
    echo Path set to $PATH
fi

cd "$HERE"

if in_list clean BUILDLIST; then
  echo
  echo "************"
  echo "* Cleaning *"
  echo "************"
  echo
  rm -rf "$PREFIX" "$PREFIX"-* "$REDIST" "$REDIST_PPA" "$REDIST_DJGPP" \
    build build2 build-* log_filter log_compare
  mkdir -p "$PREFIX/bin"
fi

if in_list binutils BUILDLIST; then
  echo
  echo "*********************"
  echo "* Building binutils *"
  echo "*********************"
  echo
  ensure_prog gcc cc
  ensure_prog make
  ensure_prog flex
  ensure_prog bison
  ensure_prog makeinfo
  rm -rf build-binutils
  mkdir build-binutils
  pushd build-binutils
  ../binutils-ia16/configure --target=ia16-elf --prefix="$PREFIX" \
    $BINUTILSOPTS --disable-gdb --disable-libdecnumber --disable-readline \
    --disable-sim --disable-nls 2>&1 | tee build.log
  script -e -c "make $PARALLEL" -a build.log
  script -e -c "make $PARALLEL install" -a build.log
  popd
fi

if in_list binutils-debug BUILDLIST; then
  echo
  echo "***************************"
  echo "* Building debug binutils *"
  echo "***************************"
  echo
  ensure_prog gcc cc
  ensure_prog make
  ensure_prog flex
  ensure_prog bison
  ensure_prog makeinfo
  rm -rf build-binutils-debug
  mkdir build-binutils-debug
  pushd build-binutils-debug
  ../binutils-ia16/configure --target=ia16-elf --prefix="$PREFIX" \
    $BINUTILSOPTS --disable-gdb --disable-libdecnumber --disable-readline \
    --disable-sim --disable-nls 2>&1 | tee build.log
  make $PARALLEL 'CFLAGS=-g -O0' 'CXXFLAGS=-g -O0' 'BOOT_CFLAGS=-g -O0' 2>&1 | tee -a build.log
  script -e -c "make $PARALLEL install" -a build.log
  popd
fi

if in_list prereqs BUILDLIST; then
  echo
  echo "********************************"
  echo "* Building host prerequisities *"
  echo "********************************"
  echo
  rm -rf build-gmp "$PREFIX-gmp" \
	 build-mpfr "$PREFIX-mpfr" \
	 build-mpc "$PREFIX-mpc" \
	 build-isl "$PREFIX-isl"
  mkdir build-gmp build-mpfr build-mpc build-isl
  pushd build-gmp
  ../gmp-6.1.2/configure --prefix="$PREFIX-gmp" --disable-shared 2>&1 \
    | tee build.log
  script -e -c "make $PARALLEL" -a build.log
  script -e -c "make $PARALLEL install" -a build.log
  popd
  pushd build-mpfr
  ../mpfr-3.1.5/configure --prefix="$PREFIX-mpfr" \
    --with-gmp="$PREFIX-gmp" --disable-shared 2>&1 | tee build.log
  script -e -c "make $PARALLEL" -a build.log
  script -e -c "make $PARALLEL install" -a build.log
  popd
  pushd build-mpc
  ../mpc-1.0.3/configure --prefix="$PREFIX-mpc" \
    --with-gmp="$PREFIX-gmp" --with-mpfr="$PREFIX-mpfr" --disable-shared 2>&1 \
    | tee build.log
  script -e -c "make $PARALLEL" -a build.log
  script -e -c "make $PARALLEL install" -a build.log
  popd
  pushd build-isl
  ../isl-0.16.1/configure --prefix="$PREFIX-isl" \
    --with-gmp-prefix="$PREFIX-gmp" --disable-shared 2>&1 | tee build.log
  script -e -c "make $PARALLEL" -a build.log
  script -e -c "make $PARALLEL install" -a build.log
  popd
fi

obsolete_gcc_multilibs_installed () {
  [ -e "$PREFIX"/ia16-elf/lib/i80286 -o \
    -e "$PREFIX"/lib/gcc/ia16-elf/6.3.0/i80286 -o \
    -e "$PREFIX"/ia16-elf/include/c++/6.3.0/ia16-elf/i80286 -o \
    -e "$PREFIX"/ia16-elf/lib/any_186 -o \
    -e "$PREFIX"/lib/gcc/ia16-elf/6.3.0/any_186 -o \
    -e "$PREFIX"/ia16-elf/include/c++/6.3.0/ia16-elf/any_186 -o \
    -e "$PREFIX"/ia16-elf/lib/wide-types -o \
    -e "$PREFIX"/lib/gcc/ia16-elf/6.3.0/wide-types -o \
    -e "$PREFIX"/ia16-elf/include/c++/6.3.0/ia16-elf/wide-types -o \
    -e "$PREFIX"/ia16-elf/lib/frame-pointer -o \
    -e "$PREFIX"/lib/gcc/ia16-elf/6.3.0/frame-pointer -o \
    -e "$PREFIX"/ia16-elf/include/c++/6.3.0/ia16-elf/frame-pointer -o \
    -e "$PREFIX"/ia16-elf/lib/rtd/elkslibc -o \
    -e "$PREFIX"/ia16-elf/lib/regparmcall/elkslibc ]
}

obsolete_newlib_multilibs_installed () {
  [ -e "$PREFIX"/ia16-elf/lib/elks-combined.ld -o \
    -e "$PREFIX"/ia16-elf/lib/elks-separate.ld -o \
    -e "$PREFIX"/ia16-elf/lib/elk-mtl.ld -o \
    -e "$PREFIX"/ia16-elf/lib/elk-mts.ld -o \
    -e "$PREFIX"/ia16-elf/lib/pmode/elk-mt.ld -o \
    -e "$PREFIX"/ia16-elf/lib/pmode/elk-mtl.ld -o \
    -e "$PREFIX"/ia16-elf/lib/pmode/elk-mts.ld -o \
    -e "$PREFIX"/ia16-elf/lib/libelks.a -o \
    -e "$PREFIX"/ia16-elf/lib/elks-crt0.o -o \
    -e "$PREFIX"/ia16-elf/lib/rtd/libelks.a -o \
    -e "$PREFIX"/ia16-elf/lib/rtd/elks-crt0.o -o \
    -e "$PREFIX"/ia16-elf/lib/regparmcall/libelks.a -o \
    -e "$PREFIX"/ia16-elf/lib/regparmcall/elks-crt0.o -o \
    -e "$PREFIX"/ia16-elf/lib/pmode/dpm-mt.a -o \
    -e "$PREFIX"/ia16-elf/lib/pmode/dpm-ms.a -o \
    -e "$PREFIX"/ia16-elf/lib/pmode/dpm-mt-crt0.o -o \
    -e "$PREFIX"/ia16-elf/lib/pmode/dpm-ms-crt0.o -o \
    -e "$PREFIX"/ia16-elf/lib/pmode/libelks.a -o \
    -e "$PREFIX"/ia16-elf/lib/pmode/elks-crt0.o -o \
    -e "$PREFIX"/ia16-elf/lib/libdos-com.a -o \
    -e "$PREFIX"/ia16-elf/lib/dos-com-crt0.o -o \
    -e "$PREFIX"/ia16-elf/lib/libdos-exe-small.a -o \
    -e "$PREFIX"/ia16-elf/lib/dos-exe-small-crt0.o ]
}

obsolete_multilibs_installed () {
  obsolete_gcc_multilibs_installed || obsolete_newlib_multilibs_installed
}

if in_list gcc1 BUILDLIST; then
  echo
  echo "************************"
  echo "* Building stage 1 GCC *"
  echo "************************"
  echo
  # Check for any previously installed `i80286', `wide-types', or `frame-
  # pointer' multilibs, Newlib/ELKS libraries, as well as "old style"
  # `elkslibc' libraries, and clean them away...
  if obsolete_gcc_multilibs_installed; then
    set +e
    find "$PREFIX"/ia16-elf/lib -name i80286 -print0 | xargs -0 rm -rf
    find "$PREFIX"/lib/gcc/ia16-elf -name i80286 -print0 | xargs -0 rm -rf
    find "$PREFIX"/ia16-elf/include -name i80286 -print0 | xargs -0 rm -rf
    find "$PREFIX"/ia16-elf/lib -name any_186 -print0 | xargs -0 rm -rf
    find "$PREFIX"/lib/gcc/ia16-elf -name any_186 -print0 | xargs -0 rm -rf
    find "$PREFIX"/ia16-elf/include -name any_186 -print0 | xargs -0 rm -rf
    find "$PREFIX"/ia16-elf/lib -name wide-types -print0 | xargs -0 rm -rf
    find "$PREFIX"/lib/gcc/ia16-elf -name wide-types -print0 | xargs -0 rm -rf
    find "$PREFIX"/ia16-elf/include -name wide-types -print0 | xargs -0 rm -rf
    find "$PREFIX"/ia16-elf/lib -name frame-pointer -print0 | xargs -0 rm -rf
    find "$PREFIX"/lib/gcc/ia16-elf -name frame-pointer -print0 \
      | xargs -0 rm -rf
    find "$PREFIX"/ia16-elf/include -name frame-pointer -print0 \
      | xargs -0 rm -rf
    find "$PREFIX"/ia16-elf/lib -name elkslibc -print0 | xargs -0 rm -rf
    set -e
  fi
  rm -rf build
  mkdir build
  pushd build
  ../gcc-ia16/configure --target=ia16-elf --prefix="$PREFIX" \
    --without-headers --with-newlib --enable-languages=c --disable-libssp \
    --disable-libquadmath --with-gmp="$PREFIX-gmp" --with-mpc="$PREFIX-mpc" \
    --with-mpfr="$PREFIX-mpfr" --with-isl="$PREFIX-isl" 2>&1 | tee build.log
#--enable-checking=all,valgrind
  script -e -c "make $PARALLEL" -a build.log
  script -e -c "make install" -a build.log
  popd
fi

if in_list newlib BUILDLIST; then
  echo
  echo "*****************************"
  echo "* Building Newlib C library *"
  echo "*****************************"
  echo
  if obsolete_gcc_multilibs_installed; then
    echo 'Please rebuild gcc1.'
    exit 1
  fi
  if obsolete_newlib_multilibs_installed; then
    set +e
    find "$PREFIX" -name elks-combined.ld -print0 | xargs -0 rm -rf
    find "$PREFIX" -name elks-separate.ld -print0 | xargs -0 rm -rf
    find "$PREFIX" -name 'elk-m[ts]'.ld -print0 | xargs -0 rm -rf
    find "$PREFIX" -name 'elk-m[ts][sl]'.ld -print0 | xargs -0 rm -rf
    find "$PREFIX" -name 'elk-m[ts]sl'.ld -print0 | xargs -0 rm -rf
    find "$PREFIX"/ia16-elf/lib -name libelks.a -print0 | xargs -0 rm -rf
    find "$PREFIX"/ia16-elf/lib -name elks-crt0.o -print0 | xargs -0 rm -rf
    find "$PREFIX"/ia16-elf/lib -name dpm-mt.a -print0 | xargs -0 rm -rf
    find "$PREFIX"/ia16-elf/lib -name dpm-ms.a -print0 | xargs -0 rm -rf
    find "$PREFIX"/ia16-elf/lib -name dpm-mt-crt0.o -print0 | xargs -0 rm -rf
    find "$PREFIX"/ia16-elf/lib -name dpm-ms-crt0.o -print0 | xargs -0 rm -rf
    find "$PREFIX"/ia16-elf/lib -name libdos-com.a -print0 | xargs -0 rm -rf
    find "$PREFIX"/ia16-elf/lib -name dos-com-crt0.o -print0 | xargs -0 rm -rf
    find "$PREFIX"/ia16-elf/lib -name libdos-exe-small.a -print0 \
      | xargs -0 rm -rf
    find "$PREFIX"/ia16-elf/lib -name dos-exe-small-crt0.o -print0 \
      | xargs -0 rm -rf
    set -e
  fi
  # Then...
  rm -rf build-newlib
  mkdir build-newlib
  pushd build-newlib
  CFLAGS_FOR_TARGET='-g -Os -D_IEEE_LIBM ' \
    ../newlib-ia16/configure --target=ia16-elf --prefix="$PREFIX" \
      --disable-elks-libc \
      --disable-newlib-wide-orient --enable-newlib-nano-malloc \
      --disable-newlib-multithread --enable-newlib-global-atexit \
      --enable-newlib-reent-small --disable-newlib-fseek-optimization \
      --disable-newlib-unbuf-stream-opt --enable-target-optspace \
      --enable-newlib-iconv \
      --enable-newlib-iconv-encodings=utf_8,utf_16,cp850,cp852,koi8_uni 2>&1 \
      | tee build.log
  script -e -c "make $PARALLEL" -a build.log
  script -e -c "make install" -a build.log
  popd
fi

if either_or_or_in_list elks-libc elf2elks elksemu BUILDLIST; then
  echo
  echo "*********************************************"
  echo "* Building elks-libc, elf2elks, and elksemu *"
  echo "*********************************************"
  echo
  # For now, specifying either the `elks-libc', `elf2elks', or `elksemu'
  # option will build both all of these together.  However, I am leaving
  # open the possibility of building them separately later.
  #	-- tkchia 20200913
  #
  # The ELKS source tree is not downloaded on default by fetch.sh, since it
  # is quite big and we may not always need it.  -- tkchia 20190426
  [ -f elks/.git/config ] || \
    git clone -b tkchia/devel https://github.com/tkchia/elks.git
  if obsolete_multilibs_installed; then
    echo 'Please rebuild gcc1 and newlib.'
    exit 1
  fi
  rm -rf build-elks
  mkdir build-elks
  # Instead of building inside the ELKS source tree, create a copy of it (with
  # only the files under Git control) as a separate subdirectory, and build
  # elks-libc and elksemu inside the copy.
  #
  # Copy the working tree versions of the files, not the committed versions.
  #	-- tkchia 20200227
  (cd elks && find . \! -type d -print0 | xargs -0 git ls-files --) | \
    xargs -d '\n' tar cvf - -C elks | tar xvf - -C build-elks
  pushd build-elks
  mkdir -p cross include
  script -e -c ". env.sh && make defconfig" build.log
  script -e -c ". env.sh && cd libc && make clean" -a build.log
  script -e -c ". env.sh && cd libc && make -j4 all" -a build.log
  script -e -c ". env.sh && cd libc && make -j4 DESTDIR='$PREFIX' install" \
	 -a build.log
  script -e -c ". env.sh && cd elks/tools/elf2elks && make doclean" \
	 -a build.log
  script -e -c ". env.sh && cd elks/tools/elf2elks && make" -a build.log
  cp -a elks/tools/bin/elf2elks "$PREFIX"/bin/
  script -e -c ". env.sh && cd elksemu && make clean" -a build.log
  script -e -c ". env.sh && cd elksemu && make PREFIX='$PREFIX'" \
	 -a build.log
  popd
fi

if in_list libi86 BUILDLIST; then
  echo
  echo "*******************"
  echo "* Building libi86 *"
  echo "*******************"
  echo
  [ -f libi86/.git/config ] || \
    git clone https://gitlab.com/tkchia/libi86.git
  ensure_prog autoconf
  ensure_prog autom4te
  if obsolete_multilibs_installed; then
    echo 'Please rebuild gcc1 and newlib.'
    exit 1
  fi
  # Remove some internal headers that I added at some point in time and later
  # made redundant (or build-internal) again...  -- tkchia 20190101
  rm -f "$PREFIX"/ia16-elf/include/libi86/internal/conio.h \
	"$PREFIX"/ia16-elf/include/libi86/internal/int86.h \
	"$PREFIX"/ia16-elf/include/libi86/internal/farptr.h
  # Then...
  rm -rf build-libi86
  mkdir build-libi86
  pushd build-libi86
  if [ -e ../libi86/autogen.sh ]; then
    (cd ../libi86 && ./autogen.sh)
  fi
  script -e -c "../libi86/configure --prefix='$PREFIX'" build.log
  script -e -c "make $PARALLEL" -a build.log
  # Only run tests if dosemu exists.  (I prefer the "original" dosemu ---
  # dosemu2 does not have a designated stable version yet.  Unfortunately,
  # Ubuntu Focal does not seem to come with the original dosemu.)
  if dosemu --version; then
    script -e -c "make check TESTSUITEFLAGS='$AUTOTESTPARALLEL'" -a build.log
  fi
  script -e -c "make $PARALLEL install" -a build.log
  popd
fi

if in_list gcc2 BUILDLIST; then
  echo
  echo "************************"
  echo "* Building stage 2 GCC *"
  echo "************************"
  echo
  if obsolete_multilibs_installed; then
    echo 'Please rebuild gcc1 and newlib.'
    exit 1
  fi
  rm -rf build2
  mkdir build2
  pushd build2
  ../gcc-ia16/configure --target=ia16-elf --prefix="$PREFIX" --enable-libssp \
    --enable-languages=$LANGUAGES $EXTRABUILD2OPTS --disable-libquadmath \
    --with-gmp="$PREFIX-gmp" --with-mpc="$PREFIX-mpc" \
    --with-mpfr="$PREFIX-mpfr" --with-isl="$PREFIX-isl" 2>&1 | tee build.log
  script -e -c "make $PARALLEL" -a build.log
  script -e -c "make install" -a build.log
  popd
fi

if in_list extra BUILDLIST; then
  echo
  echo "****************************************************"
  echo "* Building extra stuff (PDCurses, ubasic, tinyasm) *"
  echo "****************************************************"
  echo
  [ -f pdcurses/.git/config ] || \
    git clone https://github.com/tkchia/PDCurses.git pdcurses
  rm -rf build-pdcurses
  mkdir build-pdcurses
  pushd build-pdcurses
  make $PARALLEL -f ../pdcurses/dos/gccdos16.mak PDCURSES_SRCDIR=../pdcurses \
    CC="$PREFIX/bin/ia16-elf-gcc" pdcurses.a 2>&1 | tee build.log
  make -f ../pdcurses/dos/gccdos16.mak PDCURSES_SRCDIR=../pdcurses \
    CC="$PREFIX/bin/ia16-elf-gcc" worm.exe xmas.exe 2>&1 | tee -a build.log
  cp -a pdcurses.a "$PREFIX"/ia16-elf/lib/libpdcurses.a
  cp -a ../pdcurses/curses.h "$PREFIX"/ia16-elf/include
  popd
  #
  [ -f ubasic-ia16/.git/config ] || \
    git clone https://github.com/tkchia/ubasic-ia16.git
  rm -rf build-ubasic
  mkdir build-ubasic
  pushd build-ubasic
  make $PARALLEL -f ../ubasic-ia16/Makefile.ia16 VPATH=../ubasic-ia16 2>&1 | \
    tee build.log
  popd
  #
  [ -f tinyasm/.git/config ] || \
    git clone https://github.com/tkchia/tinyasm.git
  pushd tinyasm
  rm -rf tinyasm.exe TINYASM.EXE
  (
    set -e -x
    "$PREFIX/bin/ia16-elf-gcc" -mcmodel=small -Os -mregparmcall \
      -mnewlib-nano-stdio tinyasm.c ins.c -o tinyasm.exe
  )
  popd
fi

if in_list sim BUILDLIST; then
  echo
  echo "**********************"
  echo "* Building simulator *"
  echo "**********************"
  echo

  # This script used to build dosemu2, but not anymore (dosemu2 is getting a
  # bit too complex to build).
  #
  # To try out dosemu2, you can either use Andrew Bird et al.'s Ubuntu PPA
  # (https://launchpad.net/~dosemu2/+archive/ubuntu/ppa) or my selection of
  # the more stable packages (https://launchpad.net/~tkchia/+archive/ubuntu/
  # dosemu-on-travis-ci).
  #
  # Alternatively, use the "original" dosemu 1.x.

  if [ -e 86sim/86sim.cpp ]; then
    [ -e 86sim/86sim ] && rm 86sim/86sim
    gcc -Wall -O2 86sim/86sim.cpp -o 86sim/86sim
  fi

  g++ -std=c++11 -Ireenigne/include -Wall -O2 -fpermissive \
    reenigne/logtools/log_filter/log_filter.cpp -o log_filter
  g++ -std=c++11 -Ireenigne/include -Wall -O2 -fpermissive \
    reenigne/logtools/log_compare/log_compare.cpp -o log_compare
fi

if in_list test BUILDLIST; then
  echo
  echo "*****************"
  echo "* Running tests *"
  echo "*****************"
  echo
  ensure_prog runtest
  ensure_prog autogen
  export DEJAGNU="$HERE/site.exp"
  if [ -e 86sim/86sim.cpp ]; then
    target_board="--target_board=86sim"
  else
    target_board="--target_board=dosemu"
  fi
  pushd build2
  GROUP=""
  if [ -f ../group ]; then
    read GROUP < ../group
  fi
  i=0
  while [[ -e ../fails-$GROUP$i.txt ]] ; do
    i=$[$i+1]
  done
  if [ -z "$RUNTESTFLAGS" ]; then
    RUNTESTFLAGS="$target_board"
  else
    RUNTESTFLAGS="$RUNTESTFLAGS $target_board"
  fi
  nice make -k check RUNTESTFLAGS="$RUNTESTFLAGS" 2>&1 | tee test.log
  ../log_filter gcc/testsuite/gcc/gcc.log >../results-$GROUP$i.log
  ../log_filter gcc/testsuite/g++/g++.log >>../results-$GROUP$i.log
  ../log_filter ia16-elf/libstdc++-v3/testsuite/libstdc++.log >>../results-$GROUP$i.log
  grep -E ^FAIL\|^WARNING\|^ERROR\|^XPASS ../results-$GROUP$i.log > ../fails-$GROUP$i.txt
  popd
fi

if in_list debug BUILDLIST; then
  echo
  echo "**********************"
  echo "* Building debug GCC *"
  echo "**********************"
  echo
  rm -rf build-debug
  mkdir build-debug
  pushd build-debug
  ../gcc-ia16/configure --target=ia16-elf --prefix="$PREFIX" --enable-libssp \
    --enable-languages=$LANGUAGES --with-as="$PREFIX/bin/ia16-elf-as" \
    --disable-libquadmath $EXTRABUILD2OPTS 2>&1 | tee build.log
  make $PARALLEL 'CFLAGS=-g -O0' 'CXXFLAGS=-g -O0' 'BOOT_CFLAGS=-g -O0' 2>&1 | tee -a build.log
  popd
fi

if in_list clean-windows BUILDLIST; then
  echo
  echo "********************"
  echo "* Cleaning Windows *"
  echo "********************"
  echo
  rm -rf "$PREFIX-windows"
  mkdir -p "$PREFIX-windows/bin"
fi

if in_list prereqs-windows BUILDLIST; then
  echo
  echo "**********************************"
  echo "* Building Windows prerequisites *"
  echo "**********************************"
  echo
  rm -rf "$PREFIX-prereqs"
  mkdir -p "$PREFIX-prereqs"
  rm -rf build-gmp-windows
  mkdir build-gmp-windows
  pushd build-gmp-windows
  ../gmp-6.1.2/configure --target=i686-w64-mingw32 --host=i686-w64-mingw32 --prefix="$PREFIX-prereqs" --disable-shared 2>&1 | tee build.log
  script -e -c "make $PARALLEL" -a build.log
  script -e -c "make $PARALLEL install" -a build.log
  popd
  rm -rf build-mpfr-windows
  mkdir build-mpfr-windows
  pushd build-mpfr-windows
  ../mpfr-3.1.5/configure --target=i686-w64-mingw32 --host=i686-w64-mingw32 --prefix="$PREFIX-prereqs" --with-gmp="$PREFIX-prereqs" --disable-shared 2>&1 | tee -a build.log
  script -e -c "make $PARALLEL" -a build.log
  script -e -c "make $PARALLEL install" -a build.log
  popd
  rm -rf build-mpc-windows
  mkdir build-mpc-windows
  pushd build-mpc-windows
  ../mpc-1.0.3/configure --target=i686-w64-mingw32 --host=i686-w64-mingw32 --prefix="$PREFIX-prereqs" --with-gmp="$PREFIX-prereqs" --with-mpfr="$PREFIX-prereqs" --disable-shared 2>&1 | tee -a build.log
  script -e -c "make $PARALLEL" -a build.log
  script -e -c "make $PARALLEL install" -a build.log
  popd
  rm -rf build-isl-windows
  mkdir build-isl-windows
  pushd build-isl-windows
  ../isl-0.16.1/configure --target=i686-w64-mingw32 --host=i686-w64-mingw32 --prefix="$PREFIX-prereqs" --disable-shared --with-gmp-prefix="$PREFIX-prereqs" 2>&1 | tee -a build.log
  script -e -c "make $PARALLEL" -a build.log
  script -e -c "make $PARALLEL install" -a build.log
  popd
  mkdir "$PREFIX-windows/ia16-elf"
  cp -R "$PREFIX/ia16-elf/lib" "$PREFIX-windows/ia16-elf"
  cp -R "$PREFIX/ia16-elf/include" "$PREFIX-windows/ia16-elf"
fi

if in_list binutils-windows BUILDLIST; then
  echo
  echo "*****************************"
  echo "* Building Windows binutils *"
  echo "*****************************"
  echo
  rm -rf build-binutils-windows
  mkdir build-binutils-windows
  pushd build-binutils-windows
  ../binutils-ia16/configure --host=i686-w64-mingw32 --target=ia16-elf \
    --prefix="$PREFIX" $BINUTILSOPTS --disable-gdb --disable-libdecnumber \
    --disable-readline --disable-sim --disable-nls 2>&1 | tee build.log
  make $PARALLEL 'CFLAGS=-s -O2' 'CXXFLAGS=-s -O2' 'BOOT_CFLAGS=-s -O2' 2>&1 | tee -a build.log
  make $PARALLEL install prefix=$PREFIX-windows 2>&1 | tee -a build.log
  popd
fi

if in_list gcc-windows BUILDLIST; then
  echo
  echo "********************************"
  echo "* Building stage 2 Windows GCC *"
  echo "********************************"
  echo
  rm -rf build-windows
  mkdir build-windows
  pushd build-windows
  OLDPATH=$PATH
  export PATH=$PREFIX-windows/bin:$PATH
  ../gcc-ia16/configure --host=i686-w64-mingw32 --target=ia16-elf \
    --prefix="$PREFIX" --enable-libssp --enable-languages=$LANGUAGES \
    --disable-libquadmath --with-gmp="$PREFIX-prereqs" \
    --with-mpfr="$PREFIX-prereqs" --with-mpc="$PREFIX-prereqs" \
    $EXTRABUILD2OPTS --with-isl="$PREFIX-prereqs" 2>&1 | tee build.log
  make $PARALLEL 'CFLAGS=-s -O2' 'CXXFLAGS=-s -O2' 'BOOT_CFLAGS=-s -O2' 2>&1 | tee -a build.log
  make $PARALLEL install prefix=$PREFIX-windows 2>&1 | tee -a build.log
  export PATH=$OLDPATH
  popd
fi

if in_list clean-djgpp BUILDLIST; then
  echo
  echo "******************"
  echo "* Cleaning DJGPP *"
  echo "******************"
  echo
  rm -rf "$PREFIX-djgpp" "$PREFIX-djgpp-"* "$REDIST_DJGPP"
  mkdir -p "$PREFIX-djgpp/bin" "$PREFIX-djgpp-newlib" "$PREFIX-djgpp-libi86" \
	   "$PREFIX-djgpp-elkslibc" \
	   "$PREFIX-djgpp-binutils/bin" "$PREFIX-djgpp-elf2elks/bin" \
	   "$PREFIX-djgpp-gcc/bin"
fi

if in_list prereqs-djgpp BUILDLIST; then
  echo
  echo "********************************"
  echo "* Building DJGPP prerequisites *"
  echo "********************************"
  echo
  rm -rf "$PREFIX-djgpp-prereqs"
  mkdir -p "$PREFIX-djgpp-prereqs"
  #
  rm -rf build-gmp-djgpp
  mkdir build-gmp-djgpp
  pushd build-gmp-djgpp
  # This installation of GMP will probably not need to multiply
  # super-humongous integers, so we can disable the use of FFT...
  ../gmp-6.1.2/configure --target=i586-pc-msdosdjgpp \
    --host=i586-pc-msdosdjgpp --prefix="$PREFIX-djgpp-prereqs" \
    --disable-shared --disable-fft 2>&1 | tee build.log
  script -e -c "make $PARALLEL" -a build.log
  script -e -c "make $PARALLEL install" -a build.log
  popd
  #
  rm -rf build-mpfr-djgpp
  mkdir build-mpfr-djgpp
  pushd build-mpfr-djgpp
  ../mpfr-3.1.5/configure --target=i586-pc-msdosdjgpp \
    --host=i586-pc-msdosdjgpp --prefix="$PREFIX-djgpp-prereqs" \
    --with-gmp="$PREFIX-djgpp-prereqs" --disable-shared 2>&1 | tee build.log
  script -e -c "make $PARALLEL" -a build.log
  script -e -c "make $PARALLEL install" -a build.log
  popd
  #
  rm -rf build-mpc-djgpp
  mkdir build-mpc-djgpp
  pushd build-mpc-djgpp
  ../mpc-1.0.3/configure --target=i586-pc-msdosdjgpp \
    --host=i586-pc-msdosdjgpp --prefix="$PREFIX-djgpp-prereqs" \
    --with-gmp="$PREFIX-djgpp-prereqs" --with-mpfr="$PREFIX-djgpp-prereqs" \
    --disable-shared 2>&1 | tee build.log
  script -e -c "make $PARALLEL" -a build.log
  script -e -c "make $PARALLEL install" -a build.log
  popd
  #
  rm -rf build-isl-djgpp
  mkdir build-isl-djgpp
  pushd build-isl-djgpp
  ../isl-0.16.1/configure --target=i586-pc-msdosdjgpp \
    --host=i586-pc-msdosdjgpp --prefix="$PREFIX-djgpp-prereqs" \
    --disable-shared --with-gmp-prefix="$PREFIX-djgpp-prereqs" 2>&1 | \
    tee build.log
  script -e -c "make $PARALLEL" -a build.log
  script -e -c "make $PARALLEL install" -a build.log
  popd
fi

if either_in_list prereqs-djgpp some-prereqs-djgpp BUILDLIST; then
  echo
  echo "********************************************"
  echo "* Installing remaining DJGPP prerequisites *"
  echo "********************************************"
  echo
  # Instead of copying over everything in $PREFIX/ia16-elf/{lib, include} ---
  # including any C++ libraries --- just install Newlib into the DJGPP tree.
  # Create a separate tree dedicated to Newlib, then hard link everything.
  #
  # Remove libg.a for each multilib --- it is just a copy of the corresponding
  # libc.a .
  pushd build-newlib
  make install prefix="$PREFIX-djgpp-newlib"
  find "$PREFIX-djgpp-newlib" -name libg.a -print0 | xargs -0 rm -f
  cp -lrf "$PREFIX-djgpp-newlib"/* "$PREFIX-djgpp"
  popd
  # Similarly, install libi86 into the DJGPP tree.
  if [ -f libi86/.git/config ]; then
    pushd build-libi86
    make install prefix="$PREFIX-djgpp-libi86" \
		 exec_prefix="$PREFIX-djgpp-libi86"/ia16-elf
    cp -lrf "$PREFIX-djgpp-libi86"/* "$PREFIX-djgpp"
    popd
  fi
  # And elks-libc.
  #
  # To work around MS-DOS's 8.3 file name restriction, we mash <linuxmt/
  # minix_fs.h> and <linuxmt/minix_fs_sb.h> into a single include file. 
  # Ditto for <linuxmt/msdos_fs*.h>.
  #
  # When redist-djgpp.sh creates a FreeDOS package for elks-libc, it can pack
  # only the combined files and exclude the original files.
  #
  # Also make a copy of GCC's <stddef.h> and <stdarg.h>, since the GCC specs
  # have some trouble locating this file when `-melks-libc' is in effect
  # (due to `-nostdinc').  For DJGPP, we also need to copy <stdint-gcc.h> to
  # the elks-libc include directories as <stdint.h>.  FIXME: remove the need
  # for these hacks.
  if [ -f elks/.git/config ]; then
    pushd build-elks
    (. env.sh \
     && cd libc \
     && make -j4 DESTDIR="$PREFIX-djgpp-elkslibc" install)
    for multidir in . rtd medium medium/rtd; do
      cd "$PREFIX-djgpp-elkslibc"/ia16-elf/lib/elkslibc/"$multidir"/` \
	 `include/linuxmt
      (
	echo '/* Automatically combined from <linuxmt/minix_fs.h> and'
	echo '   <linuxmt/minix_fs_sb.h>. */'
	cat minix_fs.h minix_fs_sb.h 
      ) >minix_fs_combined.h
      (
	echo '/* Automatically combined from <linuxmt/msdos_fs.h>,'
	echo '   <linuxmt/msdos_fs_sb.h> and <linuxmt/msdos_fs_i.h>. */'
	cat msdos_fs.h msdos_fs_sb.h msdos_fs_i.h
      ) >msdos_fs_combined.h
      cp "$($PREFIX/bin/ia16-elf-gcc -print-file-name=include/stddef.h)" \
	 "$($PREFIX/bin/ia16-elf-gcc -print-file-name=include/stdarg.h)" \
	 "$PREFIX-djgpp-elkslibc"/ia16-elf/lib/elkslibc/"$multidir"/include/
      cp "$($PREFIX/bin/ia16-elf-gcc -print-file-name=include/stdint-gcc.h)" \
	 "$PREFIX-djgpp-elkslibc"/ia16-elf/lib/elkslibc/"$multidir"/include/`\
	 `stdint.h
    done
    cp -lrf "$PREFIX-djgpp-elkslibc"/* "$PREFIX-djgpp"
    popd
  fi
fi

djgpp_symlink () {
  "$HERE"/djgpp/i586-pc-msdosdjgpp/bin/stubify -g "$2"
  "$HERE"/djgpp/i586-pc-msdosdjgpp/bin/stubedit "$2" \
    runfile="`basename "$1" .exe`"
  chmod +x "$2"
}

if in_list binutils-djgpp BUILDLIST; then
  echo
  echo "***************************"
  echo "* Building DJGPP binutils *"
  echo "***************************"
  echo
  ensure_prog upx
  rm -rf build-binutils-djgpp
  mkdir build-binutils-djgpp
  pushd build-binutils-djgpp
  # Use a short program prefix "i16" to try to keep the filename component
  # unique for the first 8 characters.
  #
  # Also, to save installation space, disable support for plugins, localized
  # messages, and LTO --- for now.
  ../binutils-ia16/configure --host=i586-pc-msdosdjgpp --target=ia16-elf \
    --program-prefix=i16 --prefix="$PREFIX-djgpp" \
    --datadir="$PREFIX-djgpp"/ia16-elf \
    --infodir="$PREFIX-djgpp"/ia16-elf/info \
    --localedir="$PREFIX-djgpp"/ia16-elf/locale \
    $BINUTILSOPTS --disable-gdb --disable-libdecnumber --disable-readline \
    --disable-sim --disable-nls --disable-plugins --disable-lto 2>&1 \
    | tee build.log
  # The binutils include a facility to allow `ar' and `ranlib' to be invoked
  # as the same executable, and likewise for `objcopy' and `strip'.  However,
  # this facility is disabled in the source.  Do a hack to re-enable it.
  mkdir -p binutils
  cp ../binutils-ia16/binutils/maybe-ranlib.c binutils/is-ranlib.c
  cp ../binutils-ia16/binutils/maybe-ranlib.c binutils/not-ranlib.c
  cp ../binutils-ia16/binutils/maybe-strip.c binutils/is-strip.c
  cp ../binutils-ia16/binutils/maybe-strip.c binutils/not-strip.c
  make $PARALLEL 'CFLAGS=-s -O2' 'CXXFLAGS=-s -O2' 'BOOT_CFLAGS=-s -O2' 2>&1 \
    | tee -a build.log
  make $PARALLEL install prefix="$PREFIX-djgpp-binutils" \
    datadir="$PREFIX-djgpp-binutils"/ia16-elf \
    infodir="$PREFIX-djgpp-binutils"/ia16-elf/info \
    localedir="$PREFIX-djgpp-binutils"/ia16-elf/locale 2>&1 | tee -a build.log
  popd
  pushd "$PREFIX-djgpp-binutils"
  # Remove *ld.bfd.exe, since they seriously disagree with MS-DOS's 8.3 file
  # naming scheme.  We should not really need them anyway.
  #
  # Also remove the info hierarchy root, to avoid clashes.
  rm -f bin/i16ld.bfd.exe ia16-elf/bin/ld.bfd.exe ia16-elf/info/dir
  # Turn `ranlib' into a DJGPP-style "symbolic link" to `ar'.  Ditto for
  # `objcopy' and `strip'.  Also compress all executables in ia16-elf/bin/.
  rm -f ia16-elf/bin/ranlib.exe ia16-elf/bin/strip.exe
  upx -9 ia16-elf/bin/*.exe
  djgpp_symlink ia16-elf/bin/ar.exe ia16-elf/bin/ranlib.exe
  djgpp_symlink ia16-elf/bin/objcopy.exe ia16-elf/bin/strip.exe
  # Replace bin/i16as.exe etc. with programs that hand over to ia16-elf/bin/
  # as.exe etc.  Also compress all executables in bin/.
  rm -f bin/i16butil.exe
  for f in ar as ld nm objcopy objdump ranlib readelf strip; do
    rm -f bin/i16"$f".exe
  done
  upx -9 bin/*.exe
  i586-pc-msdosdjgpp-gcc -Os -o bin/i16butil.exe \
    ../djgpp-fdos-pkging/i16butil.c
  upx -9 bin/i16butil.exe
  for f in ar as ld nm objcopy objdump ranlib readelf strip; do
    djgpp_symlink bin/i16butil.exe bin/i16"$f".exe
  done
  popd
  # Now (really) hard-link everything into the grand unified directory.
  cp -lrf "$PREFIX-djgpp-binutils"/* "$PREFIX-djgpp"
fi

if in_list elf2elks-djgpp BUILDLIST; then
  echo
  echo "***************************"
  echo "* Building DJGPP elf2elks *"
  echo "***************************"
  echo
  ensure_prog upx
  rm -rf build-elf2elks-djgpp
  mkdir build-elf2elks-djgpp
  (cd elks && find . \! -type d -print0 | xargs -0 git ls-files --) | \
    xargs -d '\n' tar cvf - -C elks | tar xvf - -C build-elf2elks-djgpp
  pushd build-elf2elks-djgpp
  script -e -c ". env.sh && make defconfig" build.log
  script -e -c ". env.sh && cd elks/tools/elf2elks && make doclean" \
	 -a build.log
  script -e -c ". env.sh && cd elks/tools/elf2elks && \
		i586-pc-msdosdjgpp-gcc -O3 elf2elks.c -o elf2elks" -a build.log
  popd
  upx -9 -o "$PREFIX-djgpp-elf2elks/bin/elf2elks.exe" \
	 build-elf2elks-djgpp/elks/tools/bin/elf2elks
  cp -lrf "$PREFIX-djgpp-elf2elks"/* "$PREFIX-djgpp"
fi

if in_list gcc-djgpp BUILDLIST; then
  echo
  echo "******************************"
  echo "* Building stage 2 DJGPP GCC *"
  echo "******************************"
  echo
  rm -rf build-djgpp
  mkdir build-djgpp
  pushd build-djgpp
  OLDPATH=$PATH
  export PATH=$PREFIX-djgpp/bin:$PATH
  # As above, use the prefix "i16", and disable plugins, NLS, and LTO.
  #
  # Note: the switch here is --disable-plugin.  The Binutils use
  # --disable-plugins.  (!)
  ../gcc-ia16/configure --host=i586-pc-msdosdjgpp --target=ia16-elf \
    --program-prefix=i16 --with-gcc-major-version-only \
    --prefix="$PREFIX-djgpp" --datadir="$PREFIX-djgpp"/ia16-elf \
    --infodir="$PREFIX-djgpp"/ia16-elf/info \
    --localedir="$PREFIX-djgpp"/ia16-elf/locale --enable-libssp \
    --disable-libquadmath --disable-nls --disable-plugin --disable-lto \
    --enable-languages=$LANGUAGESDJGPP --with-gmp="$PREFIX-djgpp-prereqs" \
    --with-mpfr="$PREFIX-djgpp-prereqs" --with-mpc="$PREFIX-djgpp-prereqs" \
    $EXTRABUILD2OPTSDJGPP --with-isl="$PREFIX-djgpp-prereqs" 2>&1 \
    | tee build.log
  # `-Wno-narrowing' suppresses this error at configuration time (for now):
  #	"checking whether byte ordering is bigendian... unknown
  #	 configure: error: unknown endianness
  #	 presetting ac_cv_c_bigendian=no (or yes) will help"
  script -e -c "make $PARALLEL 'CFLAGS=-s -O2' \
    'CXXFLAGS=-s -O2 -Wno-narrowing' 'BOOT_CFLAGS=-s -O2' 2>&1" -a build.log
  script -e -c "make $PARALLEL install prefix='$PREFIX-djgpp-gcc' \
    datadir='$PREFIX-djgpp-gcc'/ia16-elf \
    infodir='$PREFIX-djgpp-gcc'/ia16-elf/info \
    localedir='$PREFIX-djgpp-gcc'/ia16-elf/locale" -a build.log
  popd
  pushd "$PREFIX-djgpp-gcc"
  # We do not need the copy of the GCC driver with a long name.
  rm -rf bin/ia16-elf-gcc-?.exe
  # Compress remaining executables.
  upx -9 bin/*.exe libexec/gcc/ia16-elf/?/*.exe \
	 libexec/gcc/ia16-elf/?/install-tools/*.exe
  # Give names which are more DOS-compatible to some of the user-invocable
  # programs.  Update the man pages' names too.
  if [[ ",$LANGUAGESDJGPP," = *,c++,* ]]; then
    mv bin/i16g++.exe bin/i16gxx.exe
    mv bin/i16c++.exe bin/i16cxx.exe
    djgpp_symlink bin/i16gxx.exe bin/i16cxx.exe
    mv share/man/man1/i16g++.1 share/man/man1/i16gxx.1
  fi
  # Remove the fsf-funding(7), gfdl(7), and gpl(7) man pages --- they might
  # clash with those from a host (DJGPP's) GCC installation.  And remove the
  # info hierarchy root.
  rm -f share/man/man7/fsf-funding.7 share/man/man7/gfdl.7 \
	share/man/man7/gpl.7 ia16-elf/info/dir
  popd
  export PATH=$OLDPATH
  cp -lrf "$PREFIX-djgpp-gcc"/* "$PREFIX-djgpp"
fi

if in_list redist-djgpp BUILDLIST; then
  echo
  echo "*****************************************************"
  echo "* Making redistributable DJGPP packages for FreeDOS *"
  echo "*****************************************************"
  echo
  ./redist-djgpp.sh all
fi
