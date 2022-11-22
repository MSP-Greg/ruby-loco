<# Code by MSP-Greg
Script for building & installing MinGW Ruby for CI
Assumes a Ruby exe is in path
Assumes 'Git for Windows' is installed at $env:ProgramFiles\Git
Assumes '7z             ' is installed at $env:ProgramFiles\7-Zip
For local use, set items in local.ps1
#>

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
    &$strip -Dp --strip-unneeded $t
  }

  [string[]]$exes = Get-ChildItem -Path ./*.exe |
    select -expand fullname
  foreach ($exe in $exes) {
    Set-ItemProperty -Path $exe -Name IsReadOnly -Value $false
    $t = $exe.replace('\', '/')
    &$strip -Dp --strip-all $t
  }

  $d_so = "$d_build/.ext/$rarch"

  [string[]]$sos = Get-ChildItem -Include *.so -Path $d_so -Recurse |
    select -expand fullname
  foreach ($so in $sos) {
    Set-ItemProperty -Path $so -Name IsReadOnly -Value $false
    $t = $so.replace('\', '/')
    &$strip -Dp --strip-unneeded $t
  }
  $msg = "Build:   Stripped {0,2} dll files, {1,2} exe files, and {2,3} so files" -f `
    @($dlls.length, $exes.length, $sos.length)
  EchoC $dash_line yel
  echo $msg
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
    &$strip -Dp --strip-unneeded $t
  }

  [string[]]$exes = Get-ChildItem -Path ./bin/*.exe |
    select -expand fullname
  foreach ($exe in $exes) {
    Set-ItemProperty -Path $exe -Name IsReadOnly -Value $false
    $t = $exe.replace('\', '/')
    &$strip -Dp --strip-all $t
  }

  $abi = ruby.exe -e "print RbConfig::CONFIG['ruby_version']"
  $d_so = "$d_install/lib/ruby/$abi/$rarch"

  [string[]]$sos = Get-ChildItem -Include *.so -Path $d_so -Recurse |
    select -expand fullname
  foreach ($so in $sos) {
    Set-ItemProperty -Path $so -Name IsReadOnly -Value $false
    $t = $so.replace('\', '/')
    &$strip -Dp --strip-unneeded $t
  }

  $msg = "Install: Stripped {0,2} dll files, {1,2} exe files, and {2,3} so files" -f `
    @($dlls.length, $exes.length, $sos.length)
  EchoC $dash_line yel
  echo $msg
  Pop-Location
}

#————————————————————————————————————————————————————————————————— Set-Variables-Local
# set variables only used in this script
function Set-Variables-Local {
  $script:ruby_path = $(ruby.exe -e "puts RbConfig::CONFIG['bindir']").trim().replace('\', '/')
  $script:time_info = ''
  $script:time_old  = $null
  $script:time_start = $null
}

#——————————————————————————————————————————————————————————————————————— Set-Env
# Set ENV, including gcc flags
function Set-Env {
  $env:Path = "$ruby_path;$d_mingw;$d_repo/git/cmd;$d_msys2/usr/bin;$base_path"

  # used in Ruby scripts
  $env:D_MSYS2  = $d_msys2

  $env:MSYS_NO_PATHCONV = 1

  $env:CFLAGS   = "-march=$march -mtune=generic -O3 -pipe -fstack-protector-strong"
  $env:CXXFLAGS = "-D_FORTIFY_SOURCE=2 -O3 -march=$march -mtune=generic -pipe"
  $env:CPPFLAGS = "-D_FORTIFY_SOURCE=2 -D__USE_MINGW_ANSI_STDIO=1 -DFD_SETSIZE=2048"
  $env:LDFLAGS  = "-l:libssp.a -l:libz.a -pipe -fstack-protector-strong -s"
}

#——————————————————————————————————————————————————————————————————— start build
cd $PSScriptRoot

if ($args.length -eq 1) {
  Switch ($args[0]) {
    'ucrt'  { $temp = 'ucrt'  }
    'mingw' { $temp = 'mingw' }
    default { $temp = 'ucrt'  }
  }
} else { $temp = 'ucrt' }

. ./0_common.ps1 $temp
Set-Variables
Set-Variables-Local
Set-Env

Write-Host "TEMP   = $env:TEMP"
Write-Host "TMPDIR = $env:TMPDIR"

$gcc_vers = ([regex]'\d+\.\d+\.\d+').match($(gcc.exe --version)).value

$files = "$d_msys2$env:MINGW_PREFIX/lib/libz.dll.a",
         "$d_msys2$env:MINGW_PREFIX/lib/gcc/x86_64-w64-mingw32/$gcc_vers/libssp.dll.a",
         "C:/Windows/System32/libcrypto-1_1-x64.dll",
         "C:/Windows/System32/libssl-1_1-x64.dll"

Files-Hide $files

Run-Patches @('msys2_patches')

Create-Folders

cd $d_repo
ruby 1_1_pre_build.rb 64

cd $d_ruby
# set time stamp for reproducible build
$ts = $(git log -1 --format=%at).Trim()
if ($ts -match '\A\d+\z' -and $ts -gt "1540000000") {
  $env:SOURCE_DATE_EPOCH = [String][int]$ts
  # echo "SOURCE_DATE_EPOCH = $env:SOURCE_DATE_EPOCH"
}

# Run "sh -c `"autoreconf -fi`"" { sh -c "autoreconf -fi" }

Run "sh -c ./autogen.sh" { sh -c "./autogen.sh" }

cd $d_build
Time-Log "start"

$config_args = "--build=$chost --host=$chost --target=$chost --with-out-ext=pty,syslog"
Run "sh -c `"../ruby/configure --disable-install-doc --prefix=$d_install $config_args`"" {
  sh -c "../ruby/configure --disable-install-doc --prefix=$d_install $config_args"
}
Time-Log "configure"

# below sets some directories to normal in case they're set to read-only
Remove-Read-Only $d_ruby
Remove-Read-Only $d_build

Run "make incs -j$jobs 2>&1" { iex "make incs -j$jobs 2>&1" }
Time-Log "make incs -j$jobs"

Run "make -j$jobs 2>&1" { iex "make -j$jobs 2>&1" }
Time-Log "make -j$jobs"

Files-Unhide $files

Run "make install-nodoc" {
  make install-nodoc
  cd $d_repo
  ruby 1_2_post_install.rb
  Check-Exit "'ruby 1_2_post_install.rb' failure"

  $dll_path = "$d_install/bin/ruby_builtin_dlls"

  if (!(Test-Path -Path $dll_path -PathType Container )) {
    EchoC "Failed - no bin/ruby_builtin_dlls folder" red
    exit 1
  }

  if (!(Test-Path -Path "$dll_path/ruby_builtin_dlls.manifest" -PathType Leaf )) {
    EchoC "Failed - no bin/ruby_builtin_dlls/ruby_builtin_dlls.manifest file" red
    exit 1
  }

  $env:Path = "$d_install/bin;$d_mingw;$d_repo/git/cmd;$d_msys2/usr/bin;$base_path"
  ruby 1_3_post_install.rb
  Check-Exit "'ruby 1_3_post_install.rb' failure"
  
  ruby 1_4_post_install_bin_files.rb
  Check-Exit "'ruby 1_4_post_install_bin_files.rb' failure"
}
Time-Log "make install-nodoc"

#Time-Log "post install processing"

Strip-Build
Strip-Install
Time-Log "strip build & install binary files"

Print-Time-Log

# save extension build files
Push-Location $d_build
$build_files = "$d_zips/ext_build_files.7z"
&$7z a $build_files config.log .ext\include\$rarch\ruby\*.h ext\**\Makefile ext\**\*.h ext\**\*.log ext\**\*.mk 1> $null
if ($is_av) { Push-AppveyorArtifact $build_files -DeploymentName "Ext build files" }
Pop-Location

# apply patches to install folder
# Apply-Install-Patches "patches_install"

if (Test-Path Env:\SOURCE_DATE_EPOCH ) { Remove-Item Env:\SOURCE_DATE_EPOCH }

$ruby_exe  = "$d_install/bin/ruby.exe"
$ruby_v = &$ruby_exe -v

if (-not ($ruby_v -cmatch "$rarch\]\z")) {
  throw("Ruby may have assembly issue, won't start")
} else {
  Write-Host $ruby_v
}
$env:Path = $orig_path
