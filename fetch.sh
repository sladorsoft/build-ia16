#!/bin/sh
git clone git@github.com:tkchia/gcc-ia16.git
git clone git@github.com:tkchia/newlib-ia16.git
git clone git@github.com:crtc-demos/binutils-ia16.git
if git clone git@github.com:reenigne/reenigne.git; then
  patch -dreenigne -p1 <alfe-ubuntu.diff
  patch -dreenigne -p1 <86sim-quiet.diff
  patch -dreenigne -p1 <86sim-init.diff
  rm -f 86sim
  ln -s reenigne/8088/86sim 86sim
fi
git clone -b devel-tk git@github.com:tkchia/dosemu2.git dosemu
wget https://gmplib.org/download/gmp/gmp-6.1.2.tar.bz2
tar -xjf gmp-6.1.2.tar.bz2
wget http://www.mpfr.org/mpfr-current/mpfr-3.1.5.tar.bz2
tar -xjf mpfr-3.1.5.tar.bz2
wget https://ftp.gnu.org/gnu/mpc/mpc-1.0.3.tar.gz
tar -xzf mpc-1.0.3.tar.gz
wget https://gcc.gnu.org/pub/gcc/infrastructure/isl-0.16.1.tar.bz2
tar -xjf isl-0.16.1.tar.bz2
