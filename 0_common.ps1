<# Code by MSP-Greg
Sets variables used in 1_0_build_install_64.ps1 and 2_0_test.ps1
If running locally, use ./local.ps1
#>

$PSDefaultParameterValues['*:Encoding'] = 'utf8'

$global:orig_path = $env:Path

if ($args.length -eq 1) {
  Switch ($args[0]) {
    'ucrt'  {
      $global:build_sys = 'msys2'
      $env:MSYSTEM      = 'UCRT64'
    }
    'mingw'  {
      $global:build_sys = 'msys2'
      $env:MSYSTEM      = 'MINGW64'
    }
    'mswin'  {
      $global:build_sys = 'mswin'
      $env:MSYSTEM      = 'UCRT64'
      $env:MINGW_PREFIX = 'ucrt64'
    }
  }
}

# color hash used by EchoC and Color functions
$clr = @{
  'red' = '[91m'
  'grn' = '[92m'
  'yel' = '[93m'
  'blu' = '[34;1m'
  'mag' = '[35;1m'
  'cyn' = '[36;1m'
  'wht' = '[37;1m'
  'gry' = '[90;1m'
}

#————————————————————————————————————————————————————————————————— Set-VCVars_Env
# Runs MSFT vcvars.bat and changes Powershell env
function Set-VCVars-Env() {
  $data = $(iex "cmd.exe /c '`"$vcvars`" && echo QWERTY && set'")

  # Output 'header', skip to ENV data
  $idx = 1
  foreach ($e in $data) {
    if ($e.trim() -eq 'QWERTY') { break }
    echo $e
    $idx += 1
  }

  # Replace current ENV data with changes from vcvars
  foreach ($e in $data[$idx .. ($data.count-1)]) {
    $key, $val = $e -split '=', 2
    $old_val = [Environment]::GetEnvironmentVariable($key)
    if ($old_val -ne $val) {
      [Environment]::SetEnvironmentVariable($key, $val)
    }
  }
}

#————————————————————————————————————————————————————————————————— Set-Variables
# set base variables, including MSYS2 location and bit related varis
function Set-Variables {
  if ($bits -eq 32) { $env:MSYSTEM = "MINGW32" }

  if ($build_sys -eq "msys2" -or $env:MAKE -eq "make.exe") {
    Switch ($env:MSYSTEM) {
      "UCRT64"  {
        $script:install = [string]::IsNullOrWhiteSpace($env:PRE) ? "ruby-ucrt" : $env:PRE
        $env:MINGW_PREFIX = "/ucrt64"
        $env:MINGW_PACKAGE_PREFIX = "mingw-w64-ucrt-x86_64"
        $script:march = "x86-64" ; $script:carch = "x86_64" ; $script:rarch = "x64-mingw-ucrt"
      }
      "MINGW32" {
        $script:install = [string]::IsNullOrWhiteSpace($env:PRE) ? "ruby-mingw32" : $env:PRE
        $env:MINGW_PREFIX = "/mingw32"
        $env:MINGW_PACKAGE_PREFIX = "mingw-w64-i686"
        $script:march = "i686"   ; $script:carch = "i686"   ; $script:rarch = "i386-mingw32"
      }
      default   {
        $env:MSYSTEM = "MINGW64"
        $script:install = [string]::IsNullOrWhiteSpace($env:PRE) ? "ruby-mingw" : $env:PRE
        $env:MINGW_PREFIX = "/mingw64"
        $env:MINGW_PACKAGE_PREFIX = "mingw-w64-x86_64"
        $script:march = "x86-64" ; $script:carch = "x86_64" ; $script:rarch = "x64-mingw32"
      }
    }

    $script:chost   = "$carch-w64-mingw32"

    # below two items appear in MSYS2 shell printenv
    $env:MSYSTEM_CARCH = $carch
    $env:MSYSTEM_CHOST = $chost

    # not sure if below are needed, maybe just for makepkg scripts.  See
    # https://github.com/Alexpux/MSYS2-packages/blob/master/pacman/makepkg_mingw64.conf
    # https://github.com/Alexpux/MSYS2-packages/blob/master/pacman/makepkg_mingw32.conf
    $env:CARCH        = $carch
    $env:CHOST        = $chost
    $env:MAKE         = "make.exe"
  } else {
    $script:install = [string]::IsNullOrWhiteSpace($env:PRE) ? "ruby-mswin" : $env:PRE
    $script:rarch   = "x64-mswin64_140"
    $env:MAKE       = "nmake.exe"
  }

  if ($env:GITHUB_ACTIONS -eq 'true') {
    $script:is_actions = $true
    $script:d_msys2   = "C:/msys64"
    $script:d_git     = "$env:ProgramFiles/Git"
    $script:d_vcpkg   =  $env:VCPKG_INSTALLATION_ROOT.replace('\', '/')
    $env:TMPDIR       =  $env:RUNNER_TEMP
    $script:base_path =  $env:Path -replace '[^;]+?(Chocolatey|CMake|OpenSSL|Ruby|Strawberry)[^;]*;', ''
    $script:jobs      = 3

    if (Test-Path -Path "$env:ProgramFiles/7-Zip/7z.exe" -PathType Leaf ) {
      $script:7z =  "$env:ProgramFiles/7-Zip/7z.exe"
    } else {
      $script:7z = "$env:ChocolateyInstall\bin\7z.exe"
    }

    # Write-Host ($base_path -replace ';', "`n")
  } elseif ($env:Appveyor -eq 'True') {
    $script:is_av     = $true
    $script:d_msys2   = "C:/msys64"
    $script:d_git     =  "$env:ProgramFiles/Git"
    $script:7z        =  "$env:ProgramFiles/7-Zip/7z.exe"
    $env:TMPDIR       = $env:TEMP
    $script:jobs = 2
    $script:base_path = ("$env:ProgramFiles/7-Zip;" + `
      "$env:ProgramFiles/AppVeyor/BuildAgent;$d_git/cmd;" + `
      "$env:SystemRoot/system32;$env:ProgramFiles;$env:SystemRoot").replace('\', '/')
  } else {
    ./local.ps1
  }

  $script:d_repo   = $PSScriptRoot.replace('\', '/')
  # below is a *nix style path, ie, 'C:\' becomes '/C/'
  $script:d_repo_u = if ($d_repo -cmatch "\A[A-Z]:") {
    '/' + $d_repo.replace(':', '')
  } else { $d_repo }

  # below are folder shortcuts
  $script:d_build   = "$d_repo/build"
  $script:d_logs    = "$d_repo/logs"
  $script:d_mingw   = "$d_msys2$env:MINGW_PREFIX/bin"
  $script:d_ruby    = "$d_repo/ruby"
  $script:d_zips    = "$d_repo/zips"

  $script:d_install = "$d_repo/$install"

  $script:fc   = "Yellow"
  $script:dash = "$([char]0x2500)"
  $script:dash_line = $($dash * 80)
  $script:dash_hdr  = $($dash * 74)
  $script:dash_hdr2 = $($dash * 54)

  $script:UTF8 = $(New-Object System.Text.UTF8Encoding $False)
}

#———————————————————————————————————————————————————————————————————— Color
# Returns text in color
function Color($text, $color) {
  $c = $clr[$color.ToLower()]
  "$c$text[0m"
}

#———————————————————————————————————————————————————————————————————— EchoC
# Writes text in color
function EchoC($text, $color) {
  echo $(Color $text $color)
}

#—————————————————————————————————————————————————————————————————————— Enc-Info
# Dump misc encoding info to console
function Enc-Info {
  echo ''
  EchoC "$($dash * 8) Encoding $($dash * 8)" yel
  echo "PS Console  $([Console]::OutputEncoding.HeaderName)"
  echo "PS Output   $($OutputEncoding.HeaderName)"
  iex "ruby.exe -e `"['external','filesystem','internal','locale'].each { |e| puts e.ljust(12) + Encoding.find(e).to_s }`""
  echo ''
}

# Runs Apply-Patches from folder contained in array parameter
#————————————————————————————————————————————————————————————————— Run-Patches
function Run-Patches($ary_dir) {
  $all_log = ''
  $all_clr = 'grn'
  foreach ($patch_dir in $ary_dir) {
    $log, $p_clr = Apply-Patches($patch_dir)
    if ($log -ne $null) { $all_log += $log }
    if ($p_clr -eq 'red') { $all_clr = 'red' }
    if ($p_clr -eq 'yel' -and $p_clr -ne 'red') {
      $all_clr = 'yel'
    }
  }
  if ($is_actions) {
    echo "##[group]$(color "Apply Patches" $all_clr)"
  } else {
    echo "all_clr $all_clr"
    $e_str = "$dash_hdr Apply Patches"
    echo $(color $e_str $all_clr)
  }
  echo $all_log.TrimEnd()
  if ($is_actions) { echo ::[endgroup] } else { echo '' }
}

#————————————————————————————————————————————————————————————————— Apply-Patches
# Applies patches
function Apply-Patches($p_dir) {
  if (Test-Path -Path $p_dir -PathType Container ) {
    $patch_exe = "$d_msys2/usr/bin/patch.exe"
    Push-Location "$d_repo/$p_dir"
    [string[]]$patches = Get-ChildItem -Include *.patch -Path . -Recurse |
      select -expand name
    Pop-Location
    $fix = 'grn'
    if ($patches.length -ne 0) {
      Push-Location "$d_ruby"
      foreach ($p in $patches) {
        if ($p.StartsWith("__")) { continue }
        $patch_log = $(&$patch_exe -p1 -N --no-backup-if-mismatch -i "$d_repo/$p_dir/$p" 2>&1) -replace '^', "`n  "
        if ($patch_log -match 'offset|fuzz') {
          if ($fix -eq 'grn') { $fix = 'yel'}
          $log += $(EchoC "$p" yel)
        } elseif ($patch_log -match 'FAILED') {
          $log += $(EchoC "$p" red)
          $fix = 'red'
        } else {
          $log += $p
        }
        $log += $patch_log + "`n`n"
      }
      Pop-Location
      $log = $(EchoC "$dash_hdr2 $p_dir" $fix) + "`n" + $log
      return @($log, $fix)
    }
  }
  return @($null, $null)
}

