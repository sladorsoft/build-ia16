This is a fork of the repo from [https://github.com/tkchia/build-ia16](https://github.com/tkchia/build-ia16) mainly focused on building the toolchain for Windows.

This is the workflow to build the ia16-elf compiler toolchain on Linux machine (tested on Ubuntu 22.04 LTS) for Windows:

         «START»
            ▾
    ./fetch.sh
            ▾
    ./build.sh clean
            ▾
    ./build.sh binutils
            ▾
    ./build.sh prereqs
            ▾
    ./build.sh gcc1
            ▾
    ./build.sh newlib
            ▾
    ./build.sh causeway
            ▾
    ./build.sh elks-libc
            ▾
    ./build.sh libi86
            ▾
    ./build.sh gcc2 ────────────────────────────┐
            ▾                                   ▾
    ./build.sh clean-windows        ./build.sh clean-win64
            ▾                                   ▾
    ./build.sh binutils-windows     ./build.sh binutils-win64
            ▾                                   ▾
    ./build.sh prereqs-windows      ./build.sh prereqs-win64
            ▾                                   ▾
    ./build.sh gcc-windows          ./build.sh gcc-win64
            ▾                                   ▾
          «END» ◂───────────────────────────────┘

### Build process
  * Follow the workflow above. You can specify multiple build stages together when running `build.sh`.  E.g., `./build.sh binutils prereqs gcc1`.
  * The easiest way to run the whole build in one command is to use either: `./build.sh all-windows` or `./build.sh all-win64` (after issuing `./fetch.sh`).
  * The 32-bit version of the toolchain will be installed in the `prefix-windows/` subdirectory.
  * The 64-bit version of the toolchain will be installed in the `prefix-win64/` subdirectory.

### Pre-compiled compiler toolchain binaries

  * A pre-compiled [binaries for Windows](https://github.com/sladorsoft/build-ia16/releases) are now available.
  * Other binaries may be found on the [original GitHub page](https://github.com/tkchia/libi86/releases) of this repo.

