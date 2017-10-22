# frozen_string_literal: true

require 'rubygems'
require 'rubygems/gem_runner'
require 'rubygems/package'

# See ruby tool/gem-unpack.rb
#
# This method is used by "make extract-gems" to unpack bundled gem files.
#
# Unlike the gem unpack command, it correctly unpacks the gemspec file.
# Corrects problems with spec.files & spec.test_files using things like
# git ls-files or grep

def Gem.unpack(file, dir = nil)
  pkg = Gem::Package.new(file)
  spec = pkg.spec
  target = spec.full_name
  target = File.join(dir, target) if dir
  pkg.extract_files target
  spec_file = File.join(target, "#{spec.name}.gemspec")
  open(spec_file, 'wb') do |f|
    f.print spec.to_ruby
  end
  puts "gem unpacked #{file}"
end

module Prepare  

  @@r_inst_dir = "ruby#{ENV['R_VERS_2']}_#{ ENV['MINGW_INSTALLS'][-2,2]}"
  @@arch = @@r_inst_dir[-2,2]

  class << self  

    def run
      @@r_vers_int = vers_str_2_int(ENV['R_VERS'])
      check_openssl
      copy_spec if @@r_vers_int < 20500
      `attrib -r %REPO_RUBY%\\spec\\*.* /s /d`
      apply_patches
      clean_repo
      add_gems
    end

    private

    # Cleans and refreshes bundled gems
    def add_gems
      b_gem_dir = File.join(__dir__, 'src', 'ruby', 'gems')
      hsh = Hash.new
      
      # get list of bundled gems and delete incorrect items or versions
      Dir.chdir(b_gem_dir) { |d|
        # load hash with key of full name ie, 'did_you_mean-1.1.0', and value
        # of array with [name, vers]
        File.open( 'bundled_gems', 'rb') { |f|
          f.read.each_line { |l|
            ary = l.strip.split(/\s+/)
            ary.pop if ary.length == 3
            hsh[ary[0].join('-')] = ary
          }
        }

        # need to loop thru existing files in gems and delete any that aren't needed
        gem_files = Dir["*.gem"]
        gem_dirs  = Dir["*/"]
        gem_files.each { |f|
          f_name = f.sub(/\.gem/, '')
          `del #{f}` unless hsh.key?(f_name)
        }
        gem_dirs.each { |d|
          d_name = d.sub(/\//, '')
          `rd /s /q #{d_name}`unless hsh.key?(d_name)
        }
      }

      # check for, and add (if needed) all required gems
      `md bundled_gems` unless Dir.exist?('bundled_gems')
      Dir.chdir(File.join(__dir__, 'bundled_gems') ) { |dir|
        win_b_gem_dir = b_gem_dir.gsub(/\//, '\\')
        hsh.each { |k,v|
          # see if they exist already
          next if File.exist?( File.join(b_gem_dir, "#{k}.gem") ) &&
            Dir.exist?( File.join(b_gem_dir, k) )
          unless File.exist?("#{k}.gem") && Dir.exist?(k)
            # need to get gem
            runner ||= Gem::GemRunner.new
            begin
              puts "gem fetch #{v[0]} -v #{v[1]}"
              runner.run ['fetch' , v[0], '-v',  v[1]]
              Gem.unpack("#{k}.gem")
#              puts "gem unpack #{k}"
#              runner.run ['unpack', "#{k}.gem"]
            rescue
              puts "Issue with bundled gem #{k}"
              next
            end
          end
          `copy #{k}.gem #{win_b_gem_dir}`
          unless Dir.exist? File.join(b_gem_dir, k)
            # puts "md #{win_b_gem_dir}\\#{k}"
            `md #{win_b_gem_dir}\\#{k}` 
          end
          # puts "xcopy /s /q #{k} #{win_b_gem_dir}\\#{k}"
          `xcopy /s /q #{k} #{win_b_gem_dir}\\#{k}`
        }
      }
    end

    # Reads patch dir, applies patches
    def apply_patches
      
      raise ArgumentError, "Argument must 32 or 64" unless @@arch == '32' || @@arch == '64'
      # puts "Dir.pwd #{Dir.pwd}"

      ENV['PATH'] += "#{File::PATH_SEPARATOR}#{File.join(__dir__, 'git', 'cmd')}"

      Dir.chdir('src/ruby') { |dir|
        # collect patches and apply
        patches = Dir["#{__dir__}/patches/{[^_],#{@@arch}/[^_]}*.patch"]
        # 
        patches.concat(vers_patches)
        patches.sort_by! { |p| File.basename(p) }
        patches.each { |p|
          puts "#{'- ' * 25} #{File.basename(p)}" 
          puts `patch -p1 -N --no-backup-if-mismatch -i #{p}`
        }
        puts ''  # just for formatting of prepare.log
      }
    end

    # Checks mingw openssl version.  If needed, swaps to correct version
    def check_openssl
      puts "OpenSSL - checking  package version..."
      arch = (@@arch == '32' ? 'i686' : 'x86_64')
      t = `pacman -Qs mingw-w64-#{arch}-openssl`.strip
      if t && !t.empty?
        vers = vers_str_2_int(t.strip.split(' ')[1])
        vers_old = "#{ENV['MSYS2_DIR_U']}/var/cache/pacman/pkg/mingw-w64-#{arch}-openssl-#{ENV['OPENSSL_102']}-any.pkg.tar.xz"
        vers_new = "#{ENV['MSYS2_DIR_U']}/var/cache/pacman/pkg/mingw-w64-#{arch}-openssl-#{ENV['OPENSSL_110']}-any.pkg.tar.xz"
        if @@r_vers_int >= 20400 && vers < 10100
          # swap to 1.1.0
          puts `pacman -Rdd --noconfirm mingw-w64-#{arch}-openssl`
          puts `pacman -Udd --noconfirm --force #{vers_new}`
        elsif @@r_vers_int < 20400 && vers >= 10100
          # swap to 1.0.2
          puts `pacman -Rdd --noconfirm mingw-w64-#{arch}-openssl`
          puts `pacman -Udd --noconfirm --force #{vers_old}`
        end
      else
        if @@r_vers_int >= 20400
          puts `pacman -Udd --noconfirm --force #{vers_new}`
        else
          puts `pacman -Udd --noconfirm --force #{vers_old}`
        end
      end
      puts "OpenSSL - done"
    end

    # Cleans previous build artifacts from ruby repo, all are accounted for in
    # .gitignore.
    #
    def clean_repo
      Dir.chdir( 'src/ruby') { |dir|
#        ruby_files   = %w[ configure tool\\config.guess tool\\config.sub ]
        ruby_files   = %w[ configure ]
        
        ruby_folders = %w[ autom4te.cache ]   # enc\\unicode\\data
        
        ruby_files.each   { |f|
          if File.exist?(f)
            puts "Deleting file   #{f}"
            `del /q #{f}`
          end
        }
        ruby_folders.each { |f|
          if Dir.exist?(f)
            puts "Deleting folder #{f}"
            `rd /s /q #{f}`
          end
        }
      }
      if Dir.exist?("src/build-#{@@arch}")
        `rd /s /q src\\build-#{@@arch}`
      end
      # clean or create package dir
      if Dir.exist?("pkg\\{@@r_inst_dir}")
        `del /s /q pkg\\{@@r_inst_dir}\\*.*`
      else
        `mkdir pkg\\{@@r_inst_dir}`
      end
      puts
    end

    # Copies spec & mspec repos into ruby repo for testing
    def copy_spec
      #puts "copying rubyspec folder..."
      #`xcopy /s /q /y %REPO_SPEC%   %REPO_RUBY%\\spec\\ruby\\`
      #puts "copying mspec folder..."
      #`xcopy /s /q /y %REPO_MSPEC%  %REPO_RUBY%\\spec\\mspec\\`
      puts "xcopy /s /q /y #{__dir__.gsub(/\//, '\\')}\\spec  #{__dir__.gsub(/\//, '\\')}\\src\ruby\\spec\\"
      `xcopy /s /q /y #{__dir__.gsub(/\//, '\\')}\\spec  #{__dir__.gsub(/\//, '\\')}\\src\ruby\\spec\\`
    end

    # Adds version specific patches to patches array
    def vers_patches
      patches = []
      ary = []
      dirs = Dir.glob("#{__dir__}/patches/*").select { |f| File.directory? f }
      dirs.each { |d|
        next unless /(gte|lt)(\d+)\z/ =~ d
        ary << [ $1, $2.to_i, Dir[ File.join(d, '*.patch') ].reject { |fn| File.basename(fn).start_with?('_') } ]
      }
      ary.each { |e|
        if e[0] == 'lt' && @@r_vers_int < e[1]
          patches.concat(e[2])
        elsif e[0] == 'gte' && @@r_vers_int >= e[1]
          patches.concat(e[2])
        end
      }
      patches
    end

    # Returns an integer equivalent of three digit version string
    # a.b.c => 10000a + 100b + c
    def vers_str_2_int(s)
      t = s[/\A\d+\.\d+\.\d+/]  # parse to d.d.d string
      raise "Invalid version string #{s}" unless t
      t.split('.').map.with_index { |e, i| e.to_i * 100 ** (2 - i) }.sum
    end

  end
end
Prepare.run

# ENV['OPENSSL_102'] = '/e/msys64/var/cache/pacman/pkg/mingw-w64-x86_64-ruby-openssl-1.0.2.l-1-any.pkg.tar.xz'
# ENV['OPENSSL_110'] = '/e/msys64/var/cache/pacman/pkg/mingw-w64-x86_64-ruby-openssl-1.1.0.f-1-any.pkg.tar.xz'
# ENV['R_VERS'] = '2.3.4'

#Prepare.check_openssl