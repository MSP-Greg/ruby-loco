<# Code by MSP-Greg
Script for building & installing MinGW Ruby for CI
Assumes a Ruby exe is in path
Assumes 'Git for Windows' is installed at $env:ProgramFiles\Git
Assumes '7z             ' is installed at $env:ProgramFiles\7-Zip
For local use, set items in local.ps1
#>

#————————————————————————————————————————————————————————————————— Apply-Patches
# Applies patches
function Apply-Patches($p_dir) {
  $patch_exe = "$d_msys2/usr/bin/patch.exe"
  Push-Location "$d_repo/$p_dir"
  [string[]]$patches = Get-ChildItem -Include *.patch -Path . -Recurse |
    select -expand name
  Pop-Location
  Push-Location "$d_ruby"
  foreach ($p in $patches) {
    if ($p.substring(0,2) -eq "__") { continue }
    Write-Host $($dash * 55) $p -ForegroundColor $fc
    & $patch_exe -p1 -N --no-backup-if-mismatch -i "$d_repo/$p_dir/$p"
  }
  Pop-Location
  Write-Host ''
}

#———————————————————————————————————————————————————————————————— Print-Time-Log
function Print-Time-Log {
  $diff = New-TimeSpan -Start $script:time_start -End $script:time_old
  $script:time_info += ("{0:mm}:{0:ss} {1}" -f @($diff, "Total"))

  Write-Host $($dash * 80) -ForegroundColor $fc
  Write-Host $script:time_info
  $fn = "$d_logs/time_log_build.log"
  [IO.File]::WriteAllText($fn, $script:time_info, $UTF8)
  if ($is_av) {
    Add-AppveyorMessage -Message "Time Log Build" -Details $script:time_info
  }
}

#—————————————————————————————————————————————————————————————————————— Time-Log
function Time-Log($msg) { 
  if ($script:time_old) {
    $time_new = Get-Date
    $diff = New-TimeSpan -Start $time_old -End $time_new
    $script:time_old = $time_new
    $script:time_info += ("{0:mm}:{0:ss} {1}`n" -f @($diff, $msg))
  } else {
    $script:time_old   = Get-Date
    $script:time_start = $script:time_old
  }
}

#———————————————————————————————————————————————————————————————————— Basic Info
function Basic-Info {
  $env:path = "$d_install/bin;$base_path"
  Write-Host $($dash * 80) -ForegroundColor $fc
  ruby -v
  bundle version
  ruby -ropenssl -e "puts OpenSSL::OPENSSL_LIBRARY_VERSION"
  Write-Host "gem --version" $(gem --version)
  rake -V
  Write-Host "$($dash * 80)`n" -ForegroundColor $fc
}

#———————————————————————————————————————————————————————————————————— Check-Exit
# checks whether to exit
function Check-Exit($msg, $pop) {
  if ($LastExitCode -and $LastExitCode -ne 0) {
    if ($pop) { Pop-Location }
    Write-Line "Failed - $msg" -ForegroundColor $fc
    exit 1
  }
}

#———————————————————————————————————————————————————————————————— Create-Folders
# creates build, install, log, and git folders at same place as ruby repo folder
# most of the code is for local builds, as the folders should be cleaned

function Create-Folders {
  # reset to read/write
  (Get-Item $d_repo).Attributes = 'Normal'

  # create (or clean) build & install
  if (Test-Path -Path $d_build   -PathType Container ) {
    Remove-Read-Only  $d_build
    Remove-Item -Path $d_build   -Recurse
  }

  if (Test-Path -Path $d_install -PathType Container ) {
    Remove-Read-Only  $d_install
    Remove-Item -Path $d_install -Recurse
  }

  # Don't erase contents of log folder
  if (Test-Path -Path $d_logs    -PathType Container ) {
    Remove-Read-Only  $d_logs
  } else {
    New-Item    -Path $d_logs    -ItemType Directory 1> $null
  }

  # create git symlink, which RubyGems seems to want
  if (!(Test-Path -Path $d_repo/git -PathType Container )) {
        New-Item  -Path $d_repo/git -ItemType Junction -Value $d_git 1> $null
  }

  New-Item -Path $d_build   -ItemType Directory 1> $null
  New-Item -Path $d_install -ItemType Directory 1> $null
}

#——————————————————————————————————————————————————————————————————————————— Run
# Run a command and check for error
function Run($exec, $silent = $false) {
  Write-Line "$exec"
  if ($silent) { iex $exec -ErrorAction SilentlyContinue }
  else         { iex $exec }
  Check-Exit $exec
}

