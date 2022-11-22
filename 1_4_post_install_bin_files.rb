# frozen_string_literal: true

require 'fileutils'

# run from build/installed Ruby
module CopyBashScripts
  BIN_DIR = "#{RbConfig::TOPDIR}/bin"

  class << self

    def run
      # clean empty gem folders, needed as of 2019-10-20
      ary = Dir["#{Gem.dir}/gems/*"]
      ary.each { |d| Dir.rmdir(d) if Dir.empty?(d) }

      bash_preamble = <<~BASH.strip.rstrip
        #!
        {
          bindir=$(dirname "$0")
          exec "$bindir/ruby" "-x" "$0" "$@"
        }
        #!/usr/bin/env ruby
      BASH

      windows_script = <<~BAT
        @ECHO OFF
        @"%~dp0ruby.exe" -x "%~dpn0" %*
      BAT

      # all files in bin folder
      bins = Dir["#{BIN_DIR}/*"].select { |fn| File.file? fn }

      bash_bins = bins.select { |fn| File.extname(fn).empty? }

      # file permissions may not work on Windows, especially execute
      bash_bins.each do |fn|
        ruby_code = File.read(fn, mode: 'rb:UTF-8').split(/^#![^\n]+ruby/,2).last.lstrip
        File.write fn, "#{bash_preamble}\n#{ruby_code}", mode: 'wb:UTF-8'
      end

      windows_bins = bins.select { |fn| File.extname(fn).match?(/\A\.bat|\A\.cmd/) }

      windows_bins.each do |fn|
        # 'gem' bash script doesn't exist
        bash_bin = "#{BIN_DIR}/#{File.basename fn, '.*'}"
        unless File.exist? bash_bin
          ruby_code = File.read(fn, mode: 'rb:UTF-8').split(/^#![^\n]+ruby/,2).last.lstrip
          File.write bash_bin, "#{bash_preamble}\n#{ruby_code}", mode: 'wb:UTF-8'
        end

        File.write fn, windows_script, mode: 'wb:UTF-8'
      end
    end

    def fix_rbs_debug_ext
      debug_gem = Dir.glob("#{Gem.default_dir}/gems/debug-*").first
      debug_name = File.basename debug_gem
      unless File.exist? "#{debug_gem}/lib/debug/debug.so"
        ext_path = "#{Gem.default_dir}/extensions/#{RUBY_PLATFORM.tr '_', '-'}/" \
          "#{RbConfig::CONFIG['ruby_version']}/#{debug_name}"
        if File.exist? "#{ext_path}/debug/debug.so"
          FileUtils.cp "#{ext_path}/debug/debug.so", "#{debug_gem}/lib/debug/debug.so"
        end
      end

      rbs_gem = Dir.glob("#{Gem.default_dir}/gems/rbs-*").first
      rbs_name = File.basename rbs_gem
      unless File.exist? "#{rbs_gem}/lib/rbs_extension.so"
        ext_path = "#{Gem.default_dir}/extensions/#{RUBY_PLATFORM.tr '_', '-'}/" \
          "#{RbConfig::CONFIG['ruby_version']}/#{rbs_name}"
        if File.exist? "#{ext_path}/rbs_extension.so"
          FileUtils.cp "#{ext_path}/rbs_extension.so", "#{rbs_gem}/lib/rbs_extension.so"
        end
      end
    end

  end
end
CopyBashScripts.run
CopyBashScripts.fix_rbs_debug_ext
