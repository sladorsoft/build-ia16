(possible workflow to build toolchain on Linux build machine, for Linux host and/or DJGPP/MS-DOS host)

         «START»
            ▾
    ./fetch.sh
            ▾
    ./build.sh clean ─────┐
            │             ▾
            │      ./build.sh binutils-debug
            ▾             │
    ./build.sh binutils ◂─┘
            ▾
    ./build.sh isl
            ▾
    ./build.sh gcc1 ◂───────────────┐
            ▾                       │
    ./build.sh newlib ────────────────────────────┐
            ▾                       │             ▾
    ./build.sh gcc2 ──────┐         │     ./build.sh clean-djgpp
            │             ▾         │             ▾
            │      ./build.sh sim   │     ./build.sh prereqs-djgpp
            │             ▾         │             ▾
            │      ./build.sh test ─┘     ./build.sh binutils-djgpp
            ├◂────────────┘                       ▾
            ├─────────────┐               ./build.sh gcc-djgpp
            │             ▾                       │
            │      ./build.sh extra ...           │
            ├◂────────────┘                       │
            ├─────────────┐                       │
            │             ▾                       ▾
            ▾      ./redist-ppa.sh all    ./redist-djgpp.sh
          «END» ◂─────────┴◂──────────────────────┘

A pre-compiled [Ubuntu Personal Package Archive](https://launchpad.net/~tkchia/+archive/ubuntu/build-ia16/) is now available.
