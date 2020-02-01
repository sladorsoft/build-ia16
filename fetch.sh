#!/bin/sh

set -e

banner_beg="`tput bold 2>/dev/null || :`*** "
banner_end=" ***`tput sgr0 2>/dev/null || :`"

do_banner () {
    echo "$banner_beg$*$banner_end"
}

do_git_clone () {
    name="$1"
    server="$2"
    path="$3"
    do_banner "Trying to download $name Git repository using SSH"
    if git clone git@"$server":"$path" "$name"; then
	do_banner "Successfully downloaded $name"
	return 0
    fi
    do_banner "SSH failed; falling back on using HTTPS to download $name"
    if git clone https://"$server"/"$path" "$name"; then
	do_banner "Successfully downloaded $name"
	return 0
    fi
    do_banner "Could not download $name!"
    exit 1
}

do_git_clone gcc-ia16 github.com tkchia/gcc-ia16.git
do_git_clone newlib-ia16 github.com tkchia/newlib-ia16.git
do_git_clone binutils-ia16 github.com tkchia/binutils-ia16.git
do_git_clone reenigne github.com tkchia/reenigne.git
rm -f 86sim
ln -s reenigne/8088/86sim 86sim
wget https://gmplib.org/download/gmp/gmp-6.1.2.tar.bz2
tar -xjf gmp-6.1.2.tar.bz2
wget https://www.mpfr.org/mpfr-3.1.5/mpfr-3.1.5.tar.bz2
tar -xjf mpfr-3.1.5.tar.bz2
wget https://ftp.gnu.org/gnu/mpc/mpc-1.0.3.tar.gz
tar -xzf mpc-1.0.3.tar.gz
wget https://gcc.gnu.org/pub/gcc/infrastructure/isl-0.16.1.tar.bz2
tar -xjf isl-0.16.1.tar.bz2
do_git_clone libi86 gitlab.com tkchia/libi86.git  # GitLab, not GitHub
do_git_clone pdcurses github.com tkchia/PDCurses.git
do_git_clone ubasic-ia16 github.com tkchia/ubasic-ia16.git
do_git_clone tinyasm github.com tkchia/tinyasm.git
wget https://github.com/andrewwutw/build-djgpp/releases/download/v2.8/` \
  `djgpp-linux64-gcc720.tar.bz2
tar -xjf djgpp-linux64-gcc720.tar.bz2
