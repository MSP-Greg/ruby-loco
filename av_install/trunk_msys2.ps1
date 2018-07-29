$orig_path = $env:path

$key = 'D688DA4A77D8FA18'
$ks1 = 'hkp://pool.sks-keyservers.net'
$ks2 = 'hkp://pgp.mit.edu'

$msys2   = 'C:\msys64'
$openssl = 'mingw-w64-x86_64-openssl-1.1.0.h-1-any.pkg.tar.xz'
$dl_uri  = 'https://dl.bintray.com/msp-greg/ruby_trunk'

$wc  = $(New-Object System.Net.WebClient)
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

$dash = "$([char]0x2015)"
$pkgs = "C:\pkgs"
$pkgs_u = $pkgs.replace('\', '/')

$env:path = "$msys2\usr\bin;C:\ruby25-x64\bin;C:\Program Files\7-Zip;C:\Program Files\AppVeyor\BuildAgent;C:\Program Files\Git\cmd;C:\Windows\system32;C:\Program Files;C:\Windows"

$pre = "mingw-w64-x86_64-"

#—————————————————————————————————————————————————————————————————————————————— Update MSYS2
Write-Host "$($dash * 63) Updating MSYS2 / MinGW" -ForegroundColor Yellow
$tools  = 'base base-devel ' + $pre + 'toolchain '
$tools += $pre + 'gcc-libs ' + $pre + 'gdbm '     + $pre + 'gmp '
$tools += $pre + 'libffi '   + $pre + 'readline ' + $pre + 'zlib'
pacman.exe -Syd --noconfirm --needed --noprogressbar $tools 2> $null

#—————————————————————————————————————————————————————————————————————————————— Update gnupg
Write-Host "$($dash * 63) Updating gnupg `& depends" -ForegroundColor Yellow
pacman.exe -Sd  --noconfirm --needed --noprogressbar bzip2 libassuan libbz2 libcurl libgcrypt libgnutls libgpg-error libiconv 2> $null
pacman.exe -Sd  --noconfirm --needed --noprogressbar libintl libksba libnpth libreadline libsqlite nettle pinentry zlib       2> $null
pacman.exe -Sd  --noconfirm --needed --noprogressbar gnupg 2> $null

#—————————————————————————————————————————————————————————————————————————————— Add GPG key
Write-Host "$($dash * 63) Adding GPG key" -ForegroundColor Yellow
Write-Host "try retrieving & signing key" -ForegroundColor Yellow

$t1 = "`"pacman-key -r $key --keyserver $ks1 && pacman-key -f $key && pacman-key --lsign-key $key`""
Appveyor-Retry bash.exe -lc $t1 2> $null
# below is for occasional key retrieve failure on Appveyor
if ($LastExitCode -and $LastExitCode -ne 0) {
  Write-Host GPG Key Lookup failed from $ks1 -ForegroundColor Yellow
  # try another keyserver
  $t1 = "`"pacman-key -r $key --keyserver $ks2 && pacman-key -f $key && pacman-key --lsign-key $key`""
  Appveyor-Retry bash.exe -lc $t1 1> $null
  if ($LastExitCode -and $LastExitCode -ne 0) {
    Write-Host GPG Key Lookup failed from $ks2 -ForegroundColor Yellow
    Update-AppveyorBuild -Message "keyserver retrieval failed"
    exit $LastExitCode
  } else { Write-Host GPG Key Lookup succeeded from $ks2 }
}   else { Write-Host GPG Key Lookup succeeded from $ks1 }

if ( !(Test-Path -Path $pkgs -PathType Container) ) {
  New-Item -Path $pkgs -ItemType Directory 1> $null
}

#—————————————————————————————————————————————————————————————————————————————— Add openssl
Write-Host "$($dash * 63) Install custom openssl" -ForegroundColor Yellow
Write-Host "Installing $openssl"
$wc.DownloadFile("$dl_uri/$openssl", "$pkgs\$openssl")
$wc.DownloadFile("$dl_uri/$openssl" + ".sig", "$pkgs\$openssl" + ".sig")

pacman.exe -Rdd --noconfirm mingw-w64-x86_64-openssl 1> $null
pacman.exe -Udd --noconfirm $pkgs_u/$openssl         1> $null
if ($LastExitCode) {
  Write-Host "Error installing openssl" -ForegroundColor Yellow
  exit 1
} else { Write-Host "Finished" }

Write-Host "$($dash * 63) MinGW Package Check" -ForegroundColor Yellow
bash -lc "pacman -Qs x86_64\.\+\(gcc\|gdbm\|openssl\) | sed -n '/^local/p' | sed 's/^local\///' | sed 's/ (.\+$//'"
Write-Host "$($dash * 83)" -ForegroundColor Yellow
$env:path = $orig_path
