# frozen_string_literal: true
# encoding: UTF-8

# Copies & processes files in RubyInstaller2 repo to install/package dir.
# Also cleans files in bin directory of artifacts like #!/usr/bin/env.
# Requires ENV['SUFFIX'] and ENV['REPO_RI2'], also assumes git is in path.
# @note Must be run from newly built ruby
#
module InstallPostRI2

  # 32 or 64, maybe use RbConfig::CONFIG["target_cpu"] == 'x64' ? '64' : '32'
  ARCH = ENV['SUFFIX'][-2,2]

  # rubyinstaller2 git dir
  REPO_RI2 = ENV['REPO_RI2']

  # internal version like 2.5.0
  R_VERS_INT = RbConfig::CONFIG["ruby_version"]

  REWRITE_MARK = /^( *)module Build.*Use for: Build, Runtime/

  # Files to copy from RI2 repo to ruby package / install dir
  RI2_FILES = [
    ["bin", %w|
      resources\files\ridk.cmd
      resources\files\ridk.ps1
      resources\files\setrbvars.cmd | ],

    ["lib\\ruby\\#{R_VERS_INT}\\rubygems\\defaults", %w|
      resources\files\operating_system.rb | ],

    ["lib\\ruby\\site_ruby\\#{R_VERS_INT}", %w|
      resources\files\irbrc_predefiner.rb | ],
  ]
  BINDIR = RbConfig::CONFIG['bindir']
  TOPDIR = RbConfig::TOPDIR
  # path to site_ruby dir
  SITE_RUBY = File.join(TOPDIR, 'lib', 'ruby', 'site_ruby', R_VERS_INT)
  
  # Array of regex and strings for bin file cleanup
  # 1st element for full path ruby
  # 2nd element for odd path ruby seen in rake.bat
  # 3rd element for generic "ruby.exe" (e.g. RubyGems update --system)
  CLEAN_INFO = [
    [ /^@"#{Regexp.escape(BINDIR.gsub("/", "\\"))}\\ruby\.exe"/u, '@%~dp0ruby.exe'],
    [ /^@"\\ruby#{ENV['SUFFIX']}\\bin\\ruby.exe"/u              , '@%~dp0ruby.exe'],
    [ /^@"ruby.exe"/u                                           , '@%~dp0ruby.exe'],
    [ /"#{Regexp.escape(BINDIR)}\/([^ "]+)"/u      , '%~dp0\1'],
    [ /^#!(\/usr\/bin\/env|\/mingw#{ARCH}\/bin\/)/u, '#!'     ],
    [ /\r/, '']
  ]

  def self.run
    add_ri2
    add_ri2_site_ruby
    generate_version_file
    clean_bin_files
  end

  private

  # Add files defined in {RI2_FILES} from RI2
  def self.add_ri2
    puts "installing RubyInstaller2:    From #{REPO_RI2}"
    Dir.chdir(TOPDIR) { |d|
      RI2_FILES.each { |i|
        unless Dir.exist?(i[0])
          `mkdir #{i[0]}`
        end
        i[1].each { |fn|
          fp = "#{REPO_RI2}/#{fn}"
          if File.exist?(fp)
            puts "#{' ' * 30}#{fn}"
            `copy /b /y #{fp.gsub('/', '\\')} #{i[0]}`
          else
            puts "#{' ' * 30}#{fn} DOES NOT exist!"
          end
        }
      }
      Dir.chdir("lib/ruby/#{R_VERS_INT}/rubygems/defaults") { |d|
        patch = `patch -p1 -N --no-backup-if-mismatch -i #{__dir__}/patches/__operating_system.rb.patch`
        puts "#{' ' * 30}#{patch}"
      }
    }
  end

  # Adds files to ruby_installer/runtime dir
  def self.add_ri2_site_ruby
    src = File.join(REPO_RI2, 'lib').gsub('/', '\\') # + "\\"
    site_ruby = SITE_RUBY.gsub('/', '\\')
    puts "installing RI2 runtime files: From #{src}"
    puts "                              To   #{site_ruby}"
    # copy everything over to pkg dir
    `xcopy /s /q /y #{src} #{site_ruby}`
    # now, loop thru build dir, and move to runtime
    Dir.chdir( File.join(SITE_RUBY, 'ruby_installer') ) { |d|
      Dir.glob('build/*.rb').each { |fn|
        f_str = File.binread(fn)
        if f_str.sub!(REWRITE_MARK, '\1module Runtime # Rewrite')
          puts "#{' ' * 30}rewrite #{fn[6..-1]}"
          File.open( File.join( 'runtime', fn[6..-1]), 'wb') { |f| f << f_str }
        end
      }
      `rd /s /q build`
      puts "#{' ' * 30}deleting build dir"
    }
  end

  # Creates ruby_installer/runtime/package_version.rb file
  def self.generate_version_file
    ri2_vers = ''
    commit = ''
    Dir.chdir(REPO_RI2) {
      ri2_vers = File.binread( File.join('packages', 'rubyinstaller', 'Rakefile') )[/^[ \t]*ruby_packages[ \t]*=[ \t]*%w\[([^\s\]]+)/,1]
      commit   = `#{ENV['GIT']} rev-parse HEAD`[0,7]
      ri2_vers = `#{ENV['GIT']} tag`[/^\S+\Z/] unless ri2_vers
    }
    puts "creating package_version.rb:  #{ri2_vers}  commit #{commit}"
    puts "#{' ' * 30}#{commit}"

    f_str = <<~EOT
    module RubyInstaller
      module Runtime
        PACKAGE_VERSION = "ruby-loco RI2 #{ri2_vers}"
        GIT_COMMIT = "#{commit}"
      end
    end
    EOT
    dest = File.join(SITE_RUBY, 'ruby_installer', 'runtime', 'package_version.rb')
    File.binwrite(dest, f_str)
  end

  # Cleans files in bin dir of items like #!/usr/bin/env ruby
  def self.clean_bin_files
    Dir.chdir(BINDIR) { |d|
      `attrib -r /s /d`
      files = Dir.glob("*").reject { |fn| fn.end_with?('.dll', '.exe') || Dir.exist?(fn) }
      files.each { |fn|
        str = File.read(fn, mode: 'rb').encode('UTF-8')
        wr = nil
        CLEAN_INFO.each { |i| wr = str.gsub!(i[0], i[1]) ? true : wr }
        File.write(fn, str.encode('UTF-8'), mode: 'wb:UTF-8') if wr
      }
    }
  end

end
InstallPostRI2.run
