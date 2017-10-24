dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

r_inst_dir=ruby${SUFFIX}

jobs=${M_JOBS}
echo JOB = ${jobs}

_realname=ruby
pkgbase=${r_inst_dir}
pkgname=${r_inst_dir}
pkgver=${R_VERS}
pkgrel=1
pkgdesc="An object-oriented language for quick and easy programming (mingw-w64)"
arch=('any')
url="https://www.ruby-lang.org/en"
license=("BSD, custom")

makedepends=("${MINGW_PACKAGE_PREFIX}-gcc" "${MINGW_PACKAGE_PREFIX}-pkg-config")

depends=("${MINGW_PACKAGE_PREFIX}-gcc-libs"
         "${MINGW_PACKAGE_PREFIX}-gdbm"
         "${MINGW_PACKAGE_PREFIX}-libffi"
         "${MINGW_PACKAGE_PREFIX}-ncurses"
         "${MINGW_PACKAGE_PREFIX}-openssl"
         "${MINGW_PACKAGE_PREFIX}-readline"
         "${MINGW_PACKAGE_PREFIX}-zlib"
         )

makedepends=()
depends=()

options=('staticlibs' 'strip')

source=()

sha256sums=()

PACKAGER=MSP-Greg

PATH=${PATH}:${GIT_PATH_SH}

prepare() {
  echo ruby ${R_VERS}${R_PATCH} ${R_DATE} ${R_SVN}
  echo MINGW_CHOST ${MINGW_CHOST}   CARCH ${CARCH}
  where git
  echo
  echo PATH
  echo ${PATH}
  echo
  cd ${dir}
  PATH=${PATH}:${GIT_PATH_SH}:${RUBY_OPATH}
  ${RUBY} prepare.rb
  
  cd ${srcdir}/${_realname}
  autoreconf -fi

#  if [[ ${R_VERS_2} > 24 ]]; then
#    sed -f tool/prereq.status Makefile.in common.mk > Makefile
#    make touch-unicode-files
#    rm MakeFile
#  fi
}

build() {
  echo ruby ${R_VERS}${R_PATCH} ${R_DATE} ${R_SVN}

  CPPFLAGS+=" -DFD_SETSIZE=2048"

  [[ -d "${srcdir}/build${SUFFIX}" ]] && rm -rf "${srcdir}/build${SUFFIX}"
  mkdir -p "${srcdir}/build${SUFFIX}" && cd "${srcdir}/build${SUFFIX}"

  ../${_realname}/configure \
    --prefix=/${r_inst_dir} \
    --build=${MINGW_CHOST} \
    --host=${MINGW_CHOST} \
    --target=${MINGW_CHOST} \
    --disable-install-doc \
    --with-git=${GIT} \
    --with-out-ext=pty,syslog,tk

  echo - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - Done with configure
  mkdir -p "${dir}/pkg/${r_inst_dir}/${r_inst_dir}"
  attrib.exe -r ${srcdir}/ruby/\*\.\* //s //d
  attrib.exe -r ${srcdir}/ruby/spec/ruby/\*\.\* //s //d
  attrib.exe -r ${srcdir}/build${SUFFIX}/\*\.\* //s //d
  if [[ ${R_VERS_2} > 24 ]]; then
    # make -j ${jobs} UNICODE_FILES=.
    # echo - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - Done with update-unicode
    make -j ${jobs}
  else
    jobs=1
    make after-update
    echo - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - Done with after-update
    make UNICODE_FILES=.
  fi
  echo - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - Done with all, jobs = ${jobs}
}

package() {
  echo ruby ${R_VERS}${R_PATCH} ${R_DATE} ${R_SVN}

  pkgdir=${dir}/pkg/${r_inst_dir}

  cd "${srcdir}/build${SUFFIX}"
  make -f GNUMakefile DESTDIR="${pkgdir}" install-nodoc
  for script in {erb,gem,irb,rdoc,ri}; do
    install ${srcdir}/${_realname}/bin/${script} \
      ${pkgdir}/${r_inst_dir}/bin/
  done
  cd "../.."
  NEW_RUBY=${PKG_RUBY}/bin/ruby.exe
  if [[ ${R_VERS_2} < 25 ]]; then
    ${NEW_RUBY} install_rubygems.rb ${r_inst_dir}
  fi
  ${NEW_RUBY} install_gem_update.rb
  ${RUBY} install_post.rb ${r_inst_dir}
  ${NEW_RUBY} install_post_ri2.rb ${r_inst_dir}
}
