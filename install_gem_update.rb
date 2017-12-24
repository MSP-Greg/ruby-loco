# frozen_string_literal: true

# ruby E:/GitHub/\ruby-loco/install_gem_update.rb

# Updates bundled gems
#
module InstallGemUpdate

  def self.run
    update_gems
    # Change build name to ruby -v
    `appveyor UpdateBuild -Message \"#{RUBY_DESCRIPTION}\"` if ENV['APPVEYOR']
  end

  private

  def self.update_gems
    require 'rubygems'
    require 'rubygems/gem_runner'
    suffix = %w[--no-document --env-shebang --silent]
    if RUBY_VERSION < '2.5'
      Gem::GemRunner.new.run %w[uninstall rubygems-update -x]
      # rdoc won't update without UI confirmation of bin directory file replacement ?
      Gem::GemRunner.new.run(%w[update minitest power_assert rake rdoc test-unit] + suffix)
      if RUBY_VERSION.start_with?('2.4')
        Gem::GemRunner.new.run(%w[update did_you_mean] + suffix)
      elsif RUBY_VERSION.start_with?('2.3')
        Gem::GemRunner.new.run(%w[install did_you_mean:1.0.3] + suffix)
      end
      Gem::GemRunner.new.run %w[cleanup]
      Gem::GemRunner.new.run(%w[install bundler] + suffix)
    else
      Gem::GemRunner.new.run(%w[install bundler] + suffix)
    end

  end

end
InstallGemUpdate.run
