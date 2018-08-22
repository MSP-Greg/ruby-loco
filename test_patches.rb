# frozen_string_literal: true
=begin
ruby C:\Greg\GitHub\ruby-loco\test_patches.rb
=end

module TestPatches

  YELLOW = "\e[33m"
  RESET = "\e[0m"
  
  MSYS2_BIN = "C:/msys64/usr/bin"
  R_VERS   = '2.6.0'
  R_VERS_2 = '26'

  ARCH = '64'

  class << self  

    def run
      @@r_vers_int = vers_str_2_int(R_VERS)
      apply_patches
    end

    private

    # Reads patch dir, applies patches
    def apply_patches
      
      raise ArgumentError, "Argument must 32 or 64" unless ARCH == '32' || ARCH == '64'
      # puts "Dir.pwd #{Dir.pwd}"

      Dir.chdir("#{__dir__}/src/ruby") { |dir|
        # collect patches and apply
        patches = Dir["#{__dir__}/patches/{[^_],#{ARCH}/[^_]}*.patch"]
        patches.concat(vers_patches)
        patches.sort_by! { |p| File.basename(p) }
        patches.each { |p|
          puts "#{YELLOW}#{'—' * 55} #{File.basename(p)}#{RESET}" 
          puts `#{MSYS2_BIN}/patch -p1 -N --no-backup-if-mismatch -i #{p}`
        }
        puts ''  # just for formatting of prepare.log
      }
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
TestPatches.run
