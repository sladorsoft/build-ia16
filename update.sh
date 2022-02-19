#!/bin/sh

set -e

banner_beg="`tput bold 2>/dev/null || :`*** "
banner_end=" ***`tput sgr0 2>/dev/null || :`"

do_banner () {
    echo "$banner_beg$*$banner_end"
}

do_git_pull () {
    name="$1"
    if [ -d "$name" ]; then
      do_banner "Trying to pull updates from $name Git repository"
      (cd "$name" && git pull)
    else
      do_banner "No existing $name tree, not updating"
    fi
}

do_git_pull gcc-ia16
do_git_pull newlib-ia16
do_git_pull binutils-ia16
do_git_pull reenigne
do_git_pull elks
do_git_pull causeway
do_git_pull libi86
do_git_pull pdcurses
do_git_pull ubasic-ia16
do_git_pull tinyasm
