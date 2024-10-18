# frozen_string_literal: true
# Code by MSP-Greg

require 'fileutils'

module PostInstall3
  case ENV['MSYSTEM']
  when 'UCRT64'
    D_INSTALL = File.join __dir__, 'ruby-ucrt'
  when 'MINGW32'
    D_INSTALL = File.join __dir__, 'ruby-mingw32'
  else
    D_INSTALL = File.join __dir__, 'ruby-mingw'
  end

  COL_WID = 36
  COL_SPACE = ' ' * COL_WID

  D_MSYS2 = ENV['D_MSYS2']
  D_RI2   = File.join __dir__, 'rubyinstaller2'
  # -REMOVE rbreadline- D_RL    = File.join __dir__, 'ruby_readline'
  D_RUBY  = File.join __dir__, 'ruby'

  # internal version like 2.5.0
  ABI = RbConfig::CONFIG["ruby_version"]

  REWRITE_MARK = /^( *)module Build.*Use for: Build, Runtime/

  # Files to copy from RI2 repo to ruby package / install dir
  RI2_FILES = [
    ["bin", %w|
      resources/files/ridk.cmd
      resources/files/ridk.ps1
      resources/files/setrbvars.cmd | ],

    ["lib/ruby/#{ABI}/rubygems/defaults", %w|
      resources\files\operating_system.rb | ],

    ["lib/ruby/site_ruby/#{ABI}", %w|
      resources\files\irbrc_predefiner.rb | ],
  ]
  BINDIR = RbConfig::CONFIG['bindir']
  TOPDIR = RbConfig::TOPDIR
  # path to site_ruby dir
  SITE_RUBY = File.join TOPDIR, 'lib', 'ruby', 'site_ruby', ABI

class << self

  def run
    add_ri2
    add_ri2_site_ruby
    generate_version_file
    update_gems
  end

  private

  # Add files defined in {RI2_FILES} from RI2
  def add_ri2
    puts "#{'installing RubyInstaller2:'.ljust(COL_WID)}From #{D_RI2}"
    Dir.chdir(TOPDIR) { |d|
      RI2_FILES.each { |i|
        dest_dir = File.join(TOPDIR, i[0])
        FileUtils.mkdir_p dest_dir unless Dir.exist?(dest_dir)
        i[1].each { |fn|
          fp = "#{D_RI2}/#{fn}"
          if File.exist?(fp)
            puts "#{COL_SPACE}#{fn}"
            #`copy /b /y #{fp.gsub('/', '\\')} #{i[0]}`
            FileUtils.cp fp, dest_dir, preserve: true
          else
            puts "#{COL_SPACE}#{fn} DOES NOT exist!"
          end
        }
      }
      #Dir.chdir("lib/ruby/#{ABI}/rubygems/defaults") { |d|
      #  patch_exe = File.join D_MSYS2, "usr", "bin", "patch.exe"
      #  patch = `#{patch_exe} -p1 -N --no-backup-if-mismatch -i #{__dir__}/patches/__operating_system.rb.patch`
      #  puts "#{COL_SPACE}#{patch}"
      #}
    }
  end

  # Adds files to ruby_installer/runtime dir
  def add_ri2_site_ruby
    src = File.join(D_RI2, 'lib') # .gsub('/', '\\') # + "\\"
    site_ruby = SITE_RUBY # .gsub('/', '\\')
    puts "#{'installing RI2 runtime files:'.ljust(COL_WID)}From #{src}"
    puts "#{COL_SPACE}To   #{site_ruby}"
    # copy everything over to pkg/install dir
    #`xcopy /s /q /y #{src} #{site_ruby}`
    FileUtils.copy_entry src, site_ruby, preserve: true
    # now, loop thru build dir, and move to runtime
    Dir.chdir( File.join(SITE_RUBY, 'ruby_installer') ) { |d|
      Dir.glob('build/*.rb').each { |fn|
        f_str = File.binread(fn)
        if f_str.sub!(REWRITE_MARK, '\1module Runtime # Rewrite')
          puts "#{COL_SPACE}rewrite #{fn[6..-1]}"
          File.open( File.join( 'runtime', fn[6..-1]), 'wb') { |f| f << f_str }
        end
      }
      `rd /s /q build`
      puts "#{COL_SPACE}deleting build dir"
    }
  end

  # Creates ruby_installer/runtime/package_version.rb file
  def generate_version_file
    ri2_vers = ''
    commit = ''
    Dir.chdir(D_RI2) {
      commit   = `git rev-parse HEAD`[0,7]
      if (str = File.binread( File.join('.', 'packages', 'ri', 'Rakefile') )[/^[ \t]*ruby_arch_packages[ \t]*=[^\n]*\n[ \t]*%w\[([\d .-]+)/,1])
        ri2_vers = str.split[-1]
      else
        ri2_vers = `git tag --list "rubyinstaller-[0-9]*"`[/^rubyinstaller-(\S+)\Z/, 1]
      end
    }
    puts "#{'creating package_version.rb:'.ljust(COL_WID)}#{ri2_vers}  commit #{commit}"
    puts "#{COL_SPACE}#{commit}"

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

  # No changes to trunk/master
  def update_gems
    require 'rubygems'
    require 'rubygems/gem_runner'
    suffix = %w[--no-document --env-shebang --silent --norc]
    if RUBY_DESCRIPTION.include? 'master'
      # added as of r65509
      # Gem::GemRunner.new.run(%w[install bundler] + suffix)
    else
      # Gem::GemRunner.new.run %w[uninstall rubygems-update -x]
      # rdoc won't update without UI confirmation of bin directory file replacement ?
      Gem::GemRunner.new.run(%w[update minitest power_assert rake rdoc test-unit] + suffix)
      if RUBY_VERSION.start_with? '2.4'
        Gem::GemRunner.new.run(%w[update did_you_mean] + suffix)
      elsif RUBY_VERSION.start_with? '2.3'
        Gem::GemRunner.new.run(%w[install did_you_mean:1.0.3] + suffix)
      end
      Gem::GemRunner.new.run %w[cleanup]
      if RUBY_VERSION < "2.6"
        Gem::GemRunner.new.run(%w[install bundler] + suffix)
      end
    end
    # clean empty gem folders, needed as of 2019-10-20
    ary = Dir["#{Gem.dir}/gems/*"]
    ary.each { |d| Dir.rmdir(d) if Dir.empty?(d) }
  end

end
end
PostInstall3.run
