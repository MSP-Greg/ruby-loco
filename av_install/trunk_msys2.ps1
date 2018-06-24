$orig_path = $env:path

$key = '77D8FA18'
$ks1 = 'hkp://pool.sks-keyservers.net'
$ks2 = 'hkp://pgp.mit.edu'

$msys2   = 'C:\msys64'
$gdbm    = 'mingw-w64-x86_64-gdbm-1.10-2-any.pkg.tar.xz'
$openssl = 'mingw-w64-x86_64-openssl-1.1.0.h-1-any.pkg.tar.xz'
$dl_uri  = 'https://dl.bintray.com/msp-greg/ruby_trunk'

$wc  = $(New-Object System.Net.WebClient)
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

$dash = "$([char]0x2015)"
$pkgs = "C:\pkgs"
$pkgs_u = $pkgs.replace('\', '/')

$env:path = "$msys2\usr\bin;C:\ruby25-x64\bin;C:\Program Files\7-Zip;C:\Program Files\AppVeyor\BuildAgent;C:\Program Files\Git\cmd;C:\Windows\system32;C:\Program Files;C:\Windows"

#—————————————————————————————————————————————————————————————————————————————— Update MSYS2
Write-Host "$($dash * 63) Updating MSYS2 / MinGW" -ForegroundColor Yellow
$tools  = 'base-devel mingw-w64-x86_64-toolchain'
$tools += ' mingw-w64-x86_64-gcc-libs mingw-w64-x86_64-gmp mingw-w64-x86_64-libffi mingw-w64-x86_64-zlib'
iex "pacman.exe -Sy --noconfirm --needed $tools" 2> $null

#—————————————————————————————————————————————————————————————————————————————— Add GPG key
Write-Host "$($dash * 63) Adding GPG key" -ForegroundColor Yellow
$t1 = "pacman-key -r $key --keyserver $ks1 && pacman-key -f $key && pacman-key --lsign-key $key"
bash.exe -lc $t1 2> $null
$exit_code = $LastExitCode
# below is for occasional key retrieve failure on Appveyor
if ($exit_code) {
  Write-Host GPG Key Lookup failed from $ks1
  # try another keyserver
  $t1 = "pacman-key -r $key --keyserver $ks2 && pacman-key -f $key && pacman-key --lsign-key $key"
  bash.exe -lc $t1 2> $null
  $exit_code = $LastExitCode
  if ($exit_code) {
    Write-Host GPG Key Lookup failed from $ks2
    exit $exit_code
  }
  Write-Host "Added key $key"
}

if ( !(Test-Path -Path $pkgs -PathType Container) ) {
  New-Item -Path $pkgs -ItemType Directory 1> $null
}

#—————————————————————————————————————————————————————————————————————————————— Add gdbm & openssl
Write-Host "$($dash * 63) Install gdbm & openssl" -ForegroundColor Yellow
Write-Host "Installing $gdbm"
$wc.DownloadFile("$dl_uri/$gdbm", "$pkgs\$gdbm")
$wc.DownloadFile("$dl_uri/$gdbm" + ".sig", "$pkgs\$gdbm" + ".sig")

#pacman.exe -Rdd --noconfirm mingw-w64-x86_64-gdbm  1> $null
pacman.exe -Udd --noconfirm $pkgs_u/$gdbm            1> $null
if ($LastExitCode) {
  Write-Host "Error installing gdbm" -ForegroundColor Yellow
  exit 1
} else { Write-Host "Finished" }

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
