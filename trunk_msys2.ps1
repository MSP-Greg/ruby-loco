$orig_path = $env:path

$key = 'D688DA4A77D8FA18'
$ks1 = 'hkp://pool.sks-keyservers.net'
$ks2 = 'hkp://pgp.mit.edu'

$msys2   = 'C:\msys64'
# OpenSSL 1.1.1 release
$openssl = 'mingw-w64-x86_64-openssl-1.1.1-1-any.pkg.tar.xz'
$openssl_sha = '0c8be3277693f60c319f997659c2fed0eadce8535aed29a4617ec24da082b60ee30a03d3fe1024dae4461041e6e9a5e5cff1a68fa08b4b8791ea1bf7b02abc40'
$dl_uri  = 'https://ci.appveyor.com/api/projects/MSP-Greg/ruby-makepkg-mingw/artifacts'

#$openssl = 'mingw-w64-x86_64-openssl-1.1.0.i-1-any.pkg.tar.xz'
#$dl_uri  = 'https://ci.appveyor.com/api/projects/MSP-Greg/ruby-makepkg-mingw/artifacts'

$wc  = $(New-Object System.Net.WebClient)
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

$dash = "$([char]0x2015)"
$pkgs = "C:\pkgs"
$pkgs_u = $pkgs.replace('\', '/')

$env:path = "$msys2\usr\bin;C:\Ruby25-x64\bin;C:\Program Files\7-Zip;C:\Program Files\AppVeyor\BuildAgent;C:\Program Files\Git\cmd;C:\Windows\system32;C:\Program Files;C:\Windows"

$pre = "mingw-w64-x86_64-"
$fc  = 'Yellow'

#——————————————————————————————————————————————————————————————————— Check-Exit
# checks whether to exit
function Check-Exit($msg, $pop) {
  if ($LastExitCode -and $LastExitCode -ne 0) {
    if ($pop) { Pop-Location }
    Write-Host $msg -ForegroundColor $fc
    exit 1
  }
}

#——————————————————————————————————————————————————————————————————— Check_SHA
# checks SHA512 from file, script variable & Appveyor message
function Check-SHA($path, $file, $uri_dl, $sha_local) {
  $uri_bld = $uri_dl -replace '/artifacts$', ''
  $obj_bld = ConvertFrom-Json -InputObject $(Invoke-WebRequest -Uri $uri_bld)
  $job_id = $obj_bld.build.jobs[0].jobId

  $json_msgs = Invoke-WebRequest -Uri "https://ci.appveyor.com/api/buildjobs/$job_id/messages"
  $obj_msgs = ConvertFrom-Json -InputObject $json_msgs
  $sha_msg  = $($obj_msgs.list | Where {$_.message -eq $($file + '_SHA512')}).details

  $sha_file = $(CertUtil -hashfile $path\$file SHA512).split("`r`n")[1].replace(' ', '')
  if ($sha_local -ne '') {
    if (($sha_msg -eq $sha_file) -and ($sha_local -eq $sha_file)) {
      Write-Host "Three SHA512 values match for file, Appveyor message, and local script" -ForegroundColor $fc
    } else {
      Write-Host SHA512 values do not match -ForegroundColor $fc
      exit 1
    }
  } else {
    if ($sha_msg -eq $sha_file) {
      Write-Host SHA512 matches for file and Appveyor message -ForegroundColor $fc
    } else {
      Write-Host SHA512 values do not match -ForegroundColor $fc
      exit 1
    }
  }
}

#——————————————————————————————————————————————————————————————————— Update MSYS2

<#—————————————————————————————————————————————— 30-Aug-2018 Fully updated on Appveyor
# Only use below for really outdated systems, as it wil perform a full update
# for 'newer' systems...
Write-Host "$($dash * 63) Updating MSYS2 / MinGW -Syu" -ForegroundColor $fc
pacman.exe -Syu --noconfirm --needed --noprogressbar
Check-Exit 'Cannot update with -Syu'

Write-Host "$($dash * 63) Updating MSYS2 / MinGW base" -ForegroundColor $fc
# change to -Syu if above is commented out
pacman.exe -S --noconfirm --needed --noprogressbar base 2> $null
# Check-Exit 'Cannot update base'
#>

# Some issue with needing to update before toolchain.  Check whether it can move
# back to after toolchain update
#Write-Host "$($dash * 63) Updating MSYS2 / MinGW ruby depends 1" -ForegroundColor Yellow
#$tools = "___readline".replace('___', $pre)
#pacman.exe -Sy --noconfirm --needed --noprogressbar $tools.split(' ') 2> $null

Write-Host "$($dash * 63) Updating MSYS2 / MinGW toolchain" -ForegroundColor $fc
#pacman.exe -Sy --noconfirm --noprogressbar --needed $($pre + 'toolchain') 2> $null
$tools = " ___binutils ___isl ___libiconv ___mpc ___windows-default-manifest ___libwinpthread ___winpthreads  ___gcc-libs ___gcc".replace('___', $pre)
pacman.exe -Syd --noconfirm --noprogressbar --needed $tools.split(' ') 2> $null
Check-Exit 'Cannot update toolchain'

Write-Host "$($dash * 63) Updating MSYS2 / MinGW ruby depends 2" -ForegroundColor Yellow
$tools = "___gdbm ___gmp ___libffi ___libyaml ___openssl ___ragel ___readline ___zlib".replace('___', $pre)
pacman.exe -S --noconfirm --noprogressbar --needed $tools.split(' ') 2> $null
Check-Exit 'Cannot update dependencies'

# As of Sept-2018 libyaml is not installed on Appveyor
# pacman -Rdd --noconfirm mingw-w64-x86_64-libyaml

<#
#——————————————————————————————————————————————————————————————————— Add GPG key
Write-Host "$($dash * 63) Adding GPG key" -ForegroundColor Yellow
Write-Host "try retrieving & signing key" -ForegroundColor Yellow

$t1 = "`"pacman-key -r $key --keyserver $ks1 && pacman-key -f $key && pacman-key --lsign-key $key`""
Appveyor-Retry bash.exe -c $t1 2> $null
# below is for occasional key retrieve failure on Appveyor
if ($LastExitCode -and $LastExitCode -ne 0) {
  Write-Host GPG Key Lookup failed from $ks1 -ForegroundColor Yellow
  # try another keyserver
  $t1 = "`"pacman-key -r $key --keyserver $ks2 && pacman-key -f $key && pacman-key --lsign-key $key`""
  Appveyor-Retry bash.exe -c $t1 1> $null
  if ($LastExitCode -and $LastExitCode -ne 0) {
    Write-Host GPG Key Lookup failed from $ks2 -ForegroundColor Yellow
    Update-AppveyorBuild -Message "keyserver retrieval failed"
    exit $LastExitCode
  } else { Write-Host GPG Key Lookup succeeded from $ks2 }
}   else { Write-Host GPG Key Lookup succeeded from $ks1 }
#>

