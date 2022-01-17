<# Code by MSP-Greg
Sets variables used in 1_0_build_install_64.ps1 and 2_0_test.ps1
If running locally, use ./local.ps1
#>

$PSDefaultParameterValues['*:Encoding'] = 'utf8'

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
  if ($bits -eq 32) { $env:MSYSTEM = "MINGW32" }

  Switch ($env:MSYSTEM) {
    "UCRT64"  {
      $script:install = "ruby-ucrt"
      $env:MINGW_PREFIX = "/ucrt64"
      $env:MINGW_PACKAGE_PREFIX = "mingw-w64-ucrt-x86_64"
      $script:march = "x86-64" ; $script:carch = "x86_64" ; $script:rarch = "x64-mingw-ucrt"
    }
    "MINGW32" {
      $script:install = "ruby-mingw32"
      $env:MINGW_PREFIX = "/mingw32"
      $env:MINGW_PACKAGE_PREFIX = "mingw-w64-i686"
      $script:march = "i686"   ; $script:carch = "i686"   ; $script:rarch = "i386-mingw32"
    }
    default   {
      $env:MSYSTEM = "MINGW64"
      $script:install = "ruby-mingw"
      $env:MINGW_PREFIX = "/mingw64"
      $env:MINGW_PACKAGE_PREFIX = "mingw-w64-x86_64"
      $script:march = "x86-64" ; $script:carch = "x86_64" ; $script:rarch = "x64-mingw32"
    }
  }

  if ($env:GITHUB_ACTIONS -eq 'true') {
    $script:is_actions = $true
    $script:d_msys2   = "C:/msys64"
    $script:d_git     = "$env:ProgramFiles/Git"
    $script:7z        = "$env:ChocolateyInstall\bin\7z.exe"
    $env:TMPDIR       =  $env:RUNNER_TEMP
    $script:jobs = 3
    $script:base_path =  $env:Path -replace '[^;]+?(Chocolatey|CMake|OpenSSL|Ruby|Strawberry)[^;]*;', ''
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

  $script:chost   = "$carch-w64-mingw32"

  # below two items appear in MSYS2 shell printenv
  $env:MSYSTEM_CARCH = $carch
  $env:MSYSTEM_CHOST = $chost

  # not sure if below are needed, maybe just for makepkg scripts.  See
  # https://github.com/Alexpux/MSYS2-packages/blob/master/pacman/makepkg_mingw64.conf
  # https://github.com/Alexpux/MSYS2-packages/blob/master/pacman/makepkg_mingw32.conf
  $env:CARCH        = $carch
  $env:CHOST        = $chost

  # below are folder shortcuts
  $script:d_build   = "$d_repo/build"
  $script:d_logs    = "$d_repo/logs"
  $script:d_mingw   = "$d_msys2$env:MINGW_PREFIX/bin"
  $script:d_ruby    = "$d_repo/ruby"
  $script:d_zips    = "$d_repo/zips"

  $script:d_install = "$d_repo/$install"

  $script:fc   = "Yellow"
  $script:dash = "$([char]0x2500)"
  $script:dl   = $($dash * 80)

  $script:UTF8 = $(New-Object System.Text.UTF8Encoding $False)
}

#———————————————————————————————————————————————————————————————————— Color
# Returns text in color
function Color($text, $color) {
  $c = $clr[$color.ToLower()]
  "`e$c$text`e[0m"
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
