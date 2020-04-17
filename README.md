## ruby-loco

[![mingw](https://github.com/MSP-Greg/ruby-loco/workflows/mingw/badge.svg)](https://github.com/MSP-Greg/ruby-loco/actions?query=workflow%3Amingw)
[![mswin](https://github.com/MSP-Greg/ruby-loco/workflows/mswin/badge.svg)](https://github.com/MSP-Greg/ruby-loco/actions?query=workflow%3Amswin)
[![mingw](https://ci.appveyor.com/api/projects/status/0gif1tjb4lmtoro0?svg=true)](https://ci.appveyor.com/project/MSP-Greg/ruby-loco)

### General

This repo builds self-contained Ruby master mingw and mswin binaries and saves them to the one [release](https://github.com/MSP-Greg/ruby-loco/releases/tag/ruby-master) in the repo.  This is done three times a day.

The links for the build 7z files are:

mingw build:

https://github.com/MSP-Greg/ruby-loco/releases/download/ruby-master/ruby-mingw.7z

mswin build (VS 2019):

https://github.com/MSP-Greg/ruby-loco/releases/download/ruby-master/ruby-mswin.7z

Note that if any of the Ruby test suites fail, the build will not be uploaded.  Hence, the links will provide the most recent build that passed.

The builds can be used in GitHub Actions CI by using the [ruby/setup-ruby](https://github.com/ruby/setup-ruby/blob/master/README.md) action or the [MSP-Greg/setup-ruby-pkgs](https://github.com/MSP-Greg/setup-ruby-pkgs/blob/master/README.md) action, which also helps with cross-platform package installation.

The repo can be used to build Ruby locally.  At present, only MinGW builds are supported.  See (WIP) [Local Use](https://github.com/MSP-Greg/ruby-loco/blob/master/Local-Use.md).

### Differences from Ruby CI

* Patches allow the test suites to run from the install folder, as opposed to the build folder.  'make' is not used to run any tests.

* A simple CLI test is run on all bin files to verify they work.

### Brief History

I started working with building and testing MSYS2/MinGW Ruby in 2016, and what could be considered the start of ruby-loco happened in early 2017.

At first, its main purpose was to run full testing on MinGW master builds, as at the time, that was not done in ruby/ruby.  The code was updated to create a full binary build and moved to AppVeyor.  It also began to be used for gem CI.

Recently, an mswin (msvc) build was added to allow CI testing. 

