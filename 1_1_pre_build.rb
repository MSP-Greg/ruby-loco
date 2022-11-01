# frozen_string_literal: true
# encoding: UTF-8

# Code by MSP-Greg
# Reads version.h and adds message to Appveyor build, updates revision.h
# writes new ruby/win32/ruby.manifest file

module PreBuild

  class << self

    def run
      abi_version = revision[/\A\d+\.\d+/].delete('.') << '0'
      manifest = File.read('manifest_mingw.xml', mode: 'rb').dup
      so_name = case ENV['MSYSTEM']
        when 'UCRT64'  then "x64-ucrt-ruby#{abi_version}.dll"
        when 'MINGW64' then "x64-msvcrt-ruby#{abi_version}.dll"
        else
          raise "Unknown ENV['MSYSTEM'] #{ENV['MSYSTEM']}"
        end

      manifest.sub! 'LIBRUBY_SO', so_name
      File.write 'ruby/win32/ruby.manifest', manifest, mode: 'wb'
    end

    private

    # returns version
    def revision
      File.open('ruby/include/ruby/version.h', 'rb:utf-8') { |f|
        v_data = f.read
        v_data[/^#define RUBY_API_VERSION_MAJOR (\d+)/, 1] + '.' +
        v_data[/^#define RUBY_API_VERSION_MINOR (\d+)/, 1] + '.' +
        v_data[/^#define RUBY_API_VERSION_TEENY (\d+)/, 1]
      }
    end
  end
end
PreBuild.run
