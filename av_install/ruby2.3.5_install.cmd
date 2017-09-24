SETLOCAL

@set gdbm=mingw-w64-x86_64-gdbm-1.10-2-any.pkg.tar.xz
@set r_fn=ruby2.3.5.7z

appveyor DownloadFile https://dl.bintray.com/msp-greg/ruby_windows/%r_fn%.sig  -FileName C:\%r_fn%.sig

@echo --------------------------------------------------------------- Adding GPG key
@bash -lc "pacman-key -r 77D8FA18 && pacman-key -f 77D8FA18 && pacman-key --lsign-key 77D8FA18"

@echo --------------------------------------------------------------- Verify %r_fn%
@bash -lc "pacman-key --verify /c/%r_fn%.sig"

@echo --------------------------------------------------------------- Replacing gdbm with gdbm-1.10
appveyor DownloadFile https://dl.bintray.com/msp-greg/ruby_windows/%gdbm%     -FileName C:\%gdbm%
appveyor DownloadFile https://dl.bintray.com/msp-greg/ruby_windows/%gdbm%.sig -FileName C:\%gdbm%.sig
@pacman -Rdd --noconfirm mingw-w64-x86_64-gdbm > nul
@pacman -Udd --noconfirm --force  /c/%gdbm%    > nul

@echo --------------------------------------------------------------- MinGW Package Check
@bash -lc "pacman -Qs x86_64\.\+\(gcc\|gdbm\|openssl\) | sed -n '/^local/p' | sed 's/^local\///' | sed 's/ (.\+$//'"

ENDLOCAL
