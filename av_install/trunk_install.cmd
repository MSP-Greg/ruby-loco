SETLOCAL

@set ORIG_PATH_1=%PATH%
@PATH=C:\msys64\usr\bin;C:\ruby24-x64\bin;C:\Program Files\7-Zip;C:\Program Files\AppVeyor\BuildAgent;C:\Program Files\Git\cmd;C:\Windows\system32;C:\Program Files;C:\Windows

@set    gdbm=mingw-w64-x86_64-gdbm-1.10-2-any.pkg.tar.xz
@set openssl=mingw-w64-x86_64-openssl-1.1.0.h-1-any.pkg.tar.xz
@set    r_fn=ruby_trunk.7z

@echo --------------------------------------------------------------- Adding GPG key
@bash -lc "pacman-key -r 77D8FA18 --keyserver na.pool.sks-keyservers.net && pacman-key -f 77D8FA18 && pacman-key --lsign-key 77D8FA18"

@echo --------------------------------------------------------------- Verify %r_fn%
appveyor DownloadFile https://dl.bintray.com/msp-greg/ruby_windows/%r_fn%.sig  -FileName C:\%r_fn%.sig
@bash -lc "pacman-key --verify /c/%r_fn%.sig"

@echo --------------------------------------------------------------- Replacing gdbm with gdbm-1.10
appveyor DownloadFile https://dl.bintray.com/msp-greg/ruby_windows/%gdbm%     -FileName C:\%gdbm%
appveyor DownloadFile https://dl.bintray.com/msp-greg/ruby_windows/%gdbm%.sig -FileName C:\%gdbm%.sig
@pacman -Rdd --noconfirm mingw-w64-x86_64-gdbm > nul
@pacman -Udd --noconfirm --force  /c/%gdbm%    > nul

@echo --------------------------------------------------------------- Replacing openssl with openssl-1.1.0
appveyor DownloadFile https://dl.bintray.com/msp-greg/ruby_windows/%openssl%     -FileName C:\%openssl%
appveyor DownloadFile https://dl.bintray.com/msp-greg/ruby_windows/%openssl%.sig -FileName C:\%openssl%.sig
@pacman -Rdd --noconfirm mingw-w64-x86_64-openssl > nul
@pacman -Udd --noconfirm --force /c/%openssl%     > nul

@echo --------------------------------------------------------------- MinGW Package Check
@bash -lc "pacman -Qs x86_64\.\+\(gcc\|gdbm\|openssl\) | sed -n '/^local/p' | sed 's/^local\///' | sed 's/ (.\+$//'"

@PATH=%ORIG_PATH_1%
ENDLOCAL
