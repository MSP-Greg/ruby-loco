# frozen_string_literal: true

module CopyBashScripts
  BIN_DIR = "#{RbConfig::TOPDIR}/bin"

  class << self

    def run
      # clean empty gem folders, needed as of 2019-10-20
      ary = Dir["#{Gem.dir}/gems/*"]
      ary.each { |d| Dir.rmdir(d) if Dir.empty?(d) }

      bash_preamble = <<~BASH.strip.rstrip
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
        File.open(fn, File::RDWR, 0755) do |fio|
          ruby_code = fio.read.split(/^#![^\n]+ruby/,2).last.lstrip
          fio.truncate 0
          fio.seek 0
          fio.write "#{bash_preamble}\n#{ruby_code}"
          fio.chmod 0755
        end
      end

      windows_bins = bins.select { |fn| File.extname(fn).match?(/\A\.bat|\A\.cmd/) }

      windows_bins.each do |fn|
        # 'gem' bash script doesn't exist
        bash_bin = "#{BIN_DIR}/#{File.basename fn, '.*'}"
        unless File.exist? bash_bin
          ruby_code = File.read(fn, mode: 'rb:UTF-8').split(/^#![^\n]+ruby/,2).last.lstrip
          File.write bash_bin, "#{bash_preamble}\n#{ruby_code}", mode: 'wb:UTF-8'
          File.chmod 0755, bash_bin
        end

        File.write fn, windows_script, mode: 'wb:UTF-8'
        File.chmod 0755, fn
      end
    end
  end
end
CopyBashScripts.run
