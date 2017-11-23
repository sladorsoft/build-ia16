#!/bin/bash

set -e
set -o pipefail

SCRIPTDIR="$(dirname "$0")"
export HERE="$(cd "$SCRIPTDIR" && pwd)"
PREFIX="$HERE/prefix"
REDIST="$HERE/redist"
PARALLEL="-j 4"
#PARALLEL=""

# Set this to false to disable C++ (speed up build a bit).
WITHCXX=true

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

declare -a BUILDLIST
BUILDLIST=()

while [ $# -gt 0 ]; do
  case "$1" in
    clean|binutils|isl|gcc1|newlib|gcc2|sim|test|extra|redist|debug|binutils-debug|clean-windows|prereqs-windows|binutils-windows|gcc-windows)
      BUILDLIST=( "${BUILDLIST[@]}" $1 )
      ;;
    all)
      BUILDLIST=("clean" "binutils" "isl" "gcc1" "newlib" "gcc2" "sim" "test" "extra" "redist" "debug" "binutils-debug" "clean-windows" "prereqs-windows" "binutils-windows" "gcc-windows")
      ;;
    *)
      echo "Unknown option '$1'."
      exit 1
      ;;
  esac
  shift
done

if [ "${#BUILDLIST}" -eq 0 ]; then
  echo "build options: clean binutils isl gcc1 newlib gcc2 sim test extra redist debug binutils-debug all clean-windows prereqs-windows binutils-windows gcc-windows"
  exit 1
fi

if $WITHCXX; then
  LANGUAGES="c,c++"
  EXTRABUILD2OPTS="--with-newlib"
else
  LANGUAGES="c"
  EXTRABUILD2OPTS=
fi

BIN=$HERE/prefix/bin
if [[ ":$PATH:" != *":$BIN:"* ]]; then
    export PATH="$BIN:${PATH:+"$PATH:"}"
    echo Path set to $PATH
fi

cd "$HERE"

if in_list clean BUILDLIST; then
  echo
  echo "************"
  echo "* Cleaning *"
  echo "************"
  echo
  rm -rf "$PREFIX" "$REDIST"
  mkdir -p "$PREFIX/bin"
fi

if in_list binutils BUILDLIST; then
  echo
  echo "*********************"
  echo "* Building binutils *"
  echo "*********************"
  echo
  rm -rf build-binutils
  mkdir build-binutils
  pushd build-binutils
  ../binutils-ia16/configure --target=ia16-elf --prefix="$PREFIX" --disable-gdb --disable-libdecnumber --disable-readline --disable-sim --disable-nls 2>&1 | tee build.log
  make $PARALLEL 2>&1 | tee -a build.log
  make $PARALLEL install 2>&1 | tee -a build.log
  popd
fi

if in_list binutils-debug BUILDLIST; then
  echo
  echo "***************************"
  echo "* Building debug binutils *"
  echo "***************************"
  echo
  rm -rf build-binutils-debug
  mkdir build-binutils-debug
  pushd build-binutils-debug
  ../binutils-ia16/configure --target=ia16-elf --prefix="$PREFIX" --disable-gdb --disable-libdecnumber --disable-readline --disable-sim --disable-nls 2>&1 | tee build.log
  make $PARALLEL 'CFLAGS=-g -O0' 'CXXFLAGS=-g -O0' 'BOOT_CFLAGS=-g -O0' 2>&1 | tee -a build.log
  make $PARALLEL install 2>&1 | tee -a build.log
  popd
fi

if in_list isl BUILDLIST; then
  echo
  echo "****************"
  echo "* Building ISL *"
  echo "****************"
  echo
  rm -rf build-isl prefix-isl
  mkdir build-isl
  pushd build-isl
  ../isl-0.16.1/configure --prefix="$PREFIX-isl" --disable-shared 2>&1 | tee build.log
  make $PARALLEL 2>&1 | tee -a build.log
  make $PARALLEL 2>&1 install | tee -a build.log
  popd
fi

if in_list gcc1 BUILDLIST; then
  echo
  echo "************************"
  echo "* Building stage 1 GCC *"
  echo "************************"
  echo
  rm -rf build
  mkdir build
  pushd build
  ../gcc-ia16/configure --target=ia16-elf --prefix="$PREFIX" --without-headers --with-newlib --enable-languages=c --disable-libssp --with-isl="$PREFIX-isl" 2>&1 | tee build.log
#--enable-checking=all,valgrind
  make $PARALLEL 2>&1 | tee -a build.log
  make $PARALLEL 2>&1 install | tee -a build.log
  popd
fi

if in_list newlib BUILDLIST; then
  echo
  echo "*****************************"
  echo "* Building Newlib C library *"
  echo "*****************************"
  echo
  rm -rf build-newlib
  mkdir build-newlib
  pushd build-newlib
  CFLAGS_FOR_TARGET='-g -O2 -mseparate-code-segment -D_IEEE_LIBM' ../newlib-ia16/configure --target=ia16-elf --prefix="$PREFIX" --disable-newlib-wide-orient --enable-newlib-nano-malloc --disable-newlib-multithread --enable-newlib-global-atexit --enable-newlib-reent-small 2>&1 | tee build.log
  make $PARALLEL 2>&1 | tee -a build.log
  make install 2>&1 | tee -a build.log
  popd
fi

