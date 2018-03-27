@SETLOCAL

@set ORIG_PATH_1=%PATH%
@PATH=C:\msys64\usr\bin;C:\ruby24-x64\bin;C:\Program Files\7-Zip;C:\Program Files\AppVeyor\BuildAgent;C:\Program Files\Git\cmd;C:\Windows\system32;C:\Program Files;C:\Windows

@echo ——————————————————————————————————————————————————————————————— Updating MSYS2 / MinGW
@pacman -Sy --noconfirm --needed mingw-w64-x86_64-toolchain mingw-w64-x86_64-gcc-libs mingw-w64-x86_64-gmp mingw-w64-x86_64-libffi mingw-w64-x86_64-zlib

@set    gdbm=mingw-w64-x86_64-gdbm-1.10-2-any.pkg.tar.xz
@set openssl=mingw-w64-x86_64-openssl-1.1.0.h-1-any.pkg.tar.xz
@set  dl_uri=https://dl.bintray.com/msp-greg/ruby_trunk

@echo ——————————————————————————————————————————————————————————————— Adding GPG key
@bash -lc "pacman-key -r 77D8FA18 --keyserver na.pool.sks-keyservers.net && pacman-key -f 77D8FA18 && pacman-key --lsign-key 77D8FA18"

@md C:\pkgs

@echo ——————————————————————————————————————————————————————————————— Installing gdbm-1.10
appveyor DownloadFile %dl_uri%/%gdbm%     -FileName C:\pkgs\%gdbm%
appveyor DownloadFile %dl_uri%/%gdbm%.sig -FileName C:\pkgs\%gdbm%.sig
@pacman -Rdd --noconfirm mingw-w64-x86_64-gdbm   > nul
@pacman -Udd --noconfirm --force  /c/pkgs/%gdbm% > nul

@echo ——————————————————————————————————————————————————————————————— Installing openssl-1.1.0
appveyor DownloadFile %dl_uri%/%openssl%     -FileName C:\pkgs\%openssl%
appveyor DownloadFile %dl_uri%/%openssl%.sig -FileName C:\pkgs\%openssl%.sig
@pacman -Rdd --noconfirm mingw-w64-x86_64-openssl  > nul
@pacman -Udd --noconfirm --force /c/pkgs/%openssl% > nul

@echo ——————————————————————————————————————————————————————————————— MinGW Package Check
@bash -lc "pacman -Qs x86_64\.\+\(gcc\|gdbm\|openssl\) | sed -n '/^local/p' | sed 's/^local\///' | sed 's/ (.\+$//'"

@PATH=%ORIG_PATH_1%
@ENDLOCAL
