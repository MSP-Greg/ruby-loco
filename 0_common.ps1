<# Code by MSP-Greg
Sets variables used in 1_0_build_install_64.ps1 and 2_0_test.ps1
If running locally, use ./local.ps1
#>

#
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

#—————————————————————————————————————————————————————————————— Remove-Read-Only
# removes readonly from folder and all child directories
function Remove-Read-Only($path) {
  (Get-Item $path).Attributes = 'Normal'
  Get-ChildItem -Path $path -Directory -Force -Recurse |
    foreach {$_.Attributes = 'Normal'}
  Get-ChildItem -Path $path -File -Force -Recurse |
    Set-ItemProperty -Name IsReadOnly -Value $false
}

#————————————————————————————————————————————————————————————————— Set-Variables
# set base variables, including MSYS2 location and bit related varis
function Set-Variables {
  if ($env:Appveyor -eq 'True') {
    # } elseif ($env:GITHUB_ACTIONS -eq 'true') {
    $script:is_av     = $true
    $script:d_msys2   = "C:/msys64"
    $script:d_git     =  "$env:ProgramFiles/Git"
    $script:7z        =  "$env:ProgramFiles/7-Zip/7z.exe"
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

  if ($bits -eq 32) {
    $script:march = "i686"   ; $script:carch = "i686"   ; $script:rarch = "i386-mingw32"
  } else {
    $script:march = "x86-64" ; $script:carch = "x86_64" ; $script:rarch = "x64-mingw32"
  }

  $script:chost   = "$carch-w64-mingw32"

  #$script:make = "mingw32-make.exe"
  $script:make = "make"

  # below two items appear in MSYS2 shell printenv
  $env:MSYSTEM_CARCH = $carch
  $env:MSYSTEM_CHOST = $chost
  $env:MSYSTEM = "MINGW$bits"

  # not sure if below are needed, maybe just for makepkg scripts.  See
  # https://github.com/Alexpux/MSYS2-packages/blob/master/pacman/makepkg_mingw64.conf
  # https://github.com/Alexpux/MSYS2-packages/blob/master/pacman/makepkg_mingw32.conf
  $env:CARCH        = $carch
  $env:CHOST        = $chost
  $env:MINGW_PREFIX = "/mingw$bits"

  # below are folder shortcuts
  $script:d_build   = "$d_repo/build"
  $script:d_logs    = "$d_repo/logs"
  $script:d_mingw   = "$d_msys2/mingw$bits/bin"
  $script:d_ruby    = "$d_repo/ruby"
  $script:d_zips    = "$d_repo/zips"

  $script:install   = "install"
  $script:d_install = "$d_repo/$install"

  $script:jobs = $env:NUMBER_OF_PROCESSORS
  $script:fc   = "Yellow"
  $script:dash = "$([char]0x2015)"
  $script:dl   = $($dash * 80)

  $script:UTF8 = $(New-Object System.Text.UTF8Encoding $False)
}

#———————————————————————————————————————————————————————————————————— Write-Line
# Write 80 dash line then msg in color $fc
function Write-Line($msg) { Write-Host "$dl`n$msg" -ForegroundColor $fc }

#—————————————————————————————————————————————————————————————————————— Enc-Info
# Dump misc encoding info to console
function Enc-Info {
  Write-Host "`n$($dash * 8) Encoding $($dash * 8)" -ForegroundColor $fc
  Write-Host "PS Console  $([Console]::OutputEncoding.HeaderName)"
  Write-Host "PS Output   $($OutputEncoding.HeaderName)"
  iex "ruby.exe -e `"['external','filesystem','internal','locale'].each { |e| puts e.ljust(12) + Encoding.find(e).to_s }`""
  Write-Host ''
}
