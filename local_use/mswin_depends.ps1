<#
This file downloads and installs prerequisites for building a mswin Ruby
Two repositories:
  ruby/ruby
  oneclick/rubyinstaller2 - we borrow the OpenSSL cert file processing from it

Two 7z files:
  Packages built using MSFT/vcpkg
  The base MSYS2 system, which includes many bash commands and also bison

The base directory locations are determined via the data you set in local.ps1.
If you empty any of the root folders, this code will re-download and install
#>

# the stable branch is ruby_3_2
$ruby_ref = 'v3_2_2'

$d_file = $PSScriptRoot.replace('\', '/')

$d_repo = $d_file/..

$build_sys = 'mswin'

cd $d_file
cd ..
./local.ps1

$d_vcpkg = $env:VCPKG_INSTALLATION_ROOT.replace('\', '/')

$gh = 'https://github.com'

# clone rubyinstaller2 for cert creation
if (!(Test-Path -Path $d_rubyinstaller2_repo/lib/ruby_installer/build -PathType Container )) {
  echo "Cloning oneclick/rubyinstaller2 at master"
  git clone -q --depth=1 --no-tags --branch=master $gh/oneclick/rubyinstaller2.git $d_rubyinstaller2_repo
} else {
  echo "oneclick/rubyinstaller2 is installed"
}

# create rubyinstaller2 symlink
if (!(Test-Path -Path $d_repo/rubyinstaller2 -PathType Container )) {
      New-Item  -Path $d_repo/rubyinstaller2 -ItemType Junction -Value $d_rubyinstaller2_repo 1> $null
      echo "Created symlink into rubyinstaller2"
}

# clone ruby
if (!(Test-Path -Path $d_ruby_repo/ext/openssl -PathType Container )) {
  echo "Cloning ruby/ruby at $ruby_ref"
  git clone -q --depth=1 --no-tags --branch=$ruby_ref $gh/ruby/ruby.git $d_ruby_repo
} else {
  echo "ruby/ruby is installed"
}

# create ruby symlink
if (!(Test-Path -Path $d_repo/ruby -PathType Container )) {
      New-Item  -Path $d_repo/ruby -ItemType Junction -Value $d_ruby_repo 1> $null
      echo "Created symlink into ruby"
}

# download packages - pre-compiled vcpkg
if (!(Test-Path -Path $d_vcpkg/installed/x64-windows/bin -PathType Container )) {
  echo "Downloading msys2-gcc-pkgs/mswin.7z"
  $url = "$gh/ruby/setup-msys2-gcc/releases/download/msys2-gcc-pkgs/mswin.7z"
  Start-BitsTransfer -Source $url -Destination ./zips/mswin.7z
  &$7z x ./zips/mswin.7z -aoa -bd -o"$d_vcpkg"
} else {
  echo "vcpkg files are installed"
}

# download packages - MSYS2 msys base (bison)
if (!(Test-Path -Path $d_msys2/usr/bin -PathType Container )) {
  echo "Downloading msys2-base-x86_64-20231026.sfx.exe"
  $url = "$gh/msys2/msys2-installer/releases/download/2023-10-26/msys2-base-x86_64-20231026.sfx.exe"
  Start-BitsTransfer -Source $url -Destination ./zips/msys2-base.sfx.exe
  $exe = './zips/msys2-base.sfx.exe'
  echo "Extracting msys2-base-x86_64-20231026.sfx.exe"
  &$exe -y -o"$msys2_parent"

  echo "Downloading msys2-gcc-pkgs/msys2.7z"
  $url = "$gh/ruby/setup-msys2-gcc/releases/download/msys2-gcc-pkgs/msys2.7z"
  Start-BitsTransfer -Source $url -Destination ./zips/msys2.7z
  &$7z x ./zips/msys2.7z -aoa -bd -o"$d_msys2"
} else {
  echo "MSYS2 files are installed"
}

