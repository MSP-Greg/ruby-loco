# frozen_string_literal: true

# Updates RubyGems for non trunk versions
#
module InstallRubyGemsUpdate

  # ruby name like ruby25_64
  @@pkg_name = ARGV[0]
  # 32 or 64
  @@arch = ARGV[0][-2,2]
  @@carch = @@arch == '64' ? 'x86_64' : 'i686'
  # path to root ruby install dir

  @@pkg_path = File.join(__dir__, 'pkg', @@pkg_name, @@pkg_name)

  def self.run
    update_rubygems
  end

  private

  # Updates Rubygems & bundled gems
  def self.update_rubygems
    gem_version = Gem::VERSION

    require 'rbconfig'
    config = defined?(RbConfig) ? RbConfig : Config
    ruby_exe = File.join config::CONFIG['bindir'], config::CONFIG['ruby_install_name']
    ruby_exe << config::CONFIG['EXEEXT']
    gem_exe    = File.join config::CONFIG['bindir'], 'gem'
    gem_update = File.join config::CONFIG['bindir'], 'update_rubygems'

    if `#{gem_exe} install rubygems-update --no-document`
      up_path = File.join(@@pkg_path, 'lib/ruby/gems', ENV['R_VERS_INT'], 'gems/rubygems-update-')
      t = Dir.glob("#{up_path}*")
      if t && t.length == 1
        puts `#{gem_update}`
        if (gem_version == Gem::VERSION) &&  Dir.exist?(t[0])
          Dir.chdir(t[0]) { puts `#{ruby_exe} setup.rb` }
        end
      end
    end
  end

end
InstallRubyGemsUpdate.run
