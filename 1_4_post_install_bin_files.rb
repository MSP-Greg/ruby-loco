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

      windows_script = <<~BAT
        @ECHO OFF
        @"%~dp0ruby.exe" -x "%~dpn0" %*
      BAT

      # all files in bin folder
      bins = Dir["#{BIN_DIR}/*"].select { |fn| File.file? fn }
        .reject { |fn| File.basename(fn, ".*") == 'ridk' }

      bash_bins = bins.select { |fn| File.extname(fn).empty? }

      # file permissions may not work on Windows, especially execute
      bash_bins.each do |fn|
        str = File.read(fn, mode: 'rb:UTF-8').sub(/^#![^\n]+ruby/, '#!/usr/bin/env ruby')
        File.write fn, str, mode: 'wb:UTF-8'
      end

      windows_bins = bins.select { |fn| File.extname(fn).match?(/\A\.bat|\A\.cmd/) }

      windows_bins.each do |fn|
        # 'gem' bash script doesn't exist
        bash_bin = "#{BIN_DIR}/#{File.basename fn, '.*'}"
        unless File.exist? bash_bin
          str = File.read(fn, mode: 'rb:UTF-8').sub(/^#![^\n]+ruby/, '#!/usr/bin/env ruby')
          File.write bash_bin, str, mode: 'wb:UTF-8'
        end

        File.write fn, windows_script, mode: 'wb:UTF-8'
      end
    end
  end
end
CopyBashScripts.run
