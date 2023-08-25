<# Code by MSP-Greg
Script for building & installing MinGW Ruby for CI
Assumes a Ruby exe is in path
Assumes 'Git for Windows' is installed at $env:ProgramFiles\Git
Assumes '7z             ' is installed at $env:ProgramFiles\7-Zip
For local use, set items in local.ps1
#>

#————————————————————————————————————————————————————————————————— Set-Variables-Local
# set variables only used in this script
function Set-Variables-Local {
  $script:ruby_path = $(ruby.exe -e "puts RbConfig::CONFIG['bindir']").trim().replace('\', '/')
  $script:time_info = ''
  $script:time_old  = $null
  $script:time_start = $null
  $script:d_vcpkg_install = "$d_vcpkg/installed/x64-windows"
}

#——————————————————————————————————————————————————————————————————— start build
cd $PSScriptRoot

$global:build_sys = 'mswin'

. ./0_common.ps1 mswin

Set-Variables

Set-Variables-Local
$env:Path = "$ruby_path;$d_repo/git/cmd;$env:Path;$d_msys2/usr/bin;$d_mingw;"

$files = 'C:/Windows/System32/libcrypto-1_1-x64.dll',
         'C:/Windows/System32/libssl-1_1-x64.dll'

Files-Hide $files

Run-Patches @('mswin_patches')

Create-Folders

# set time stamp for reproducible build
$ts = $(git log -1 --format=%at).Trim()
if ($ts -match '\A\d+\z' -and $ts -gt "1540000000") {
  $env:SOURCE_DATE_EPOCH = [String][int]$ts
  # echo "SOURCE_DATE_EPOCH = $env:SOURCE_DATE_EPOCH"
}

cd $d_build

Time-Log "start"

$cmd_config = "..\ruby\win32\configure.bat --disable-install-doc --prefix=$d_install --without-ext=+,dbm,gdbm --with-opt-dir=$d_vcpkg_install"
Run $cmd_config { cmd.exe /c "$cmd_config" }
Time-Log "configure"

# below sets some directories to normal in case they're set to read-only
Remove-Read-Only $d_ruby
Remove-Read-Only $d_build

Run "nmake incs" { nmake incs }
Time-Log "make incs"

$env:Path = "$d_vcpkg_install\bin;$env:Path"

Run "nmake" { nmake }
Time-Log "nmake"

Files-Unhide $files

Run "nmake 'DESTDIR=' install-nodoc" {
  nmake "DESTDIR=" install-nodoc
  # generates string like 320, 310, etc
  $ruby_abi = ([regex]'\Aruby (\d+\.\d+)').match($(./miniruby.exe -v)).groups[1].value.replace('.', '') + '0'
  # set correct ABI version for manifest file
  $file = "$d_repo/mswin/ruby-exe.xml"
  (Get-Content $file -raw) -replace "ruby\d{3}","ruby$ruby_abi" | Set-Content $file

  cd $d_install\bin\ruby_builtin_dlls
  echo "installing dll files:               From $d_vcpkg_install/bin"
  $dlls = @('libcrypto-3-x64', 'libssl-3-x64', 'ffi-8', 'readline', 'yaml', 'zlib1')
  foreach ($dll in $dlls) {
    Copy-Item $d_vcpkg_install/bin/$dll.dll
    echo "                                    $dll.dll"
  }

  Copy-Item $d_repo/mswin/ruby_builtin_dlls.manifest

  cd $d_install\bin\lib\ossl-modules
  Copy-Item $d_vcpkg_install/bin/legacy.dll

  cd $d_repo
  del $d_install\lib\x64-vcruntime140-ruby$ruby_abi-static.lib
  # below can't run from built Ruby, as it needs valid cert files
  ruby 1_2_post_install_common.rb run
}
Time-Log "make install-nodoc"

Run "manifest ruby.exe, rubyw.exe" {
  cd $d_install\bin
  mt.exe -manifest $d_repo\mswin\ruby-exe.xml -outputresource:ruby.exe;1
  mt.exe -manifest $d_repo\mswin\ruby-exe.xml -outputresource:rubyw.exe;1
}
Time-Log "manifest ruby.exe, rubyw.exe"

Print-Time-Log

# below needs to run from built/installed Ruby
cd $d_repo
$env:Path = "$d_install\bin;$no_ruby_path"
&"$d_install/bin/ruby.exe" 1_4_post_install_bin_files.rb

if (Test-Path Env:\SOURCE_DATE_EPOCH ) { Remove-Item Env:\SOURCE_DATE_EPOCH }

$ruby_exe  = "$d_install/bin/ruby.exe"
$ruby_v = &$ruby_exe -v

if (-not ($ruby_v -cmatch "$rarch\]\z")) {
  throw("Ruby may have compile/install issue, won't start")
} else {
  Write-Host $ruby_v
}

# reset to original
$env:Path = $orig_path

# Apply-Patches "mswin_test_patches"