if in_list gcc2 BUILDLIST; then
  echo
  echo "************************"
  echo "* Building stage 2 GCC *"
  echo "************************"
  echo
  rm -rf build2
  mkdir build2
  pushd build2
  ../gcc-ia16/configure --target=ia16-elf --prefix="$PREFIX" --disable-libssp --enable-languages=$LANGUAGES $EXTRABUILD2OPTS --with-isl="$PREFIX-isl" 2>&1 | tee build.log
  make $PARALLEL 2>&1 | tee -a build.log
  make $PARALLEL install 2>&1 | tee -a build.log
  popd
fi

if in_list sim BUILDLIST; then
  echo
  echo "*************************"
  echo "* Building simulator(s) *"
  echo "*************************"
  echo

  if [ -e 86sim/86sim.cpp ]; then
    [ -e 86sim/86sim ] && rm 86sim/86sim
    gcc -Wall -O2 86sim/86sim.cpp -o 86sim/86sim
  fi

  g++ -std=c++11 -Ireenigne/include -Wall -O2 \
    reenigne/logtools/log_filter/log_filter.cpp -o log_filter
  g++ -std=c++11 -Ireenigne/include -Wall -O2 \
    reenigne/logtools/log_compare/log_compare.cpp -o log_compare

  rm -rf build-dosemu
  mkdir build-dosemu
  pushd build-dosemu
  (cd ../dosemu && ./autogen.sh)
  ../dosemu/default-configure --prefix="$PREFIX"
  make $PARALLEL 2>&1 | tee -a build.log
  make $PARALLEL install 2>&1 | tee -a build.log
  popd
fi

if in_list test BUILDLIST; then
  echo
  echo "*****************"
  echo "* Running tests *"
  echo "*****************"
  echo
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

if in_list extra BUILDLIST; then
  echo
  echo "***********************************"
  echo "* Building extra stuff (PDCurses) *"
  echo "***********************************"
  echo
  [ -f pdcurses/.git/config ] || \
    git clone git@github.com:tkchia/PDCurses.git pdcurses
  rm -rf build-pdcurses
  mkdir build-pdcurses
  pushd build-pdcurses
  make $PARALLEL -f ../pdcurses/dos/gccdos16.mak PDCURSES_SRCDIR=../pdcurses \
    CC="$PREFIX/bin/ia16-elf-gcc" pdcurses.a 2>&1 | tee -a build.log
  cp -a pdcurses.a "$PREFIX"/ia16-elf/lib/libpdcurses.a
  cp -a ../pdcurses/curses.h "$PREFIX"/ia16-elf/include
  popd
fi

if in_list redist BUILDLIST; then
  echo
  echo "*********************************************"
  echo "* Making (somewhat) redistributable tarball *"
  echo "*********************************************"
  echo
  ./redist.sh
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
  ../gcc-ia16/configure --target=ia16-elf --prefix="$PREFIX" --disable-libssp --enable-languages=$LANGUAGES --with-as="$PREFIX/bin/ia16-elf-as" $EXTRABUILD2OPTS 2>&1 | tee build.log
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
  make $PARALLEL 2>&1 | tee -a build.log
  make $PARALLEL install 2>&1 | tee -a build.log
  popd
  rm -rf build-mpfr-windows
  mkdir build-mpfr-windows
  pushd build-mpfr-windows
  ../mpfr-3.1.5/configure --target=i686-w64-mingw32 --host=i686-w64-mingw32 --prefix="$PREFIX-prereqs" --with-gmp="$PREFIX-prereqs" --disable-shared 2>&1 | tee -a build.log
  make $PARALLEL 2>&1 | tee -a build.log
  make $PARALLEL install 2>&1 | tee -a build.log
  popd
  rm -rf build-mpc-windows
  mkdir build-mpc-windows
  pushd build-mpc-windows
  ../mpc-1.0.3/configure --target=i686-w64-mingw32 --host=i686-w64-mingw32 --prefix="$PREFIX-prereqs" --with-gmp="$PREFIX-prereqs" --with-mpfr="$PREFIX-prereqs" --disable-shared 2>&1 | tee -a build.log
  make $PARALLEL 2>&1 | tee -a build.log
  make $PARALLEL install 2>&1 | tee -a build.log
  popd
  rm -rf build-isl-windows
  mkdir build-isl-windows
  pushd build-isl-windows
  ../isl-0.16.1/configure --target=i686-w64-mingw32 --host=i686-w64-mingw32 --prefix="$PREFIX-prereqs" --disable-shared --with-gmp-prefix="$PREFIX-prereqs" 2>&1 | tee -a build.log
  make $PARALLEL 2>&1 | tee -a build.log
  make $PARALLEL install 2>&1 | tee -a build.log
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
  ../binutils-ia16/configure --host=i686-w64-mingw32 --target=ia16-elf --prefix="$PREFIX" --disable-gdb --disable-libdecnumber --disable-readline --disable-sim --disable-nls 2>&1 | tee build.log
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
  ../gcc-ia16/configure --host=i686-w64-mingw32 --target=ia16-elf --prefix="$PREFIX" --disable-libssp --enable-languages=$LANGUAGES --with-gmp="$PREFIX-prereqs" --with-mpfr="$PREFIX-prereqs" --with-mpc="$PREFIX-prereqs" $EXTRABUILD2OPTS --with-isl="$PREFIX-prereqs" 2>&1 | tee build.log
  make $PARALLEL 'CFLAGS=-s -O2' 'CXXFLAGS=-s -O2' 'BOOT_CFLAGS=-s -O2' 2>&1 | tee -a build.log
  make $PARALLEL install prefix=$PREFIX-windows 2>&1 | tee -a build.log
  export PATH=$OLDPATH
  popd
fi
