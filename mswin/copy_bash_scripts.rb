# frozen_string_literal: true

module CopyBashScripts
  BIN_DIR = "#{RbConfig::TOPDIR}/bin"
  
  SRC_DIR = "#{Dir.pwd}/src/bin"

  class << self
  
    def run
      bins = Dir["#{SRC_DIR}/*"]

      bins.each do |fn|
        str = File.read(fn, mode: 'rb:UTF-8').sub(/^#![^\n]+ruby/, '#!/usr/bin/env ruby')
        base = File.basename fn
        File.write "#{BIN_DIR}/#{base}", str, mode: 'wb:UTF-8'
      end

      # rake bash bin file
      fn = "#{BIN_DIR}/rake"
      str = File.read(fn, mode: 'rb:UTF-8').sub(/\A#![^\n]+ruby$/, '#!/usr/bin/env ruby')
      File.write fn, str, mode: 'wb:UTF-8'
    end
  end
end
CopyBashScripts.run
