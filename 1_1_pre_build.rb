# frozen_string_literal: true
# encoding: UTF-8

# Code by MSP-Greg
# Reads version.h and adds message to Appveyor build, updates revision.h

module PreBuild

  if ARGV.length == 0
    ARCH = '64'
  elsif ARGV[0] == '32' || ARGV[0] == '64'
    ARCH = ARGV[0]
  else
    puts "Incorrect first argument, must be nil, '32' or '64'"
    exit 1
  end

class << self

  def run
    revision
  end

  private

  def revision
    Dir.chdir( File.join(__dir__, 'ruby') ) { |d|

      str = %x[ruby tool/file2lastrev.rb --revision.h]
      File.write('revision.h', str, mode: 'wb:utf-8')

      svn = %x[git log -n1 --format=%H][0,10]

      branch = `git branch`[/^\* (.+)/, 1].sub(')', '')[/[^ \/]+\Z/]
      # set branch to trunk if it's a commit
      branch = 'master' if /\A[0-9a-f]{7}\Z/ =~ branch

      # open version.h and get ruby info
      version, title = nil, nil

      File.open('version.h', 'rb:utf-8') { |f|
        v_data = f.read
        version = v_data[/^#define[ \t]+RUBY_VERSION[ \t]+["']([\d\.]+)["']/, 1]
        patch   = v_data[/^#define[ \t]+RUBY_PATCHLEVEL[ \t]+(-?\d+)/, 1]
        date    = v_data[/^#define[ \t]+RUBY_RELEASE_YEAR[ \t]+(\d{4})/, 1] + '-' +
                  v_data[/^#define[ \t]+RUBY_RELEASE_MONTH[ \t]+(\d{1,2})/, 1].rjust(2,'0') + '-' +
                  v_data[/^#define[ \t]+RUBY_RELEASE_DAY[ \t]+(\d{1,2})/, 1].rjust(2,'0')
        patch = patch == '-1' ? 'dev' : "p#{patch}"
        arch = ARCH == '64' ? '[x64-mingw32]' : '[i386-mingw32]'
        # update for git commit time as date in RUBY_DESCRIPTION
        date = Time.at(%x[git log -n1 --format=%ct].to_i).utc.strftime('%FT%TZ')[0,10]
        title = "#{patch} (#{date} #{branch} #{svn}) #{arch}".sub(/ +\)/, ')')
      }
      # needed for r66602 and later
      if version.nil?
        File.open('include/ruby/version.h', 'rb:utf-8') { |f|
          v_data = f.read
          version = v_data[/^#define RUBY_API_VERSION_MAJOR (\d+)/, 1] + '.' +
                    v_data[/^#define RUBY_API_VERSION_MINOR (\d+)/, 1] + '.' +
                    v_data[/^#define RUBY_API_VERSION_TEENY (\d+)/, 1]
        }
      end
      title = "ruby #{version}" + title

      # Add title to Appveyor build
      if ENV['APPVEYOR']
        `appveyor UpdateBuild -Message \"#{title}\"`
      end
      puts title
    }
  end

end
end
PreBuild.run
