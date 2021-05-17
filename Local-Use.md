## Local Building Instructions

### MinGW

#### Prerequisites

1. Clone or fork of this repo

2. At the root of the repo, a symlink of 'ruby' to the Ruby repo you want to use for source.

3. Current MSYS2 installation

< More to come >

#### Setup

Copy the file `local.ps1.sample`, remove `.sample`, then update its contents to match your system.

#### Build & Test

Once the setup is done, just two simple commands:

This runs make and make install
```
./1_0_build_install_64.ps1
```

This runs all test suites:
```
./2_0_test.ps1
```
