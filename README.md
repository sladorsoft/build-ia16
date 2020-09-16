(possible workflow to build compiler toolchain on Linux build machine, for Linux host and/or DJGPP/MS-DOS host)

         «START»
            ▾
    ./fetch.sh
            ▾
    ./build.sh clean ─────┐
            │             ▾
            │  ./build.sh binutils-debug
            ▾             │
    ./build.sh binutils ◂─┘
            ▾
    ./build.sh prereqs
            ▾
    ./build.sh gcc1 ◂───────────────┐
            ▾                       │
    ./build.sh newlib ────┐         │
            │             ▾         │
            │  ./build.sh elks-libc │
            │             ▾         │
            │  ./build.sh elf2elks  │
            ├◂────────────┘         │
            ▾                       │
    ./build.sh libi86 ────────────────────────────┐
            ▾                       │             ▾
    ./build.sh gcc2 ──────┐         │     ./build.sh clean-djgpp
            │             ▾         │             ▾
            │  ./build.sh extra     │     ./build.sh prereqs-djgpp
            ├◂────────────┘         │             ▾
            ├─────────────┐         │     ./build.sh binutils-djgpp
            │             ▾         │             ▾
            │  ./build.sh sim       │     ./build.sh elf2elks-djgpp
            │             ▾         │             ▾
            │  ./build.sh test ─────┘     ./build.sh gcc-djgpp
            ├◂────────────┘                       │
            ├─────────────┐                       │
            │             ▾                       ▾
            ▾  ./redist-ppa.sh all        ./redist-djgpp.sh all
          «END» ◂─────────┴◂──────────────────────┘

### Pre-compiled compiler toolchain packages

  * A pre-compiled [Ubuntu Personal Package Archive](https://launchpad.net/~tkchia/+archive/ubuntu/build-ia16/) is now available.
  * There are also binary FreeDOS packages [for the toolchain](https://github.com/tkchia/build-ia16/releases) and [for `libi86`](https://github.com/tkchia/libi86/releases).  The toolchain requires a 32-bit machine (i.e. 80386 or above), but it will produce 16-bit code.

### Further information

  * A [write-up](elf16-writeup.md) on the ELF relocation schemes implemented for IA-16 segmented addressing.
