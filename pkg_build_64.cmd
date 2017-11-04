@if "%AV_BUILD%"=="true" (
  call pkg_set_env_av.cmd
  set M_JOBS=%NUMBER_OF_PROCESSORS%
) else (
  call pkg_set_env.cmd
  set M_JOBS=3
)

@TITLE pkg_build_64 %R_DATE% %R_SVN% %R_VERS%

@set ORIG_PATH=%PATH%

@set SUFFIX=%R_VERS_2%_64
@set LOG_PATH_NAME=%DP0%ruby%SUFFIX%-%R_VERS%-1-x86_64
@set PKG_RUBY=%DP0%pkg/ruby%SUFFIX%/ruby%SUFFIX%

@rem --- git in path for bundled gems with gemspec using git ls-files ?
@PATH=%MSYS2_DIR%/mingw64/bin;%GIT_PATH%;%MSYS2_DIR%/usr/bin;%PATH%
@echo on

@attrib -r %DP0%src/*.* /s /d

@rem --------------------------------------------------------------------- Build
bash.exe --login -c  "cd '%DP0%'; MINGW_INSTALLS=mingw64 makepkg-mingw --nocheck --skippgpcheck -dLf -p PKGBUILD"
@if ERRORLEVEL 1 exit
@set /a ERROR_BLD=ERRORLEVEL

@@PATH=%MSYS2_DIR%/mingw64/bin;%MSYS2_DIR%/usr/bin;%GIT_PATH%;%ORIG_PATH%

@attrib +r %PKG_RUBY%/*.* /s
@rem --- Set bin & gem folders to rw
@attrib -r %PKG_RUBY%/bin/*
@attrib -r %PKG_RUBY%/bin/*.cmd 
@attrib -r %PKG_RUBY%/bin/*.bat
@attrib -r %PKG_RUBY%/bin/*.ps1
@attrib -r %PKG_RUBY%/lib/ruby/gems/%R_VERS_INT%/*.* /s /d

@rem --- rename readline.rb so extension is used for tests (ren only works with backslashes)
@ren %~dp0pkg\ruby%SUFFIX%\ruby%SUFFIX%\lib\ruby\site_ruby\readline.rb readline.rb_

@echo.
@echo ——————————————————————————————————————————————————————————————————————————————— Running Tests

@set SSL_CERT_FILE=%PKG_RUBY%/ssl/cert.pem
@set TEST_SSL=TRUE
@set OSSL_TEST_ALL=1
@cd %DP0%src/build%SUFFIX%

@rem ------------------------------------------------------------------ test-all
@echo test-all

@make.exe test-all "TESTOPTS=-v -j%M_JOBS% --job-status=normal --show-skip --retry" > %LOG_PATH_NAME%-test-all.log 2>&1

@rem make.exe test-all "TESTOPTS=-v --show-skip" > %LOG_PATH_NAME%-test-all.log 2>&1

@rem --------------------------------------------------------- btest, test-basic
@cd %DP0%src/build%SUFFIX%
@if "%R_VERS_2%" GEQ "24" (
  @echo btest
  make.exe -j 1 "TESTOPTS=-v -j%M_JOBS%" btest      > %LOG_PATH_NAME%-test-btest.log 2>&1
  @echo test-basic
  make.exe -j 1 "TESTOPTS=-v -j%M_JOBS%" test-basic > %LOG_PATH_NAME%-test-basic.log 2>&1
) else (
  @echo test
  make.exe -j 1 "TESTOPTS=-v -j%M_JOBS%" test       > %LOG_PATH_NAME%-test.log 2>&1
)

@rem ---------------------------------------------------------------------- spec
@attrib -r %DP0%src/build%SUFFIX%/*.* /s /d

@rem just in case...
@@PATH=%MSYS2_DIR%/mingw64/bin;%MSYS2_DIR%/usr/bin;%GIT_PATH%;%ORIG_PATH%

@if "%R_VERS_2%" GEQ "25" (
  @echo test-spec
  make.exe "MSPECOPT=-j" test-spec > %LOG_PATH_NAME%-test-spec.log 2>&1
) else (
  @echo test-rubyspec
  make.exe test-rubyspec > %LOG_PATH_NAME%-test-spec.log 2>&1
)

@rem --------------------------------------------------------------------- mspec
@attrib -r %DP0%src/ruby/spec/*.* /s /d
@attrib -r %DP0%src/ruby/spec/ruby/*.* /s /d

@PATH=%PKG_RUBY%/bin;%GIT_PATH%;%ORIG_PATH%

@cd %REPO_RUBY%/spec/ruby
@echo mspec
@call ..\mspec\bin\mspec -rdevkit -j > %LOG_PATH_NAME%-test-mspec.log 2>&1

@PATH=%PKG_RUBY%/bin;%GIT_PATH%;%ORIG_PATH%

@cd %~dp0

@set R_NAME=ruby%SUFFIX%

@rem Parse spec files, add total time file, and zip
@echo.
@echo ——————————————————————————————————————————————————————————————————————————————— Build ^& Test Times
@call time_log_64.cmd

@rem --- rename readline.rb_ back to readline.rb_
@attrib -r %PKG_RUBY%/lib/ruby/site_ruby/readline.rb_
@rem --- rename seems to only work with backslashes
@ren %~dp0pkg\ruby%SUFFIX%\ruby%SUFFIX%\lib\ruby\site_ruby\readline.rb_ readline.rb
@attrib +r %PKG_RUBY%/lib/ruby/site_ruby/readline.rb

@exit /b 0
