# Installs (first run) Microsoft/vcpkg packages needed to build Ruby must be run
# from the base Microsoft/vcpkg folder, typically C:/vcpkg
# remember to update the repo with 'git pull'

if (Test-Path -Path vcpkg.exe -PathType Leaf ) {
  $vcpkg_depends = 'libffi libyaml openssl readline-win32 zlib'
  ./bootstrap-vcpkg.bat
  ./vcpkg install --triplet=x64-windows $vcpkg_depends.split(' ')
} else {
  echo "`nMust start from vcpkg install folder, typically C:/vcpkg`n"
}
