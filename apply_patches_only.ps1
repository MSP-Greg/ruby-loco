<# Code by MSP-Greg
Applies all patches to ruby
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

# apply patches for testing
Apply-Patches "patches_basic_boot"
Apply-Patches "patches_spec"
Apply-Patches "patches_test"
