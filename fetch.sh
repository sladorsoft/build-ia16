#!/bin/sh
set -e
git clone git@github.com:tkchia/gcc-ia16.git || \
    git clone https://github.com/tkchia/gcc-ia16.git
git clone git@github.com:tkchia/newlib-ia16.git || \
    git clone https://github.com/tkchia/newlib-ia16.git
git clone git@github.com:tkchia/binutils-ia16.git || \
    git clone https://github.com/tkchia/binutils-ia16.git
git clone git@github.com:tkchia/nasm-elf16-oldseg.git || \
    git clone https://github.com/tkchia/nasm-elf16-oldseg.git
if git clone git@github.com:tkchia/reenigne.git || \
   git clone https://github.com/tkchia/reenigne.git; then
  rm -f 86sim
  ln -s reenigne/8088/86sim 86sim
fi
wget https://gmplib.org/download/gmp/gmp-6.1.2.tar.bz2
tar -xjf gmp-6.1.2.tar.bz2
wget https://www.mpfr.org/mpfr-3.1.5/mpfr-3.1.5.tar.bz2
tar -xjf mpfr-3.1.5.tar.bz2
wget https://ftp.gnu.org/gnu/mpc/mpc-1.0.3.tar.gz
tar -xzf mpc-1.0.3.tar.gz
wget https://gcc.gnu.org/pub/gcc/infrastructure/isl-0.16.1.tar.bz2
tar -xjf isl-0.16.1.tar.bz2
git clone git@gitlab.com:tkchia/libi86.git || \
    git clone https://gitlab.com/tkchia/libi86.git  # GitLab, not GitHub
git clone git@github.com:tkchia/PDCurses.git pdcurses || \
    git clone https://github.com/tkchia/PDCurses.git pdcurses
git clone git@github.com:tkchia/ubasic-ia16.git || \
    git clone https://github.com/tkchia/ubasic-ia16.git
wget https://github.com/andrewwutw/build-djgpp/releases/download/v2.8/` \
  `djgpp-linux64-gcc720.tar.bz2
tar -xjf djgpp-linux64-gcc720.tar.bz2