#————————————————————————————————————————————————————————————————— Apply-Install-Patches
# Applies patches in install folder
function Apply-Install-Patches($p_dir) {
  if (Test-Path -Path $p_dir -PathType Container ) {
    EchoC "$dash_hdr $p_dir" yel
    $patch_exe = "$d_msys2/usr/bin/patch.exe"
    Push-Location "$d_repo/$p_dir"
    [string[]]$patches = Get-ChildItem -Include *.patch -Path . -Recurse |
      select -expand name
    Pop-Location
    if ($patches.length -ne 0) {
      Push-Location "$d_install"
      foreach ($p in $patches) {
        EchoC "$p" yel
        $out = $(& $patch_exe -p1 -N --no-backup-if-mismatch -i "$d_repo/$p_dir/$p")
        $out -replace '^', '  '
        echo ''
      }
      Pop-Location
    }
  }
}

#———————————————————————————————————————————————————————————————————— Check-Exit
# checks whether to exit
function Check-Exit($msg, $pop) {
  if ($LastExitCode -and $LastExitCode -ne 0) {
    if ($pop) { Pop-Location }
    EchoC "Failed - $msg" yel
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

  # Create download cache
  $dl_cache = ".downloaded-cache"
  if (!(Test-Path -Path $d_repo/$dl_cache -PathType Container )) {
         New-Item -Path $d_repo/$dl_cache -ItemType Directory 1> $null
  }

  # create download cache symlink
  if (!(Test-Path -Path $d_repo/ruby/$dl_cache -PathType Container )) {
        New-Item  -Path $d_repo/ruby/$dl_cache -ItemType Junction -Value $d_repo/$dl_cache 1> $null
  }

  New-Item -Path $d_build   -ItemType Directory 1> $null
  New-Item -Path $d_install/bin/ruby_builtin_dlls -ItemType Directory 1> $null
  New-Item -Path $d_install/bin/lib               -ItemType Directory 1> $null
  New-Item -Path $d_install/bin/lib/ossl-modules  -ItemType Directory 1> $null
}

#————————————————————————————————————————————————————————————————— Files-Hide
# Hides files for compiling/linking
function Files-Hide($f_ary) {
  foreach ($f in $f_ary) {
    if (Test-Path -Path $f -PathType Leaf ) { ren $f ($f + '__') }
  }
}

#————————————————————————————————————————————————————————————————— Files-Unhide
# UnHides files previously hidden
function Files-Unhide($f_ary) {
  foreach ($f in $f_ary) {
    if (Test-Path -Path ($f + '__') -PathType Leaf ) { ren ($f + '__') $f }
  }
}

#———————————————————————————————————————————————————————————————— Print-Time-Log
function Print-Time-Log {
  $diff = New-TimeSpan -Start $script:time_start -End $script:time_old
  $script:time_info += ("{0:mm}:{0:ss} {1}" -f @($diff, "Total"))

  EchoC $dash_line yel
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

#—————————————————————————————————————————————————————————————— Remove-Read-Only
# removes readonly from folder and all child directories
function Remove-Read-Only($path) {
  (Get-Item $path).Attributes = 'Normal'
  Get-ChildItem -Path $path -Directory -Force -Recurse |
    foreach {$_.Attributes = 'Normal'}
  Get-ChildItem -Path $path -File -Force -Recurse |
    Set-ItemProperty -Name IsReadOnly -Value $false
}

#——————————————————————————————————————————————————————————————————————————— Run
# Run a command and check for error
function Run($e_msg, $exec) {
  $orig = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'

  if ($is_actions) {
    echo "##[group]$(color $e_msg yel)"
  } else {
    if ($e_msg.length -lt 35) {
      $e_str = "$($dash * 55) $e_msg"
    } else {
      $e_str = "$($dash * 80)`n  $e_msg"
    }
    echo "$(color $e_str yel)"
  }

  &$exec

  Check-Exit $eMsg
  $ErrorActionPreference = $orig
  if ($is_actions) { echo ::[endgroup] } else { echo '' }
}
