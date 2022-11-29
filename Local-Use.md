## Local Building Instructions

**Important Note:** ruby-loco is designed to build from the [ruby/ruby repo](https://github.com/ruby/ruby), not from
tarballs downloaded from https://www.ruby-lang.org/en/downloads/.

### Prerequisites

1. Clone or fork of this repo

2. A stand-alone Ruby in your path.

3. Git for Windows.

3. At the root of the repo, a symlink of 'ruby' to the [Ruby repo](https://github.com/ruby/ruby)
  you want to use for source.

4. At the root of the repo, a symlink of 'rubyinstaller2' to the
  [RubyInstaller2 repo](https://github.com/oneclick/rubyinstaller2) you want to use for
  source.  This provides the 'ridk' runtime files and command for mingw & ucrt builds,
  and provides the code to generate the SSL cert file used in all builds.

5. Current MSYS2 installation. Normally, this would be installed at `C:/msys64`.  The mingw
  & ucrt builds compile using the MSYS2 compiler.  The mswin build uses `bison`, which is
  a 'MSYS2' package.  Builds may also use `ragel`, which is a mingw or ucrt package.

6. **mswin only** - A Microsoft Visual Studio installation.  The path to `vcvars64.bat` should
  be added to your `local.ps1` file mentioned below. 

7. **mswin only** - mswin build uses the [Microsoft/vcpkg](https://github.com/Microsoft/vcpkg)
  system for dependency dll's.  Normally a fork/clone of the repository.  Standard location
  is `C:/vcpkg`.

### Setup

Copy the file `local.ps1.sample`, remove `.sample`, then update its contents to match your system.

MSYS2 installation info is at https://www.msys2.org/

The 'local_use' folder of this repo contains PowerShell scripts to install MSYS2
(mingw & ucrt) packages and vcpkg packages needed to build Ruby.  All must be started from
the root folder of their respective system, ie, `C:/msys64` or `C:/vcpkg`.

### Build & Test

Once the setup is done, just two simple commands from the repo root:

The below commands run make and make install, along with installing dll's, etc.  The self-contained
build is contained one of three folders: `ruby-ucrt`, `ruby-mswin`, or `ruby-mingw`,
depending on the build selected.
```
mingw or ucrt (defaults to ucrt)
./1_0_build_install_64.ps1 <mingw|ucrt> 

mswin
./1_0_build_install_mswin.ps1
```

The below command runs all test suites:
```
./2_0_test.ps1 <mingw|ucrt|mswin>
```

### Notes - General

Patches are used in both the build/install step and the test step.  When working with the
ruby/ruby repo, these should be 'cleaned' from the repo.  The patches are mainly used to
allow testing from the install folder, and some are needed in ruby lib files for testing.

Note that the patches are meant to work with ruby/ruby master, so they may not work with
older Ruby versions.

The msys2 OpenSSL package is patched to reference the cert file relative to the exe file
using it.  That is not the case for the vcpkg OpenSSL package.  Hence, the mswin build is
patched to set the related OpenSSL env variables in the build.  If you have code that
changes the env values, the original values should be restored, otherwise ssl connections
cannot be verified.
