# Install/Update msys2 and ucrt packages needed to build Ruby
# must be run from the base MSYS2 folder, typically C:/msys64

if (Test-Path -Path ./usr/bin/pacman.exe -PathType Leaf ) {
  $msys2_pkgs  = 'autoconf-wrapper autogen automake-wrapper bison diffutils libtool m4 make patch re2c texinfo texinfo-tex compression'
  $gcc_depends = '__make __pkgconf __libmangle-git __tools-git __gcc __gmp __libffi __libyaml __openssl __ragel __readline'

  $pre = 'mingw-w64-ucrt-x86_64-'

  ./usr/bin/pacman.exe -Syuu --needed
  ./usr/bin/pacman.exe -S --noconfirm --needed $msys2_pkgs.split(' ')
  ./usr/bin/pacman.exe -S --noconfirm --needed $gcc_depends.replace('__', $pre).split(' ')
} else {
  echo "`nMust start from MSYS2 install folder, typically C:/msys64`n"
}
