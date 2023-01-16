# frozen_string_literal: true
# code by MSP-Greg

require 'open3'
require 'fileutils'

module PostInstall2Common
  if ENV['MAKE'].start_with? 'nmake'
    D_INSTALL = File.join __dir__, 'ruby-mswin'
    D_SSL_CNF = File.join ENV['VCPKG_INSTALLATION_ROOT'], "packages/openssl_x64-windows"
  else
    case ENV['MSYSTEM']
    when 'UCRT64'
      D_INSTALL = File.join __dir__, 'ruby-ucrt'
    when 'MINGW32'
      D_INSTALL = File.join __dir__, 'ruby-mingw32'
    else
      D_INSTALL = File.join __dir__, 'ruby-mingw'
    end
    D_MSYS2 = ENV['D_MSYS2']
    D_SSL_CNF = "#{D_MSYS2}#{ENV['MINGW_PREFIX']}/ssl"
  end

  D_RI2   = File.join __dir__, 'rubyinstaller2'
  D_RUBY  = File.join __dir__, 'ruby'

  COL_WID = 36
  COL_SPACE = ' ' * COL_WID

  class << self

    def run
      copy_ssl_files
      add_licenses
    end

    private

    def copy_ssl_files
      Dir.chdir(D_RI2) { |d|
        require_relative "rubyinstaller2/lib/ruby_installer/build/ca_cert_file.rb"
        require_relative "rubyinstaller2/lib/ruby_installer/build/gem_version.rb"
        ca_file = RubyInstaller::Build::CaCertFile.new
        File.binwrite("resources/ssl/cacert.pem", ca_file.content)
        Dir.mkdir "#{D_INSTALL}/etc" unless Dir.exist? "#{D_INSTALL}/etc"
        Dir.mkdir "#{D_INSTALL}/etc/ssl" unless Dir.exist? "#{D_INSTALL}/etc/ssl"
        Dir.mkdir "#{D_INSTALL}/etc/ssl/certs" unless Dir.exist? "#{D_INSTALL}/etc/ssl/certs"
        cp "./resources/ssl/cacert.pem", "#{D_INSTALL}/etc/ssl/cert.pem"
        puts "#{'installing ssl files:'.ljust(COL_WID)}cert.pem"

        src = File.join D_SSL_CNF, "openssl.cnf"
        if File.exist?(src)
          cp src, "#{D_INSTALL}/etc/ssl/openssl.cnf"
          puts "#{COL_SPACE}openssl.cnf"
        end

        cp "./resources/ssl/README-SSL.md", "#{D_INSTALL}/etc/ssl/README-SSL.md"
        puts "#{COL_SPACE}README-SSL.md"
        cp "./resources/ssl/c_rehash.rb", "#{D_INSTALL}/etc/ssl/c_rehash.rb"
        puts "#{COL_SPACE}certs\\c_rehash.rb"
      }
    end

    def cp(src, dest)
      unless Dir.exist? (dest_dir = File.dirname dest)
        FileUtils.mkdir_p dest_dir
      end
      FileUtils.copy_file(src, dest, preserve: true)
    end

    def add_licenses
      cp "#{D_RUBY}/BSDL"      , "#{D_INSTALL}/BSDL"
      cp "#{D_RUBY}/COPYING"   , "#{D_INSTALL}/COPYING Ruby"
      cp "#{D_RUBY}/LEGAL"     , "#{D_INSTALL}/LEGAL Ruby"
      cp "#{D_RI2}/LICENSE.txt", "#{D_INSTALL}/LICENSE Ruby Installer.txt"
    end

  end
end

if ARGV[0] == 'run'
  PostInstall2Common.run
end

