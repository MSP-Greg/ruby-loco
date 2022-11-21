## ruby-loco

[![ucrt](https://github.com/MSP-Greg/ruby-loco/workflows/ucrt/badge.svg)](https://github.com/MSP-Greg/ruby-loco/actions?query=workflow%3Acucrt)
[![mswin](https://github.com/MSP-Greg/ruby-loco/workflows/mswin/badge.svg)](https://github.com/MSP-Greg/ruby-loco/actions?query=workflow%3Amswin)
[![mingw](https://github.com/MSP-Greg/ruby-loco/workflows/mingw/badge.svg)](https://github.com/MSP-Greg/ruby-loco/actions?query=workflow%3Amingw)

### General

This repo creates self-contained Windows Ruby master builds (mingw, ucrt and mswin), and
saves them to the one [release](https://github.com/MSP-Greg/ruby-loco/releases/tag/ruby-master)
in the repo.  This is done three times a day.


The links for the build 7z files are:

mingw: https://github.com/MSP-Greg/ruby-loco/releases/download/ruby-master/ruby-mingw.7z

ucrt: https://github.com/MSP-Greg/ruby-loco/releases/download/ruby-master/ruby-ucrt.7z

mswin: https://github.com/MSP-Greg/ruby-loco/releases/download/ruby-master/ruby-mswin.7z

Note that if any of the Ruby test suites fail, the build will not be uploaded.
Hence, the links will provide the most recent build that passed.

The builds can be used in GitHub Actions CI by using the
[ruby/setup-ruby](https://github.com/ruby/setup-ruby/blob/master/README.md) action or the
[ruby/setup-ruby-pkgs](https://github.com/ruby/setup-ruby-pkgs/blob/master/README.md) action,
which also helps with cross-platform package installation.

The repo can be used to build Ruby locally.
See (WIP) [Local Use](https://github.com/MSP-Greg/ruby-loco/blob/master/Local-Use.md).

### Differences from Ruby CI

* Patches allow the test suites to run from the install folder, as opposed to the build folder.  'make' is not used to run any tests.

* A simple CLI test is run on all bin files to verify they work.  Both Windows & Bash
  shells are checked.

### Brief History

I started working with building and testing MSYS2/MinGW Ruby in 2016, and what could be
considered the start of ruby-loco happened in early 2017.

At first, its main purpose was to run full testing on MinGW master builds, as at the time,
that was not done in ruby/ruby.  The code was updated to create a full binary build and moved
to AppVeyor.

Today, mingw, ucrt and mswin builds are done, and are available for use with GitHUb Actions.