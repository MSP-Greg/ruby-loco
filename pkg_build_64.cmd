@set BITS=64

@if "%AV_BUILD%"=="true" (
  call pkg_set_env_av.cmd
  set M_JOBS=%NUMBER_OF_PROCESSORS%
) else (
  call pkg_set_env.cmd
  set M_JOBS=3
)

@TITLE pkg_build_64 %R_DATE% %R_SVN% %R_VERS%

@set SUFFIX=%R_VERS_2%_64
@set LOG_PATH_NAME=%DP0%ruby%SUFFIX%-%R_VERS%-1-x86_64
@set PKG_RUBY=%DP0%pkg/ruby%SUFFIX%

@rem --- git in path for bundled gems with gemspec using git ls-files ?
@PATH=%MSYS2_DIR%/mingw64/bin;%GIT_PATH%;%MSYS2_DIR%/usr/bin;%base_path%
@echo on

@attrib -r %DP0%src/*.* /s /d

@ren C:\Windows\System32\libssl-1_1-x64.dll    libssl-1_1-x64.dll_ 
@ren C:\Windows\System32\libcrypto-1_1-x64.dll libcrypto-1_1-x64.dll_

@rem ————————————————————————————————————————————————————————————————————— Build
bash.exe -c  "cd '%DP0%'; MINGW_INSTALLS=mingw64 makepkg-mingw --nocheck --skippgpcheck -dLf -p PKGBUILD"
@echo ———————————————————————————————————————————————————————————————————————————————
@set /a ERROR_BLD=%ERRORLEVEL%

@cd %DP0%src/build%SUFFIX%/ext
@7z.exe a ../../../ext_build_files.7z **/Makefile **/*.h **/*.log **/*.mk
@cd %DP0%
@if "%AV_BUILD%"=="true" ( appveyor PushArtifact ext_build_files.7z )

@if %ERROR_BLD% NEQ 0 (
  cd %DP0%src/build%SUFFIX%/.ext/x64-mingw32
  7z.exe a ../../../../ext_so_files.7z *.so **/*.so
  dir *.so
  cd %DP0%

  if "%AV_BUILD%"=="true" ( appveyor PushArtifact ext_so_files.7z )
  exit %ERROR_BLD%
)

@@PATH=%MSYS2_DIR%/mingw64/bin;%MSYS2_DIR%/usr/bin;%GIT_PATH%;%base_path%

@attrib +r %PKG_RUBY%/*.* /s
@rem --- Set bin & gem folders to rw
@attrib -r %PKG_RUBY%/bin/*
@attrib -r %PKG_RUBY%/bin/*.cmd 
@attrib -r %PKG_RUBY%/bin/*.bat
@attrib -r %PKG_RUBY%/bin/*.ps1
@attrib -r %PKG_RUBY%/lib/ruby/gems/%R_VERS_INT%/*.* /s /d

@rem --- rename readline.rb so extension is used for tests (ren only works with backslashes)
@ren %~dp0pkg\ruby%SUFFIX%\lib\ruby\site_ruby\readline.rb readline.rb_

@echo.
@echo ——————————————————————————————————————————————————————————————————————————————— Running Tests

@set SSL_CERT_FILE=%PKG_RUBY%/ssl/cert.pem
@set TEST_SSL=TRUE

@if "%R_VERS_2%" GEQ "25" ( set RUBY_FORCE_TEST_JIT=1 )

@rem ————————————————————————————————————————————————————————— btest, test-basic

@PATH=%PKG_RUBY%/bin;%MSYS2_DIR%/mingw64/bin;%MSYS2_DIR%/usr/bin;%GIT_PATH%;%base_path%

@if "%R_VERS_2%" GEQ "24" (
  @echo btest
  @cd %DP0%src/ruby/bootstraptest
  @ruby -v runner.rb --ruby=%PKG_RUBY%/bin/ruby.exe -v > %LOG_PATH_NAME%-test-btest.log 2>&1

  @echo test-basic
  @cd %DP0%src/build%SUFFIX%
  make.exe "TESTOPTS=-v -j%M_JOBS%" test-basic > %LOG_PATH_NAME%-test-basic.log 2>&1
) else (
  @echo test
  @cd %DP0%src/build%SUFFIX%
  make.exe "TESTOPTS=-v -j%M_JOBS%" test       > %LOG_PATH_NAME%-test.log 2>&1
)

@rem —————————————————————————————————————————————————————————————————————— spec
@attrib -r %DP0%src/build%SUFFIX%/*.* /s /d

@rem just in case...
@PATH=%MSYS2_DIR%/mingw64/bin;%MSYS2_DIR%/usr/bin;%GIT_PATH%;%base_path%

@if "%R_VERS_2%" GEQ "25" (
  @echo test-spec
  make.exe "MSPECOPT=-j" test-spec > %LOG_PATH_NAME%-test-spec.log 2>&1
) else (
  @echo test-rubyspec
  make.exe test-rubyspec > %LOG_PATH_NAME%-test-spec.log 2>&1
)

@rem ————————————————————————————————————————————————————————————————————— mspec
@attrib -r %DP0%src/ruby/spec/*.* /s /d
@attrib -r %DP0%src/ruby/spec/ruby/*.* /s /d

@PATH=%PKG_RUBY%/bin;%MSYS2_DIR%/mingw64/bin;%MSYS2_DIR%/usr/bin;%GIT_PATH%;%base_path%

@cd %REPO_RUBY%/spec/ruby
@echo mspec
@call ..\mspec\bin\mspec -rdevkit -j > %LOG_PATH_NAME%-test-mspec.log 2>&1

@rem —————————————————————————————————————————————————————————————————— test-all
@cd %DP0%src/build%SUFFIX%

@rem just in case...
@PATH=%MSYS2_DIR%/mingw64/bin;%MSYS2_DIR%/usr/bin;%GIT_PATH%;%base_path%

@echo test-all

@if "%R_VERS_2%" GEQ "25" (
  set RUBY_FORCE_TEST_JIT=1
  make test-all "TESTOPTS=-a -j%M_JOBS% --job-status=normal --show-skip --retry --subprocess-timeout-scale=1.5" > %LOG_PATH_NAME%-test-all.log 2>&1
@rem  timeout.exe 25m make test-all "TESTOPTS=--verbose -j%M_JOBS% --job-status=normal --show-skip --retry --subprocess-timeout-scale=1.5"
) else (
  make.exe test-all "TESTOPTS=-v --show-skip --retry" > %LOG_PATH_NAME%-test-all.log 2>&1
)

@rem ————————————————————————————————————————————————————————————————————— done with tests

@PATH=%PKG_RUBY%/bin;%GIT_PATH%;%base_path%

@cd %~dp0

@set R_NAME=ruby%SUFFIX%

@rem Parse spec files, add total time file, and zip
@echo.
@call time_log_64.cmd

@if "%AV_BUILD%" NEQ "true" ( ruby test_script.rb )

@rem --- rename readline.rb_ back to readline.rb
@attrib -r %PKG_RUBY%/lib/ruby/site_ruby/readline.rb_
@rem --- rename seems to only work with backslashes
@ren %~dp0pkg\ruby%SUFFIX%\lib\ruby\site_ruby\readline.rb_ readline.rb
@attrib +r %PKG_RUBY%/lib/ruby/site_ruby/readline.rb

@ren C:\Windows\System32\libssl-1_1-x64.dll_    libssl-1_1-x64.dll
@ren C:\Windows\System32\libcrypto-1_1-x64.dll_ libcrypto-1_1-x64.dll

@exit /b 0
