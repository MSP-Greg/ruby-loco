# frozen_string_literal: true

#require_relative File.join(__dir__, 'install_dll_info.rb')
require('open3')

# Handles dll files, private assembly tasks, & manifest details.
#
module InstallPost

  COL_WID = 36
  COL_SPACE = ' ' * COL_WID

  # ruby name like ruby25_64
#  @@pkg_name = ARGV[0]
  @@pkg_name = "ruby#{ENV['SUFFIX']}"
  # 32 or 64
  @@arch = @@pkg_name[-2,2]

  @@carch = @@arch == '64' ? 'x86_64' : 'i686'
  # path to root ruby install dir
  @@pkg_path = File.join(__dir__, 'pkg', @@pkg_name, @@pkg_name)

  def self.run
    copy_dll_files
    copy_ssl_files
    add_priv_assm
    add_rb_readline
    add_licenses
  end

  private

  # Copies correct dll files from mys location to package dir.
  def self.copy_dll_files
    pkg_pre = (@@arch == '64' ? 'mingw-w64-x86_64' : 'mingw-w64-i686')
    # pkgs = 'gcc-libs gdbm libffi openssl readline zlib'
    pkgs = 'gcc-libs gdbm libffi openssl readline zlib'
    dll_files, lib_files = find_dlls(pkgs, pkg_pre)

    # get mingw bin path for arch
    msys2_dll_bin_path = File.join(ENV['MSYS2_DIR'].gsub('\\', "/"), "mingw#{@@arch}", "bin")

    # create side-by-side directory and add manifest xml file
    dest = File.join(__dir__, 'pkg', @@pkg_name, @@pkg_name, 'bin', 'ruby_builtin_dlls').gsub('/', '\\')
    `mkdir #{dest}` unless Dir.exist?(dest)
    create_manifest(dll_files, dest)

    # copy bin/ dll's
    puts "installing dll files:         FROM #{msys2_dll_bin_path}"
    dll_files.each { |fn|
      orig = File.join(msys2_dll_bin_path, fn).gsub('/', '\\')
      if File.exist?(orig)
        puts "#{COL_SPACE}#{fn}"
        `copy /b /y "#{orig}" #{dest}`
      else
        puts "#{COL_SPACE}ERROR: #{File.basename(orig)} does not exist"
      end
    }
    dll_dirs = lib_files.map{ | fn| File.dirname(fn) }.uniq 
    dll_dirs.each { |d|
      src = File.join(ENV['MSYS2_DIR'].gsub('\\', "/"), "mingw#{@@arch}", "lib", d)
      if Dir.exist?(src)
        dest = File.join(__dir__, 'pkg', @@pkg_name, @@pkg_name, "lib", d)
        `mkdir #{dest.gsub('/', '\\')}` unless Dir.exist?(dest)
        `xcopy /s /q #{src.gsub('/', '\\')} #{dest.gsub('/', '\\')}`
        puts "#{COL_SPACE}Copy dir #{d}"
      else
        puts "#{COL_SPACE}ERROR: Dir #{src} does not exist"
      end
    }
  end

  # Copies SSL files
  def self.copy_ssl_files
    repo_ri2_nix = ENV['REPO_RI2'].gsub(/\\/, '/')
    Dir.chdir(repo_ri2_nix) { |d|
      patch = `patch -p1 -N --no-backup-if-mismatch -i #{__dir__}/patches/__lib-ruby_installer-build-ca_cert_file.rb.patch`
      puts "#{COL_SPACE}#{patch}"
      require("#{repo_ri2_nix}/lib/ruby_installer/build/ca_cert_file.rb")
      require("#{repo_ri2_nix}/lib/ruby_installer/build/gem_version.rb")
      ca_file = RubyInstaller::Build::CaCertFile.new
      File.binwrite("resources/ssl/cacert.pem", ca_file.content)
#      `rake ssl:update`
      pkg_ruby = @@pkg_path.gsub('/', '\\')
      `md #{pkg_ruby}\\ssl`
      `md #{pkg_ruby}\\ssl\\certs`
      `copy /b /y resources\\ssl\\cacert.pem    #{pkg_ruby}\\ssl\\cert.pem`
      puts "installing ssl files:         cert.pem"
      src = File.join(ENV['MSYS2_DIR'].gsub('\\', "/"), "mingw#{@@arch}", "ssl", "openssl.cnf")
      if File.exist?(src)
        `copy /b /y #{src.gsub('/', '\\')} #{pkg_ruby}\\ssl\\openssl.cnf`
        puts "#{COL_SPACE}openssl.cnf"
      end
      if Dir.exist?("C:/SSL")
        `copy /b /y resources\\ssl\\cacert.pem    C:\\SSL\\cacert.pem`
      end
      `copy /b /y resources\\ssl\\README-SSL.md #{pkg_ruby}\\ssl\\README-SSL.md`
      puts "#{COL_SPACE}README-SSL.md"
      `copy /b /y resources\\ssl\\c_rehash.rb   #{pkg_ruby}\\ssl\\certs\\`
      puts "#{COL_SPACE}certs\\c_rehash.rb"
      `copy /b /y #{ENV['%MSYS2_DIR']}\\mingw64\\openssl.cnf #{pkg_ruby}\\ssl\\`
    }
  end

  # Creates manifest xml file
  # @param dlls [Array<String>] file list
  # @param dest [Array<String>] dest dir for manifest file
  def self.create_manifest(dlls, dest)
    manifest = String.new("<?xml version='1.0' encoding='UTF-8' standalone='yes'?>\n" \
               "<assembly xmlns='urn:schemas-microsoft-com:asm.v1' manifestVersion='1.0'>\n" \
               "  <assemblyIdentity type='win32' name='ruby_builtin_dlls' version='1.0.0.0'/>\n")
    dlls.each { |fn| manifest << "  <file name='#{File.basename(fn)}'/>\n" }
    manifest << "</assembly>\n"
    File.open( File.join(dest, 'ruby_builtin_dlls.manifest'), 'wb') { |f| f << manifest }
  end

  # Adds private assembly data to ruby.exe and rubyw.exe files
  def self.add_priv_assm
    libruby_regex = /msvcrt-ruby\d+\.dll$/i
    bin_dir = File.join(__dir__, 'pkg', @@pkg_name, @@pkg_name, 'bin')
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

  def self.add_licenses
    IO.copy_stream("#{ENV['REPO_RUBY']}/LEGAL"     , "#{ENV['PKG_RUBY']}/LEGAL Ruby")
    IO.copy_stream("#{ENV['REPO_RI2']}/LICENSE.txt", "#{ENV['PKG_RUBY']}/LICENSE Ruby Installer.txt")
  end
  
  def self.add_rb_readline
    src = File.join(ENV['REPO_RB-RL'].gsub('\\', "/"), "lib").gsub('/', '\\')
    pkg_dest = File.join(@@pkg_path, 'lib', 'ruby', 'site_ruby').gsub('/', '\\')
    `mkdir #{pkg_dest}` unless Dir.exist?(pkg_dest)
    `xcopy /s /q #{src} #{pkg_dest}`
  end

  def self.find_dlls(pkgs, pkg_pre)
    pacman = "#{ENV['MSYS2_DIR']}\\usr\\bin\\pacman"
    re_dep = /^Depends On +: +([^\r\n]+)/i
    re_bin = /\A\/mingw#{@@arch}\/bin\//i
    re_lib = /\A\/mingw#{@@arch}\/lib\//i
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
InstallPost.run
