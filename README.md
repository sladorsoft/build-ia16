(possible workflow to build toolchain for Linux host)

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
    ./build.sh newlib               │
            ▾                       │
    ./build.sh gcc2 ──────┐         │
            │             ▾         │
            │      ./build.sh sim   │
            │             ▾         │
            │      ./build.sh test ─┘
            ├◂────────────┘
            ├─────────────┐
            │             ▾
            │      ./build.sh extra ...
            ├◂────────────┘
            ├─────────────┐
            │             ▾
            ▾      ./redist-ppa.sh all
          «END» ◂─────────┘

A pre-compiled [Ubuntu Personal Package Archive](https://launchpad.net/~tkchia/+archive/ubuntu/build-ia16/) is now available.
