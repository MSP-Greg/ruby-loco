# frozen_string_literal: true

# Copies & processes files in RubyInstaller2 repo to install/package dir.
# Also cleans files in bin directory of artifacts like #!/usr/bin/env.
# Requires ENV['SUFFIX'] and ENV['REPO_RI2'], also assumes git is in path.
#
module InstallPostRI2

  # ruby name like ruby25_64
#  @@pkg_name = ARGV[0]
  @@pkg_name = "ruby#{ENV['SUFFIX']}"
  # 32 or 64
  @@arch = @@pkg_name[-2,2]

  # rubyinstaller2 git dir
  @@repo_ri2 = ENV['REPO_RI2']

  # internal version like 2.5.0
  @@r_vers_int = "#{@@pkg_name[4..-4].sub(/\d/, '\0.')}.0"
  # path to root ruby install dir
  @@pkg_path = File.join(__dir__, 'pkg', @@pkg_name, @@pkg_name)
  # path to site_ruby dir
  @@site_ruby_rb = File.join(@@pkg_path, 'lib', 'ruby', 'site_ruby', @@r_vers_int)

  REWRITE_MARK = /^( *)module Build.*Use for: Build, Runtime/

  # Files to copy from RI2 repo to ruby package / install dir
  RI2_FILES = [
    ["bin", %w|
      resources\files\ridk.cmd
      resources\files\ridk.ps1
      resources\files\setrbvars.cmd | ],

    ["lib\\ruby\\#{@@r_vers_int}\\rubygems\\defaults", %w|
      resources\files\operating_system.rb | ],

    ["lib\\ruby\\site_ruby\\#{@@r_vers_int}", %w|
      resources\files\irbrc_predefiner.rb | ],
  ]

  bin_frwd = Regexp.new(Regexp.escape("#{__dir__}/pkg/#{@@pkg_name}/#{@@pkg_name}/bin/"))
  bin_back = Regexp.new(Regexp.escape("#{(__dir__).gsub(/\//, '\\')}\\pkg\\#{@@pkg_name}\\#{@@pkg_name}\\bin\\"))
  # Array of regex and strings for bin file cleanup
  CLEAN_INFO = [
    [ Regexp.new("^" + Regexp.escape("#!/#{@@pkg_name}/bin/" )), '#!'],
    [ Regexp.new("^" + Regexp.escape("#!/usr/bin/env"        )), '#!'],
    [ Regexp.new("^" + Regexp.escape("#!/mingw#{@@arch}/bin/")), '#!'],
    [ Regexp.new("^@" + Regexp.escape("\"\\#{@@pkg_name}\\bin\\ruby.exe\"")), 'ruby.exe'],
    [ Regexp.new(Regexp.escape("\"#{__dir__}/pkg/#{@@pkg_name}/#{@@pkg_name}/bin/rake\"")), 'rake'],
    [ bin_frwd, ''],
    [ bin_back, '']
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
    puts "installing RubyInstaller2:    From #{@@repo_ri2}"
    Dir.chdir(@@pkg_path) { |d|
      RI2_FILES.each { |i|
        unless Dir.exist?(i[0])
          `mkdir #{i[0]}`
        end
        i[1].each { |fn|
          fp = "#{@@repo_ri2}/#{fn}"
          if File.exist?(fp)
            puts "#{' ' * 30}#{fn}"
            `copy /b /y #{fp.gsub('/', '\\')} #{i[0]}`
          else
            puts "#{' ' * 30}#{fn} DOES NOT exist!"
          end
        }
      }
      Dir.chdir("lib/ruby/#{@@r_vers_int}/rubygems/defaults") { |d|
        patch = `patch -p1 -N --no-backup-if-mismatch -i #{__dir__}/patches/__operating_system.rb.patch`
        puts "#{' ' * 30}#{patch}"
      }
    }
  end

  # Adds files to ruby_installer/runtime dir
  def self.add_ri2_site_ruby
    src = File.join(@@repo_ri2, 'lib').gsub('/', '\\') # + "\\"
    site_ruby = @@site_ruby_rb.gsub('/', '\\')
    puts "installing RI2 runtime files: From #{src}"
    puts "                              To   #{site_ruby}"
    # copy everything over to pkg dir
    `xcopy /s /q /y #{src} #{site_ruby}`
    # now, loop thru build dir, and move to runtime
    Dir.chdir( File.join(@@site_ruby_rb, 'ruby_installer') ) { |d|
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
    Dir.chdir(@@repo_ri2) {
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
    dest = File.join(@@site_ruby_rb, 'ruby_installer', 'runtime', 'package_version.rb')
    File.binwrite(dest, f_str)
  end

  # Cleans files in bin dir of items like #!/usr/bin/env ruby
  def self.clean_bin_files
    Dir.chdir(File.join(@@pkg_path, "bin")) { |d|
      `attrib -r /s /d`
      files = Dir.glob("*").reject { |fn| fn.end_with?('.dll', '.exe') || Dir.exist?(fn) }
      files.each { |fn|
        str = File.binread(fn)
        CLEAN_INFO.each { |i| str.gsub!(i[0], i[1]) }
        File.binwrite(fn, str)
      }
    }
    pkg_path = @@pkg_path.gsub(/\//, "\\")      # to win style
  end

end
InstallPostRI2.run