#——————————————————————————————————————————————————————————————————— Strip-Build
# Strips dll & so files in build folder
function Strip-Build {
  Push-Location $d_build
  $strip = "$d_mingw/strip.exe"

  [string[]]$dlls = Get-ChildItem -Include *.dll -Recurse |
    select -expand fullname
  foreach ($dll in $dlls) {
    Set-ItemProperty -Path $dll -Name IsReadOnly -Value $false
    $t = $dll.replace('\', '/')
    &$strip --strip-unneeded $t
  }

  [string[]]$exes = Get-ChildItem -Path ./*.exe |
    select -expand fullname
  foreach ($exe in $exes) {
    Set-ItemProperty -Path $exe -Name IsReadOnly -Value $false
    $t = $exe.replace('\', '/')
    &$strip --strip-all $t
  }

  $d_so = "$d_build/.ext/$rarch"

  [string[]]$sos = Get-ChildItem -Include *.so -Path $d_so -Recurse |
    select -expand fullname
  foreach ($so in $sos) {
    Set-ItemProperty -Path $so -Name IsReadOnly -Value $false
    $t = $so.replace('\', '/')
    &$strip --strip-unneeded $t
  }
  $msg = "Build:   Stripped {0,2} dll files, {1,2} exe files, and {2,3} so files" -f `
    @($dlls.length, $exes.length, $sos.length)
  Write-Host $($dash * 80) -ForegroundColor $fc
  Write-Host $msg
  Pop-Location
}

#————————————————————————————————————————————————————————————————— Strip-Install
# Strips dll & so files in install folder
function Strip-Install {
  Push-Location $d_install
  $strip = "$d_mingw/strip.exe"

  $d_bin = "$d_install/bin"

  [string[]]$dlls = Get-ChildItem -Path ./bin/*.dll |
    select -expand fullname
  foreach ($dll in $dlls) {
    Set-ItemProperty -Path $dll -Name IsReadOnly -Value $false
    $t = $dll.replace('\', '/')
    &$strip --strip-unneeded $t
  }

  [string[]]$exes = Get-ChildItem -Path ./bin/*.exe |
    select -expand fullname
  foreach ($exe in $exes) {
    Set-ItemProperty -Path $exe -Name IsReadOnly -Value $false
    $t = $exe.replace('\', '/')
    &$strip --strip-all $t
  }

  $abi = ruby.exe -e "print RbConfig::CONFIG['ruby_version']"
  $d_so = "$d_install/lib/ruby/$abi/$rarch"

  [string[]]$sos = Get-ChildItem -Include *.so -Path $d_so -Recurse |
    select -expand fullname
  foreach ($so in $sos) {
    Set-ItemProperty -Path $so -Name IsReadOnly -Value $false
    $t = $so.replace('\', '/')
    &$strip --strip-unneeded $t
  }

  $msg = "Install: Stripped {0,2} dll files, {1,2} exe files, and {2,3} so files" -f `
    @($dlls.length, $exes.length, $sos.length)
  Write-Host $($dash * 80) -ForegroundColor $fc
  Write-Host $msg
  Pop-Location
}

#————————————————————————————————————————————————————————————————— Set-Variables
# set base variables, including MSYS2 location and bit related varis
function Set-Variables-Local {
  $script:ruby_path = $(ruby.exe -e "puts RbConfig::CONFIG['bindir']").trim().replace('\', '/')
  $script:time_info = ''
  $script:time_old  = $null
  $script:time_start = $null
}

#——————————————————————————————————————————————————————————————————————— Set-Env
# Set ENV, including gcc flags
function Set-Env {
  $env:path = "$ruby_path;$d_mingw;$d_repo/git/cmd;$d_msys2/usr/bin;$base_path"

  # used in Ruby scripts
  $env:D_MSYS2  = $d_msys2

  $env:CFLAGS   = "-march=$march -mtune=generic -O3 -pipe"
  $env:CXXFLAGS = "-march=$march -mtune=generic -O3 -pipe"
  $env:CPPFLAGS = "-D_FORTIFY_SOURCE=2 -D__USE_MINGW_ANSI_STDIO=1 -DFD_SETSIZE=2048"
  $env:LDFLAGS  = "-pipe"
}

#——————————————————————————————————————————————————————————————————— start build
# defaults to 64 bit
$script:bits = if ($args.length -eq 1 -and $args[0] -eq 32) { 32 } else { 64 }

cd $PSScriptRoot

. ./0_common.ps1
Set-Variables
Set-Variables-Local
Set-Env

Apply-Patches "patches"

Create-Folders

cd $d_repo
ruby 1_1_pre_build.rb 64

cd $d_ruby
Run "sh -c `"autoreconf -fi`""

cd $d_build
Time-Log "start"

$config_args = "--build=$chost --host=$chost --target=$chost --with-out-ext=pty,syslog"
Run "sh -c `"../ruby/configure --disable-install-doc --prefix=/$install $config_args`""
Time-Log "configure"

# download gems & unicode files
Run "$make -j$jobs update-unicode"
Run "$make -j$jobs update-gems"
Time-Log "$make -j$jobs update-unicode, $make -j$jobs update-gems"

# below sets some directories to normal in case they're set to read-only
Remove-Read-Only $d_ruby
Remove-Read-Only $d_build

Run "$make -j$jobs 2>&1" $true
Time-Log "$make -j$jobs"

# Run "$make -f GNUMakefile DESTDIR=$d_repo_u install-nodoc"
Run "$make DESTDIR=$d_repo_u install-nodoc"
Time-Log "$make install"

cd $d_repo

# run with old ruby
ruby 1_2_post_install.rb $bits $install

# run with new ruby (gem install, exc)
$env:path = "$d_install/bin;$d_mingw;$d_repo/git/cmd;$d_msys2/usr/bin;$base_path"
ruby 1_3_post_install.rb $bits $install
Time-Log "post install processing"

Strip-Build
Strip-Install
Time-Log "strip build & install binary files"

Print-Time-Log
Basic-Info

# save extension build files
Push-Location $d_build/ext
$build_files = "$d_zips/ext_build_files.7z"
&$7z a $build_files **/Makefile **/*.h **/*.log **/*.mk 1> $null
if ($is_av) { Push-AppveyorArtifact $build_files -DeploymentName "Ext build files" }
Pop-Location

# apply patches for testing
Apply-Patches "patches_basic_boot"
Apply-Patches "patches_spec"
Apply-Patches "patches_test"
