# frozen_string_literal: true

module CopyBashScripts
  BIN_DIR = "#{RbConfig::TOPDIR}/bin"

  SRC_DIR = "#{Dir.pwd}/src/bin"

  class << self

    def run
      # clean empty gem folders, needed as of 2019-10-20
      ary = Dir["#{Gem.dir}/gems/*"]
      ary.each { |d| Dir.rmdir(d) if Dir.empty?(d) }

      bins = Dir["#{SRC_DIR}/*"]

      bins.each do |fn|
        str = File.read(fn, mode: 'rb:UTF-8').sub(/^#![^\n]+ruby/, '#!/usr/bin/env ruby')
        base = File.basename fn
        File.write "#{BIN_DIR}/#{base}", str, mode: 'wb:UTF-8'
      end

      bash_bins = Dir["#{BIN_DIR}/*"].reject { |fn| fn.match?(/\.bat|\.cmd|\.dll|\.exe/) || !File.file?(fn) }
      bash_bins.each do |fn|
        str = File.read(fn, mode: 'rb:UTF-8').sub(/\A.+?ruby$/m, '#!/usr/bin/env ruby')
        File.write fn, str, mode: 'wb:UTF-8'
        File.chmod 755, fn
      end

      # below replaces code in cmd files with hard coded paths
      new_cmd = <<NEW_CMD
@ECHO OFF
@"%~dp0ruby.exe" "%~dpn0" %*
NEW_CMD

      cmd_bins = Dir["#{BIN_DIR}/*.cmd"]
      cmd_bins.each do |fn|
        File.write fn, new_cmd, mode: 'wb:UTF-8'
      end
    end
  end
end
CopyBashScripts.run
