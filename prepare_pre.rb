# frozen_string_literal: true

# Loads revision.h with svn number, passes two digit ruby version back to
# calling script
#
module PreparePre
  # @return [Integer] two digit ruby version number
  def self.run

    # add git to path
    # ENV['PATH'] += "#{File::PATH_SEPARATOR}#{File.join(__dir__, 'git', 'cmd')}"

    Dir.chdir( File.join(__dir__, 'src', 'ruby') ) { |d|

    branch = `git branch`[/^\* (.+)/, 1].sub(')', '')[/[^ \/]+\Z/]

    # Get svn from commit info, write to revision.h
      svn = (`git log -1`)[/svn\+ssh:\S+?@(\d+)/, 1]
      File.open('revision.h', 'wb:utf-8') { |f| f.write "#define RUBY_REVISION #{svn}\n" }

      # open version.h and get ruby info
      File.open('version.h', 'rb:utf-8') { |f|
        v_data = f.read
        version = v_data[/^#define[ \t]+RUBY_VERSION[ \t]+["']([\d\.]+)["']/, 1]
        patch   = v_data[/^#define[ \t]+RUBY_PATCHLEVEL[ \t]+(-?\d+)/, 1]

        date    = v_data[/^#define[ \t]+RUBY_RELEASE_YEAR[ \t]+(\d{4})/, 1] + '-' +
                  v_data[/^#define[ \t]+RUBY_RELEASE_MONTH[ \t]+(\d{1,2})/, 1].rjust(2,'0') + '-' +
                  v_data[/^#define[ \t]+RUBY_RELEASE_DAY[ \t]+(\d{1,2})/, 1].rjust(2,'0')
        patch = patch == '-1' ? 'dev' : "p#{patch}"
        vers_int = version.sub(/\d+$/, '0')
        vers_2 = version[/\d+\.\d+/].sub('.', '')

        puts "#{version} #{patch} #{date} #{svn} #{vers_int} #{vers_2} #{branch}"
        puts
      }
    }
    0
  end
end
exit PreparePre.run