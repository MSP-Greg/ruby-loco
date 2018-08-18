@echo off

set DP0=%~dp0
set DP0=%DP0:\=/%

set MSYS2_DIR=C:/msys64
set MSYS2_DIR_U=/c/msys64

set build_path=/c/projects/ruby-loco
set RUBY=/c/Ruby25-x64/bin/ruby.exe
set RUBY_OPATH=/c/Ruby25-x64/bin

set GIT=%DP0%git/cmd/git.exe
set GIT_PATH=%DP0%git/cmd
set GIT_PATH_SH=/c/projects/ruby-loco/git/cmd

set REPO_RI2=C:/ri2
set REPO_RB-RL=C:/rb-readline
set REPO_RUBY=%DP0%src/ruby
set REPO_SPEC=C:/spec
set REPO_MSPEC=C:/mspec

@PATH=C:/Ruby25-x64/bin;%MSYS2_DIR%/mingw64/bin;%GIT_PATH%;%MSYS2_DIR%/usr/bin;%base_path%

@rem below is shared by many cmd files, no changes required

for /F "tokens=1-7 delims= " %%G in ('ruby prepare_pre.rb') do (
@set R_VERS=%%G
@set R_PATCH=%%H
@set R_DATE=%%I
@set R_SVN=%%J
@set R_VERS_INT=%%K
@set R_VERS_2=%%L
@set R_BRANCH=%%M
)

@echo —————————————————————————————————————————————————————————————————————— Ruby version ENV variables
@echo R_VERS      %R_VERS%
@echo R_PATCH     %R_PATCH%
@echo R_DATE      %R_DATE%
@echo R_SVN       %R_SVN%
@echo R_VERS_INT  %R_VERS_INT%
@echo R_VERS_2    %R_VERS_2%
@echo R_BRANCH    %R_BRANCH%
@echo.
@echo GIT         %GIT%
@echo GIT_PATH    %GIT_PATH%
@echo GIT_PATH_SH %GIT_PATH_SH%
@echo JOBS        %NUMBER_OF_PROCESSORS%
@echo.
