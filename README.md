[![Build status](https://ci.appveyor.com/api/projects/status/0gif1tjb4lmtoro0?svg=true)](https://ci.appveyor.com/project/MSP-Greg/ruby-loco)

This repo contains code to build ruby trunk from a local repo using MinGW and msys2 packages.

Please see [ChangeLog](https://github.com/MSP-Greg/ruby-loco/blob/master/ChangeLog.md) for info regarding recent updates.

### Requirements, Setup and Configuration

1. An msys2/MinGW installation, with toolchain, gcc-libs, libffi, ncurses, readline, termcap, nd zlib installed.
2. A clone or fork of [oneclick/rubyinstaller2](https://github.com/oneclick/rubyinstaller2)
3. [GitHub for Windows](https://git-for-windows.github.io/).
4. Installation of the ruby-gdbm, ruby-openssl, and ruby-libyaml packages from [release v0.1](https://github.com/MSP-Greg/ruby-loco/releases/tag/v0.1).  Existing
package should be removed if they are installed.
5. A symlink named `ruby` within the `src` directory to your ruby repo.  On my system, the command is (run as admin):
```
mklink /d E:\GitHub\ruby-loco\src\ruby E:\GitHub\ruby
```

You may need to create the src dir first, not sure...

6. Since the default `Git for Windows` install path is in `Program Files`, a symlink with no spaces is needed.  I used:
```
mklink /d E:\GitHub\ruby-loco\git "C:\Program Files\Git"
```
7. The file [pkg_set_env.cmd.sample]() needs to copied/renamed to `pkg_set_env.cmd`, with all the environment variables set for your system.  I set it up to use a separate temp directory for building.  Note the path delimiters used.

#### Important Note - I have my most of my 'normal' apps and windows on my c drive, but most of my repos and development code are on my e drive.  Please make sure to adjust for that.

### Use

Before building, position the ruby repo where you would like it (branch, commit, tag, etc).  Code makes no changes to the repo.  At present, builds from 2.3 forward seem to work.

To build and run all tests, run/click [pkg_build_64.cmd](https://github.com/MSP-Greg/ruby-loco/blob/master/pkg_build_64.cmd)

To run test-all again, run [pkg_test-all_64.cmd](https://github.com/MSP-Greg/ruby-loco/blob/master/pkg_test-all_64.cmd).  It will overwrite the *test-all.log file.

A useable ruby build exists in the pkg dir.  I have used these builds to update my doc site, and installed several ruby extension gems.  See [RubyInstaller2 wiki](https://github.com/oneclick/rubyinstaller2/wiki) for information about extension gem installation.

**Important** Between builds, please make sure to reset the Ruby repo with something similar to:

```
git clean -fdx & git reset --hard HEAD
```

### Notes

This code was started based on some forks/branches of the original [oneclick/rubyinstaller](https://github.com/oneclick/rubyinstaller).

Originally, I was just building trunk.  Recently, I build the ruby_2_3 branch, and it required some changes (1.0.2 openssl package and installation dlls).  I have not (yet) created code to allow easy building of versions before 2.5.

I've got an interest in doc software (see [msp-greg.github.io/](https://msp-greg.github.io/)), so I've tried to keep code in either .cmd or .rb files, as there are a few common (deservedly rightly so) std-lib / gem items that do not doc well.

### Packages

GDBM - I believe the current msys2/mingw gdbm 1.12 package does not work.  I have tried to build 1.11, 1.12, and 1.13, to no avail.  The package used is based on 1.10.

LibYAML - some packages have a libyaml.dll file.  Mine does not, and all tests to pass.

OpenSSL - built to use the Windows CAPI engine (enable-capieng & --api=1.0.0).

### rb file info

| File                | runs in          | Desc                                                     |
| ------------------- | ---------------- | -------------------------------------------------------- |
| prepare_pre.rb      | cmd              | Loads env variables with info from repo                  |
| prepare.rb          | PKBBUILD prepare | Cleans some artifacts from src\ruby dir, applies patches, and adds bundled gems |
| install_dll_info.rb | install_post.rb  | Constants that define included dll's by ruby version     |
| install_post.rb     | PKBBUILD package | Copies dlls, creates manifest xml, modifies .exe files   |
| install_post_ri2.rb | PKBBUILD package | Copies RI2 runtime files to package                      |

### Patches

At present, all patches are located in the patches dir.  The sub dirs, 64 and 32, are used when patches differ for 32 and 64 bit builds.

1. The only patches required for building are `configure.in.patch` and `include_ruby_defines.h.patch`.

2. All other patches are for `test-all`.  Patches beginning with `segv` are intermittently needed, otherwise `test-all` silently stops.

3. If a patch file name begins with an underscore, **it is not applied**.

4. `test-runner.patch` adds several things that output info (ENV, PATH, etc) to the test-all.log file.

5. `lib-rubygems-test_case.patch` has an open PR for it.

6. `test-readline-test_readline.patch` is needed due to some issues with readline testing using temp files.

Patch code needs to be written and re-organized to allow patching based on the ruby version being built.  I haven't decided how best to set that up, given the desire to be able to easily swap patches in and out of builds...

### Thanks to...

Lars Kanis for [RubyInstaller2](https://github.com/oneclick/rubyinstaller2).  Code I've written builds and runs test-all, but all of the runtime code, the code that creates the dll manifest (and modifies the exe files to use it), and hooks extension gem build into msys2 came from his work.  Thanks again.