if ( !(Test-Path -Path $pkgs -PathType Container) ) {
  New-Item -Path $pkgs -ItemType Directory 1> $null
}

<# USE STANDARD MSYS2 1.1.1 package see line 87 ($tools = ... )
#——————————————————————————————————————————————————————————————————— Add openssl
Write-Host "$($dash * 63) Install custom openssl" -ForegroundColor Yellow
Write-Host "Installing $openssl"

$wc.DownloadFile("$dl_uri/$openssl", "$pkgs\$openssl")
#$wc.DownloadFile("$dl_uri/$openssl" + ".sig", "$pkgs\$openssl" + ".sig")
Check-SHA $pkgs $openssl $dl_uri $openssl_sha

Write-Host "pacman.exe -Rdd --noconfirm mingw-w64-x86_64-openssl" -ForegroundColor Yellow
pacman.exe -Rdd --noconfirm mingw-w64-x86_64-openssl
Write-Host "pacman.exe -Udd --noconfirm $pkgs_u/$openssl" -ForegroundColor Yellow
pacman.exe -Udd --noconfirm $pkgs_u/$openssl
if ($LastExitCode) {
  Write-Host "Error installing openssl" -ForegroundColor Yellow
  exit 1
} else { Write-Host "Finished" }
#>

Write-Host "$($dash * 63) MinGW Package Check" -ForegroundColor Yellow
bash -c "pacman -Qs x86_64\.\+\(gcc\|gdbm\|openssl\) | sed -n '/^local/p' | sed 's/^local\///' | sed 's/ (.\+$//'"
Write-Host "$($dash * 83)" -ForegroundColor Yellow
$env:path = $orig_path
