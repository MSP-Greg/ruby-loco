<# Code by MSP-Greg
Sets variables used in 1_0_build_install_64.ps1 and 2_0_test.ps1
If running locally, use ./local.ps1
#>

$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# color hash used by EchoC and Color functions
$clr = @{
  'red' = [char]0x001B + '[31;1m'
  'grn' = [char]0x001B + '[32;1m'
  'yel' = [char]0x001B + '[93m'
  'blu' = [char]0x001B + '[34;1m'
  'mag' = [char]0x001B + '[35;1m'
  'cyn' = [char]0x001B + '[36;1m'
  'wht' = [char]0x001B + '[37;1m'
  'gry' = [char]0x001B + '[90;1m'
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

#————————————————————————————————————————————————————————————————— Set-Variables
# set base variables, including MSYS2 location and bit related varis
function Set-Variables {
  if ($env:GITHUB_ACTIONS -eq 'true') {
    $script:is_actions = $true
    $script:d_msys2   = "C:/msys64"
    $script:d_git     = "$env:ProgramFiles/Git"
    $script:7z        = "$env:ChocolateyInstall\bin\7z.exe"
    $env:TMPDIR       =  $env:RUNNER_TEMP
    $script:base_path =  $env:PATH -replace '[^;]+?(Chocolatey|CMake|OpenSSL|Ruby|Strawberry)[^;]*;', ''
    $script:install   = "ruby-mingw"
    # Write-Host ($base_path -replace ';', "`n")
  } elseif ($env:Appveyor -eq 'True') {
    $script:is_av     = $true
    $script:d_msys2   = "C:/msys64"
    $script:d_git     =  "$env:ProgramFiles/Git"
    $script:7z        =  "$env:ProgramFiles/7-Zip/7z.exe"
    $script:base_path = ("$env:ProgramFiles/7-Zip;" + `
      "$env:ProgramFiles/AppVeyor/BuildAgent;$d_git/cmd;" + `
      "$env:SystemRoot/system32;$env:ProgramFiles;$env:SystemRoot").replace('\', '/')
    $script:install   = "install"
  } else {
    $script:install   = "install"
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

  $script:d_install = "$d_repo/$install"

  $script:jobs = $env:NUMBER_OF_PROCESSORS
  $script:fc   = "Yellow"
  $script:dash = "$([char]0x2015)"
  $script:dl   = $($dash * 80)

  $script:UTF8 = $(New-Object System.Text.UTF8Encoding $False)
}

#———————————————————————————————————————————————————————————————————— Color
# Returns text in color
function Color($text, $color) {
  $rst = [char]0x001B + '[0m'
  $c = $clr[$color.ToLower()]
  "$c$text$rst"
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
