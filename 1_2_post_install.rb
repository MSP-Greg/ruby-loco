# frozen_string_literal: true
# code by MSP-Greg

require 'open3'

module PostInstall2
  if ARGV.length == 0
    ARCH = '64'
    D_INSTALL = File.join __dir__, 'install'
  elsif ARGV[0] == '32' || ARGV[0] == '64'
    ARCH = ARGV[0]
  else
    puts "Incorrect first argument, must be '32' or '64'"
    exit 1
  end

  if ARGV.length == 2 && !ARGV[1].nil?  && ARGV[1] != ''
    D_INSTALL = File.join __dir__, ARGV[1]
  elsif ARGV.length == 1
    D_INSTALL = File.join __dir__, 'install'
  end

  D_MSYS2 = ENV['D_MSYS2']
  D_RI2   = File.join __dir__, 'rubyinstaller2'
  D_RL    = File.join __dir__, 'ruby_readline'
  D_RUBY  = File.join __dir__, 'ruby'

  COL_WID = 36
  COL_SPACE = ' ' * COL_WID

class << self

  def run
    copy_dll_files
    add_priv_assm
    add_rb_readline
    copy_ssl_files
    add_licenses
  end

  private

  # Copies correct dll files from mys location to package dir.
  def copy_dll_files
    pkg_pre = (ARCH == '64' ? 'mingw-w64-x86_64' : 'mingw-w64-i686')
    pkgs = 'gcc-libs gdbm libffi openssl readline zlib'
    dll_files, lib_files = find_dlls pkgs, pkg_pre

    # get mingw bin path for arch
    msys2_dll_bin_path = File.join D_MSYS2, "mingw#{ARCH}", "bin"

    # create and add manifest
    dest = File.join D_INSTALL, 'bin', 'ruby_builtin_dlls'
    Dir.mkdir dest unless Dir.exist? dest
    create_manifest dll_files, dest

    # copy bin/ dll's
    puts "#{'installing dll files:'.ljust(COL_WID)}FROM #{msys2_dll_bin_path}"
    dll_files.each { |fn|
      orig = File.join msys2_dll_bin_path, fn
      if File.exist? orig
        puts "#{COL_SPACE}#{fn}"
        IO.copy_stream orig, File.join(dest, fn)
      else
        puts "#{COL_SPACE}ERROR: #{File.basename(orig)} does not exist"
      end
    }
    dll_dirs = lib_files.map{ | fn| File.dirname(fn) }.uniq
    dll_dirs.each { |d|
      src = File.join D_MSYS2, "mingw#{ARCH}", "lib", d
      if Dir.exist?(src)
        dest = File.join D_INSTALL, "lib", d
        Dir.mkdir dest unless Dir.exist? dest
        `xcopy /s /q #{src.gsub('/', '\\')} #{dest.gsub('/', '\\')}`
        puts "#{COL_SPACE}Copy dir #{d}"
      else
        puts "#{COL_SPACE}ERROR: Dir #{src} does not exist"
      end
    }
  end

  # Adds private assembly data to ruby.exe and rubyw.exe files
  def add_priv_assm
    libruby_regex = /msvcrt-ruby\d+\.dll$/i
    bin_dir = File.join D_INSTALL, "bin"
    Dir.chdir(bin_dir) { |d|
      libruby = Dir['*.dll'].grep(libruby_regex)[0]
      new = <<-EOT
  <dependency>
    <dependentAssembly>
      <assemblyIdentity version='1.0.0.0' type='win32' name='ruby_builtin_dlls'/>
    </dependentAssembly>
  </dependency>
  <file name='#{libruby}'/>
EOT
      ['ruby.exe', 'rubyw.exe'].each { |fn|
        image = File.binread(fn)
        image.gsub!(/<\?xml.*?<assembly.*?<\/assembly>\s+/m) { |m|
          orig_len = m.bytesize
          newm = m.gsub(/^\s*<\/assembly>/, "#{new}</assembly>")
          # shorten to match original
          newm.gsub!(/<!--The ID below indicates application support for/, '<!--') if newm.bytesize > orig_len
          newm.gsub!(/^ *<!--.*?-->\n/m, "")                if newm.bytesize > orig_len
          newm.gsub!(/^ +/, "")                             if newm.bytesize > orig_len
          raise "replacement manifest too big #{m.bytesize} < #{newm.bytesize}" if m.bytesize < newm.bytesize
          newm + " " * (orig_len - newm.bytesize)
        }
        File.binwrite(fn, image)
      }
    }
  end

  def add_rb_readline
    src = File.join D_RL, "lib"
    pkg_dest = File.join D_INSTALL, 'lib', 'ruby', 'site_ruby'
    Dir.mkdir pkg_dest unless Dir.exist? pkg_dest
    `xcopy /s /q #{src.gsub('/', '\\')} #{pkg_dest.gsub('/', '\\')}`
  end

  def copy_ssl_files
    Dir.chdir(D_RI2) { |d|
      require_relative "rubyinstaller2/lib/ruby_installer/build/ca_cert_file.rb"
      require_relative "rubyinstaller2/lib/ruby_installer/build/gem_version.rb"
      ca_file = RubyInstaller::Build::CaCertFile.new
      File.binwrite("resources/ssl/cacert.pem", ca_file.content)
      Dir.mkdir "#{D_INSTALL}/ssl"
      Dir.mkdir "#{D_INSTALL}/ssl/certs"
      IO.copy_stream "./resources/ssl/cacert.pem", "#{D_INSTALL}/ssl/cert.pem"
      puts "#{'installing ssl files:'.ljust(COL_WID)}cert.pem"

      src = File.join D_MSYS2, "mingw#{ARCH}", "ssl", "openssl.cnf"
      if File.exist?(src)
        IO.copy_stream src, "#{D_INSTALL}/ssl/openssl.cnf"
        puts "#{COL_SPACE}openssl.cnf"
      end

      IO.copy_stream "./resources/ssl/README-SSL.md", "#{D_INSTALL}/ssl/README-SSL.md"
      puts "#{COL_SPACE}README-SSL.md"
      IO.copy_stream "./resources/ssl/c_rehash.rb", "#{D_INSTALL}/ssl/c_rehash.rb"
      puts "#{COL_SPACE}certs\\c_rehash.rb"
    }
  end

  def add_licenses
    IO.copy_stream("#{D_RUBY}/LEGAL"     , "#{D_INSTALL}/LEGAL Ruby")
    IO.copy_stream("#{D_RI2}/LICENSE.txt", "#{D_INSTALL}/LICENSE Ruby Installer.txt")
  end

  # Creates manifest xml file
  # @param dlls [Array<String>] file list
  # @param dest [Array<String>] dest dir for manifest file
  def create_manifest(dlls, dest)
    manifest = +"<?xml version='1.0' encoding='UTF-8' standalone='yes'?>\n" \
               "<assembly xmlns='urn:schemas-microsoft-com:asm.v1' manifestVersion='1.0'>\n" \
               "  <assemblyIdentity type='win32' name='ruby_builtin_dlls' version='1.0.0.0'/>\n"
    dlls.each { |fn| manifest << "  <file name='#{File.basename(fn)}'/>\n" }
    manifest << "</assembly>\n"
    File.open( File.join(dest, 'ruby_builtin_dlls.manifest'), 'wb') { |f| f << manifest }
  end

  def find_dlls(pkgs, pkg_pre)
    pacman = File.join D_MSYS2, "usr/bin/pacman"
    re_dep = /^Depends On +: +([^\r\n]+)/i
    re_bin = /\A\/mingw#{ARCH}\/bin\//i
    re_lib = /\A\/mingw#{ARCH}\/lib\//i
    bin_dlls = []
    lib_dlls = []
    pkg_files_added = []
    # add correct package prefix
    pkgs = pkgs.split(' ').map { |e| "#{pkg_pre}-#{e}"}

    while !pkgs.empty? do
      depends = []
      files = `#{pacman} -Ql #{pkgs.join(' ')}`
      files.scan(/\S+.dll$/) { |dll|
        if    re_bin =~ dll ; bin_dlls << dll.sub(re_bin, '')
        elsif re_lib =~ dll ; lib_dlls << dll.sub(re_lib, '')
        else
          puts "#{dll.ljust(COL_WID)} Unknown dll location!"
        end
      }
      pkg_files_added += pkgs
      if info = `#{pacman} -Qi #{pkgs.join(' ')}`
        info.scan(re_dep) { |dep|
          next if /\ANone/ =~ dep[0]
          depends += dep[0].split(/\s+/)
        }
        if depends && !depends.empty?
          depends.uniq!
          depends.reject! { |e| pkg_files_added.include?(e) }
          unless depends.empty?
            stdin, stdout, stderr = Open3.popen3("#{pacman} -Q #{depends.join(' ')}")
            errs = stderr.read
            stdin.close ; stdout.close ; stderr.close
            if errs && !errs.strip.empty?
              errs.scan(/'([^']+)'/) { |e|
                depends[depends.index(e[0])] += '-git'
              }
            end
          end
        end
      end
      pkgs = depends
    end
    [ ( bin_dlls.uniq.sort || [] ), ( lib_dlls.uniq.sort || [] ) ]
  end

end
end
PostInstall2.run
